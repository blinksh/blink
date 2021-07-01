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

import BlinkConfig
import BlinkFiles
import FileProvider
import SSH
import SSHConfig

// TODO Provide proper error subclassing. BlinkFilesProviderError
extension String: Error {}

enum BlinkFilesProtocol: String {
  case ssh = "ssh"
  case local = "local"
  case sftp = "sftp"
}

final class FileTranslatorPool {
  static let shared = FileTranslatorPool()
  private var translators: [String: AnyPublisher<Translator, Error>] = [:]
  private var references: [String: BlinkItemReference] = [:]
  private var backgroundThread: Thread? = nil
  private var backgroundRunLoop: RunLoop = RunLoop.current
  
  private init() {
    self.backgroundThread = Thread {
      self.backgroundRunLoop = RunLoop.current
      
      RunLoop.current.run()
    }
    
    self.backgroundThread!.start()
  }
  
  static func translator(for encodedRootPath: String) -> AnyPublisher<Translator, Error> {
    guard let rootData = Data(base64Encoded: encodedRootPath),
          let rootPath = String(data: rootData, encoding: .utf8) else {
      return Fail(error: "Wrong encoded identifier for Translator").eraseToAnyPublisher()
    }
    
    // rootPath: ssh:host:root_folder
    let components = rootPath.split(separator: ":")
    
    // TODO At least two components. Tweak for sftp
    let remoteProtocol = BlinkFilesProtocol(rawValue: String(components[0]))
    let pathAtFiles: String
    let host: String?
    if components.count == 2 {
      pathAtFiles = String(components[1])
      host = nil
    } else {
      pathAtFiles = String(components[2])
      host = String(components[1])
    }
    
    if let translator = shared.translators[encodedRootPath] {
      return translator
    }
    
    switch remoteProtocol {
    case .local:
      let translatorPub = Local().walkTo(pathAtFiles)
      shared.translators[encodedRootPath] = translatorPub
      return translatorPub
    case .sftp:
      
      let (host, config) = SSHClientConfigProvider.config(host: host!)
            
      return Just(config).receive(on: DispatchQueue.main).flatMap {
        SSHClient
        .dial(host, with: $0)
        .print("Dialing...")
        .receive(on: FileTranslatorPool.shared.backgroundRunLoop)
        .flatMap { $0.requestSFTP() }.print("SFTP")
        .flatMap { sftp -> AnyPublisher<Translator, Error> in
          let translatorPub = sftp.walkTo(pathAtFiles)
          shared.translators[encodedRootPath] = translatorPub
          return translatorPub
        }
      }
      .eraseToAnyPublisher()
      .handleEvents(receiveCompletion: { c in
        
        var y = c
        
      })
      .eraseToAnyPublisher()
    default:
      return Fail(error: "Not implemented").eraseToAnyPublisher()
    }
  }
  
  static func store(reference: BlinkItemReference) {
    print("storing File BlinkItemReference : \(reference.itemIdentifier.rawValue)")
    shared.references[reference.itemIdentifier.rawValue] = reference
  }

  static func reference(identifier: BlinkItemIdentifier) -> BlinkItemReference? {
    print("requiesting File BlinkItemReference : \(identifier.itemIdentifier.rawValue)")
    return shared.references[identifier.itemIdentifier.rawValue]
  }
}

class FileProviderExtension: NSFileProviderExtension {
  
  var fileManager = FileManager()
  var cancellableBag: Set<AnyCancellable> = []
  
  override init() {
    super.init()
  }
  
  // MARK: - BlinkItem Entry : DB-GET query (using uniq NSFileProviderItemIdentifier ID)
  override func item(for identifier: NSFileProviderItemIdentifier) throws -> NSFileProviderItem {
    print("ITEM \(identifier.rawValue) REQUESTED")
    
    var queryableIdentifier: BlinkItemIdentifier!
    
    if identifier == .rootContainer {
      queryableIdentifier = BlinkItemIdentifier(domain!.identifier.rawValue)
    } else {
      queryableIdentifier = BlinkItemIdentifier(identifier)
    }
    
    guard let reference = FileTranslatorPool.reference(identifier: queryableIdentifier) else {
      print("ITEM \(queryableIdentifier.path) REQUESTED with ERROR")
      throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: queryableIdentifier.itemIdentifier)
    }
    
