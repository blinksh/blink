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
  
  // The main interface with the SearchModel. Provides the index whenever it has changed in any way.
  // TODO Problem is it does not communicate errors very well.
  public let indexPublisher = CurrentValueSubject<[Snippet], Error>([])
  
  public init() {
    // TODO Read from .locations and initialize
    let snippetsLocation = BlinkPaths.snippetsLocationURL()!
    let localSnippetsLocation = LocalSnippets(from: snippetsLocation.appendingPathComponent("local"))
    
    //let blinkSnippetsLocation = GitHubSnippets(owner: "blinksh", repo: "snippets", cachedAt: snippetsLocation.appendingPathComponent("com.github"))
    
    self.defaultLocation = localSnippetsLocation
    self.locations = [localSnippetsLocation]//, blinkSnippetsLocation]
    
    refreshIndex()
  }
  
  // If the ".locations" file changes, it will be read again
  // on "refresh". Or forced when the change happens.
  // Same with the .ignore file.
  
  // Another entry point is to trigger the "refresh" when we request the indexPublisher if it is nil.
  // That way we know we need to start with the cache, then subsequent ones should perform full refresh.
  public func refreshIndex() {
    // Multiple ways on updating the index, we will go easy to start.
    // Collect cached first and push immediately. Then load the rest.
    // send(cachedSnippets) -> send(refreshedSnippets)
    // TODO Communicating errors but still continue the fetch
    let cachedSnippets: AnyPublisher<[[Snippet]], Error> = Publishers.MergeMany(locations.map { loc in
      Future { try await loc.listSnippets(forceUpdate: false) }
    }).collect().eraseToAnyPublisher()
    
    refreshCancellable = cachedSnippets.sink(
      receiveCompletion: { _ in },
      receiveValue: { snippets in
        self.indexPublisher.send(Array(snippets.joined()))
      }
    )
  }
  
  public func saveSnippet(folder: String, name: String, content: String) throws {
    try self.defaultLocation.saveSnippet(folder: folder, name: name, content: content)
    refreshIndex()
  }
  
  public func deleteSnippet(snippet: Snippet) throws {
    try snippet.store.deleteSnippet(folder: snippet.folder, name: snippet.name)
    // Remove from the index manually
    var index = indexPublisher.value
    index.removeAll(where: { $0 == snippet })
    indexPublisher.send(index)
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
