//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2024 Blink Mobile Shell Project
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

import BlinkConfig

struct BookmarkedLocation: Codable, Identifiable {
  var id: String { self.name }
  let name: String
  private let bookmarkData: Data
  let url: URL?
  let isStale: Bool
  // Whether the bookmark is currently reachable. Not persisted.
  var isAvailable: Bool = true

  fileprivate init(name: String, location: URL) throws {
    self.name = name
    self.isStale = false
    self.bookmarkData = try location.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
    self.url = location
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.name = try container.decode(String.self, forKey: .name)
    self.bookmarkData = try container.decode(Data.self, forKey: .bookmarkData)
    var isStale = false
    if let url = try? URL(resolvingBookmarkData: bookmarkData, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &isStale) {
      self.url = url
    } else {
      // The URL can still fail internally (with a "no file provider found" error), even though the underlying data is correct.
      // I think this should have been handled through a "stale" state instead, so I follow that here.
      self.url = nil
      isStale = true
    }
    self.isStale = isStale
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(name, forKey: .name)
    try container.encode(bookmarkData, forKey: .bookmarkData)
  }

  private enum CodingKeys: String, CodingKey {
    case name, bookmarkData
  }

  func refresh() throws -> BookmarkedLocation {
    guard let url = self.url else {
      return self
    }
    return try Self(name: name, location: url)
  }
}

@objc class BookmarkedLocationsManager: NSObject {
  let symlinkBaseDirectory: URL
  @objc static let `default` = BookmarkedLocationsManager(storedLocationsDirectory: BlinkPaths.blinkURL(),
                                                    symlinkBaseDirectory: BlinkPaths.homeURL())
  private let storedLocationsURL: URL

  private let fm = FileManager.default


  enum Error: Swift.Error {
    case locationNameExists
    case locationNotAvailable
    case invalidFile(Swift.Error)
  }

  private init(storedLocationsDirectory: URL, symlinkBaseDirectory: URL) {
    self.symlinkBaseDirectory = symlinkBaseDirectory
    self.storedLocationsURL = storedLocationsDirectory.appendingPathComponent(".locations.json")
  }

  func addLocation(name: String, location: URL) throws -> BookmarkedLocation {
    let symlinkURL = symlinkBaseDirectory.appendingPathComponent(name)

    if fm.fileExists(atPath: symlinkURL.path()) {
      throw Self.Error.locationNameExists
    }

    var storedLocations = try readLocations()

    guard location.startAccessingSecurityScopedResource() else {
      throw Self.Error.locationNotAvailable
    }

    try fm.createSymbolicLink(at: symlinkURL, withDestinationURL: location)

    let bookmarkedLocation: BookmarkedLocation
    do {
      bookmarkedLocation = try BookmarkedLocation(name: name, location: location)
      storedLocations.append(bookmarkedLocation)
      try writeLocations(storedLocations)
    } catch {
      try? FileManager.default.removeItem(at: symlinkURL)
      throw error
    }

    return bookmarkedLocation
  }

  func removeLocation(name: String) throws {
    let symlinkURL = symlinkBaseDirectory.appendingPathComponent(name)

    // removeItem targets the symlink itself, so a dangling link is cleared too.
    try? fm.removeItem(at: symlinkURL)

    var locations = try readLocations()
    if let index = locations.firstIndex(where: { $0.name == name }) {
      let location = locations[index]
      location.url?.stopAccessingSecurityScopedResource()
      locations.remove(at: index)
      try writeLocations(locations)
    }
  }

  /// The stored bookmarks with their current availability.
  func getLocations() throws -> [BookmarkedLocation] {
    _activate(try readLocations())
  }

  /// Makes every stored bookmark usable this session, flagging the unreachable ones.
  @discardableResult
  private func _activate(_ storedLocations: [BookmarkedLocation]) -> [BookmarkedLocation] {
    storedLocations.map { stored in
      var location = stored
      if location.isStale,
         let refreshed = try? location.refresh(), !refreshed.isStale {
        location = refreshed
      }
      if let url = location.url, url.startAccessingSecurityScopedResource() {
        _ensureSymlink(name: location.name, target: url)
        location.isAvailable = true
      } else {
        location.isAvailable = false
      }
      return location
    }
  }

  private func _ensureSymlink(name: String, target: URL) {
    let symlinkURL = symlinkBaseDirectory.appendingPathComponent(name)
    let symlinkPath = symlinkURL.path()
    if (try? fm.attributesOfItem(atPath: symlinkPath)) != nil {
      if let destPath = try? fm.destinationOfSymbolicLink(atPath: symlinkPath),
         fm.isReadableFile(atPath: destPath) {
        return
      }
      try? fm.removeItem(at: symlinkURL)
    }
    try? fm.createSymbolicLink(at: symlinkURL, withDestinationURL: target)
  }

  private func readLocations() throws -> [BookmarkedLocation] {
    do {
      guard fm.fileExists(atPath: storedLocationsURL.path()) else {
        try? self.writeLocations([])
        return []
      }
      let data = try Data(contentsOf: storedLocationsURL)
      let locations = try JSONDecoder().decode([BookmarkedLocation].self, from: data)
      return locations
    } catch {
      throw Error.invalidFile(error)
    }
  }

  private func writeLocations(_ locations: [BookmarkedLocation]) throws {
    do {
      let data = try JSONEncoder().encode(locations)
      try data.write(to: storedLocationsURL, options: .atomic)
    } catch {
       throw Error.invalidFile(error)
    }
  }

  /// Re-acquire the security scope for every bookmark.
  @objc func activateAccess() {
    _ = try? getLocations()
  }

  @objc func getLocationURLs() -> [URL] {
    ((try? readLocations()) ?? []).compactMap { $0.url }
  }

  @objc func getLocationPaths() -> [String] {
    ((try? readLocations()) ?? []).compactMap { $0.url?.path }
  }
}
