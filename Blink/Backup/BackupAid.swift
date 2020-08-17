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
import UICKeyChainStore

/**
 Utility to compress & export Blink essential folders: `.ssh` & `.blink`.
 */
@objc class BackupAid: NSObject {
  
  private let _fileManager = FileManager.default
  
  /**
   App document's URL where Blink's files are stored
   */
  var blinksDocumentsUrl: URL? = nil
  
  private let _encoder = JSONEncoder()
  
  private let _decoder = JSONDecoder()
  
  /**
   Structure of folders and files containing data to be exported or saved to backup
   */
  var blinkFolders: [FileToMigrate] = []
  
  override init() {
    super.init()
    
    guard let url = _fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    
    blinksDocumentsUrl = url
  }
  
  /**
   De-base64 the `JSONEncoded` `[FileToMigrate]` data from Blink. Only used  when migrating from Blink 13.
   
   - Parameter xCallbackUrlQueryParameters: Dictionary coming from the `URLQueryItem` containing the backup data in `Base64` `String` form
   - Parameter completion: Optional callback called when the restoration operation finished, set to `true` if the operation was successful and to `false` if it fails
   */
  func deBase64AndRestore(xCallbackUrlQueryParameters: [String: String],_ completion: ((Bool) -> Void)? = nil) {
    
    guard let backUpData = xCallbackUrlQueryParameters.first(where: { $0.key == "backUpData" })?.value else {
      completion?(false)
      return
    }
    
    guard let decodedBackUpData = Data(base64Encoded: backUpData, options: .ignoreUnknownCharacters) else {
      completion?(false)
      return
    }
    
    let blinkItemsToRestore = try? _decoder.decode(BKBackupItemsValues.self, from: decodedBackUpData)
    
    if let fileFoldersData = blinkItemsToRestore?.files {
      _restoreFilesFromMigration(filesData: fileFoldersData)
    }
    
    if let hostsData = blinkItemsToRestore?.hosts {
      _restoreHostsFromMigration(hostsData: hostsData)
    }
    
    if let keysData = blinkItemsToRestore?.keys {
      _restoreKeysFromMigration(keysInBase64: keysData)
    }
    
    completion?(true)
  }
  
  /**
   Given the items to export proceed exporting them and encoding each one as a `Base64` `String` using the respective method for each option.
   
   - Parameters items: Contains the components of the app to export
   - Returns `BKBackupItemValues` containing a `Base64` encoded `String` for each element being exported
   */
  func backUpBlink(items: Set<BKItemsToExport>) -> BKBackupItemsValues {
    
    var backup = BKBackupItemsValues()
    
    for item in items {
      switch item.item {
      case .files:
        if let filesB64 = _migrateFiles() {
          backup.files = filesB64
        }
      case .keys:
        if let keysB64 = _migrateKeys() {
          backup.keys = keysB64
        }
      case .hosts:
        if let hostsB64 = _migrateHosts() {
          backup.hosts = hostsB64
        }
      }
    }
    
    return backup
  }
  
  /**
   Exports the specified contents of Blink in `items` to a file that can be restored later on.
   
   - Parameters items: `Set<BKItemsToExport>` containing the items to export
   - Throws: Error ir the operation fails
   - Returns: The `URL` containing the file being exported.
   */
  func exportBlinkContentsViaFile(items: Set<BKItemsToExport>) throws -> URL? {
    
    let items = backUpBlink(items: items)
    
    guard let encoded = try? _encoder.encode(items) else { return nil }
    
    guard let documentsUrl = blinksDocumentsUrl else { return nil }
    
    let backUpFileName = documentsUrl.appendingPathComponent("backup_\(Date().blinkBackUpDateString).blink")
    
    try? encoded.write(to: backUpFileName, options: .atomic)
    
    return backUpFileName
  }
  
