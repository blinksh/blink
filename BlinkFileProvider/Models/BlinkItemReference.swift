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
// Representations of the item.
final class BlinkItemReference: NSObject {
  private let identifier: BlinkItemIdentifier
  var remote: BlinkFiles.FileAttributes?
  var local: BlinkFiles.FileAttributes?
  
  var primary: BlinkFiles.FileAttributes = [:]
  var replica: BlinkFiles.FileAttributes?

  var isDownloaded: Bool = false
  var downloadingTask: AnyCancellable? = nil
  var downloadingError: Error? = nil

  var uploadingTask: AnyCancellable? = nil
  var isUploaded: Bool = false
  var uploadingError: Error? = nil

  // MARK: - Enumerator Entry Point:
  // Requires attributes. If you only have the Identifier, you need to go to the DB.
  // Identifier format <encodedRootPath>/path/to/more/components/filename
  init(_ itemIdentifier: BlinkItemIdentifier,
       remote: BlinkFiles.FileAttributes? = nil,
       local: BlinkFiles.FileAttributes? = nil) {
    self.remote = remote
    self.identifier = itemIdentifier
    self.local = local

    super.init()

    evaluate()
  }

  func updateAttributes(remote: BlinkFiles.FileAttributes, local: BlinkFiles.FileAttributes? = nil) {
    self.remote = remote
    if let local = local {
      self.local = local
    }
    evaluate()
  }
  
  private func evaluate() {
    guard let remoteModified = (remote?[.modificationDate] as? Date) else {
      primary = local!
      replica = nil
      isDownloaded = false
      return
    }

    guard let localModified = (local?[.modificationDate] as? Date) else {
      primary = remote!
      replica = nil
      isDownloaded = false
      return
    }

    if remoteModified > localModified {
      primary = remote!
      replica = local
      isDownloaded = false
      isUploaded = true
    } else if remoteModified == localModified {
      primary = remote!
      replica = local
      isDownloaded = true
      isUploaded = true
    } else {
      primary = local!
      replica = primary
      // TODO Not sure in this case.
      isDownloaded = true
      isUploaded = false
    }
  }

  var url: URL {
    identifier.url
  }

  var isDirectory: Bool {
    return (primary[.type] as? FileAttributeType) == .typeDirectory
  }

  var filename: String {
    return identifier.filename
  }
  
  var permissions: PosixPermissions? {
    guard let perm = primary[.posixPermissions] as? NSNumber else {
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

    local = remote
    evaluate()
    downloadingTask = nil
  }

  func uploadStarted(_ c: AnyCancellable) {
    uploadingTask = c
    uploadingError = nil
  }
  
  func uploadCompleted(_ error: Error?) {
    if let error = error {
      uploadingError = error
      uploadingTask = nil
      return
    }
    
    remote = local
    evaluate()
    uploadingTask = nil
  }
}

// MARK: - NSFileProviderItem

extension BlinkItemReference: NSFileProviderItem {
  var parentItemIdentifier: NSFileProviderItemIdentifier { identifier.parentIdentifier }
  var childItemCount: NSNumber? { nil }
  var creationDate: Date? { primary[.creationDate] as? Date }
  var contentModificationDate: Date? { primary[.modificationDate] as? Date }
  var documentSize: NSNumber? { primary[.size] as? NSNumber }
  var itemIdentifier: NSFileProviderItemIdentifier { identifier.itemIdentifier }
  var isDownloading: Bool { downloadingTask != nil }
  // Indicates whether the item is the most recent version downloaded from the server.
  // In our case, there is only one version, so if it is downloaded, it is the most recent
  // TODO Not sure how this will play out when the local may be the most recent version.
  var isMostRecentVersionDownloaded: Bool { isDownloaded }
  var isTrashed: Bool { false }
  var isUploading: Bool { uploadingTask != nil }

  // iOS14
  //  var contentType: UTType
  
  var typeIdentifier: String {
    guard let type = primary[.type] as? FileAttributeType else {
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
        c.formUnion([.allowsRenaming]) // .allowsDeleting - not supported yet
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
