//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2024 Blink Mobile Shell Project
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
// GNU General Public License for more details.no
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
import BlinkConfig
import Combine
import FileProvider


public class FileProviderReplicatedExtension: NSObject, NSFileProviderReplicatedExtension {
  internal let connection: FilesTranslatorConnection
  internal var cancellables: Set<AnyCancellable> = []
  internal let copyArguments = CopyArguments(inplace: true,
                                    preserve: [.permissions, .timestamp],
                                    checkTimes: true)
  internal let temporaryDirectoryURL: URL
  internal let workingSet: WorkingSet
  internal var rootTranslator: TranslatorPublisher { connection.rootTranslator }

  private let _logger: ((String) -> BlinkLogger)

  public required init(domain: NSFileProviderDomain) {
    guard let fpm = NSFileProviderManager(for: domain),
          let domainReference = domain.reference,
          let domainProviderPath = domain.providerPath else {
      fatalError("Could not initialize domain. Missing parameters.")
    }

    guard let fileProviderURL = BlinkPaths.fileProviderReplicatedURL() else {
      fatalError("Invalid shared FileProvider location for WorkingSets.")
    }

    do {
      let providerPath = try BlinkFileProviderPath(domainProviderPath)
      self.connection = FilesTranslatorConnection(providerPath: providerPath, configurator: BlinkConfigFactoryConfiguration())
    } catch {
      fatalError("Could not initialize domain: \(error)")
    }

    do {
      let loggingHandlers = try BlinkLoggingHandlers.fileProviderLoggingHandlers(domainName: "\(domain.displayName)-\(domain.identifier.rawValue.prefix(8))")
      self._logger = { BlinkLogger($0, handlers: loggingHandlers) }
    } catch {
      fatalError("Could not initialize logging: \(error)")
    }

    do {
      temporaryDirectoryURL = try fpm.temporaryDirectoryURL()
    } catch {
      fatalError("failed to get temporary directory: \(error)")
    }

    do {
      let db = try WorkingSetDatabase(path: fileProviderURL.appendingPathComponent("\(domainReference).db").path(), reset: false)
      let workingSetLogger = self._logger("WorkingSet")
      self.workingSet = try WorkingSet(domain: domain, db: db, logger: workingSetLogger)
    } catch {
      fatalError("could not initialize working set database: \(error)")
    }

    super.init()

    let log = logger("FP")
    log.info("Started")

    DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 5) { [weak self] in
      guard let self = self else { return }
      self.workingSet.resumeChangesTimerEvery(seconds: 5)
      // Background clean-up
      // self.cancellables.insert(self.cleanUpOldTmpFiles())
    }
  }

  init(connection: FilesTranslatorConnection, workingSet: WorkingSet, temporaryDirectoryURL: URL) {
    self.connection = connection
    self.workingSet = workingSet
    self.temporaryDirectoryURL = temporaryDirectoryURL

    self._logger = { BlinkLogger($0, handlers: [BlinkLoggingHandlers.print]) }

    super.init()
  }

  func logger(_ component: String) -> BlinkLogger {
    // Each Extension has its own Handler so we can log outputs to different files, etc...
    // Loggers here are connected to each Handler per provider.
    return self._logger(component)
  }

  public func invalidate() {
    // Cleanup any resources
    let log = logger("Invalidate")
    log.info("FP Extension")
    self.workingSet.invalidate()
  }

  public func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
    let log = self.logger("itemFor \(identifier.rawValue)")
    log.info("Requested")

    // resolve the given identifier to a record in the model
    if identifier == .trashContainer {
      log.warn("Trash disabled")
      completionHandler(nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
      return Progress()
    }

    var blinkIdentifier: BlinkFileItemIdentifier = .rootContainer
    if identifier != .rootContainer {
      do {
        if let value = try self.workingSet.blinkIdentifier(for: identifier) {
          blinkIdentifier = value
        } else {
          log.warn("Could not find blinkIdentifier in DB.")
          completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier))
          return Progress()
        }
      } catch {
        log.debug("Error: \(error)")
        completionHandler(nil, error)
        return Progress()
      }
    }

    let progress = Progress(totalUnitCount: 1)

    let statItemProgress = self._statItem(blinkIdentifier, log: log, completionHandler: completionHandler)
    progress.addChild(statItemProgress, withPendingUnitCount: 1)

    return progress
  }

  public func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
    // Fetching of the contents for the itemIdentifier at the specified version
    let log = self.logger("fetchContentsFor \(itemIdentifier.rawValue)")
    log.info("started")

    let totalProgress = Progress(totalUnitCount: 110)
    let itemForProgress = self.item(for: itemIdentifier, request: request) { (fileItem: NSFileProviderItem?, error: (any Error)?) in
      guard let fileItem = fileItem as? FileProviderItem else {
        let error = error!
        log.error("Stat item error: \(error)")
        completionHandler(nil, nil, error)
        return
      }

//      // Doesn't exist on iOS yet.
//      if let requestedVersion = requestedVersion {
//        guard requestedVersion.contentVersion == fileItem.itemVersion?.contentVersion else {
//          let error =  NSFileProviderError(.versionNoLongerAvailable)
//          log.error("\(error)")
//          completionHandler(nil, nil, error)
//          return
//      }

      let copyProgress = self._downloadItem(fileItem: fileItem,
                                            log: log,
                                            completionHandler: completionHandler)

      totalProgress.addChild(copyProgress, withPendingUnitCount: 100)
    }

    totalProgress.addChild(itemForProgress, withPendingUnitCount: 10)

    return totalProgress
  }

  public func createItem(basedOn itemTemplate: NSFileProviderItem,
                         fields: NSFileProviderItemFields,
                         contents url: URL?,
                         options: NSFileProviderCreateItemOptions = [],
                         request: NSFileProviderRequest,
                         completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    // A new item was created on disk, process the item's creation
    let log = self.logger("createItem \(itemTemplate.filename)")
    log.info("Requested with \(fields.debugDescription) and \(options.debugDescription)")
    let parentItemIdentifier = itemTemplate.parentItemIdentifier
    var parentIdentifier: BlinkFileItemIdentifier
    do {
      guard let validParentIdentifier = try self.workingSet.blinkIdentifier(for: parentItemIdentifier) else {
        completionHandler(nil, [], false, NSError.fileProviderErrorForNonExistentItem(withIdentifier: parentItemIdentifier))
        return Progress()
      }
      parentIdentifier = validParentIdentifier
    } catch {
      log.error("\(error)")
      completionHandler(nil, [], false, error)
      return Progress()
    }

    // Template - itemIdentifier should stay stable between retries (but, I have seen retries use a different identifier).
    // Set properties from itemTemplate into the object. Fields may have what has changed.
    // Document in URL, otherwise nil.
    // Not sure how to work with symlinks, because the destination may be somewhere else not part of WorkingSet.
    // - The item needs to exist because otherwise it wouldn't be created pointing to a place within the structure?
    // - Validate the destination beforehand? Support symlink reads before writes.
    let totalProgress = Progress(totalUnitCount: 100)

    switch itemTemplate.contentType {
    case .folder?:
      log.info("Is a Folder")
      let folderProgress = _createFolder(withName: itemTemplate.filename,
                                         inParent: parentIdentifier,
                                         log: log,
                                         completionHandler: completionHandler)
      totalProgress.addChild(folderProgress, withPendingUnitCount: totalProgress.totalUnitCount)
    case .aliasFile?, .symbolicLink?:
      log.warn("Is alias. Skipping")
      completionHandler(itemTemplate, [], false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
    default:
      log.info("Is a File")
      // Upload on content
      if fields.contains(.contents),
         let url = url {
        let createProgress = _createItem(basedOn: itemTemplate,
                                         inParent: parentIdentifier,
                                         fields: fields,
                                         contents: url,
                                         options: options,
                                         request: request,
                                         log: log,
                                         completionHandler: completionHandler)
        totalProgress.addChild(createProgress, withPendingUnitCount: totalProgress.totalUnitCount)
      } else if options.contains(.mayAlreadyExist) {
        // The system is calling with an already-existing item that's dataless.
        // This only happens during a reimport, for items that the system hasn’t
        // materialized before. In this case, return nil (which causes the
        // system to delete the local item). After the system reenumerates the folder, it then recreates the file.
        log.warn("Create unmaterialized empty file. Skipping.")
        completionHandler(nil, [], false, nil)
      } else {
        log.info("Empty file")
        let createFileProgress = _createEmptyFile(basedOn: itemTemplate,
                                                  inParent: parentIdentifier,
                                                  fields: fields,
                                                  options: options,
                                                  log: log,
                                                  completionHandler: completionHandler)
        totalProgress.addChild(createFileProgress, withPendingUnitCount: totalProgress.totalUnitCount)
      }
    }

    return totalProgress
  }

  public func modifyItem(_ item: NSFileProviderItem,
                         baseVersion version: NSFileProviderItemVersion,
                         changedFields: NSFileProviderItemFields,
                         contents newContents: URL?,
                         options: NSFileProviderModifyItemOptions = [],
                         request: NSFileProviderRequest,
                         completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
    let log = self.logger("modifyItem \(item.filename)")
    log.info("Requested with \(changedFields.debugDescription) and \(options.debugDescription)")

    var originalIdentifier: BlinkFileItemIdentifier
    // NOTE The parent may be in a different location than the current item if it is also reparenting.
    var modifiedItemParent: BlinkFileItemIdentifier
    do {
      guard let validOriginalIdentifier = try self.workingSet.blinkIdentifier(for: item.itemIdentifier) else {
        // TODO This may need a full resync instead as the identifier is not valid.
        completionHandler(nil, [], false, NSError.fileProviderErrorForNonExistentItem(withIdentifier: item.itemIdentifier))
        return Progress()
      }
      originalIdentifier = validOriginalIdentifier

      guard let validModifiedItemParent = try self.workingSet.blinkIdentifier(for: item.parentItemIdentifier) else {
        completionHandler(nil, [], false, NSError.fileProviderErrorForNonExistentItem(withIdentifier: item.parentItemIdentifier))
        return Progress()
      }
      modifiedItemParent = validModifiedItemParent
    } catch {
      log.error("\(error)")
      completionHandler(nil, [], false, error)
      return Progress()
    }

    // Moving, renaming or updating content.
    // Moving, renaming, attributes updated - stat
    // Updating - reupload.
    // Update entry on WorkingSet for all cases.
    // You can only call completionHandler once, but I am unsure of what other changes we may have.
    let totalProgress = Progress(totalUnitCount: 100)

    if changedFields.contains(.contents) {
      if item.contentType == .symbolicLink {
        log.info("Symlink")
        completionHandler(nil, [], false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
      } else if let url = newContents {
        log.info("File Content")
        let uploadProgress = _uploadItem(item,
                                         inParent: modifiedItemParent,
                                         originalIdentifier: originalIdentifier,
                                         baseVersion: version,
                                         changedFields: changedFields,
                                         contents: url,
                                         options: options,
                                         request: request,
                                         log: log,
                                         completionHandler: completionHandler)
        totalProgress.addChild(uploadProgress, withPendingUnitCount: 100)
      } else {
        completionHandler(nil, changedFields, false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
      }
    } else {
      log.info("File Attributes")
      // Cannot modify Symlink attributes
      if originalIdentifier.itemIdentifier.isSymbolicLink() {
        completionHandler(nil, changedFields, false, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
      } else {
        let modifyProgress = _modifyItemAttributes(originalIdentifier: originalIdentifier,
                                                   baseVersion: version,
                                                   name: changedFields.contains(.filename) ? item.filename : nil,
                                                   parent: changedFields.contains(.parentItemIdentifier) ? modifiedItemParent : nil,
                                                   creationDate: changedFields.contains(.creationDate) ? item.creationDate! : nil,
                                                   modificationDate: changedFields.contains(.contentModificationDate) ? item.contentModificationDate! : nil,
                                                   log: log,
                                                   completionHandler: completionHandler
        )
        totalProgress.addChild(modifyProgress, withPendingUnitCount: 100)

      }
    }

    return totalProgress
  }

  public func deleteItem(identifier: NSFileProviderItemIdentifier,
                         baseVersion version: NSFileProviderItemVersion,
                         options: NSFileProviderDeleteItemOptions = [],
                         request: NSFileProviderRequest,
                         completionHandler: @escaping (Error?) -> Void) -> Progress {
    // An item was deleted on disk, process the item's deletion.
    // (Should read more like "request to delete an item on disk").
    let log = self.logger("deleteItem \(identifier.rawValue)")

    var blinkIdentifier: BlinkFileItemIdentifier
    do {
      guard let validBlinkIdentifier = try self.workingSet.blinkIdentifier(for: identifier) else {
        completionHandler(NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier))
        return Progress()
      }
      blinkIdentifier = validBlinkIdentifier
      log.info("At path \(blinkIdentifier.path)")
    } catch {
      log.error("\(error)")
      completionHandler(error)
      return Progress()
    }

    // If file already deleted.
    // Recursive deletion.
    // Version - not relevant on iOS
    // Update the WorkingSet accordingly. Even recursive.
    // In this case, signal a refresh of the WorkingSet. It makes sense, because other items may be affected
    // by that, and although in our case we keep a local state, others may not.

    let progress = Progress(totalUnitCount: 10)
    let recursive = options.contains(.recursive)
    // Single item deletions may come as recursive too
//    if recursive {
//      log.error("Recursive delete not supported")
//      completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
//      return Progress()
//    }

    // If we move this to BlinkFiles, we may want to report (maybe FileAttributes and current path) instead of just returning Void.
    func delete(_ translators: [Translator]) -> AnyPublisher<Void, Error> {
      translators.publisher
        .flatMap(maxPublishers: .max(1)) { t -> AnyPublisher<Void, Error> in
          log.debug(t.current)
          if t.fileType == .typeDirectory {
            return [deleteDirectoryContent(t), AnyPublisher(t.rmdir().map {_ in})]
              .compactMap { $0 }
              .publisher
              .flatMap(maxPublishers: .max(1)) { $0 }
              .collect()
              .map {_ in}
              .eraseToAnyPublisher()
          }

          return AnyPublisher(t.remove().map { _ in })
        }.eraseToAnyPublisher()
    }

    func deleteDirectoryContent(_ t: Translator) -> AnyPublisher<Void, Error>? {
      if recursive == false {
        return nil
      }

      return t.directoryFilesAndAttributes().flatMap {
        $0.compactMap { i -> FileAttributes? in
          if (i[.name] as! String) == "." || (i[.name] as! String) == ".." {
            return nil
          } else {
            return i
          }
        }.publisher
      }
      .flatMap { i in
        log.debug("processing: \((t.current as NSString).appendingPathComponent(i[.name] as! String))")
        let fileType = i[.type] as? FileAttributeType
        if fileType == .typeSymbolicLink {
          return Just(t.clone()).tryMap { try $0.join(i[.name] as! String) }
            .mapError { error in
              log.error("Error at \((t.current as NSString).appendingPathComponent(i[.name] as! String))")
              return error
            }.eraseToAnyPublisher()
        } else {
          return t.cloneWalkTo(i[.name] as! String).mapError { error in
            log.error("Error at \((t.current as NSString).appendingPathComponent(i[.name] as! String))")
            return error
          }.eraseToAnyPublisher()
        }
      }
      .collect()
      .flatMap {
        delete($0) }
      .eraseToAnyPublisher()
    }

    var deleteCancellable: AnyCancellable? = nil

    deleteCancellable = self.rootTranslator
      .flatMap { t -> AnyPublisher<[Translator], Never> in
        if blinkIdentifier.itemIdentifier.isSymbolicLink() {
          return Just(t.clone())
            .tryMap { try $0.join(blinkIdentifier.path) }
            .collect()
            .catch { error -> AnyPublisher<[Translator], Never> in
              log.warn("Cannot resolve item. Skipping deletion. \(error)")
              return Just([]).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        } else {
          return t.cloneWalkTo(blinkIdentifier.path)
            .collect()
          // If the walk fails (file does not exist), then finish and report.
            .catch { error -> AnyPublisher<[Translator], Never> in
              log.warn("Cannot walk to item. Skipping deletion. \(error)")
              return Just([]).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
      }
      .flatMap { delete($0) }
      .sink(
        receiveCompletion: { completion in
          switch completion {
          case .finished:
            log.info("Completed")
            progress.completedUnitCount = progress.totalUnitCount
            completionHandler(nil)
          case .failure(let error):
            log.error("Error: \(error)")
            completionHandler(error)
          }
        }, receiveValue: { _ in }
      )

    progress.cancellationHandler = {
      deleteCancellable?.cancel()
      deleteCancellable = nil
      // Enumerate here as well for partial deletion
      completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError))
    }

    return progress
  }

  public func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
    let log = self.logger("enumeratorFor \(containerItemIdentifier.rawValue)")

    if containerItemIdentifier == .workingSet {
      log.info("Requested")
      return WorkingSetEnumerator(workingSet: workingSet, logger: self.logger("enumeratorFor WorkingSet"))
    }

    if containerItemIdentifier == .trashContainer {
      throw NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:])
    }

    let blinkIdentifier = try containerItemIdentifier == .rootContainer ?
      BlinkFileItemIdentifier.rootContainer :
      {
        guard let identifier = try workingSet.blinkIdentifier(for: containerItemIdentifier) else {
          // TODO This may need a full resync instead as the identifier is not valid.
          throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: containerItemIdentifier)
        }
        return identifier
      }()

    log.info("\(blinkIdentifier.description)")
    let enumeratorLog = self.logger("enumeratorFor \(blinkIdentifier.itemIdentifier.rawValue) \(blinkIdentifier.description)")
    let enumerator = FileProviderReplicatedEnumerator(for: blinkIdentifier,
                                                      workingSet: self.workingSet,
                                                      connection: self.connection,
                                                      logger: enumeratorLog)
    try enumerator.makeActiveEnumerator()
    return enumerator
  }

  deinit {
    let log = self.logger("deinit")
    log.info("FP Extension")
  }
}

