//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2023 Blink Mobile Shell Project
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
import BlinkSnippets
import BlinkConfig
import Combine

// Works exclusively with the SearchModel, while being responsible for the
// locations, efficient caching and fetching of Snippets.
// Being a separate object gives us more flexibility to make this a Singleton, to cache it
// between multiple SearchModel usages, etc...
class SnippetsLocations {
  let locations: [SnippetContentLocation]
  // Default as the writing location.
  // NOTE In the future we may allow to re-define it, or to select it when storing.
  let defaultLocation: SnippetContentLocation
  var refreshCancellable: Cancellable? = nil
  
  enum RefreshProgress {
    case none
    case started
    case completed([Error]?)
  }
  // The main interface with the SearchModel. Provides the index whenever it has changed in any way.
  // TODO Problem is it does not communicate errors very well.
  // We could use another publisher for Errors, associated to Progress.
  public let indexPublisher = CurrentValueSubject<[Snippet], Never>([])
  public let indexProgressPublisher = CurrentValueSubject<RefreshProgress, Never>(.none)
  
  public init() {
    let snippetsLocation = BlinkPaths.snippetsLocationURL()!
    let cachedSnippetsLocation = snippetsLocation.appending(path: ".cached")
    
    // Create main snippets location. Each location then is responsible for its structure.
    if !FileManager.default.fileExists(atPath: snippetsLocation.path()) {
      try! FileManager.default.createDirectory(at: snippetsLocation, withIntermediateDirectories: true)
      try! FileManager.default.createDirectory(at: cachedSnippetsLocation, withIntermediateDirectories: true)
    }
    
    // ".blink/snippets" for local
    // ".blink/snippets/.cached/com.github" for github
    let localSnippetsLocation = LocalSnippets(from: snippetsLocation)
    let blinkSnippetsLocation = try! GitHubSnippets(owner: "blinksh", repo: "snippets", cachedAt: cachedSnippetsLocation)
    
    self.defaultLocation = localSnippetsLocation
    self.locations = [localSnippetsLocation, blinkSnippetsLocation]
    
    refreshIndex()
  }
  
  // If the ".locations" file changes, it will be read again
  // on "refresh". Or forced when the change happens.
  // Same with the .ignore file.
  public func refreshIndex(forceUpdate: Bool = false) {
    indexProgressPublisher.send(.started)

    var errors: [Error] = []
    let listSnippets: AnyPublisher<[[Snippet]], Never> =
      Publishers.MergeMany(locations.map { loc in
        Deferred {
          Future {
            do {
              return try await loc.listSnippets(forceUpdate: forceUpdate)
            } catch {
              errors.append(error)
              return []
            }
          }
        }
      })
      .assertNoFailure()
      .collect()
      .eraseToAnyPublisher()
    
    refreshCancellable = listSnippets.sink(
      receiveCompletion: { _ in self.indexProgressPublisher.send(.completed(errors.isEmpty ? nil : errors))},
      receiveValue: { snippets in
        self.indexPublisher.send(Array(snippets.joined()))
      }
    )
  }
  
  public func saveSnippet(at location: SnippetContentLocation, folder: String, name: String, content: String) throws -> Snippet {
    let snippet = try location.saveSnippet(folder: folder, name: name, content: content)
    refreshIndex()
    return snippet
  }
  
  public func saveSnippet(folder: String, name: String, content: String) throws -> Snippet {
    return try saveSnippet(at: self.defaultLocation, folder: folder, name: name, content: content)
  }
  
  public func deleteSnippet(snippet: Snippet) throws {
    try snippet.store.deleteSnippet(folder: snippet.folder, name: snippet.name)
    // Remove from the index manually
    var index = indexPublisher.value
    index.removeAll(where: { $0 == snippet })
    indexPublisher.send(index)
  }
  
  public func renameSnippet(snippet: Snippet, folder: String, name: String, content: String) throws -> Snippet {
    // If we cannot write at the location, we store on default
    let store = snippet.store.isReadOnly ? defaultLocation : snippet.store
    if !snippet.store.isReadOnly {
      try self.deleteSnippet(snippet: snippet)
    }
    return try self.saveSnippet(at: store, folder: folder, name: name, content: content)
  }
}

extension Future where Failure == Error {
    convenience init(operation: @escaping () async throws -> Output) {
        self.init { promise in
            Task {
                do {
                    let output = try await operation()
                    promise(.success(output))
                } catch {
                    promise(.failure(error))
                }
            }
        }
    }
}
