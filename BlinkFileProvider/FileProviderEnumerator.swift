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
import Combine
import BlinkFiles
import FileProvider

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
  var enumeratedItemIdentifier: NSFileProviderItemIdentifier
  var root = Local()
  let path: String

  
  init(enumeratedItemIdentifier: NSFileProviderItemIdentifier, path: String) {
    self.enumeratedItemIdentifier = enumeratedItemIdentifier
    self.path = path
    super.init()
  }
  
  func invalidate() {
    // TODO: perform invalidation of server connection if necessary
  }
  
  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    /* TODO:
     - inspect the page to determine whether this is an initial or a follow-up request
     
     If this is an enumerator for a directory, the root container or all directories:
     - perform a server request to fetch directory contents
     If this is an enumerator for the active set:
     - perform a server request to update your local database
     - fetch the active set from your local database
     
     - inform the observer about the items returned by the server (possibly multiple times)
     - inform the observer that you are finished with this page
     */
    
    switch enumeratedItemIdentifier {
    case .rootContainer:
      // I am cross-referencing here the cancellable. Use .store instead
      var c: AnyCancellable? = nil
      c = root.walkTo(self.path).flatMap { $0.directoryFilesAndAttributes() }
        .sink(receiveCompletion: { _ in
        // TODO Pass errors to the other side
        // fatalError
          print("@@@ receive completion")
          c = nil
      }, receiveValue: { attrs in
        print("curr")
        let curr = self.root.current
        debugPrint(curr)
        let items = attrs.map { blinkAttr -> FileProviderItem in
          let ref = BlinkItemReference(rootPath: curr,
                                       attributes: blinkAttr)
          return FileProviderItem(reference: ref)
        }

        observer.didEnumerate(items)
        observer.finishEnumerating(upTo: nil)
      })
      return
    case .workingSet:
      return
    default:
      // I am cross-referencing here the cancellable. Use .store instead
//      var c: AnyCancellable? = nil
//      c = root.walkTo(self.path).flatMap { $0.directoryFilesAndAttributes() }
//        .sink(receiveCompletion: { _ in
//        // TODO Pass errors to the other side
//        // fatalError
//          print("default @@@ receive completion")
//          c = nil
//      }, receiveValue: { attrs in
//        print("default @@@ receive receiveValue")
//        let items = attrs.map { FileProviderItem(attributes: $0) }
//        observer.didEnumerate(items)
//        observer.finishEnumerating(upTo: nil)
//      })
      print("@@@ default receiveValue")
      print("curr")
      let curr = self.root.current
      print(curr)
      break
    }
  }
  
  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    /* TODO:
     - query the server for updates since the passed-in sync anchor
     
     If this is an enumerator for the active set:
     - note the changes in your local database
     
     - inform the observer about item deletions and updates (modifications + insertions)
     - inform the observer when you have finished enumerating up to a subsequent sync anchor
     */
  }
  
}


//class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
//
//  private let path: String
//  private var cancellables = [AnyCancellable]()
//
//  init(path: String) {
//    self.path = path
//    super.init()
//  }
//
//  func invalidate() {
//
//  }
//
//  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
//     var items = [FileProviderItem]()
//
//     let localBlinkfile = Local()
//
//
//     localBlinkfile.directoryFilesAndAttributes().flatMap {
//         $0.compactMap { i -> FileAttributes? in
//
//          let ref = BlinkItemReference(path: self.path, filename: i[.name] as! String)
//          let item = FileProviderItem(reference: ref)
//
//           items.append(item)
//
//           if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
//             return nil
//           } else { return i }
//
//         }.publisher
//       }.assertNoFailure()
//         .sink { items in
//
//          print(items.count)
//
//      }.store(in: &cancellables)
//
//     observer.didEnumerate(items)
//     observer.finishEnumerating(upTo: nil)
//
//
//  }
//
//}