    return FileProviderItem(reference: reference)
  }
  
  override func urlForItem(withPersistentIdentifier identifier: NSFileProviderItemIdentifier) -> URL? {
    let blinkItemFromId = BlinkItemIdentifier(identifier)
    debugPrint("blinkItemFromId.url")
    debugPrint(blinkItemFromId.url)
    return blinkItemFromId.url
  }
  
  // MARK: - Actions
  
  /* TODO: implement the actions for items here
   each of the actions follows the same pattern:
   - make a note of the change in the local model
   - schedule a server request as a background task to inform the server of the change
   - call the completion block with the modified item in its post-modification state
   */
  
  // url => file:///Users/xxxx/Library/Developer/CoreSimulator/Devices/212A70E4-CE48-48C7-8A19-32357CE9B3BD/data/Containers/Shared/AppGroup/658A68A7-43BE-4C48-8586-C7029B0DCD9A/File%20Provider%20Storage/bG9jYWw6L3Vzcg==/L2xvY2Fs/filename
  
  // https://developer.apple.com/documentation/fileprovider/nsfileproviderextension/1623479-persistentidentifierforitematurl?language=objc
  //  define a static mapping between URLs and their persistent identifiers.
  //  A document's identifier should remain constant over time; it should not change when the document is edited, moved, or rename
  //  TODO: Always return nil if the _URL is not inside in the directory referred to by the NSFileProviderManager object's documentStorageURL_ property.
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
    
    // TODO If the file is already at the specified URL, then we can figure out if we need to download it.
    
    // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
    
    /* TODO:
     This is one of the main entry points of the file provider. We need to check whether the file already exists on disk,
     whether we know of a more recent version of the file, and implement a policy for these cases. Pseudocode:
     */
    //    if !fileOnDisk {
    //      downloadRemoteFile()
    //      callCompletion(downloadErrorOrNil)
    //    } else if fileIsCurrent {
    //      callCompletion(nil)
    //    } else {
    //      if localFileHasChanges {
    //        // in this case, a version of the file is on disk, but we know of a more recent version
    //        // we need to implement a strategy to resolve this conflict
    //        moveLocalFileAside()
    //        scheduleUploadOfLocalFile()
    //        downloadRemoteFile()
    //        callCompletion(downloadErrorOrNil)
    //      } else {
    //        downloadRemoteFile()
    //        callCompletion(downloadErrorOrNil)
    //      }
    //    }
    //
    
    // 1 - From URL we get the identifier.
    
    //    guard let identifier = persistentIdentifierForItem(at: url) else {
    //      completionHandler(NSFileProviderError(.noSuchItem))
    //      return
    //    }
    let blinkIdentifier = BlinkItemIdentifier(url: url)
    print("\(blinkIdentifier.path) - Start Providing item")
    //let filename = url.lastPathComponent
    
    // SRC                --> DEST
    // remote             --> local
    // FileTranslatorPool --> Local()
    
    // local
    let destTranslator = Local().cloneWalkTo(url.deletingLastPathComponent().path)
    
    // 2 remote - From the identifier, we get the translator, and we can walk to the remote file
    let srcTranslator = FileTranslatorPool.translator(for: blinkIdentifier.encodedRootPath)
    srcTranslator.flatMap { $0.cloneWalkTo(blinkIdentifier.path) }
      .flatMap { fileTranslator in
        return destTranslator.flatMap { $0.copy(from: [fileTranslator]) }
      }.sink(receiveCompletion: { completion in
        print(completion)
        completionHandler(nil)
      }, receiveValue: { _ in }).store(in: &cancellableBag)
    // 3 - On local, the path is already the URL, so we walk to the local file path to provide there.
    // 4 - Copy from one to the other, and call the completionHandler once done.
    
    // file://
  }
  
  override func itemChanged(at url: URL) {
    print("itemChanged ITEM at \(url)")
    
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    /* TODO:
     - mark file at <url> as needing an update in the model
     - if there are existing NSURLSessionTasks uploading this file, cancel them
     - create a fresh background NSURLSessionTask and schedule it to upload the current modifications
     - register the NSURLSessionTask with NSFileProviderManager to provide progress updates
     */
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
        // TODO: handle any error, do any necessary cleanup
      })
    }
  }
  
  override func importDocument(at fileURL: URL, toParentItemIdentifier parentItemIdentifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
    
    var myerror: NSError?
    var error: NSError?
    
    let localParentIdentifier: BlinkItemIdentifier!

    if parentItemIdentifier == .rootContainer {
      localParentIdentifier = BlinkItemIdentifier(domain!.identifier.rawValue)
    } else {
      localParentIdentifier = BlinkItemIdentifier(parentItemIdentifier)
    }
    
    let localBlinkIdentifier = BlinkItemIdentifier(parentItemIdentifier: localParentIdentifier, filename: fileURL.lastPathComponent)
    let localFileURLDirectory = localBlinkIdentifier.url.deletingLastPathComponent().path
    
    var attributes: FileAttributes!
    do {
      attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
      attributes[.name] = localBlinkIdentifier.url.lastPathComponent
    } catch {
      completionHandler(nil, error)
      return
    }

    if attributes[.type] as! FileAttributeType != .typeRegular {
      completionHandler(nil, NSFileProviderError(.noSuchItem))
      return
    }
    
    do {
      try moveFile(fileURL, to: localFileURLDirectory)
    } catch {
      completionHandler(nil, error)
    }

    var blinkItemReference = BlinkItemReference(localBlinkIdentifier, attributes: attributes)
    blinkItemReference.isUploading = true
    let item = FileProviderItem(reference: blinkItemReference)
    FileTranslatorPool.store(reference: blinkItemReference)
    
    completionHandler(item, nil)

    // 1. Translator for local target path
    let localFileURLPath = localBlinkIdentifier.url.path
    let srcTranslator = Local().cloneWalkTo(localFileURLPath)

    // 2. translator for remote target path
    let destTranslator = FileTranslatorPool.translator(for: localParentIdentifier.encodedRootPath)
      .flatMap { $0.cloneWalkTo(localParentIdentifier.path) }
    
    destTranslator.flatMap { remotePathTranslator in
        return srcTranslator.flatMap{ localFileTranslator -> CopyProgressInfo in
          return remotePathTranslator.copy(from: [localFileTranslator])
        }
      }.sink  { completion in
        if case let .failure(error) = completion {
          print("Copyfailed. \(error)")
          blinkItemReference.isUploading = false
          blinkItemReference.uploadingError = error
          return
        }
        
        blinkItemReference.isUploaded = true
        blinkItemReference.isUploading = false
      } receiveValue: { _ in
        // When working with directories, we can use it to update the cache.
      }.store(in: &cancellableBag)
    
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
    
    let maybeEnumerator: NSFileProviderEnumerator? = nil
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

class SSHClientConfigProvider {
  
  static func config(host: String) -> (String, SSHClientConfig) {
    
    let bkConfig = BKConfig(allHosts: BKHosts.groupContainerHosts(), allIdentities: BKPubKey.groupContainerKeys())
    let agent = SSHAgent()
    
    let consts: [SSHAgentConstraint] = [SSHConstraintTrustedConnectionOnly()]
    
    if let (signer, name) = bkConfig.signer(forHost: host) {
      _ = agent.loadKey(signer, aka: name, constraints: consts)
    } else {
      for identity in ["id_dsa", "id_rsa", "id_ecdsa", "id_ed25519"] {
        if let (signer, name) = bkConfig.signer(forIdentity: identity) {
          _ = agent.loadKey(signer, aka: name, constraints: consts)
        }
      }
    }
    
    var availableAuthMethods: [AuthMethod] = [AuthAgent(agent)]
    if let password = bkConfig.password(forHost: host), !password.isEmpty {
      availableAuthMethods.append(AuthPassword(with: password))
    }
    
    let logger = PassthroughSubject<String, Never>()
    
    return (
      bkConfig.hostName(forHost: host)!,
      SSHClientConfig(
        user: bkConfig.user(forHost: host) ?? "root",
        port: bkConfig.port(forHost: host) ?? "22",
        proxyJump: nil,
        proxyCommand: bkConfig.proxyCommand(forHost: host),
        authMethods: availableAuthMethods,
        agent: agent,
        loggingVerbosity: SSHLogLevel.debug,
        verifyHostCallback: nil,
        connectionTimeout: 300,
        sshDirectory: BlinkPaths.ssh()!,
        logger: logger,
        compression: false,
        compressionLevel: 6
      )
    )
  }
}
