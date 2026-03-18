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
import Combine
import FileProvider
import SQLite

class FileProviderReplicatedEnumerator: NSObject, NSFileProviderEnumerator {
  let blinkIdentifier: BlinkFileItemIdentifier
  private let anchor = NSFileProviderSyncAnchor("an anchor".data(using: .utf8)!)
  private let log: BlinkLogger
  private var enumerateItemsCancellable: AnyCancellable? = nil
  private var tryMakeActiveEnumerator = false
  private var isActiveEnumerator = false

  // Made weak just in case the WorkingSet still retains any enumerators before shut down
  // (although what we see is that the FP is always cleaning up).
  private weak var workingSet: WorkingSet? = nil
  private let connection: FilesTranslatorConnection

  private var itemTranslator: TranslatorPublisher {
    let path = blinkIdentifier.path
    let identifier = self.blinkIdentifier.itemIdentifier
    return connection.rootTranslator
      .flatMap { path.isEmpty ? .just($0.clone()) :
        $0.cloneWalkTo(path)
          .mapError { _ in NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier) }.eraseToAnyPublisher()
      }
      .eraseToAnyPublisher()
  }

  public init(for blinkIdentifier: BlinkFileItemIdentifier,
              workingSet: WorkingSet,
              connection: FilesTranslatorConnection,
              logger: BlinkLogger) {
    self.log = logger
    self.blinkIdentifier = blinkIdentifier
    self.connection = connection
    self.workingSet = workingSet

    super.init()
  }

  func makeActiveEnumerator(needsEnumeration: Bool = true) throws {
    tryMakeActiveEnumerator = true
    if let workingSet = workingSet,
       try workingSet.addToActiveEnumerators(self, itemIdentifier: blinkIdentifier.itemIdentifier, needsEnumeration: needsEnumeration) {
      self.log.info("Enumerator is Active in WorkingSet")
      tryMakeActiveEnumerator = false
      isActiveEnumerator = true
    } else {
      self.log.info("Not part of WorkingSet yet")
    }
  }

  public func invalidate() {
    self.log.info("invalidate")
    if isActiveEnumerator {
      self.workingSet?.removeFromActiveEnumerators(self)
    }
    self.workingSet = nil
    self.enumerateItemsCancellable = nil
  }

  public func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    log.info("enumerateItems")

    guard let workingSet = workingSet else {
      log.error("enumerateItems for invalidated enumerator (no workingSet)")
      observer.finishEnumeratingWithError(NSFileProviderError(errorCode: 100,
                                              errorDescription: "Invalid enumerator",
                                              failureReason: "enumerateItems for invalidated enumerator (no workingSet)"))
      return
    }
    /*
     If this is an enumerator for a directory, the root container or all directories:
     - perform a server request to fetch directory contents
     If this is an enumerator for the active set:
     - perform a server request to update your local database
     - fetch the active set from your local database

     - inform the observer about the items returned by the server (possibly multiple times)
     - inform the observer that you are finished with this page
     */

    enumerateItemsCancellable = self.allItems()
      .tryMap { itemsAttributes -> [FileProviderItem] in
        try workingSet.commitItemsInContainer(self.blinkIdentifier, itemsAttributes: itemsAttributes)
      }
      .sink (
        receiveCompletion: { completion in
          switch completion {
          case .failure(let error):
            self.log.error("enumerateItems Error \(error)")
            observer.finishEnumeratingWithError(error)
          case .finished:
            if self.tryMakeActiveEnumerator { try? self.makeActiveEnumerator(needsEnumeration: false) }
            observer.finishEnumerating(upTo: nil)
          }
        },
        receiveValue: {
          self.log.info("Enumerated \($0.count) items")
          // Skip "." as internal. If you enumerate ".", it is seen as a container by the System, and it may
          // end up in a recursion loop itself.
          observer.didEnumerate($0.filter { $0.filename != "." })
        })
  }

  public func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    /*
     - query the server for updates since the passed-in sync anchor

     If this is an enumerator for the active set:
     - note the changes in your local database

     - inform the observer about item deletions and updates (modifications + insertions)
     - inform the observer when you have finished enumerating up to a subsequent sync anchor
     */
    log.info("No changes at enumerator")
    // I wouldn't expect this one to be called. But we could return it
    // based on the current state of the Accumulator - as previous states shouldn't be called either.
    // Or, if we to return from a previous Accumulator, we could return it based on database and doing individual stat for contents.
    observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
  }

  func allItems() -> AnyPublisher<[BlinkFiles.FileAttributes], Error> {
    itemTranslator
      .flatMap { $0.isDirectory ? $0.directoryFilesAndAttributesWithTargetLinks() : AnyPublisher($0.stat().collect()) }
      .map { allAttributes -> [BlinkFiles.FileAttributes] in
        allAttributes.compactMap { fileAttributes -> BlinkFiles.FileAttributes? in
          guard let fileName = fileAttributes[.name] as? String else { return nil }
          if fileName == ".." ||
               // This is recognized as a special directory by the system, we skip it.
               fileName == ".Trash" ||
               fileName.starts(with: ".blink.tmp.") {
            return nil
          }
          return fileAttributes
        }
      }
      .eraseToAnyPublisher()
  }

  public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
    log.info("currentSyncAnchor requested")
    completionHandler(nil)
    // if let workingSet = workingSet,
    //    ((try? workingSet.isContentInSet(self.blinkIdentifier.itemIdentifier)) ?? false),
    //    let anchor = self.workingSet?.anchor {
    //   log.info("currentSyncAnchor \(anchor.string)")
    //   completionHandler(anchor)
    // } else {
    //   completionHandler(nil)
    // }
  }

  deinit {
    log.info("cleared")
  }
}

