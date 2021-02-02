//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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
import Combine

public extension Translator {
  func cloneWalkTo(_ path: String) -> AnyPublisher<Translator, Error> {
    let t = self.clone()
    return t.walkTo(path)
  }
}

extension Translator {
  public func translatorsMatching(path: String) -> AnyPublisher<Translator, Error> {
    // If the source path contains a wildcard, then list and filter
    // (or do it anyway).
    // ~/asdf/test* - go to asdf, list and
    // /asdf*
    let sourceRootPath: String
    if path.contains("/") {
      sourceRootPath = (path as NSString).deletingLastPathComponent
    } else {
      sourceRootPath = current
    }
    let sourceComponent = (path as NSString).lastPathComponent
    var sourceRootTranslator: Translator? = nil
    return self.cloneWalkTo(sourceRootPath)
      .flatMap { s -> AnyPublisher<FileAttributes, Error> in
        sourceRootTranslator = s
        return s.directoryFilesAndAttributes().flatMap { $0.publisher }.eraseToAnyPublisher()
      }.compactMap { (elem: BlinkFiles.FileAttributes) -> String? in
        let name = elem[.name] as! String
        // Skip "." and ".."?
        if wildcard(name, pattern: sourceComponent) {
          return name
        }
        return nil
      }.flatMap {
        sourceRootTranslator!.cloneWalkTo($0)
      }.eraseToAnyPublisher()
  }
  
  private func wildcard(_ string: String, pattern: String) -> Bool {
    let pred = NSPredicate(format: "self LIKE %@", pattern)
    return !NSArray(object: string).filtered(using: pred).isEmpty
  }
}