  /**
    Restores the contents and configuration of Blink from a file.
   
   - Parameter url: The `URL` of the file which contains the contents to restore, it has a `.blink` extension
   - Parameter completion: Optional callback called when the restoration operation finished, set to `true` if the operation was successful and to `false` if it fails
   */
  func restoreContentsOfFile(url: URL, _ completion: ((Bool) -> Void)? = nil) {
    
    // Needed to mark this when accessing files inside iCloud
    _ = url.startAccessingSecurityScopedResource()
    let dataContents = try? Data(contentsOf: url)
    url.stopAccessingSecurityScopedResource()
    
    guard let data = dataContents else {
      completion?(false)
      return
    }
    
    guard let decoded = try? _decoder.decode(BKBackupItemsValues.self, from: data) else {
      completion?(false)
      return
    }
    
    if let fileFoldersData = decoded.files {
      _restoreFilesFromMigration(filesData: fileFoldersData)
    }
    
    if let hostsData = decoded.hosts {
      _restoreHostsFromMigration(hostsData: hostsData)
    }
    
    if let keysData = decoded.keys {
      _restoreKeysFromMigration(keysInBase64: keysData)
    }
    
    completion?(true)
  }
  
  
  /**
   Backs up data and share it as base64 to be shared via a x-callback-url. This is intended to be used from Blink13 to move data to Blink14.
   1. Gathers the files and folder structure of Blink's documents, `readFilesAndExport()`
   2. Encode it using a `Codable` structure
   3. `Base64` the encoded data
   4. Share the data via x-callback-url.
   
   - Throws: `throw BackUpAidError.blinkFourteenIsNotInstalled` if the associated x-callback-url couldn't be opened
   */
  @objc func exportBlinkContentsAndConfigurationViaXcallbackUrl() throws {
    
    let itemsToExport: Set<BKItemsToExport> = [
      BKItemsToExport(item: .files, enabled: true),
      BKItemsToExport(item: .hosts, enabled: true),
      BKItemsToExport(item: .keys, enabled: true)
    ]
    
    let exportItems = backUpBlink(items: itemsToExport)
    
    guard let backUpCoded = try? _encoder.encode(exportItems) else { return }
    
    let base64CodedBackup = backUpCoded.base64EncodedString()
    
    var queryComponents: [URLQueryItem] = []
    
    let hostsComponent = URLQueryItem(name: "backUpData", value: base64CodedBackup)
    queryComponents.append(hostsComponent)
    
    
    var xCallbackUrlComponents = URLComponents()
    
    xCallbackUrlComponents.scheme = "sh.blink.shell"
    xCallbackUrlComponents.host = "x-callback-url"
    xCallbackUrlComponents.path = "/restoreBackup"
    
    xCallbackUrlComponents.queryItems = queryComponents
    
    guard let xCallbackUrl = xCallbackUrlComponents.url else { return }
    
    if UIApplication.shared.canOpenURL(xCallbackUrl) {
      blink_openurl(xCallbackUrl)
    } else {
      throw BackUpAidError.blinkFourteenIsNotInstalled
    }
  }
}

// MARK: Files migration

extension BackupAid {
  
  /**
   Detect Blink's current files and returns the structure of it.
   
   - Throws:
    - `BackUpAidError.couldNotReadFilesDocument` if the document's folder couldn't be located
    - `BackUpAidError.couldNotReadFilesContent filePath:`
   - Returns: `[FileToMigrate]` containing for each file the path and contents
   */
  private func _getBlinkFileStructure() throws -> [FileToMigrate] {
    
    blinkFolders = []
    
    guard let documentURL = blinksDocumentsUrl else {
      throw BackUpAidError.couldNotReadFilesDocument
    }
    
    let files = _fileManager.getBlinkFilesUrls()
    
    // With all of the files' URLs read the contents of each one
    for file in files {
      
      let fileFolderPath = file.path.replacingOccurrences(of: _fileManager.currentDirectoryPath, with: "", options: .caseInsensitive, range: nil)

      guard let stringFileContents = try? Data(contentsOf: documentURL.appendingPathComponent(String(fileFolderPath.dropFirst()))) else {
        // If the file's content can't be read throw an error indicating which file couldn't be read.
        continue
      }
      
      let file = FileToMigrate(fileName: String(fileFolderPath.dropFirst()), fileContents: stringFileContents)
      blinkFolders.append(file)
    }
    
    return blinkFolders
  }
  
  private func _migrateFiles() -> String? {
    guard let fileUrls = try? _getBlinkFileStructure() else { return nil }
    
    do {
      let coded = try _encoder.encode(fileUrls)
      
      return coded.base64EncodedString()
      
    } catch {
      print(error.localizedDescription)
      return nil
    }
  }
}


// MARK: Keys migration
extension BackupAid {
  
  /**
   Decode the `Base64` encoded `[KeyToMigrate]` `Codable` structure and saves it to Blink's key store using `BKPubKey.saveCard(:)`
   
   - Parameters:
      - `keysInBase64`: `Base64` encoded `String` containing [KeyToMigrate]
   */
  private func _restoreKeysFromMigration(keysInBase64: String) {
    
    guard let decodedBase64Keys = Data(base64Encoded: keysInBase64, options: .ignoreUnknownCharacters) else { return }
    

    guard let migratedKeys = try? _decoder.decode([KeyToMigrate].self, from: decodedBase64Keys) else {
      return
    }
    
    /**
     Save the migrated keys on the system. Saves `priateKey` in the `UICKeyChainStore` creating a new
     private key reference with the format: `KEY_ID.pem`.
     */
    migratedKeys.forEach({ BKPubKey.saveCard($0.id, privateKey: $0.privateKey, publicKey: $0.publicKey) })
  }
  