public class WorkingSetEnumerator: NSObject, NSFileProviderEnumerator {
  private let log: BlinkLogger
  private let workingSet: WorkingSet

  public func invalidate() {
    log.info("invalidate")
  }

  public func enumerateItems(for observer: any NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
    log.info("enumerateItems")
    /*
     If this is an enumerator for the active set:
     - perform a server request to update your local database
     - fetch the active set from your local database
     */
    //observer.didEnumerate([FileProviderItem(identifier: NSFileProviderItemIdentifier("a file"))])

    observer.finishEnumerating(upTo: nil)
  }

  public func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    log.info("enumerateChanges from \(anchor.string)")
    self.workingSet.enumerateChanges(for: observer, from: anchor)
  }

  public func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
    let anchor = workingSet.anchor
    log.info("currentSyncAnchor \(anchor.string)")
    completionHandler(anchor)
  }

  init(workingSet: WorkingSet, logger: BlinkLogger) {
    self.log = logger
    self.workingSet = workingSet

    super.init()

    log.info("requested")
  }

  deinit {
    log.info("deinit")
  }
}

public class WorkingSet {
  private let fpm: NSFileProviderManager?
  private let pollCoordinator = PollCoordinator()
  private var timer: DispatchSourceTimer? = nil
  private var timerIntervalInSeconds = 0
  private let log: BlinkLogger
  private var prepareChangesCancellable: AnyCancellable? = nil
  private var prepareChangesTick = 0
  private let changesQueue = DispatchQueue(label: "sh.blink.BlinkFileProvider.WorkingSet")

  private var anchorIteration: Int
  private var anchorVersion: String
  var anchor: NSFileProviderSyncAnchor {
    NSFileProviderSyncAnchor("\(anchorVersion)-\(anchorIteration)".data(using: .utf8)!)
  }
  private var changes = ItemsChanged()
  private let db: WorkingSetDatabase

  private var itemsInCommit = Set<String>()

  init(domain: NSFileProviderDomain?, db: WorkingSetDatabase, logger: BlinkLogger) throws {
    self.log = logger

    if let domain = domain {
      self.fpm = NSFileProviderManager(for: domain)!
    } else {
      self.fpm = nil
    }

    self.db = db
    self.anchorIteration = try db.newestAnchor()
    self.anchorVersion = db.anchorVersion

    self.log.info("Initialized")
  }

  deinit {
    self.log.debug("Deinit")
  }

  func resumeChangesTimerEvery(seconds: Int) {
    let timer = DispatchSource.makeTimerSource(flags: [], queue: changesQueue)
    timer.setEventHandler { [weak self] in
      guard let self = self else {
        return
      }

      self.log.info("Timer triggered")
      self.prepareChangesAndSignalEnumerator()
    }

    timer.schedule(deadline: .now(), repeating: .seconds(seconds))
    timer.resume()

    self.timer = timer
    self.timerIntervalInSeconds = seconds
  }

