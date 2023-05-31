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

public protocol AdaptiveSearchable {
  var searchableContent: String { get }
}

extension Sequence where Element: AdaptiveSearchable {
  public func adaptiveSearchMatch(searchString: String) -> [(Element, [Range<String.Index>])] {
    let searchTokens = searchString.components(separatedBy: " ").sorted { $0.count > $1.count }

    var matches: [(Element, [Range<String.Index>])] = []

    // "tunnel work one"
    // "Tunnel work two"
    for candidate in self {
      var candidateTokens = candidate.searchableContent.components(separatedBy: " ")

      var matchedSearchToken = false
      var ranges: [Range<String.Index>] = []
      for token in searchTokens {
        matchedSearchToken = false
        // "tun" "t"
        // Process valid candidates for each token and consume them.
        // "tunnel" "work" "one" - "work" "one"
        for (candidateTokenIdx, candidateToken) in candidateTokens.enumerated() {
          if let range = candidateToken.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]),
             range.lowerBound == candidateToken.startIndex {
            candidateTokens.remove(at: candidateTokenIdx)
            matchedSearchToken = true
            ranges.append(range)
            break
          }
        }

        guard matchedSearchToken else { break }
      }
      if matchedSearchToken {
        matches.append((candidate, ranges))
      }
    }

    return matches
  }

}

//public func adaptiveSearchMatch<T: AdaptiveSearchable, S: Sequence<T>>(
//  within index: S, searchString: String) -> [(T, [Range<String.Index>])] {
//  let searchTokens = searchString.components(separatedBy: " ").sorted { $0.count > $1.count }
//
//  var matches: [(T, [Range<String.Index>])] = []
//
//  // "tunnel work one"
//  // "Tunnel work two"
//  for candidate in index {
//    var candidateTokens = candidate.searchableContent.components(separatedBy: " ")
//
//    var matchedSearchToken = false
//    var ranges: [Range<String.Index>] = []
//    for token in searchTokens {
//      matchedSearchToken = false
//      // "tun" "t"
//      // Process valid candidates for each token and consume them.
//      // "tunnel" "work" "one" - "work" "one"
//      for (candidateTokenIdx, candidateToken) in candidateTokens.enumerated() {
//        if let range = candidateToken.range(of: token, options: [.caseInsensitive, .diacriticInsensitive]),
//           range.lowerBound == candidateToken.startIndex {
//          candidateTokens.remove(at: candidateTokenIdx)
//          matchedSearchToken = true
//          ranges.append(range)
//          break
//        }
//      }
//
//      guard matchedSearchToken else { break }
//    }
//    if matchedSearchToken {
//      matches.append((candidate, ranges))
//    }
//  }
//
//  return matches
//}

// NOTE This uses Data, but CFData functions may be more optimized for
// what we are trying to do.
// Ranges is supported on 16+ only.
// We could also just use a prototype for the algorithm.
// We could move this as part of String.
public func Search(content: String, searchString: String) -> [(line: String, ranges: [NSRange])] { // [Range<Int>] {
  // Read file on Data
  // Return ranges
  // let d = try Data(contentsOf: url)
  // This may not be a proper way to transform to U8
  //return d.ranges(of: [UInt8](searchString.utf8))

  // Separate in tokens.
  // On first range, extract a line, and from there search the rest recursively.
  let compareOptions: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
  let searchTokens = searchString.components(separatedBy: " ").sorted { $0.count > $1.count }
  var searchTokenRanges: [(String, [NSRange])] = []
  let linesLimit = 5
  content.enumerateLines { line, stop in
    var lineRanges: [NSRange] = []
    for range in line.ranges(of: searchTokens[0], options: compareOptions) {
      lineRanges.append(NSRange(range, in: line))
      for token in searchTokens[1...] {
        let subRanges = line.ranges(of: token, options: compareOptions)
        if subRanges.isEmpty {
          return
        } else {
          for range in subRanges {
            lineRanges.append(NSRange(range, in: line))
          }
        }
      }
    }
    if !lineRanges.isEmpty {
      searchTokenRanges.append((line, lineRanges))
      
      if searchTokenRanges.count >= linesLimit {
        stop = true
      }
    }
    
  }

  return searchTokenRanges
}

//   let str = try String(contentsOf: url)
//   return str.ranges(of: searchString, options: [.caseInsensitive, .diacriticInsensitive])
// }

extension String {
  func ranges(of substring: String, options: CompareOptions = [], locale: Locale? = nil) -> [Range<Index>] {
    var ranges: [Range<Index>] = []
    while let range = range(of: substring, options: options, range: (ranges.last?.upperBound ?? self.startIndex)..<self.endIndex, locale: locale) {
      ranges.append(range)
    }
    return ranges
  }
}

extension Snippet: AdaptiveSearchable {
  public var searchableContent: String {
    (try? self.content) ?? ""
  }
}
