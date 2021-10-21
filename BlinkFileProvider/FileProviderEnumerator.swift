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

import BlinkFiles
import FileProvider
import Combine

import SSH

class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
  let identifier: BlinkItemIdentifier
  let translator: AnyPublisher<Translator, Error>
  var cancellableBag: Set<AnyCancellable> = []
  var currentAnchor: Int = 0
  let log: BlinkLogger

  init(enumeratedItemIdentifier: NSFileProviderItemIdentifier,
       domain: NSFileProviderDomain) {
    // TODO An enumerator may be requested for an open file, in order to enumerate changes to it.
    if enumeratedItemIdentifier == .rootContainer {
      self.identifier = BlinkItemIdentifier(domain.pathRelativeToDocumentStorage)
    } else {
      self.identifier = BlinkItemIdentifier(enumeratedItemIdentifier)
    }

    let path = self.identifier.path
    self.log = BlinkLogger("enumeratorFor \(path)")
    self.log.debug("Initialized")

    self.translator = FileTranslatorCache.translator(for: domain.pathRelativeToDocumentStorage)
      .flatMap { t -> AnyPublisher<Translator, Error> in
        path.isEmpty ? .just(t.clone()) : t.cloneWalkTo(path)
      }.eraseToAnyPublisher()

    // TODO Schedule an interval enumeration (pull) from the server.
    super.init()
  }

  func invalidate() {
    // TODO: perform invalidation of server connection if necessary?
    // Stop the enumeration
    self.log.debug("Invalidate")
    cancellableBag = []
  }

  func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    /*
     - inspect the page to determine whether this is an initial or a follow-up request

     If this is an enumerator for a directory, the root container or all directories:
     - perform a server request to fetch directory contents
     If this is an enumerator for the active set:
     - perform a server request to update your local database
     - fetch the active set from your local database

     - inform the observer about the items returned by the server (possibly multiple times)
     - inform the observer that you are finished with this page
     */
    self.log.info("Enumeration requested")

    // We use the local files and the representation of the remotes to construct the view of the system.
    // It is a simpler way to warm up the local cache without having a persistent representation.
    var containerTranslator: Translator!
    translator
      .flatMap { t -> AnyPublisher<FileAttributes, Error> in
        containerTranslator = t
        return t.stat()
      }
      .map { containerAttrs -> Translator in
        // 1. Store the container reference
        // TODO We may be able to skip this if stat would return '.'
        if let reference = FileTranslatorCache.reference(identifier: self.identifier) {
          reference.updateAttributes(remote: containerAttrs)
        } else {
          let ref = BlinkItemReference(self.identifier,
                                       remote: containerAttrs)
          FileTranslatorCache.store(reference: ref)
        }
        return containerTranslator
      }
      .flatMap {
        // 2. Stat both local and remote files.
        Publishers.Zip($0.directoryFilesAndAttributes(),
                         Local().walkTo(self.identifier.url.path)
                          .flatMap { $0.directoryFilesAndAttributes() }
                          .catch { _ in AnyPublisher.just([]) })
      }
      .map { (remoteFilesAttributes, localFilesAttributes) -> [BlinkItemReference] in
        // 3.1 Collect all current file references
        return remoteFilesAttributes.map { attrs -> BlinkItemReference in
          // 3.2 Match local and remote files, and upsert accordingly
          let fileIdentifier = BlinkItemIdentifier(parentItemIdentifier: self.identifier,
                                                   filename: attrs[.name] as! String)
          // Find a local file that matches the remote.
          let localAttrs = localFilesAttributes.first(where: { $0[.name] as! String == fileIdentifier.filename })

          if let reference = FileTranslatorCache.reference(identifier: fileIdentifier) {
            reference.updateAttributes(remote: attrs, local: localAttrs)
            return reference
          } else {
            let ref = BlinkItemReference(fileIdentifier,
                                         remote: attrs,
                                         local: localAttrs)

            // Store the reference in the internal DB for later usage.
            FileTranslatorCache.store(reference: ref)
            return ref
          }
        }
      }
      .sink(
        receiveCompletion: { completion in
        switch completion {
          case .failure(let error):
            self.log.error("\(error)")
            observer.finishEnumeratingWithError(error)
          case .finished:
            observer.finishEnumerating(upTo: nil)
          }
        },
        receiveValue: {
          self.log.info("Enumerated \($0.count) items")
          observer.didEnumerate($0)
        }).store(in: &cancellableBag)
  }

  
//  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
//    /* TODO:
//     - query the server for updates since the passed-in sync anchor
//
//     If this is an enumerator for the active set:
//     - note the changes in your local database
//
//     - inform the observer about item deletions and updates (modifications + insertions)
//     - inform the observer when you have finished enumerating up to a subsequent sync anchor
//     */
//    // Schedule changes
//
//    print("\(self.identifier.path) - Enumerating changes at \(currentAnchor) anchor")
//    let data = "\(currentAnchor)".data(using: .utf8)
//    observer.finishEnumeratingChanges(upTo: NSFileProviderSyncAnchor(data!), moreComing: false)
//
//  }
//

  /**
   Request the current sync anchor.

   To keep an enumeration updated, the system will typically
   - request the current sync anchor (1)
   - enumerate items starting with an initial page
   - continue enumerating pages, each time from the page returned in the previous
     enumeration, until finishEnumeratingUpToPage: is called with nextPage set to
     nil
   - enumerate changes starting from the sync anchor returned in (1)
   - continue enumerating changes, each time from the sync anchor returned in the
     previous enumeration, until finishEnumeratingChangesUpToSyncAnchor: is called
     with moreComing:NO

   This method will be called again if you signal that there are more changes with
   -[NSFileProviderManager signalEnumeratorForContainerItemIdentifier:
   completionHandler:] and again, the system will enumerate changes until
   finishEnumeratingChangesUpToSyncAnchor: is called with moreComing:NO.

   NOTE that the change-based observation methods are marked optional for historical
   reasons, but are really required. System performance will be severely degraded if
   they are not implemented.
  */
//  func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
//
//    // todo
//    print("\(self.identifier.path) - Requested \(currentAnchor) anchor")
//
//    let data = "\(currentAnchor)".data(using: .utf8)
//    completionHandler(NSFileProviderSyncAnchor(data!))
//  }
}