  func addToActiveEnumerators(_ enumerator: FileProviderReplicatedEnumerator,
                              itemIdentifier: NSFileProviderItemIdentifier,
                              needsEnumeration: Bool) throws -> Bool {
    // What happens if an Container is empty? Then it will never be part of the WorkingSet?
    // Always add the ".", but do not publish it.
    if try self.isContentInSet(itemIdentifier) {
      return changesQueue.sync {
        self.pollCoordinator.addActiveEnumerator(enumerator)

        if needsEnumeration && prepareChangesCancellable == nil {
          self.cancelChanges()
          if timer != nil {
            resumeChangesTimerEvery(seconds: self.timerIntervalInSeconds)
          }
        }
        return true
      }
    }
    return false
  }

  func removeFromActiveEnumerators(_ enumerator: FileProviderReplicatedEnumerator) {
    self.log.info("Removing enumerator \(enumerator)")

    changesQueue.sync { self.pollCoordinator.removeActiveEnumerator(enumerator) }
  }

  @objc func prepareChangesAndSignalEnumerator() {
    prepareChanges { [weak self] (changes) in
      guard let self = self else {
        return
      }

      if changes.isEmpty {
        self.log.info("No changes.")
        return
      }

      // Only apply changes if previous batch was applied.
      if self.changes.isEmpty {
        self.anchorIteration += 1
        self.changes = changes
      }

      self.signalEnumerator()
    }
  }

  func prepareChanges(onCompletion: @escaping ((ItemsChanged) -> Void)) {
    changesQueue.async { [weak self] in
      guard let self = self else {
        return
      }

      self.log.info("Preparing changes. \(self.itemsInCommit.count) items in commit.")

      // The WorkingSet may step on its own while enumerating changes and with long running
      // operations in the background. The backoff control tries to avoid that.
      if prepareChangesCancellable != nil {
        if prepareChangesTick < 3 {
          prepareChangesTick += 1
        } else {
          prepareChangesTick = 0
          prepareChangesCancellable?.cancel()
          prepareChangesCancellable = nil
        }
      }

      let enumerators = self.pollCoordinator.nextBatch()

      if enumerators.isEmpty {
        onCompletion(ItemsChanged())
        return
      }

      self.prepareChangesCancellable = enumerators.publisher
        .compactMap { enumerator in
          self.itemsInCommit.contains { $0.hasPrefix(enumerator.blinkIdentifier.path + "/") } ? nil : enumerator
        }
        .flatMap { enumerator -> AnyPublisher<([ItemRow], [FileProviderItem]), Never> in
          let container = enumerator.blinkIdentifier
          let dbItemsPublisher = Just(container.itemIdentifier)
            .tryMap {
              let itemRows = try self.db.items(in: $0)
              self.log.debug("\(container.description) has \(itemRows.count) on DB")
              return itemRows
            }
          let allItemsPublisher = enumerator.allItems()
            .tryMap {
              self.log.debug("\(container.description) received \($0.count) from source.")
              return try self.matchOrGenerateItemAttributesInContainer(container, itemsAttributes: $0)
            }

          return Publishers.Zip(dbItemsPublisher, allItemsPublisher)
            .catch { error -> AnyPublisher<([ItemRow], [FileProviderItem]), Never> in
              // Skip an enumerator if it failed.
              self.log.error("prepareChanges for \(container.description) failed - \(error)")
              return Just(([], [])).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        }
        .receive(on: self.changesQueue)
        .map { (rows: [ItemRow], items: [FileProviderItem]) -> ItemsChanged in
          let deletedRows = rows.filter { row in
            !items.contains { $0.filename == row.name }
          }

          let updatedItems = items.compactMap { item in
            if let row = rows.first(where: { $0.name == item.filename }),
               item.itemVersion != row.version {
              return item
            }
            return nil
          }

          // Find new items
          let newItems = items.filter { item in
            !rows.contains { $0.name == item.filename }
          }

          let detectedChanges = ItemsChanged(creates: newItems, updates: updatedItems, deletions: deletedRows)
          if detectedChanges.hasChanges {
            (newItems + updatedItems).forEach { item in
              self.log.debug("Item changed: \(item.filename)")
            }
            deletedRows.forEach { item in
              self.log.debug("Deleted \(item.name)")
            }
          }
          return detectedChanges
        }
        .reduce(ItemsChanged()) { (all: ItemsChanged, next: ItemsChanged) -> ItemsChanged in
          return ItemsChanged(creates: all.creates + next.creates,
                              updates: all.updates + next.updates,
                              deletions: all.deletions + next.deletions)
       }
        .sink {
          self.log.info("Prepare changes completed")
          onCompletion($0)
        }
    }
  }


  func scheduleDeletionsAndSignalEnumerator(deletions: [ItemRow]) {
    // When scheduling changes, we let them sit on top of the prepared changes.
    changesQueue.async { [weak self] in
      guard let self = self else {
        return
      }

      self.log.info("Scheduling Deletion changes")

      if self.changes.isEmpty {
        self.anchorIteration += 1
      }

      self.changes = ItemsChanged(creates: self.changes.creates,
                                  updates: self.changes.updates,
                                  deletions: deletions + self.changes.deletions)

      self.signalEnumerator()
    }
  }

  func signalEnumerator() {
    self.log.info("signalEnumerator for \(self.anchorIteration) anchor iteration.")

    self.fpm?.signalEnumerator(for: .workingSet) { error in
      if let error = error {
        self.log.error("signalEnumerator failed after prepareChanges: \(error)")
      }
    }
  }
  // The flow for changes is divided in two parts. prepare and commit (changes). We use enumerateChanges as the commit part.
  func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
    self.changesQueue.sync {
      if anchor == self.anchor {
        self.log.debug("enumerateChanges on Same anchor \(anchorIteration)")
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
        return
      } else if self.anchor.iteration == anchor.iteration + 1 {
        self.log.debug("enumerateChanges coordinate next step")

        do {
          let createRows = self.changes.creates.map { ItemRow.from($0, at: self.anchorIteration) }
          let updateRows = self.changes.updates.map { ItemRow.from($0, at: self.anchorIteration) }

          let deletedRows = try db.updateChangedItems(createRows: createRows, updateRows: updateRows, deleteRows: self.changes.deletions)
          let deletions = deletedRows.map { $0.item }

          // Filter "." as internal.
          let updatedItems = (changes.creates + changes.updates).filter { $0.filename != "." }
          observer.didDeleteItems(withIdentifiers: deletions)
          observer.didUpdate(updatedItems)
          observer.finishEnumeratingChanges(upTo: self.anchor, moreComing: false)
          self.changes = ItemsChanged()
        } catch {
          self.log.error("enumerateItems error - \(error)")
          observer.finishEnumeratingWithError(error)
        }

        return
      } else {
        self.log.error("SyncAnchor expired. Requested \(anchor.string). WorkingSet at \(self.anchor.string)")
        // The system is in an incorrect state. Reset.
        observer.finishEnumeratingWithError(NSError(domain: NSFileProviderErrorDomain,
                                                    code: NSFileProviderError.syncAnchorExpired.rawValue,
                                                    userInfo: nil))
        return
      }
    }

//    // Not necessary atm.
//    func enumerateItems(for observer: any NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
//      log.info("enumerateItems")
//      /*
//       If this is an enumerator for the active set:
//       - perform a server request to update your local database
//       - fetch the active set from your local database
//       */
//      // Stop timers. Try not to Commit and PrepareChanges at the same time.
//      // I don't like we need the rootContainer. And then walk to each container to figure out if it still exists.
//      // Should the other container enumerators also check for that?
//      // Get all the containers.
//      Just(self.db)
//        .tryMap { try $0.containersInSet() }
//        .flatMap { containers in

//        }
//      // Create enumerators and enumerate one by one.
//      // Commit
//      // Restart timers.
//    }
  }
}

