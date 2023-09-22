//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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


import Foundation

public class LocalSnippets: SnippetContentLocation {
  let sourcePathURL: URL

  public var isReadOnly: Bool { false }
  public var description: String { "local/" + self.sourcePathURL.lastPathComponent }
  
  public init(from sourcePathURL: URL) {
    self.sourcePathURL = sourcePathURL
  }

  public func listSnippets(forceUpdate: Bool = false) async throws -> [Snippet] {
    return try listSnippets(atPath: "")
  }

  private func listSnippets(atPath path: String) throws -> [Snippet] {
    let folders = try sourcePathURL.appendingPathComponent(path).subDirectories()

    let snippets = try folders
      .filter { $0.lastPathComponent.first != "." }
      .flatMap { folder in
        let folderName = path == "" ? folder.lastPathComponent : "\(path)/\(folder.lastPathComponent)"
        return (try listSnippets(atPath: folderName)) +
          (try folder.files().map { fileName in
            let name = fileName.lastPathComponent
            return Snippet(name: name, folder: folderName, store: self)
           })
      }

    return snippets
  }

  public func readContent(folder: String, name: String) throws -> String {
    try String(contentsOf: snippetLocation(folder: folder, name: name))
  }

  public func readDescription(folder: String, name: String) throws -> String {
    snippetLocation(folder: folder, name: name).readFirstLineOfContent() ?? ""
  }

  func snippetLocation(folder: String, name: String) -> URL {
    self.sourcePathURL.appendingPathComponent("\(folder)/\(name)")
  }
  
  public func snippetLocationURL(folder: String, name: String) -> URL? {
    self.snippetLocation(folder: folder, name: name)
  }

  public func saveSnippet(folder: String, name: String, content: String) throws -> Snippet {
    // Write to local file.
    // Other locations may try to write to the remote before, etc...
    let folderURL = self.sourcePathURL.appendingPathComponent("\(folder)")

    if !((try? folderURL.checkResourceIsReachable()) ?? false) {
      try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    try content.write(to: snippetLocation(folder: folder, name: name), atomically: false, encoding: .utf8)
    return Snippet(name: name, folder: folder, store: self)
  }

  public func deleteSnippet(folder: String, name: String) throws {
    let fm = FileManager.default
    let location = snippetLocation(folder: folder, name: name)
    if try location.checkResourceIsReachable() {
      try fm.removeItem(at: location)
    }
  }
}

// iCloudSnippets can handle the iCloud interface to track changes to files.

extension URL {
  func subDirectories() throws -> [URL] {
    // @available(macOS 10.11, iOS 9.0, *)
    guard hasDirectoryPath else { return [] }
    return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]).filter(\.hasDirectoryPath)
  }

  func files() throws -> [URL] {
    // @available(macOS 10.11, iOS 9.0, *)
    guard hasDirectoryPath else { return [] }
    return try FileManager.default.contentsOfDirectory(at: self, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]).filter { try $0.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile! }
  }

  // TODO We may want to protect this with a max line size.
  func readFirstLineOfContent() -> String? {
    guard let inputStream = InputStream(url: self) else {
      return nil
    }
    inputStream.open()
    defer {
      inputStream.close()
    }
    var buffer = [UInt8](repeating: 0, count: 1024)
    var string = ""
    while inputStream.hasBytesAvailable {
      let bytesRead = inputStream.read(&buffer, maxLength: buffer.count)
      if bytesRead == -1 {
        // Handle read error
        //
        // iCloud Drive snippets could timeout read operation
        // should we indicate that to user?
        if let error = inputStream.streamError as? NSError {
//          if error.code == POSIXErrorCode.ETIMEDOUT.rawValue {
//          }
          print("readFirstLineOfContent: \(error)")
        } else {
          print("-1 but not NSError")
        }
        return nil
//        break;
      }
      if bytesRead == 0 {
        break
      }
      if let range = buffer.prefix(bytesRead).firstIndex(of: 10) { // Look for the first newline character
        let line = buffer.prefix(upTo: range)
        string += String(bytes: line, encoding: .utf8) ?? ""
        break
      } else {
        string += String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
      }
    }
    return string
  }
}
