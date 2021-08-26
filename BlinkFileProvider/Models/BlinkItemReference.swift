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

import Combine
import Foundation
import FileProvider
import MobileCoreServices

import BlinkFiles


// Goal is to bridge the Identifier to the underlying BlinkFiles system, and to offer
// Representations the item.

// TODO Could the BlinkItemReference actually be the FileItem?
// Make the reference work first, and then we can implement more structure around it.
final class BlinkItemReference: NSObject {
  //private let encodedRootPath: String
  // TODO We could also work with a  URL that is not the URL representation,
  // but the URL Identifier. This way we would not have to transform from NSString all the time.
  private let identifier: BlinkItemIdentifier
//  private let path: String
//  private let encodedRootPath: String
  //private let urlRepresentation: URL
  var attributes: BlinkFiles.FileAttributes
  var local: BlinkFiles.FileAttributes?

  var downloadingTask: AnyCancellable? = nil
  var downloadingError: Error? = nil

  // Not sure how to handle the states properly yet
  // A better model may be to handle the correspondence when the file is local vs remote,
  // and what is the status, when it is being read from the remote, or uploaded from it.
  // The state would try to solve the question of what file is the reference that we care about.
  // If the remote is updated, we care about that one, if the local is the reference, then we care about that.
  var isUploading: Bool = false
  var isUploaded: Bool = false
  var uploadingError: Error? = nil

  // MARK: - Enumerator Entry Point:
  // Requires attributes. If you only have the Identifier, you need to go to the DB.
  // Identifier format <encodedRootPath>/path/to/more/components/filename
  init(_ itemIdentifier: BlinkItemIdentifier,
       attributes: BlinkFiles.FileAttributes,
       local: BlinkFiles.FileAttributes? = nil) {
    self.attributes = attributes
    self.identifier = itemIdentifier
    self.local = local
  }
  
  var url: URL {
    identifier.url
  }

  var isDirectory: Bool {
    return (attributes[.type] as? FileAttributeType) == .typeDirectory
  }

  var filename: String {
    return identifier.filename
  }
  
  var permissions: PosixPermissions? {
    guard let perm = attributes[.posixPermissions] as? NSNumber else {
      return nil
    }
    return PosixPermissions(rawValue: perm.int16Value)
  }

  func downloadStarted(_ c: AnyCancellable) {
    downloadingTask = c
    downloadingError = nil
  }

  func downloadCompleted(_ error: Error?) {
    if let error = error {
      downloadingError = error
      downloadingTask = nil
      return
    }

    local = attributes
    downloadingTask = nil
  }
}

// MARK: - NSFileProviderItem

extension BlinkItemReference: NSFileProviderItem {
  var itemIdentifier: NSFileProviderItemIdentifier { identifier.itemIdentifier }
  var parentItemIdentifier: NSFileProviderItemIdentifier { identifier.parentIdentifier }

  // iOS14
  //  var contentType: UTType
  
  var typeIdentifier: String {
    guard let type = attributes[.type] as? FileAttributeType else {
      print("\(itemIdentifier) missing type")
      return ""
    }
    if type == .typeDirectory || type == .typeSymbolicLink {
      return kUTTypeFolder as String
    }
    
    let pathExtension = (filename as NSString).pathExtension
    guard let typeIdentifier = (UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension,
      pathExtension as CFString,
      nil
    )?.takeRetainedValue() as String?) else {
      return kUTTypeItem as String
    }
    
    if typeIdentifier.starts(with: "dyn") {
      return kUTTypeItem as String
    }
    
    return typeIdentifier
  }

  var capabilities: NSFileProviderItemCapabilities {
    guard let permissions = self.permissions else {
      return []
    }
    
    var c = NSFileProviderItemCapabilities()
    
    if isDirectory {
      c.formUnion(.allowsAddingSubItems)
      if permissions.contains(.ux) {
        c.formUnion([.allowsContentEnumerating, .allowsReading])
      }
      if permissions.contains(.uw) {
        c.formUnion([.allowsRenaming, .allowsDeleting])
      }
    } else {
      if permissions.contains(.ur) {
        c.formUnion(.allowsReading)
      }
      if permissions.contains(.uw) {
        c.formUnion([.allowsWriting, .allowsDeleting, .allowsRenaming, .allowsReparenting])
      }
    }

    return c
  }

  var creationDate: Date? {
    attributes[.creationDate] as? Date
  }

  var contentModificationDate: Date? {
    attributes[.modificationDate] as? Date
  }

  var documentSize: NSNumber? {
    isMostRecentVersionDownloaded ? (self.local?[.size] as? NSNumber ?? nil) :
      self.attributes[.size] as? NSNumber
  }

  var childItemCount: NSNumber? {
      return nil
  }
  
  var isTrashed: Bool {
      return false
  }

// TODO We can track from the action, which itself can be part of the reference
//  var isUploading: Bool { reference.isUploading }
//  var isUploaded: Bool { reference.isUploaded }
//  var uploadingError: Error? {
//    fatalError("uploadingError has not been implemented")
//  }
  var isDownloaded: Bool {
    guard let local = self.local else {
      return false
    }
    // TODO Compare local ts with remote
    guard let localModificationDate = local[.modificationDate] as? Date else {
      return false
    }
    guard let remoteModificationDate = self.attributes[.modificationDate] as? Date else {
      return false
    }
    
    return localModificationDate.timeIntervalSinceReferenceDate >= remoteModificationDate.timeIntervalSinceReferenceDate
    //fatalError("isDownloaded has not been implemented")
  }
  
  // TODO Update "local" after download
  var isDownloading: Bool {
    return downloadingTask != nil
//    fatalError("isDownloading has not been implemented")
  }

  // Indicates whether the item is the most recent version downloaded from the server.
  // In our case, there is only one version, so if it is downloaded, it is the most recent
  var isMostRecentVersionDownloaded: Bool { isDownloaded }
}

struct PosixPermissions: OptionSet {
  let rawValue: Int16 // It is really a CShort

  // rwx
  // u[ser]
  static let ur = PosixPermissions(rawValue: 1 << 8)
  static let uw = PosixPermissions(rawValue: 1 << 7)
  static let ux = PosixPermissions(rawValue: 1 << 6)

  // g[roup]
  static let gr = PosixPermissions(rawValue: 1 << 5)
  static let gw = PosixPermissions(rawValue: 1 << 4)
  static let gx = PosixPermissions(rawValue: 1 << 3)

  // o[ther]
  static let or = PosixPermissions(rawValue: 1 << 2)
  static let ow = PosixPermissions(rawValue: 1 << 1)
  static let ox = PosixPermissions(rawValue: 1 << 0)
}
