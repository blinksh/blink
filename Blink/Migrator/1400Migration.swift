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
import CoreData


class MigrationToAppGroup: MigrationStep {
  var version: Int { get { 1400 } }
  
  func execute() throws {
    // Creating a temporary folder tmp-migration-1400
    
    let homePath      = BlinkPaths.homePath() as NSString
    let documentsPath = BlinkPaths.documentsPath() as NSString
    
    try [".blink", ".ssh"].forEach {
      try copyFiles(original: documentsPath.appendingPathComponent($0),
                    destination: homePath.appendingPathComponent($0),
                    attributes: $0 == ".blink")
    }
  }
  
  func copyFiles(original: String, destination: String, attributes: Bool) throws {
    let fm = FileManager.default

    let tmpDirectoryPath = BlinkPaths.homePath() + "-1400-migration"
    try? fm.removeItem(atPath: tmpDirectoryPath)
    try fm.createDirectory(atPath: tmpDirectoryPath,
                           withIntermediateDirectories: true,
                           attributes: nil)
    defer { try? fm.removeItem(atPath: tmpDirectoryPath) }
    print("Temporary directory created")
    
    if fm.fileExists(atPath: destination) {
      print("Destination files exist")
      try fm.contentsOfDirectory(atPath: destination).forEach { fileName in
        let filePath = (destination as NSString).appendingPathComponent(fileName)
        print("Creating file \(filePath)")
        let tmpFilePath = (tmpDirectoryPath as NSString).appendingPathComponent(fileName)
        try fm.copyItem(atPath: filePath, toPath: tmpFilePath)
        print("Created file \(filePath)")
      }
    } else {
      print("Destination does not exist. Creating...")
      try fm.createDirectory(atPath: destination,
                             withIntermediateDirectories: true,
                             attributes: nil)
    }
    
    if fm.fileExists(atPath: original) {
      print("Original files exist")

      try fm.contentsOfDirectory(atPath: original).forEach { fileName in
        let filePath = (original as NSString).appendingPathComponent(fileName)
        print("Creating file \(filePath)")
        let tmpFilePath = (tmpDirectoryPath as NSString).appendingPathComponent(fileName)

        if !fm.fileExists(atPath: tmpFilePath) {
          try fm.copyItem(atPath: filePath, toPath: tmpFilePath)
          print("Created file \(filePath)")
        } else {
          print("File \(filePath) already created")
        }
      }
    }
    
    try fm.contentsOfDirectory(atPath: tmpDirectoryPath).forEach { fileName in
      let tmpItem = URL(fileURLWithPath: tmpDirectoryPath).appendingPathComponent(fileName)
      let originalItem = URL(fileURLWithPath: destination).appendingPathComponent(fileName)

      if fm.fileExists(atPath: originalItem.path) {
        print("Replacing \(originalItem.path)")
        try fm.replaceItemAt(originalItem, withItemAt: tmpItem)
      } else {
        print("Copying to \(originalItem.path)")
        try fm.copyItem(at: tmpItem, to: originalItem)
      }
      if attributes {
        try fm.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: originalItem.path)
      }
    }
  }
}
