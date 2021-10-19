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
import FileProvider

import BlinkFiles

// TODO Provide proper error subclassing. BlinkFilesProviderError
extension String: Error {}


class FileProviderExtension: NSFileProviderExtension {
  
  var fileManager = FileManager()
  var cancellableBag: Set<AnyCancellable> = []
  let copyArguments = CopyArguments(inplace: true,
                                    preserve: [.permissions],
                                    checkTimes: true)
  override init() {
    super.init()
  }
  
  // MARK: - BlinkItem Entry : DB-GET query (using uniq NSFileProviderItemIdentifier ID)
  override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
    print("ITEM \(identifier.rawValue) REQUESTED")
    
    var queryableIdentifier: BlinkItemIdentifier!
    
    if identifier == .rootContainer {
      guard let encodedRootPath = domain?.pathRelativeToDocumentStorage else {
        throw NSFileProviderError(.noSuchItem)
      }
      queryableIdentifier = BlinkItemIdentifier(encodedRootPath)
    } else {
      queryableIdentifier = BlinkItemIdentifier(identifier)
    }
    
    guard let reference = FileTranslatorCache.reference(identifier: queryableIdentifier) else {
     if identifier == .rootContainer {
       let attributes = try? fileManager.attributesOfItem(atPath: queryableIdentifier.url.path)
       // Move operation requests root without enumarating. Return domain root with local attribtues
       // TODO: Store in FileTranslatorCache?
       return BlinkItemReference(queryableIdentifier, local: attributes)
     }
      print("ITEM \(queryableIdentifier.path) REQUESTED with ERROR")
      throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)
    }
    
    return reference
  }
  
  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
    let blinkItemFromId = BlinkItemIdentifier(identifier)
    debugPrint("blinkItemFromId.url")
    debugPrint(blinkItemFromId.url)
    return blinkItemFromId.url
  }
  
  // MARK: - Actions
  
  override func persistentIdentifierForItem(at url: URL) -> NSFileProviderItemIdentifier? {
    let blinkItem = BlinkItemIdentifier(url: url)
    return blinkItem.itemIdentifier
  }
  
  override func providePlaceholder(at url: URL, completionHandler: @escaping (Error?) -> Void) {
    
    print("providePlaceholder at \(url)")
    
    //A.1. Get the document’s persistent identifier by calling persistentIdentifierForItemAtURL:, and pass in the value of the url parameter.
    let localDirectory = url.deletingLastPathComponent()
    
    do {
      try fileManager.createDirectory(
        at: localDirectory,
        withIntermediateDirectories: true,
        attributes: nil
      )
    } catch {
      completionHandler(error)
      return
    }
    
    //A Look Up the Document's File Provider Item
    guard let identifier = persistentIdentifierForItem(at: url) else {
      completionHandler(NSFileProviderError(.noSuchItem))
      return
    }
    print("identifier \(identifier)")
    
    do {
      
      //A.2. Call itemForIdentifier:error:, and pass in the persistent identifier. This method returns the file provider item for the document.
      let fileProviderItem = try item(for: identifier)
      
      // B. Write the Placeholder
      // B.1 Get the placeholder URL by calling placeholderURLForURL:, and pass in the value of the url parameter.
      let placeholderURL = NSFileProviderManager.placeholderURL(for: url)
      
      // B.2 Call writePlaceholderAtURL:withMetadata:error:, and pass in the placeholder URL and the file provider item.
      try NSFileProviderManager.writePlaceholder(at: placeholderURL,withMetadata: fileProviderItem)
      
      completionHandler(nil)
      
      
    } catch let error {
      debugPrint(error)
      completionHandler(error)
      return
    }
  }
  
  override func startProvidingItem(at url: URL, completionHandler: @escaping ((_ error: Error?) -> Void)) {
    // 1 - From URL we get the identifier.
    let blinkIdentifier = BlinkItemIdentifier(url: url)
    guard let blinkItemReference = FileTranslatorCache.reference(identifier: blinkIdentifier) else {
      // TODO Proper error types (NSError)
      completionHandler("Does not have a reference to copy")
      return
    }

    print("\(blinkIdentifier.path) - Start Providing item")
    
    // 2 local translator
    let destTranslator = Local().cloneWalkTo(url.deletingLastPathComponent().path)
    
    // 3 remote - From the identifier, we get the translator and walk to the remote.
    let srcTranslator = FileTranslatorCache.translator(for: blinkIdentifier.encodedRootPath)
    let downloadTask = srcTranslator.flatMap { $0.cloneWalkTo(blinkIdentifier.path) }
      .flatMap { fileTranslator in
        // 4 - Start the copy
        return destTranslator.flatMap { $0.copy(from: [fileTranslator],
                                                args: self.copyArguments) }
      }.sink(receiveCompletion: { completion in
        print(completion)
        switch completion {
        case .finished:
          blinkItemReference.downloadCompleted(nil)
          completionHandler(nil)
        case .failure(let error):
          completionHandler(error)
        }
      }, receiveValue: { _ in })

    blinkItemReference.downloadStarted(downloadTask)
  }
  
  override func stopProvidingItem(at url: URL) {
    print("stopProvidingItem ITEM at \(url)")
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
        // TODO The placeholder will take into account the file, but we will need to make sure
        // that the Reference know that the local file is actually empty.
        // This means if mtime is a reference, the size should be too, in order to differentiate
        // files we already have from those that need to be downloaded.
        // TODO: handle any error, do any necessary cleanup
      })
    }
  }
  
  override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
    print("importDocument at \(fileURL)")
    
    let parentBlinkIdentifier: BlinkItemIdentifier!
    if parentItemIdentifier == .rootContainer {
      parentBlinkIdentifier = BlinkItemIdentifier(domain!.pathRelativeToDocumentStorage)
    } else {
      parentBlinkIdentifier = BlinkItemIdentifier(parentItemIdentifier)
    }
    
    let fileBlinkIdentifier = BlinkItemIdentifier(parentItemIdentifier: parentBlinkIdentifier, filename: fileURL.lastPathComponent)
    let localFileURLDirectory = fileBlinkIdentifier.url.deletingLastPathComponent().path
    
    var attributes: FileAttributes!
    do {
      attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
      attributes[.name] = fileBlinkIdentifier.url.lastPathComponent
    } catch {
      completionHandler(nil, error)
      return
    }

    // Copy only Regular files, do not support directories yet.
    if attributes[.type] as! FileAttributeType != .typeRegular {
      completionHandler(nil, NSFileProviderError(.noSuchItem))
      return
    }
    
    // Move file to the provider container.
    do {
      try moveFile(fileURL, to: localFileURLDirectory)
    } catch {
      completionHandler(nil, error)
    }

    let blinkItemReference = BlinkItemReference(fileBlinkIdentifier, local: attributes)
    FileTranslatorCache.store(reference: blinkItemReference)
    
    // 1. Translator for local target path
    let localFileURLPath = fileBlinkIdentifier.url.path
    let srcTranslator = Local().cloneWalkTo(localFileURLPath)

    // 2. translator for remote target path
    let destTranslator = FileTranslatorCache.translator(for: parentBlinkIdentifier.encodedRootPath)
      .flatMap { $0.cloneWalkTo(parentBlinkIdentifier.path) }
    
    let c = destTranslator.flatMap { remotePathTranslator in
        return srcTranslator.flatMap{ localFileTranslator -> CopyProgressInfoPublisher in
          // 3. Start copy
          return remotePathTranslator.copy(from: [localFileTranslator],
                                           args: self.copyArguments)
        }
      }.sink { completion in
        // 4. Update reference and notify
        if case let .failure(error) = completion {
          print("Copyfailed. \(error)")
          blinkItemReference.uploadCompleted(error)
          completionHandler(blinkItemReference, error)
          return
        }

        blinkItemReference.uploadCompleted(nil)
        // NOTE: In theory, we should enumerate changes again. But when trying that,
        // the state of the file would not change.
        completionHandler(blinkItemReference, nil)
      } receiveValue: { _ in }

    blinkItemReference.uploadStarted(c)
  }
  
  override func itemChanged(at url: URL) {
    print("\(url) - itemChanged")
    
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    /* TODO:
     - mark file at <url> as needing an update in the model
     - if there are existing NSURLSessionTasks uploading this file, cancel them
     - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
     - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
     */
    
  }
  
  override func createDirectory(withName directoryName: String,
                                inParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier,
                                completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
    
    // TODO:
    
    // 1. Check for collisions
    
    // 2. Create a directory (locally?)
  }
  
  // MARK: - Enumeration
  
  override func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier) throws -> NSFileProviderEnumerator {
    
    print("Called enumerator for \(containerItemIdentifier.rawValue)")
    
    guard let domain = self.domain else {
      throw "No domain received."
    }
    
    if (containerItemIdentifier != NSFileProviderItemIdentifier.workingSet) {
      return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier, domain: domain)
    } else {
      // We may want to do an empty FileProviderEnumerator, because otherwise it will try to request it again and again.
      throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
    }
  }
  
  // MARK: - Private
  private func moveFile(_ fileURL: URL, to targetPath: String) throws {
    _ = fileURL.startAccessingSecurityScopedResource()
    
    var isDirectory: ObjCBool = false
    var coordinatorError: NSError? = nil
    var error: NSError? = nil
    NSFileCoordinator()
      .coordinate(readingItemAt: fileURL, options: .withoutChanges, error: &coordinatorError) { url in
        do {
          if !fileManager.fileExists(atPath: targetPath, isDirectory:&isDirectory) {
            try fileManager.createDirectory(atPath: targetPath, withIntermediateDirectories: true, attributes: nil)
        // Check to see if file exists, move file, error handling
          }
      
          let filename = fileURL.lastPathComponent
          let newFilePath  = (targetPath as NSString).appendingPathComponent(filename)
          if fileManager.fileExists(atPath: newFilePath) {
            try fileManager.removeItem(atPath: newFilePath)
          }
      
          try fileManager.moveItem(atPath: fileURL.path, toPath: newFilePath)
        } catch let err {
          error = err as NSError
        }
      }
    
    fileURL.stopAccessingSecurityScopedResource()

    if let error = (error != nil) ? error : coordinatorError {
      throw error
    }
  }
  
  deinit {
    print("OOOOUUUTTTTT!!!!!")
  }
}

