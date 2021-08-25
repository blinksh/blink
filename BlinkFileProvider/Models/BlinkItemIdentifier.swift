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
import Foundation


struct BlinkItemIdentifier {
  let path: String
  let encodedRootPath: String

  // <encodedRootPath>/path/to, name = filename. -> <encodedRootPath>/path/to/filename
  init(parentItemIdentifier: BlinkItemIdentifier, filename: String) {
    self.encodedRootPath = parentItemIdentifier.encodedRootPath
    self.path = (parentItemIdentifier.path as NSString).appendingPathComponent(filename)
  }

  // <encodedRootPath>/path/to/filename
  init(_ identifier: NSFileProviderItemIdentifier) {
    self.encodedRootPath = (identifier.rawValue as NSString).pathComponents[0]
    var path = (identifier.rawValue)
    path.removeFirst(encodedRootPath.count)
    if path.isEmpty {
      path = "/"
    }
    self.path = path
  }
  
  init(_ identifier: String) {
    self.init(NSFileProviderItemIdentifier(identifier))
  }
  
  init(url: URL) {
    let manager = NSFileProviderManager.default
    let containerPath = manager.documentStorageURL.absoluteString

    // file://<containerPath>/<encodedRootPath>/<encodedPath>/filename
    // file://<containerPath>/<encodedRootPath>/path/filename
    // Remove containerPath, split and get encodedRootPath.
    var encodedPath = url.absoluteString
    encodedPath.removeFirst(containerPath.count)
    
    // <encodedRootPath>/<encodedPath>/filename
    // <encodedRootPath>/<path>/<to>/filename
    let encodedComponents = encodedPath.split(separator: "/")
    self.encodedRootPath = String(encodedComponents[0])
    let components: [String] = encodedComponents.map({ String($0).removingPercentEncoding ?? String($0) })
    self.path = "/\(components[1...].joined(separator: "/"))"
    print(self.path)
  }

  // file://<containerPath>/<encodedRootPath>/path/to/filename
  var url: URL {
    let manager = NSFileProviderManager.default
    let pathcomponents = "\(encodedRootPath)\(self.path)"
    return manager.documentStorageURL.appendingPathComponent(pathcomponents)
  }

  var filename: String {
    return (path as NSString).lastPathComponent
  }

  var itemIdentifier: NSFileProviderItemIdentifier {
    if path == "/" {
      return .rootContainer
    }
    return NSFileProviderItemIdentifier(
      rawValue: "\(encodedRootPath)\(path)"
    )
  }

  var parentIdentifier: NSFileProviderItemIdentifier {
    let parentPath = (path as NSString).deletingLastPathComponent
    if parentPath == "/" {
      return .rootContainer
    } else {
      return NSFileProviderItemIdentifier(
        rawValue: "\(encodedRootPath)\(parentPath)"
      )
    }
  }
}
