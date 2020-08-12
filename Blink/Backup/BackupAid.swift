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

enum BackUpAidError: Error {
  case blinkFourteenIsNotInstalled
  case couldNotReadFilesContent(filePath: String)
  case couldNotReadFilesDocument
  
}

extension BackUpAidError: LocalizedError {
  public var errorDescription: String? {
    switch self {
    case .blinkFourteenIsNotInstalled:
      return "Error opening the newest version of Blink to restore your data. If you don't have Blink 14 install it from the App Store and come back to this to migrate your personal data."
    case .couldNotReadFilesContent(let path):
      return "Could not read the contents of file at path \(path)"
    case .couldNotReadFilesDocument:
      return "Could not read data from the document's folder"
    }
  }
}


/**
 Utility to compress & export Blink essential folders: `.ssh` & `.blink`.
 */
@objc class BackupAid: NSObject {
  
  private let _fileManager = FileManager.default
  
  /**
   App document's URL where Blink's files are stored
   */
  var documentURL: URL? = nil
  
  /**
   Encodes `[FileToMigrate]`
   */
  private let _encoder = JSONEncoder()
  /**
   Decodes `[FileToMigrate]`
   */
  private let _decoder = JSONDecoder()
  
  /**
   Structure of folders and files containing data to be exported or saved to backup
   */
  var blinkFolders: [FileToMigrate] = []
  
  override init() {
    super.init()
    
    guard let url = _fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return
    }
    
    documentURL = url
    
  }
  
  /**
   De-base64 the `JSONEncoded` `[FileToMigrate]` data from Blink.
   */
  func deBase64AndRestore(backUpData: String) {
    
    guard let documentsUrl = documentURL else { return }
    
    guard let decodedBase64Data = Data(base64Encoded: backUpData, options: .ignoreUnknownCharacters) else { return }
    
    guard let folderStruct = try? _decoder.decode([FileToMigrate].self, from: decodedBase64Data) else { return }
    
    // Iterate through all the files to restore them
    for file in folderStruct {
      
      let filePath = documentsUrl.appendingPathComponent(file.fileName)
      
      guard (try? file.fileContents.write(to: filePath)) != nil else { return }
    }
  }
  
  /**
   Read the files & folder structure, encode the `[FileToMigrate]` resulting `Codable` struct and then `Base64` the result.
   
   - Returns: `String` Base64 encoded containing a JSONEncoded `[FileToMigrate]`
   - Throws: `Error`
   */
  private func _getBlinkFoldersAsBase64() throws -> String {
    
    do {
      let readFiles = try _getBlinkFileStructure()
      
      do {
        let coded = try _encoder.encode(readFiles)
        
        return coded.base64EncodedString()
        
      } catch {
        print(error.localizedDescription)
        throw error
      }
      
    } catch {
      throw error
    }
  }
  
  /**
   Backs up data and share it as base64 to be shared via a x-callback-url. This is intended to be used from Blink13 to move data to Blink14.
   1. Gathers the files and folder structure of Blink's documents, `readFilesAndExport()`
   2. Encode it using a `Codable` structure
   3. `Base64` the encoded data
   4. Share the data via x-callback-url.
   
   - Throws: `throw BackUpAidError.blinkFourteenIsNotInstalled` if the associated x-callback-url couldn't be opened
   */
  @objc func copyBlinkFilesAndShareViaXcallbackUrl() throws {
    
    do {
      let base64BackupData = try _getBlinkFoldersAsBase64()
      
      guard let xCallbackUrl = URL(string: "sh.blink.shell://x-callback-url/restoreBackup?data=\(base64BackupData)") else { return }
      
      if UIApplication.shared.canOpenURL(xCallbackUrl) {
        blink_openurl(xCallbackUrl)
      } else {
        throw BackUpAidError.blinkFourteenIsNotInstalled
      }
    } catch {
      throw error
    }
  }
  
  /**
   Detect Blink's current files and returns the structure of it.
   
   - Throws:
    - `BackUpAidError.couldNotReadFilesDocument` if the document's folder couldn't be located
    - `BackUpAidError.couldNotReadFilesContent filePath:`
   - Returns: `[FileToMigrate]` containing for each file the path and contents
   */
  private func _getBlinkFileStructure() throws -> [FileToMigrate] {
    
    blinkFolders = []
    
    guard let documentURL = documentURL else {
      throw BackUpAidError.couldNotReadFilesDocument
    }
    
    guard let directoryContents = try? _fileManager.contentsOfDirectory(at: documentURL, includingPropertiesForKeys: nil, options: []) else {
      throw BackUpAidError.couldNotReadFilesDocument
    }
    
    for folder in directoryContents {
      
      let fileFolderPath = folder.path.replacingOccurrences(of: _fileManager.currentDirectoryPath, with: "", options: .caseInsensitive, range: nil)
      
      if !folder.hasDirectoryPath {
        
        
        guard let stringFileContents = try? Data(contentsOf: documentURL.appendingPathComponent(String(fileFolderPath.dropFirst()))) else {
          // If the file's content can't be read throw an error indicating which file couldn't be read.
          continue
        }
        
        let file = FileToMigrate(fileName: String(fileFolderPath.dropFirst()), fileContents: stringFileContents)
        blinkFolders.append(file)
        
      } else {
        
        // Get the files in directory
        guard let subFolderFiles = try? _fileManager.contentsOfDirectory(at: documentURL.appendingPathComponent(String(fileFolderPath.dropFirst())), includingPropertiesForKeys: nil, options: []) else {
          continue
        }
        
        for file in subFolderFiles {
          
          guard let stringFileContents = try? Data(contentsOf: file) else {
            // If the file's content can't be read throw an error indicating which file couldn't be read.
            throw BackUpAidError.couldNotReadFilesContent(filePath: file.lastPathComponent)
          }
          
          
          let currentFile = FileToMigrate(fileName: String(fileFolderPath.dropFirst()) + "/" + file.lastPathComponent, fileContents: stringFileContents)
          blinkFolders.append(currentFile)
        }
      }
    }
    
    return blinkFolders
  }
  
}
