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

import BlinkFiles


final class FileTranslatorCache {
  static let shared = FileTranslatorCache()
  private var translators: [String: Translator] = [:]
  private var references: [String: BlinkItemReference] = [:]
  private var fileList:   [String: [BlinkItemReference]] = [:]
  private var backgroundThread: Thread? = nil
  private var backgroundRunLoop: RunLoop = RunLoop.current


  private init() {
    // self.backgroundThread = Thread {
    //   self.backgroundRunLoop = RunLoop.current
    //   // TODO Probably need a timer. This may exit immediately
    //   RunLoop.current.run()
    // }
    
    // self.backgroundThread!.start()
  }
  
  static func translator(for encodedRootPath: String) -> AnyPublisher<Translator, Error> {
    // Check if we have it cached, if it is still working
    if let translator = shared.translators[encodedRootPath],
       translator.isConnected {
      return .just(translator)
    }
    
    return buildTranslator(for: encodedRootPath)
      .map { t -> Translator in
        shared.translators[encodedRootPath] = t
        return t
      }.eraseToAnyPublisher()
  }
  
  static func store(reference: BlinkItemReference) {
    print("storing File BlinkItemReference : \(reference.itemIdentifier.rawValue)")
//    let parent = reference.parentIdentifier.rawValue
//    if shared.fileList[parent] == nil {
//      shared.fileList[parent] = []
//    }
//    shared.fileList[parent]!.append(reference)
    shared.references[reference.itemIdentifier.rawValue] = reference
  }

  static func reference(identifier: BlinkItemIdentifier) -> BlinkItemReference? {
    print("requesting File BlinkItemReference : \(identifier.itemIdentifier.rawValue)")
    return shared.references[identifier.itemIdentifier.rawValue]
  }
}

