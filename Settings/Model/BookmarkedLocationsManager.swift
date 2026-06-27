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

    TerminalEnvironment.refreshAllowedPaths()
    return bookmarkedLocation
  }

  func removeLocation(name: String) throws {
    let symlinkURL = symlinkBaseDirectory.appendingPathComponent(name)

    if fm.fileExists(atPath: symlinkURL.path) {
      try? FileManager.default.removeItem(at: symlinkURL)
    }

    var locations = try readLocations()
    if let index = locations.firstIndex(where: { $0.name == name }) {
      let location = locations[index]
      location.url?.stopAccessingSecurityScopedResource()
      locations.remove(at: index)
      try writeLocations(locations)
      TerminalEnvironment.refreshAllowedPaths()
    }
  }

  func getLocations() throws -> [BookmarkedLocation] {
    let storedLocations = try readLocations()
    let validLocations = _syncWithStoredLocations(storedLocations)
    if storedLocations.count != validLocations.count {
      try writeLocations(validLocations)
    }
    return validLocations
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

  private func _syncWithStoredLocations(_ storedLocations: [BookmarkedLocation]) -> [BookmarkedLocation] {
    var validLocations: [BookmarkedLocation] = []

    for location in storedLocations {
      var location = location
      if location.isStale {
        guard let newLocation = try? location.refresh() else { continue }
        if newLocation.isStale {
          continue
        }
        location = newLocation
      }

      guard let url = location.url,
            url.startAccessingSecurityScopedResource() else { continue }
      let symlinkURL = symlinkBaseDirectory.appendingPathComponent(location.name)
      let symlinkPath = symlinkURL.path()

      if (try? fm.attributesOfItem(atPath: symlinkPath)) != nil {
        // If we don't have a symlink anymore, skip to remove the location.
        guard let destPath = try? fm.destinationOfSymbolicLink(atPath: symlinkPath) else {
          continue
        }

        if fm.isReadableFile(atPath: destPath) {
          validLocations.append(location)
          continue
        } else {
          try? fm.removeItem(at: symlinkURL)
        }
      }

      guard (try? fm.createSymbolicLink(at: symlinkURL, withDestinationURL: url)) != nil else {
        continue
      }

      validLocations.append(location)
    }

    return validLocations
  }

  private func writeLocations(_ locations: [BookmarkedLocation]) throws {
    do {
      let data = try JSONEncoder().encode(locations)
      try data.write(to: storedLocationsURL, options: .atomic)
    } catch {
       throw Error.invalidFile(error)
    }
  }

  @objc func getLocationURLs() -> [URL] {
    // After syncing the locations, all of them should have a valid URL.
    (try? self.getLocations().map { $0.url! }) ?? []
  }

  @objc func getLocationPaths() -> [String] {
    (try? self.getLocations().map { $0.url!.path }) ?? []
  }
}
