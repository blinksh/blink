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

import UIKit
import Foundation
import BlinkSnippets
import HighlightSwift

let ResultsLimit = 30;

public struct Accumulator<V> {
  var snippets: [Snippet] = []
  var indexedSnippets: Set<Snippet> = []
  var rangesMap: [Snippet: V] = [:]
  var matchesMap: [Snippet: AttributedString] = [:]
  var contentMap: [Snippet: AttributedString] = [:]
  var query: String
  var style: HighlightStyle {
    didSet {
      for (k, v) in contentMap {
        // TODO: find more perfomant conversion
        let content = String(v.characters);
        if let attr = try? Highlight.text(content, language: "sh", style: self.style) {
          contentMap[k] = AttributedString(attr.text)
        }
      }
    }
  }
  
  init(query: String, style: HighlightStyle) {
    self.query = query
    self.style = style
    snippets.reserveCapacity(ResultsLimit)
    rangesMap.reserveCapacity(ResultsLimit)
    indexedSnippets.reserveCapacity(ResultsLimit)
  }
  
  mutating func clear() {
    snippets = []
    rangesMap = [:]
    matchesMap = [:]
    contentMap = [:]
    indexedSnippets = []
    query = ""
  }
  
  var isEmpty: Bool {
    snippets.isEmpty
  }
  
  func chooseSource(query newQuery: String, wideIndex: [Snippet]) -> [Snippet] {
    if query.isEmpty {
      return wideIndex
    }
    if newQuery.hasPrefix(query) {
      return self.snippets
    }
    return wideIndex
  }
}

public typealias FuzzyAccumulator = Accumulator<[NSRange]>
public typealias SearchAccumulator = Accumulator<[(line: String, ranges: [NSRange])]>


extension FuzzyAccumulator {
  
  mutating func add(pair: (Snippet, Matrix<Int?>)) {
    let snippet = pair.0
    
    // If description is not accessible (rare problem with cached content), then ignore.
    // Shadow the snippet if already added (different locations).
    guard let snippetDescription = try? snippet.description else {
      return
    }

    let (inserted, _) = indexedSnippets.insert(snippet)
    guard inserted else {
      return
    }

    snippets.append(snippet)
    let ranges = pair.1.ranges()
    rangesMap[snippet] = ranges
    
    let attrStr = NSMutableAttributedString(string: snippet.indexable)

    for r in ranges {
      attrStr.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: r)
    }
    
    matchesMap[snippet] = AttributedString(attrStr)
   
    if let attr = try? Highlight.text(snippetDescription, language: "sh", style: self.style) {
      contentMap[snippet] = AttributedString(attr.text)
    }
  }
  
  static func accumulate(_ acc: Self, _ value: (Snippet, Matrix<Int?>)) -> Self {
    var acc = acc
    acc.add(pair: value)
    return acc
  }
}


extension SearchAccumulator {
  mutating func add(pair: (Snippet, V)) {
    if pair.1.isEmpty {
      return
    }
    snippets.append(pair.0)
    rangesMap[pair.0] = pair.1
    
    let lines = pair.1;
    let content = lines.map({$0.line}).joined(separator: "\n")
    
    let attrStr: NSMutableAttributedString;
    
    if let attr = try? Highlight.text(content, language: "sh", style: self.style) {
      attrStr = attr.text
    } else {
      attrStr = NSMutableAttributedString(string: content)
    }
    
    var lineLoc = 0
    for (line, ranges) in lines {
      for range in ranges {
        var res = range
        res.location += lineLoc
        attrStr.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: res)
      }
      lineLoc = line.count + 1
    }
    
    contentMap[pair.0] = AttributedString(attrStr)
    
  }
  
  static func accumulate(_ acc: Self, _ value: (Snippet, V)) -> Self {
    var acc = acc
    acc.add(pair: value)
    return acc
  }
}

