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


import Foundation

// Append-only log file. On open, wipes if larger than `maxBytes`, else appends.
final class SessionLogFile {
  private let h: FileHandle
  let queue = DispatchQueue(label: "sh.blink.zuse.file")

  init(to url: URL, maxBytes: UInt64) throws {
    let fm = FileManager.default
    let attrs: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.none]

    if !fm.fileExists(atPath: url.path) {
      guard fm.createFile(atPath: url.path, contents: nil, attributes: attrs) else {
        throw NSError(domain: NSPOSIXErrorDomain, code: 1)
      }
    } else {
      try fm.setAttributes(attrs, ofItemAtPath: url.path)
    }

    self.h = try FileHandle(forWritingTo: url)

    let size = (try? fm.attributesOfItem(atPath: url.path))?[.size] as? UInt64 ?? 0
    if size > maxBytes {
      h.truncateFile(atOffset: 0)
    } else {
      h.seekToEndOfFile()
    }
  }

  func write(_ data: Data) {
    do {
      try h.write(contentsOf: data)
    } catch {
      debugPrint("Zuse: failed to write log:", error)
    }
  }

  // Waits for pending writes to drain, then flushes to disk.
  func flush() {
    queue.sync { try? h.synchronize() }
  }
}