extension NSFileProviderDomain {
  private var _components: [String]? {
    let components = self.identifier.rawValue.components(separatedBy: "-")
    guard components.count == 2 else {
      return nil
    }
    return components
  }

  var reference: String? { _components?[0] }
  var providerPath: String? {
    guard let components = _components,
          let data = Data(base64Encoded: components[1]) else {
      return nil
    }

    return String(data: data, encoding: .utf8)
  }
}

fileprivate extension BlinkLoggingHandlers {
  static func fileProviderLoggingHandlers(domainName: String) throws -> [BlinkLogging.LogHandlerFactory] {
    let fileLoggingURL = BlinkPaths.blinkURL().appendingPathComponent("fp-\(domainName).log")
    let fileLogging = try FileLogging(to: fileLoggingURL)

    let printHandler = Self.print
    let outputHandler: BlinkLogging.LogHandlerFactory =
      {
        try $0.filter(logLevel: .debug)
        // Format
          .format { [
                      "[\(Date().formatted(.iso8601))]",
                      "[\($0[.logLevel] ?? BlinkLogLevel.log)]",
                      $0[.component] as? String ?? "global",
                      $0[.message] as? String ?? ""
                    ].joined(separator: " : ") }
          .sinkToFile(fileLogging)
      }

    return [printHandler, outputHandler]
  }
}
