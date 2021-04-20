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


import FileProvider
import UniformTypeIdentifiers
import MobileCoreServices

import BlinkFiles


final class FileProviderItem: NSObject {
  let reference: BlinkItemReference
  
  init(reference: BlinkItemReference) {
    self.reference = reference
  }

}

// MARK: - NSFileProviderItem

extension FileProviderItem: NSFileProviderItem {

  var itemIdentifier: NSFileProviderItemIdentifier {
    reference.itemIdentifier
  }

  var parentItemIdentifier: NSFileProviderItemIdentifier {
    reference.parentIdentifier
  }

  var filename: String {
    reference.filename
  }

  var typeIdentifier: String {
    reference.typeIdentifier
  }

  var capabilities: NSFileProviderItemCapabilities {
      if reference.isDirectory {
        return [ .allowsAddingSubItems, .allowsContentEnumerating, .allowsReading, .allowsDeleting, .allowsRenaming ]
    } else {
        return [ .allowsWriting, .allowsReading, .allowsDeleting, .allowsRenaming, .allowsReparenting ]
    }
  }
  
  var childItemCount: NSNumber? {
      return nil
  }
  
  var creationDate: Date? {
    reference.creationDate
  }
  
  var contentModificationDate: Date? {
    reference.contentModificationDate
  }
  
//  var lastUsedDate: Date? {
//    fatalError("lastUsedDate has not been implemented")
//  }
//  var tagData: Data? {
//    fatalError("tagData has not been implemented")
//  }
//  var favoriteRank: NSNumber? {
//    fatalError("favoriteRank has not been implemented")
//  }
  
  var isTrashed: Bool {
      return false
  }

  var isUploading: Bool { reference.isUploading }
  
  var isUploaded: Bool { reference.isUploaded }
  
  var uploadingError: Error? { reference.uploadingError }
//  var uploadingError: Error? {
//    fatalError("uploadingError has not been implemented")
//  }
//  var isDownloaded: Bool {
//    fatalError("isDownloaded has not been implemented")
//  }
//  var isDownloading: Bool {
//    fatalError("isDownloading has not been implemented")
//  }
//  var downloadingError: Error? {
//    fatalError("downloadingError has not been implemented")
//  }
  
  var isMostRecentVersionDownloaded: Bool {
      return true
  }
  
  var documentSize: NSNumber? {
    return reference.documentSize
  }
  
//  var ownerNameComponents: PersonNameComponents? {
//    fatalError("ownerNameComponents has not been implemented")
//  }
//  var versionIdentifier: Data? {
//    fatalError("versionIdentifier has not been implemented")
//  }
//  var userInfo: [AnyHashable: Any]? {
//    fatalError("userInfo has not been implemented")
//  }
}
