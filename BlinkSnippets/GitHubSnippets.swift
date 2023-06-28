//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2019 Blink Mobile Shell Project
//
// This file is part of Blink.
//
// Blink is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Blink is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Blink. If not, see <http://www.gnu.org/licenses/>.
//
// In addition, Blink is also subject to certain additional terms under
// GNU GPL version 3 section 7.
//
// You should have received a copy of these additional terms immediately
// following the terms and conditions of the GNU General Public License
// which accompanied the Blink Source Code. If not, see
// <http://www.github.com/blinksh/blink>.
//
////////////////////////////////////////////////////////////////////////////////

import ZIPFoundation

let GITHUB_API = "https://api.github.com"

struct GitHubFetchData: Codable {
  let lastRequestDate: Date
  let etag: String

  static func read(forRepoAt url: URL) throws -> GitHubFetchData? {
    let requestFile = url.appending(path: ".request")
    guard FileManager.default.fileExists(atPath: requestFile.path()) else {
      return nil
    }
    let data = try Data(contentsOf: url.appending(path: ".request"))
    return try JSONDecoder().decode(GitHubFetchData.self, from: data)
  }

  static func save(forRepoAt url: URL, etag: String) throws {
    let fetchData = GitHubFetchData(lastRequestDate: Date(), etag: etag)
    try fetchData.save(forRepoAt: url)
  }
  
  func save(forRepoAt url: URL) throws {
    let data = try JSONEncoder().encode(self)
    try data.write(to: url.appending(path: ".request"))
  }
}

public class GitHubSnippets: LocalSnippets {
  let owner: String
  let repo: String
  let location: URL
  private let rootLocation: URL
  
  public struct InvalidSnippet: Error {
    public let message: String
  }
  
  public override var isReadOnly: Bool { true }
  public override var description: String { "com.github/\(self.owner)/\(self.repo)" }

  public init(owner: String, repo: String, cachedAt location: URL) throws {
    self.owner = owner
    self.repo = repo
    self.rootLocation = location.appending(path: "com.github")
    
    if !FileManager.default.fileExists(atPath: rootLocation.path()) {
      try FileManager.default.createDirectory(at: rootLocation, withIntermediateDirectories: false)
    }
    
    self.location = rootLocation.appending(path: "\(self.owner)-\(self.repo)")
    super.init(from: self.location)
  }

  public override func listSnippets(forceUpdate: Bool = false) async throws -> [Snippet] {
    if forceUpdate {
      try await update(previous: nil)
    } 

    let (needsUpdate, previousFetchData) = try needsUpdate()
    if needsUpdate {
      try await update(previous: previousFetchData)
    }

    return try await super.listSnippets(forceUpdate: forceUpdate)
  }
  
  func needsUpdate() throws -> (Bool, GitHubFetchData?) {
    let fm = FileManager.default
    
    if fm.fileExists(atPath: self.location.path()),
       let fetchData = try GitHubFetchData.read(forRepoAt: self.location) {
      let elapsed = fetchData.lastRequestDate.distance(to: Date())
      
      if elapsed > 3600 * 24 {
        return (true, fetchData)
      } else {
        return (false, nil)
      }
    } else {
      return (true, nil)
    }
  }
  
  func update(previous previousFetchData: GitHubFetchData?) async throws {
    let fm = FileManager.default
    
    // NOTE If we used this format for other parts (ie themes and fonts), we could separate
    // to its own class.

    // Get the repository to a temporary location
    let downloadUrl = URL(string: "\(GITHUB_API)/repos/\(self.owner)/\(self.repo)/zipball")!
    var request = URLRequest(url: downloadUrl)
    if let etag = previousFetchData?.etag {
      request.addValue(etag, forHTTPHeaderField: "If-None-Match")
      request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
    }

    let (data, response): (Data, URLResponse) = try await URLSession.shared.data(for: request)
    let httpResponse = response as! HTTPURLResponse
    
    guard let etag = httpResponse.allHeaderFields["Etag"] as? String else {
      throw InvalidSnippet(message: "Missing ETag on GitHub response")
    }
    if httpResponse.statusCode == 304 {
      // Update the fetch
      try GitHubFetchData.save(forRepoAt: self.location, etag: etag)
      return
    } else if httpResponse.statusCode != 200 {
      throw InvalidSnippet(message: "Request error")
    }


    guard let archive = Archive(data: data, accessMode: .read) else {
      throw Archive.ArchiveError.unreadableArchive
    }
    let tmpDirectoryURL = try fm.url(for: .itemReplacementDirectory,
                                 in: .userDomainMask,
                                 appropriateFor: self.location,
                                 create: true)
    try fm.unzipItem(archive: archive, to: tmpDirectoryURL)

    // GH repos are contained in a folder with the reference.
    guard let firstElement = archive.makeIterator().next(),
          firstElement.type == .directory else {
      throw InvalidSnippet(message: "Wrong archive format for snippets")
    }
    let repositoryDirectoryPath = firstElement.path
    guard var repositoryRef = repositoryDirectoryPath.split(separator: "-").last else {
      throw InvalidSnippet(message: "Snippets archive missing reference")
    }
    repositoryRef.removeLast()
    
    // Rename the folder to the final name inside the tmp folder
    let tmpRepositoryURL = tmpDirectoryURL.appending(path: "\(self.owner)-\(self.repo)")
    try fm.moveItem(at: tmpDirectoryURL.appending(path: repositoryDirectoryPath), to: tmpRepositoryURL)

    // Replace previous collection with new one
    if fm.fileExists(atPath: self.location.path()) {
      try fm.removeItem(at: self.location)
    }
    try fm.moveItem(at: tmpRepositoryURL, to: self.location)
    try fm.removeItem(at: tmpDirectoryURL)

    // Save new fetch data
    try GitHubFetchData.save(forRepoAt: self.location, etag: etag)
  }
}

extension FileManager {
  public func unzipItem(archive: Archive, to destinationURL: URL) throws {
    let sortedEntries = archive.sorted { (left, right) -> Bool in
        switch (left.type, right.type) {
        case (.directory, .file): return true
        case (.directory, .symlink): return true
        case (.file, .symlink): return true
        default: return false
        }
    }
    
    for entry in sortedEntries {
      let path = entry.path
      let entryURL = destinationURL.appendingPathComponent(path)
      guard entryURL.isContained(in: destinationURL) else {
        throw CocoaError(.fileReadInvalidFileName,
                         userInfo: [NSFilePathErrorKey: entryURL.path])
      }
      let _ = try archive.extract(entry, to: entryURL)
    }
  }
}
