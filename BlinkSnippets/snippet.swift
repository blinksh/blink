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

import Foundation

public class Snippet: ObservableObject, Hashable, Identifiable {
  public var id: String { self.indexable }
  
  public static func == (lhs: Snippet, rhs: Snippet) -> Bool {
    lhs.folder == rhs.folder && lhs.name == rhs.name
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.folder)
    hasher.combine(self.name)
  }

  public let name: String
  public let folder: String
  // public let date: String
  public let title: String
  public let ext: [String]
  public let store: SnippetContentLocation

  public let language: String
  public let isEncrypted: Bool
  public let isDangerous: Bool
  public let indexable: String

  // Title and extension
  public static func parseName(_ name: String) -> (String, [String]) {
    var title = name.lowercased().replacingOccurrences(of: " ", with: "-") as NSString
    var ext: [String] = []

    while title.pathExtension != "" {
      ext.append(title.pathExtension)
      title = (title.deletingPathExtension as NSString).lastPathComponent as NSString
    }

    return (title as String, ext)
  }
  
  public static func scratch() -> Snippet { Snippet(name: "scratch", folder: "", store: Scratch()) }

  public init(name: String, folder: String, store: SnippetContentLocation) {
    self.name = name
    (self.title, self.ext) = Self.parseName(name)
    self.isEncrypted = self.ext.contains("ext")
    self.isDangerous = self.ext.contains("danger")
    self.language = self.ext.first ?? "txt"
    self.folder = folder
    self.indexable = "\(self.folder)/\(self.title)".lowercased()
    self.store = store
//    self.description = self.store.snippetLocation(
//      folder: folder,
//      name: name
//    ).readFirstLineOfContent()
  }

  private var _description: String? = nil
  private var _content: String? = nil

  public var description: String {
    get throws {
      if _description == nil {
        _description = try self.store.readDescription(folder: self.folder, name: self.name)
      }
      return _description!
    }
  }

  public var content: String {
    get throws {
      if _content == nil {
        _content = try self.store.readContent(folder: self.folder, name: self.name)
      }
      return _content!
    }
  }
  
  public var snippetLocationURL: URL? {
    self.store.snippetLocationURL(folder: self.folder, name: self.name)
  }

  public func save(content: String) throws {
    try self.store.saveSnippet(folder: self.folder, name: self.name, content: content)
  }
}

// Separate the Snippet itself from the way it is stored. This is important so
// we can use different backends (ie, Filesystem, iCloud, DB, GitHub...)
public protocol SnippetContentLocation {
  // It may be better to do it through a parameter, because if you update the snippets,
  // you are expecting to refresh the lists.
  //  func listSnippets() throws -> [Snippet]
  func listSnippets(forceUpdate: Bool) async throws -> [Snippet]
  func saveSnippet(folder: String, name: String, content: String) throws -> Snippet
  func deleteSnippet(folder: String, name: String) throws
  func readContent(folder: String, name: String) throws -> String
  func readDescription(folder: String, name: String) throws -> String
  func snippetLocationURL(folder: String, name: String) -> URL?
  var isReadOnly: Bool { get }
  var description: String { get }
//  func updateSnippets()
}

extension Snippet : FuzzySearchable {
  public var fuzzyIndex: String {
    self.indexable
  }
}

private class Scratch: SnippetContentLocation {
  func listSnippets(forceUpdate: Bool) async throws -> [Snippet] { [] }
  
  func saveSnippet(folder: String, name: String, content: String) throws -> Snippet { throw URLError(.unknown) }
  
  func deleteSnippet(folder: String, name: String) throws { }
  
  func readContent(folder: String, name: String) throws -> String { "" }
  
  func readDescription(folder: String, name: String) throws -> String { "" }
  
  func snippetLocationURL(folder: String, name: String) -> URL? { nil }
  
  var isReadOnly: Bool { true }
  
  var description: String { "scratch" }
}