// WorkingSet + DB functions
extension WorkingSet {
  func blinkIdentifier(for identifier: NSFileProviderItemIdentifier) throws -> BlinkFileItemIdentifier? {
    if identifier == .rootContainer {
      return .rootContainer
    }

    guard let row = try db.item(identifier) else {
      // Return the item does not exist, let other layers decide the error for the extension.
      // throw NSError.fileProviderErrorForNonExistentItem(withIdentifier: identifier)
      return nil
    }
    return row.blinkIdentifier()
  }

  func blinkIdentifier(itemName: String, container: BlinkFileItemIdentifier) throws -> BlinkFileItemIdentifier? {
    guard let row = try db.item(from: itemName, containerIdentifier: container.itemIdentifier) else {
      return nil
    }
    return row.blinkIdentifier()
  }

  func isItemInSet(_ identifier: NSFileProviderItemIdentifier) throws -> Bool {
    try db.isItemInSet(identifier)
  }

  func isContentInSet(_ containerIdentifier: NSFileProviderItemIdentifier) throws -> Bool {
    try db.isContentInSet(containerIdentifier)
  }

  func commitItemsInContainer(_ container: BlinkFileItemIdentifier, itemsAttributes: [BlinkFiles.FileAttributes]) throws -> [FileProviderItem] {
    log.debug("Commit \(itemsAttributes.count) items at \(container.path)")

    // Replace Rows with new set.
    let items = try matchOrGenerateItemAttributesInContainer(container, itemsAttributes: itemsAttributes)

    let newRows = items.map { ItemRow.from($0, at: self.anchorIteration) }

    let _ = try self.db.updateItemsInContainer(container, items: newRows)

    return items
  }

