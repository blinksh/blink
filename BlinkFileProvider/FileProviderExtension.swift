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

extension String: Error {}

class FileProviderExtension: NSFileProviderExtension {
  
  var fileManager = FileManager()
  
  override init() {
    super.init()
  }
  
  override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
    // resolve the given identifier to a record in the model
    
    // TODO: implement the actual lookup
    return FileProviderItem(attributes: [.name: identifier.rawValue])
  }
  
  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
    // resolve the given identifier to a file on disk
    guard let item = try? item(for: identifier) else {
      return nil
    }
    
    // in this implementation, all paths are structured as <base storage directory>/<item identifier>/<item file name>
    let manager = NSFileProviderManager.default
    let perItemDirectory = manager.documentStorageURL.appendingPathComponent(identifier.rawValue, isDirectory: true)
    
    return perItemDirectory.appendingPathComponent(item.filename, isDirectory:false)
  }
  
  override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
    // resolve the given URL to a persistent identifier using a database
    let pathComponents = url.pathComponents
    
    // exploit the fact that the path structure has been defined as
    // <base storage directory>/<item identifier>/<item file name> above
    assert(pathComponents.count > 2)
    
    return NSFileProviderItemIdentifier(pathComponents[pathComponents.count - 2])
  }
  
  override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
    guard let identifier = persistentIdentifierForItem(at: url) else {
      completionHandler(NSFileProviderError(.noSuchItem))
      return
    }
    
    do {
      let fileProviderItem = try item(for: identifier)
      let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
      try NSFileProviderManager.writePlaceholder(at: placeholderURL,withMetadata: fileProviderItem)
      completionHandler(nil)
    } catch let error {
      completionHandler(error)
    }
  }
  
  override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
    // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
    
    /* TODO:
     This is one of the main entry points of the file provider. We need to check whether the file already exists on disk,
     whether we know of a more recent version of the file, and implement a policy for these cases. Pseudocode:
     
     if !fileOnDisk {
     downloadRemoteFile()
     callCompletion(downloadErrorOrNil)
     } else if fileIsCurrent {
     callCompletion(nil)
     } else {
     if localFileHasChanges {
     // in this case, a version of the file is on disk, but we know of a more recent version
     // we need to implement a strategy to resolve this conflict
     moveLocalFileAside()
     scheduleUploadOfLocalFile()
     downloadRemoteFile()
     callCompletion(downloadErrorOrNil)
     } else {
     downloadRemoteFile()
     callCompletion(downloadErrorOrNil)
     }
     }
     */
    
    completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
  }
  
  
  override func itemChanged(at url: URL) {
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    /* TODO:
     - mark file at <url> as needing an update in the model
     - if there are existing NSURLSessionTasks uploading this file, cancel them
     - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
     - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
     */
  }
  
  override func stopProvidingItem(at url: URL) {
    // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
    // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
    
    // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
    
    // TODO: look up whether the file has local changes
    let fileHasLocalChanges = false
    
    if !fileHasLocalChanges {
      // remove the existing file to free up space
      do {
        _ = try FileManager.default.removeItem(at: url)
      } catch {
        // Handle error
      }
      
      // write out a placeholder to facilitate future property lookups
      self.providePlaceholder(at: url, completionHandler: { error in
        // TODO: handle any error, do any necessary cleanup
      })
    }
  }
  
  // MARK: - Actions
  
  /* TODO: implement the actions for items here
   each of the actions follows the same pattern:
   - make a note of the change in the local model
   - schedule a server request as a background task to inform the server of the change
   - call the completion block with the modified item in its post-modification state
   */
  
  // MARK: - Enumeration
  
  override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
    let maybeEnumerator: NSFileProviderEnumerator? = nil
    guard let domain = self.domain else {
      throw "No domain received. We need a domain to set a root for the provider."
    }

    if (containerItemIdentifier == NSFileProviderItemIdentifier.rootContainer) {
      // TODO: instantiate an enumerator for the container root
      // We should probably have a factory to create the proper translator, and
      // then pass that to the enumerator.
      return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }
    //        else if (containerItemIdentifier == NSFileProviderItemIdentifier.workingSet) {
    //            // TODO: instantiate an enumerator for the working set
    //        }
    else {
      // TODO: determine if the item is a directory or a file
      // - for a directory, instantiate an enumerator of its subitems
      // - for a file, instantiate an enumerator that observes changes to the file
    }
    guard let enumerator = maybeEnumerator else {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
    }
    return enumerator
  }
  
}


//class FileProviderExtension: NSFileProviderExtension {
//
//  //1.
//  /*
//   system provides the identifier passed to this method, and you return a FileProviderItem for that identifier.
//   */
//  override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
//
//    guard let reference = BlinkItemReference(itemIdentifier: identifier) else {
//      throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)
//    }
//    return FileProviderItem(reference: reference)
//  }
//
//  //2.
//  /*
//
//   */
//  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
//
//    // validate the item to ensure that the given identifier resolves to an instance of the extension’s model
//    guard let item = try? item(for: identifier) else {
//      return nil
//    }
//
//
//    /*
//     return a file URL specifying where to store the item within the file manager’s document storage directory
//     URL in the format <documentStorageURL>/<itemIdentifier>/<filename>,
//     */
//    return NSFileProviderManager.default.documentStorageURL
//      .appendingPathComponent(identifier.rawValue, isDirectory: true)
//      .appendingPathComponent(item.filename)
//  }
//
//  //3.
//  /*
//   Each URL returned by urlForItem(withPersistentIdentifier:) needs to map back to the NSFileProviderItemIdentifier it was originally set out to represent.
//   */
//  override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
//    // take the second to last path component as the item identifier.
//    let identifier = url.deletingLastPathComponent().lastPathComponent
//    return NSFileProviderItemIdentifier(identifier)
//  }
//
//
//  /*
//   file placeholder URL that references a Blink file.
//   */
//  private func providePlaceholder(at url: URL) throws {
//
//    //4.1 you create an identifier and a reference from the provided URL.
//    guard
//      let identifier = persistentIdentifierForItem(at: url),
//      let reference = BlinkItemReference(itemIdentifier: identifier)
//      else {
//        throw FileProviderError.unableToFindMetadataForPlaceholder
//    }
//
//    //4.3. The url passed into this method is for the image to be displayed, not the placeholder. So you create a placeholder URL with placeholderURL(for:) and obtain the NSFileProviderItem that this placeholder will represent.
//    let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
//    let item = FileProviderItem(reference: reference)
//
//    try NSFileProviderManager.writePlaceholder(
//      at: placeholderURL,
//      withMetadata: item
//    )
//  }
//
//  override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
//    do {
//      try providePlaceholder(at: url)
//      completionHandler(nil)
//    } catch {
//      completionHandler(error)
//    }
//  }
//
//  // MARK: - Enumeration
//
//  override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
//
//    print("containr identifier")
//    print(containerItemIdentifier)
//
//    // TODO: - Point at which we define different ROOT items based on Translator
//    if containerItemIdentifier == .rootContainer {
//      return FileProviderEnumerator(path: "/")
//    }
//
//    guard
//      let ref = BlinkItemReference(itemIdentifier: containerItemIdentifier),
//      ref.isDirectory
//      else {
//        throw FileProviderError.notAContainer
//    }
//
//    return FileProviderEnumerator(path: ref.path)
//  }
//
//
//}
