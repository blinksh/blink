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
import System
import AppleArchive
import CryptoKit

import BlinkConfig


struct Archive {
  struct Error: Swift.Error {
    let description: String
    init(_ description: String) {
      self.description = description
    }
  }

  let tmpDirectoryURL: URL
  let fm = FileManager.default

  private init() throws {
    try self.tmpDirectoryURL = fm.url(for: .itemReplacementDirectory,
                                      in: .userDomainMask,
                                      appropriateFor: BlinkPaths.blinkURL(),
                                      create: true)
  }
  
  static func export(to archiveURL: URL, password: String) throws {
    #if targetEnvironment(simulator)
    throw Error("Simulator")
    #else
    
    // Copy everything to the temporary directory
    // Import keys there
    let arch = try Archive()
    try arch.copyAllDataToTmpDirectory()

    guard let context = arch.createEncryptionContext(password) else {
      throw Error("Could not create encryption for given password")
    }
    guard let sourcePath = FilePath(arch.tmpDirectoryURL) else {
      throw Error("Bad source for archive")
    }
    guard let destinationPath = FilePath(archiveURL) else {
      throw Error("Bad destination for archive")
    }

    guard
      let archiveFileStream = ArchiveByteStream.fileStream(
        path: destinationPath,
        mode: .writeOnly,
        options: [.create, .truncate],
        permissions: FilePermissions(rawValue: 0o644)
      )
    else {
      throw Error("Could not create File Stream")
    }
    
    guard
      let encryptionStream = ArchiveByteStream.encryptionStream(
        writingTo: archiveFileStream,
        encryptionContext: context),

      let encoderStream = AppleArchive.ArchiveStream.encodeStream(writingTo: encryptionStream)
    else {
      throw Error("Could not create encryption streams for archive")
    }

    defer {
      try? encoderStream.close()
      try? encryptionStream.close()
      try? archiveFileStream.close()
      try? arch.fm.removeItem(at: arch.tmpDirectoryURL)
    }

    // Archive
    do {
      try encoderStream.writeDirectoryContents(archiveFrom: sourcePath, keySet: .defaultForArchive)// (archiveFrom: source, path: .FieldKeySet("*"))
    } catch {
      throw Error("Writing directory contents - \(error)")
    }
    #endif
    // TODO Open on the other side, the activateFileViewerSelecting
  }
  
  static func recover(from archiveURL: URL, password: String) throws {
    // Extract
    // Import information (keys)
    // We may want to create a command so everything is extracted, and then keys can be imported separately.
  }

  static func extract(from archiveURL: URL, password: String, to destinationURL: URL) throws {
    guard let sourcePath = FilePath(archiveURL) else {
      throw Error("Wrong source path.")
    }
    guard let destinationPath = FilePath(destinationURL) else {
      throw Error("Wrong destination path.")
    }

    guard let archiveFileStream = ArchiveByteStream.fileStream(
      path: sourcePath,
      mode: .readOnly,
      options: [],
      permissions: []), 

      let context = ArchiveEncryptionContext(from: archiveFileStream)      
    else {
      throw Error("Invalid archive file")
    }

    guard let sKey = SymmetricKey(fromPassword: password) else {
      throw Error("Invalid password for key")
    }

    do {
      try context.setSymmetricKey(sKey)
    } catch {
      throw Error("Invalid password for key")
    }

    guard 
      let decryptionStream = ArchiveByteStream.decryptionStream(
        readingFrom: archiveFileStream,
        encryptionContext: context),

      let decoderStream = ArchiveStream.decodeStream(readingFrom: decryptionStream)
    else {
      throw Error("Error creating decryption streams.")
    }
    
    guard let extractStream = ArchiveStream.extractStream(extractingTo: destinationPath) else {
      throw Error("Error creating extraction stream.")
    }

    defer {
      try? archiveFileStream.close()
      try? decryptionStream.close()
      try? decoderStream.close()
      try? extractStream.close()
    }

    do {
      try ArchiveStream.process(readingFrom: decoderStream, writingTo: extractStream)
    } catch {
      throw Error("Error extracting archive elements. \(error)")
    }
  }

  private func copyAllDataToTmpDirectory() throws {
    // Copy everything
    let blinkURL = BlinkPaths.blinkURL()!
    
    // .blink folder
    try fm.copyItem(at: blinkURL, to: tmpDirectoryURL.appendingPathComponent(".blink"))

    // Read each key and store it within the FS    
  }
  // static func import(from path: URL, password: String) {}

  #if !targetEnvironment(simulator)
  private func createEncryptionContext(_ password: String) -> ArchiveEncryptionContext? {
    // Configure encryption
//    let sKey = SymmetricKey(size: .bits256)
    guard let sKey = SymmetricKey(fromPassword: password) else {
      return nil
    }
    let context = ArchiveEncryptionContext(
      profile: .hkdf_sha256_aesctr_hmac__symmetric__none,
      compressionAlgorithm: .lzfse
    )

    do {
      try context.setSymmetricKey(sKey)
      return context
    } catch {
      return nil
    }
  }
  #endif
}

extension SymmetricKey {
  init?(fromPassword password: String) {
    guard let passwordData = password.data(using: .utf8),
          let passwordHash = String(
            // 256-bit hash
            SHA256.hash(data: passwordData).map({ String(format: "%02hhx", $0) }).joined().prefix(32)
          ).data(using: .utf8)
           else {
        return nil
      }

    self = SymmetricKey(data: passwordHash)
  }
}