  private func matchOrGenerateItemAttributesInContainer(_ container: BlinkFileItemIdentifier, itemsAttributes: [BlinkFiles.FileAttributes]) throws -> [FileProviderItem] {
    let previousRows = try self.db.items(in: container.itemIdentifier)

    return itemsAttributes.map { itemAttrs in
      let itemName = itemAttrs[.name] as! String
      let fileType = itemAttrs[.type] as? FileAttributeType
      let blinkIdentifier = if let existingRow = previousRows.first(where: { $0.name == itemName }) {
        BlinkFileItemIdentifier(with: existingRow.item, name: itemName, parent: container)
      } else {
        BlinkFileItemIdentifier.generate(name: itemName, parent: container, isSymbolicLink: fileType == .typeSymbolicLink)
      }

      return FileProviderItem(blinkIdentifier: blinkIdentifier, attributes: itemAttrs)
    }
  }

  func commitItemInSet(itemPath: String, itemPublisher: () -> AnyPublisher<FileProviderItem, Error>) ->
    AnyPublisher<FileProviderItem, Error> {
    return changesQueue.sync {
      log.debug("Committing item \(itemPath)")
      itemsInCommit.insert(itemPath)
      return itemPublisher()
        .tryMap { item in
          let row = ItemRow.from(item, at: self.anchorIteration)
          let _ = try self.db.updateItem(row)
          return item
        }
        .handleEvents(
          receiveCompletion: { _ in self.changesQueue.async { self.itemsInCommit.remove(itemPath) } },
          receiveCancel: { self.changesQueue.async { self.itemsInCommit.remove(itemPath) } }
        )
        .eraseToAnyPublisher()
    }
  }

  func commitItemInSet(_ item: FileProviderItem) throws {
    log.debug("Committing item \(item.blinkIdentifier.path)")
    let row = ItemRow.from(item, at: self.anchorIteration)
    let _ = try self.db.updateItem(row)
  }

  func invalidate() {
    cancelTimers()
    cancelChanges()
  }

  private func cancelChanges() {
    self.prepareChangesCancellable?.cancel()
    self.prepareChangesCancellable = nil
  }

  private func cancelTimers() {
    self.timer?.cancel()
    self.timer = nil
  }
}

enum ItemChange {
  case Update(FileProviderItem)
  case Delete(ItemRow)
}

struct ItemsChanged {
  var creates: [FileProviderItem]
  var updates: [FileProviderItem]
  var deletions: [ItemRow]

  init() {
    self.creates = []
    self.updates = []
    self.deletions = []
  }

  init(creates: [FileProviderItem], updates: [FileProviderItem], deletions: [ItemRow]) {
    self.creates = creates
    self.updates = updates
    self.deletions = deletions
  }

  var hasChanges: Bool {
    self.creates.count > 0 || self.updates.count > 0 || self.deletions.count > 0
  }

  var isEmpty: Bool {
    !self.hasChanges
  }
}

extension NSFileProviderSyncAnchor {
  var iteration: Int {
    Int(self.string
      .components(separatedBy: "-")[1])!
  }

  var string: String {
    String(data: self.rawValue, encoding: .utf8)!
  }
}

class PollCoordinator {
  private var activeEnumerators: [FileProviderReplicatedEnumerator] = []

  func addActiveEnumerator(_ enumerator: FileProviderReplicatedEnumerator) {
    // Observed that the provider may add the enumerator more than once while it transitions.
    // That is ok, work with the instance, and we could filter later.
    guard !activeEnumerators.contains(where: { enumerator === $0 }) else { return }

    // ActiveEnumerators are open/active folders by the user, were changes may happen,
    // so we keep them open. It is rare that it would be higher than this number, but we
    // found a case where an operation would create a lot of enumerators without killing them.
    // This is a simple way to rotate them without impacting performance.
    if activeEnumerators.count == 5 {
      _ = activeEnumerators.popLast()
    }

    activeEnumerators.append(enumerator)
  }

  func removeActiveEnumerator(_ enumerator: FileProviderReplicatedEnumerator) {
    activeEnumerators.removeAll(where: { enumerator === $0 })
  }

  func nextBatch() -> [FileProviderReplicatedEnumerator] {
    return activeEnumerators
  }
}
