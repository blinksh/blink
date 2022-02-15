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
import SSH


struct Archive {
  struct Error: Swift.Error {
    let description: String
    init(_ description: String) {
      self.description = description
    }
  }

  let tmpDirectoryURL: URL

  private init() throws {
    let fm = FileManager.default
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
    
    let fm = FileManager.default

    defer {
      try? encoderStream.close()
      try? encryptionStream.close()
      try? archiveFileStream.close()
      try? fm.removeItem(at: arch.tmpDirectoryURL)
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

  // Recover from an archive file. This operation may overwrite current configuration.
  static func recover(from archiveURL: URL, password: String) throws {
    // Extract
    let homeURL = URL(fileURLWithPath: BlinkPaths.homePath())
    try extract(from: archiveURL, password: password, to: homeURL)

    // Import information (keys)
    try recoverKeys(from: homeURL)
    
    BKHosts.loadHosts()
    BKHosts.resetHostsiCloudInformation()
  }

  static func extract(from archiveURL: URL, password: String, to destinationURL: URL) throws {
#if targetEnvironment(simulator)
    throw Error("Simulator")
#else
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
      throw Error("Error on decryption streams. Bad password?")
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
#endif
  }

  static func recoverKeys(from homeURL: URL) throws {
    let fm = FileManager.default
    let keysDirectoryURL = homeURL.appendingPathComponent(".keys", isDirectory: true)
    let keyNames = try fm.contentsOfDirectory(at: keysDirectoryURL, includingPropertiesForKeys: nil)
      .filter { $0.lastPathComponent.split(separator: ".").count == 1 }
      .map { $0.lastPathComponent }

    defer { try? fm.removeItem(at: keysDirectoryURL) }

    var failedKeys = [String]()
    keyNames.forEach { keyName in
      do {
        if BKPubKey.withID(keyName) != nil {
          throw Error("Key already exists \(keyName)")
        }

        // Import and store
        let keyURL = keysDirectoryURL.appendingPathComponent(keyName)
        let keyBlob = try Data(contentsOf: keyURL)
        //try Data(contentsOf: keyURL.appendingPathExtension("pub"))
        let certBlob = try? Data(contentsOf: keysDirectoryURL.appendingPathComponent("\(keyName)-cert.pub"))
        let pubkeyComponents = try String(contentsOf: keyURL.appendingPathExtension("pub")).split(separator: " ")
        var pubkeyComment = ""
        if pubkeyComponents.count >= 3 {
          pubkeyComment = pubkeyComponents[2...].joined(separator: " ")
        }
        let key = try SSHKey(fromFileBlob: keyBlob, passphrase: "", withPublicFileCertBlob: certBlob)
        if let comment = key.comment,
           !comment.isEmpty {
          try BKPubKey.addKeychainKey(id: keyName, key: key, comment: comment)
        } else {
          try BKPubKey.addKeychainKey(id: keyName, key: key, comment: pubkeyComment)
        }
      } catch {
        failedKeys.append(keyName)
      }
    }
    
    if !failedKeys.isEmpty {
      throw Error("The following keys failed to migrate, please move them manually: \(failedKeys.joined(separator: ", "))")
    }

  }
  private func copyAllDataToTmpDirectory() throws {
    let fm = FileManager.default
    
    // Copy everything
    let blinkURL = BlinkPaths.blinkURL()!
    let sshURL   = BlinkPaths.sshURL()!
    
    // .blink folder
    try fm.copyItem(at: blinkURL, to: tmpDirectoryURL.appendingPathComponent(".blink"))
    try fm.copyItem(at: sshURL, to: tmpDirectoryURL.appendingPathComponent(".ssh"))
    try? fm.removeItem(at: tmpDirectoryURL.appendingPathComponent(".blink/keys"))
    // TODO Remove the keys file, as keys cannot be imported to other app. Not sure this is true
    // within the same version of the app, even across devices, something to test.

    let keysDirectory = tmpDirectoryURL.appendingPathComponent(".keys")
    try fm.createDirectory(at: keysDirectory, withIntermediateDirectories: false, attributes: nil)

    // Read each key and store it within the FS
    // For each identity, get the Privatekey, Publickey and Certificate
    try BKPubKey.all().forEach { card in
      if card.storageType == BKPubKeyStorageTypeSecureEnclave {
        return
      }

      guard let privateKey = card.loadPrivateKey() else {
        throw Error("Could not read private key for \(card.id)")
      }
      let publicKey = card.publicKey
      let cert = card.loadCertificate()

      try privateKey
        .write(to: keysDirectory.appendingPathComponent("\(card.id)"),
                atomically: true, encoding: .utf8)
      try publicKey
        .write(to: keysDirectory.appendingPathComponent("\(card.id).pub"),
                atomically: true, encoding: .utf8)
      try cert?
        .write(to: keysDirectory.appendingPathComponent("\(card.id)-cert.pub"),
                atomically: true, encoding: .utf8)
    }
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