  /**
   Read keys stored on device encoding the resulting `Data` into a `Base64` `String` to export them to a new version of Blink.
   
   - Returns:
      - `keysBase64Encoded`:  a `String` containing a `[KeyToMigrate]` encoded in `Base64` to be shared later on with `x-callback-url`
   */
  private func _migrateKeys() -> String? {
    
    let keychainStore = UICKeyChainStore(service: "sh.blink.pkcard")
    
    guard let identities: [BKPubKey] = NSKeyedUnarchiver.unarchiveObject(withFile: BlinkPaths.blinkKeysFile()) as? [BKPubKey] else { return nil }
    
    guard let keysDataArchived = try? NSKeyedArchiver.archivedData(withRootObject: identities, requiringSecureCoding: false) else { return nil }
    
    var keysToMigrate: [KeyToMigrate] = []
    
    for card in identities {
      
      /// Read the private key for the current `BKPubKey` from the `UICKeyChainStore`
      let privateKey = keychainStore.string(forKey: card.id + ".pem") ?? ""
      
      keysToMigrate.append(KeyToMigrate(
                            id: card.id,
                            publicKey: card.publicKey,
                            privateKey: privateKey))
    }
    
    guard let keysAsData = try? _encoder.encode(keysToMigrate) else { return nil }
    
    let keysBase64Encoded = keysAsData.base64EncodedString()
    
    return keysBase64Encoded
  }
}

// MARK: Hosts migration
extension BackupAid {
  
  /**
   Read hosts stored on device encoding the resulting `Data` into a `Base64` `String` to export them to a new version of Blink.
   
   - Returns:
      - `hostsBase64Encoded`:  a `String` containing a `[BKHosts]` encoded in `Base64` to be shared later on with `x-callback-url`
   */
  private func _migrateHosts() -> String? {
    
    guard let hosts: [BKHosts] = NSKeyedUnarchiver.unarchiveObject(withFile: BlinkPaths.blinkHostsFile()) as? [BKHosts] else { return nil }
    
    guard let hostsDataArchived = try? NSKeyedArchiver.archivedData(withRootObject: hosts, requiringSecureCoding: false) else { return nil }
    
    let hostsBase64Encoded = hostsDataArchived.base64EncodedString()
    
    return hostsBase64Encoded
  }
  
  /**
   Decode the `Base64` encoded `[BKHosts]` and append the hosts to the new version of Blink.
   
   - Parameters:
      - `hostsData`: `Base64` encoded `String` containing [KeyToMigrate]
   */
  private func _restoreHostsFromMigration(hostsData: String) {
    
    guard let decodedBase64Hosts = Data(base64Encoded: hostsData, options: .ignoreUnknownCharacters) else { return }
    
    /// Decode the `Data` object casting it as an array of hosts
    guard var migratedHosts = NSKeyedUnarchiver.unarchiveObject(with: decodedBase64Hosts) as? [BKHosts] else {
      return
    }
    
    var hostsToSave: [BKHosts] = migratedHosts
    
    ///  Read the already stored hosts on device
    if let localHosts = NSKeyedUnarchiver.unarchiveObject(withFile: BlinkPaths.blinkHostsFile()) as? [BKHosts] {
      hostsToSave += localHosts
    }
    
    NSKeyedArchiver.archiveRootObject(migratedHosts, toFile: BlinkPaths.blinkHostsFile())
  }
}

// MARK: File/Folder migration
extension BackupAid {
  
  private func _restoreFilesFromMigration(filesData: String) {
    
    guard let documentsUrl = blinksDocumentsUrl else { return }
    
    guard let decodedBase64Data = Data(base64Encoded: filesData, options: .ignoreUnknownCharacters) else { return }
    
    guard let folderStruct = try? _decoder.decode([FileToMigrate].self, from: decodedBase64Data) else { return }
    
    // Iterate through all the files to restore them
    for file in folderStruct {
      
      let filePath = documentsUrl.appendingPathComponent(file.fileName, isDirectory: false)
      let folderUrl = documentsUrl.appendingPathComponent(file.fileName).deletingLastPathComponent()
      
      do {
        try _fileManager.createDirectory(at: folderUrl, withIntermediateDirectories: true, attributes: nil)
        try file.fileContents.write(to: filePath, options: .atomicWrite)
      } catch {
        print(error.localizedDescription)
      }
    }
  }
}
