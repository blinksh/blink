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
import FileProvider
import MobileCoreServices

import BlinkFiles


struct BlinkItemReference {
  private let urlRepresentation: URL
  let attributes: BlinkFiles.FileAttributes
  
  // TODO: Blink Translator Reference
  private var isRoot: Bool {
    return urlRepresentation.path == "/"
  }
  
  private init(urlRepresentation: URL, attributes: BlinkFiles.FileAttributes) {
    self.urlRepresentation = urlRepresentation
    self.attributes = attributes
  }
  
  // TODO: Blink Translator Reference
  init(currentPath: String, attr: BlinkFiles.FileAttributes) {
    
//    guard let type = attr[.type] as? FileAttributeType else {
//
//      return
//    }
    
//    let isDirectory = type == .typeDirectory
    var absPath = (currentPath as NSString).standardizingPath
    if !currentPath.starts(with: "/") {
      absPath = (currentPath as NSString).appendingPathComponent(absPath)
    }
    
//    let pathComponents = currentPath.pathComponents
//
//    var absolutePath = "/" + pathComponents.joined(separator: "/")
//    if isDirectory {
//      absolutePath.append("/")
//    }
//    absolutePath = absolutePath.addingPercentEncoding(
//      withAllowedCharacters: .urlPathAllowed
//    ) ?? absolutePath
    
    self.init(urlRepresentation: URL(string: "itemReference://\(absPath)")!, attributes: attr)
  }
  
  //1.
  /*
   system provides the identifier passed to this method, and you return a FileProviderItem for that identifier.
   
   scheme itemReference://.
   
   You handle the root container identifier separately to ensure its URL path is properly set.

   For the other items, the URL representation is retrieved by converting the raw value of the identifier to base64-encoded data. The information in the URL comes from the network request that first enumerated the instance.
   */
  init?(itemIdentifier: NSFileProviderItemIdentifier, attr: BlinkFiles.FileAttributes) {
    guard itemIdentifier != .rootContainer else {
      self.init(urlRepresentation: URL(string: "itemReference:///")!, attributes: attr)
      return
    }
    
    guard let data = Data(base64Encoded: itemIdentifier.rawValue),
      let url = URL(dataRepresentation: data, relativeTo: nil) else {
        return nil
    }
    
    self.init(urlRepresentation: url, attributes: attr)
  }

  var itemIdentifier: NSFileProviderItemIdentifier {
    if isRoot {
      return .rootContainer
    } else {
      return NSFileProviderItemIdentifier(
        rawValue: urlRepresentation.dataRepresentation.base64EncodedString()
      )
    }
  }

  var isDirectory: Bool {
    return urlRepresentation.hasDirectoryPath
  }

  var path: String {
    return urlRepresentation.path
  }

  var containingDirectory: String {
    return urlRepresentation.deletingLastPathComponent().path
  }

  var filename: String {
    return urlRepresentation.lastPathComponent
  }

//  var typeIdentifier: String {
//    guard !isDirectory else {
//      return kUTTypeFolder as String
//    }
//
//    let pathExtension = urlRepresentation.pathExtension
//    let unmanaged = UTTypeCreatePreferredIdentifierForTag(
//      kUTTagClassFilenameExtension,
//      pathExtension as CFString,
//      nil
//    )
//    let retained = unmanaged?.takeRetainedValue()
//
//    return (retained as String?) ?? ""
//  }
  
  var typeIdentifier: String {
    guard let type = attributes[.type] as? FileAttributeType else {
      return ""
    }
    if type == .typeDirectory {
      return kUTTypeFolder as String
    }
    
//    let fileSplit = (attributes[.name] as! String).split(separator: ".")
//    return String(fileSplit.count == 2 ? fileSplit[1] : "")
    
    let pathExtension = urlRepresentation.pathExtension
    let unmanaged = UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension,
      pathExtension as CFString,
      nil
    )
    let retained = unmanaged?.takeRetainedValue()

    return (retained as String?) ?? ""
  }

  var parentReference: BlinkItemReference? {
    guard !isRoot else {
      return nil
    }
    
    // convert between BlinkFile Attritubes and URL
    return BlinkItemReference(
      urlRepresentation: urlRepresentation.deletingLastPathComponent(), attributes: attributes
    )
  }
}
