//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2026 Blink Mobile Shell Project
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


// Wipes the session store's on-disk state. The TermSessionPayload / SessionParams
// data types changed in a way that is incompatible with previously suspended
// sessions, and migrating the old archives is not worth the effort.
class MigrationWipeSessionStore: MigrationStep {
  var version: Int { get { 1870 } }

  func execute() throws {
    let fm = FileManager.default

    let supportDirURL = try fm.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: false
    )
    let sessionsFolderURL = supportDirURL.appendingPathComponent("sessions")

    guard fm.fileExists(atPath: sessionsFolderURL.path) else {
      return
    }

    let contentURLs = (try? fm.contentsOfDirectory(at: sessionsFolderURL,
                                                   includingPropertiesForKeys: nil,
                                                   options: [])) ?? []

    for url in contentURLs {
      do {
        try fm.removeItem(at: url)
      } catch {
        print("Failed to remove \(url.path): \(error)")
      }
    }
  }
}
