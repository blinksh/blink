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
import SwiftUI
import Combine

private let _historyQueue = DispatchQueue(label: "history.queue")

struct History {
  
  struct Line: Codable {
    let num: Int
    let val: String
    let rel: Int // lower is better
  }
  
  struct SearchResponse: Codable {
    let requestId: Int
    let pattern: String
    let lines: [Line]
    let found: Int
    let total: Int
  }
  
  struct SearchRequest: Codable {
    let id: Int
    let pattern: String
    let cursor: Int
    let before: Int
    let after: Int
  }

  private static var _lastCommand: String = "";
  static private var _lines: [String]? = nil
  static private let linesLimit = 5000
  
  static func appendIfNeeded(command: String) {
    _historyQueue.async {
      if _lastCommand == command || command.isEmpty {
        return
      }

      var lines = _getLines()
      _lastCommand = command
      
      if lines.last == command {
        return;
      }
      
      lines.append(command)
      
      if lines.count > linesLimit {
        lines.remove(at: 0)
      }
      
      _saveLines(lines)
    }
  }
  
  private static func _saveLines(_ lines: [String]) {
    var allLines = lines.joined(separator: "\n")
    allLines.append("\n")
    
    guard
      let historyFile = BlinkPaths.historyFile(),
      let _ = try? allLines.write(toFile: historyFile, atomically: true, encoding: .utf8)
    else {
      return
    }
  
    _lines = lines
  }
  
  private static func _getLines() -> [String] {
    if let lines = _lines {
      // Keep history for more time
      return lines;
    }
    
    guard
      let historyFile = BlinkPaths.historyFile(),
      let str = try? String(contentsOfFile: historyFile, encoding: .utf8)
    else {
      return []
    }
    
    var result: [String] = []
    
    str.enumerateLines { line, _ in
      if !line.isEmpty {
        result.append(line)
      }
    }
    
    _lines = result
    return result
  }
  
  static func _filter(lines: [String], pattern: String) -> (total: Int, lines: [Line]) {
    var result: [Line] = [];
    var num = 0
    let all = pattern.isEmpty
    for line in lines {
      num += 1
      if all {
        result.append(Line(num: num, val: line, rel: 0))
      } else if let range = line.range(of: pattern, options: [], range: nil, locale: nil) {
        let rel = line.distance(from: line.startIndex, to: range.lowerBound)
        result.append(Line(num: num, val: line, rel: rel))
      }
    }
    
    return (total: num, lines: result.sorted { return $0.rel > $1.rel })
  }
  
  static func _slice(lines: [Line], with request: SearchRequest) -> [Line] {
    var cursorIndex = 0
    if (request.cursor == 0) {
      cursorIndex = lines.startIndex
    } else if (request.cursor == -1) {
      cursorIndex = lines.endIndex
    } else if let idx = lines.firstIndex(where: { $0.num == request.cursor }) {
      cursorIndex = idx
    } else {
      cursorIndex = lines.endIndex
    }

    let startIndex = max(0, cursorIndex - request.before)
    let endIndex = min(lines.endIndex, cursorIndex + request.after)
    let slice = lines[startIndex..<endIndex]
    return Array(slice)
  }
  
  static func _search(_ request: SearchRequest) -> SearchResponse {
    
    let (total, lines) = _filter(lines: _getLines(), pattern: request.pattern)
    let slice = _slice(lines: lines, with: request)
    
    return SearchResponse(requestId: request.id, pattern: request.pattern, lines: slice, found: lines.count, total: total)
  }
  
  static func _searchAPI(json: String) -> String? {
    let dec = JSONDecoder()
    guard
      let requestData = json.data(using: .utf8),
      let request = try? dec.decode(SearchRequest.self, from: requestData)
    else {
      return nil
    }
    
    let response = _search(request)
    let enc = JSONEncoder()
    if let responseData = try? enc.encode(response) {
      return String(data: responseData, encoding: .utf8)
    }
    return nil
  }
  

  static func searchAPI(session: MCPSession, json: String) -> AnyPublisher<String, Never> {
    Just(json)
      .subscribe(on: _historyQueue)
      .map(History._searchAPI)
      .compactMap({ $0 })
      .eraseToAnyPublisher()
  }
}


@objc class HistoryObj: NSObject {
  @objc static func appendIfNeeded(command: String) {
    History.appendIfNeeded(command: command + "") // mosh overwrites internals of the string!
  }
}
