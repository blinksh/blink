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
import Combine
import ios_system

private let _completionQueue = DispatchQueue(label: "completion.queue")

struct Complete {
  
  struct ForRequest: Codable {
    let id: Int
    let cursor: Int
    let input: String
    let n: Int
  }
  
  struct ForResponse: Codable {
    let requestId: Int
    let input: String
    let result: String
    let hint: String
    let kind: String
    let start: Int
    let pos: Int
    let len: Int
  }
  
  enum Kind: String {
    case command
    case file
    case directory
    case host
    case blinkHost
    case blinkGeo
    case no
  }
  
  static func cleanCaches() {
    __allCommandsCache = nil
    __commandHintsCache = nil
  }
  
  static var __allCommandsCache: Array<String>? = nil
  
  static func _allCommands() -> [String] {
    
    if let cache = __allCommandsCache {
      return cache
    }
    
    var result:Array<String> = []
    if let commands = commandsAsArray() as? [String] {
      result.append(contentsOf: commands)
    }
    result.append(contentsOf: ["mosh", "exit", "ssh-copy-id"])
    
    let set = Set<String>(result)
    result = Array(set)
    result = result.sorted()
    __allCommandsCache = result
    
    return result
  }
  
  static var __commandHintsCache: [String: String]? = nil
  
  static func _commandHints() -> [String: String] {
    if let cache = __commandHintsCache {
      return cache
    }
    let result = [
      "awk": "Select particular records in a file and perform operations upon them.",
      "cat": "Concatenate and print files.",
      "cd":  "Change directory.",
//  //    "chflags": "chflags", // TODO
//  //    "chksum": "chksum", // TODO
      "clear": "Clear the terminal screen. 🙈",
      "compress": "Compress data.",
      "config": "Add keys, hosts, themes, etc... 🔧 ",
      "cp": "Copy files and directories",
      "curl": "Transfer data from or to a server.",
      "date": "Display or set date and time.",
      "diff": "Compare files line by line.",
      "dig": "DNS lookup utility.",
      "du": "Disk usage",
      "echo": "Write arguments to the standard output.",
      "egrep": "Search for a pattern using extended regex.", // https://www.computerhope.com/unix/uegrep.htm
      "env": "Set environment and execute command, or print environment.", // fish
      "exit": "Exit current session. 👋",
      "fgrep": "File pattern searcher.", // fish
      "find": "Walk a file hierarchy.", // fish
      "grep": "File pattern searcher.", // fish
      "gunzip": "Compress or expand files",  // https://linux.die.net/man/1/gunzip
      "gzip": "Compression/decompression tool using Lempel-Ziv coding (LZ77)",  // fish
      "head": "Display first lines of a file", // fish
      "help": "Prints all commands. 🧐 ",
      "history": "Use -c option to clear history. 🙈 ",
      "host": "DNS lookup utility.", // fish
      "link": "Make links.", // fish
      "ln": "", // TODO
      "ls": "List files and directories",
      "md5": "Calculate a message-digest fingerprint (checksum) for a file.", // fish
      "mkdir": "Make directories.", // fish
      "mosh": "Runs mosh client. 🦄",
      "mv": "Move files and directories.",
      "nc": "", // TODO
      "nslookup": "Query Internet name servers interactively", // fish
      "pbcopy": "Copy to the pasteboard.",
      "pbpaste": "Paste from the pasteboard.",
      "ping": "Send ICMP ECHO_REQUEST packets to network hosts.", // fish
      "printenv": "Print out the environment.", // fish
      "pwd": "Return working directory name.", // fish
      "readlink": "Display file status.", // fish
//  //    @"rlogin": @"", // TODO: REMOVE
      "rm": "Remove files and directories.",
      "rmdir": "Remove directories.", // fish
      "scp": "Secure copy (remote file copy program).", // fish
      "sed": "Stream editor.", // fish
//  //    @"setenv": @"", // TODO
      "sftp": "Secure file transfer program.", // fish
      "showkey": "Display typed chars.",
      "sort": "Sort or merge records (lines) of text and binary files.", // fish
      "ssh": "Runs ssh client. 🐌",
      "ssh-copy-id": "Copy an identity to the server. 💌",
//  //    @"ssh-keygen": @"", // TODO
      "stat": "Display file status.", // fish
      "sum": "Display file checksums and block counts.", // fish
      "tail": "Display the last part of a file.", // fish
      "tar": "Manipulate tape archives.", // fish
      "tee": "Pipe fitting.", // fish
      "telnet": "User interface to the TELNET protocol.", // fish
      "theme": "Choose a theme 💅",
      "touch": "Change file access and modification times.", // fish
      "tr": "", // TODO
      "uname": "Print operating system name.", // fish
      "uncompress": "Expand data.",
      "uniq": "Report or filter out repeated lines in a file.", // fish
      "unlink": "Remove directory entries.", // fish
//  //    @"unsetenv": @"", // TODO
      "uptime": "Show how long system has been running.", // fish
      "wc": "Words and lines counter.",
      "whoami": "Display effective user id.", // fish
      "whois": "Internet domain name and network number directory service.", // fish

      "open": "open url of file (Experimental). 📤",
      "link-files": "link folders from Files.app (Experimental)."
    ]
    
    __commandHintsCache = result
    return result
  }
    
  private static func _completionKind(_ cmd: String) -> Kind {
    switch cmd {
    case "": return .command
    case "ssh", "ssh2", "mosh": return .blinkHost
    case "ping": return .host
    case "ls": return .directory
    case "file": return .file
    case "geo": return .blinkGeo
    case "help", "exit", "whoami", "config", "clear", "history", "link-files":
      return .no
    default:
      return Kind(rawValue: operatesOn(cmd) ?? "") ?? .no
    }
  }
  
  static func _hint(kind: Kind, candidates: [String]) -> String {
    guard let first = candidates.first else {
      return ""
    }
    var result = "";
    switch kind {
    case .command:
      if let hint = _commandHints()[first] {
        result = "\(first) - \(hint)"
      } else {
        result = first
      }
    default:
      result = candidates.prefix(5).joined(separator: ", ")
    }
    
    return result;
  }
  
  static func _loopIndex(arr: [String], n: Int) -> String {
    let count = arr.count
    if count == 0 {
      return ""
    }
    if n >= 0 {
      return arr[n % count]
    }
    
    return arr[count - 1 - (abs(n) % count)]
  }
 
  static func _for(cursor: Int, str: String, n: Int) -> (kind: Kind, start: Int, pos: Int, len: Int, result: String, hint: String) {

    let token = CompleteUtils.completeToken(str, cursor: cursor)

    guard let cmd = token.cmd else {
      let kind: Kind = token.isRedirect ? .file : .command
      let commands = _complete(kind: kind, input: token.query)
      let filtered = commands.filter({$0.hasPrefix(token.query)}).sorted().map { CompleteUtils.encode(str: $0, quote: token.quote) }
      let hint = token.canShowHint ? _hint(kind: kind, candidates: filtered) : ""
      
      return (
        kind: .command,
        start: token.jsStart,
        pos: token.jsPos,
        len: token.jsLen,
        result: _loopIndex(arr: filtered, n: n),
        hint: hint
      )
    }
    
    if token.query.first == "-" {
      let opts = getoptString(cmd) ?? ""
      return (
        kind: .no,
        start: token.jsStart,
        pos: token.jsPos,
        len: token.jsLen,
        result: "",
        hint: (!token.canShowHint || opts.isEmpty) ? "" : "\(token.value) [\(opts)]"
      )
    }
    
    let kind = _completionKind(cmd)
    let result = _complete(kind: kind, input: token.query).sorted().map { CompleteUtils.encode(str: $0, quote: token.quote) }
    let hint = !token.canShowHint ? "" : _hint(kind: kind, candidates: Array(result.prefix(5)))
    
    return (
      kind: kind,
      start: token.jsStart,
      pos: token.jsPos,
      len: token.jsLen,
      result: _loopIndex(arr: result, n: n),
      hint: hint.isEmpty ? "" : token.prefix + hint
    )
  }
  
  static func _for(request: ForRequest) -> ForResponse {
    let res = _for(cursor: request.cursor, str: request.input, n: request.n)
    return ForResponse(
      requestId: request.id,
      input: request.input,
      result: res.result,
      hint: res.hint,
      kind: res.kind.rawValue,
      start: res.start,
      pos: res.pos,
      len: res.len
    )
  }
  
  static func _forAPI(session: MCPSession, json: String) -> String? {
    let dec = JSONDecoder()
    guard
      let requestData = json.data(using: .utf8),
      let request = try? dec.decode(ForRequest.self, from: requestData)
    else {
      return nil
    }

    session.setActiveSession()
    let response = _for(request: request)
    let enc = JSONEncoder()
    if let responseData = try? enc.encode(response) {
      return String(data: responseData, encoding: .utf8)
    }
    return nil
  }


  static func forAPI(session: MCPSession, json: String) -> AnyPublisher<String, Never> {
    Just(json)
      .subscribe(on: _completionQueue)
      .map( { _forAPI(session:session, json:$0) } )
      .compactMap({ $0 })
      .eraseToAnyPublisher()
  }
  
  static func _complete(kind: Kind, input: String) -> [String] {
    var src: [String] = []
    
    switch kind {
    case .command: src = _allCommands()
    case .file: src = _allPaths(prefix: input, skipFiles: false);
    case .directory: src = _allPaths(prefix: input, skipFiles: true);
    case .host: src = _allBlinkHosts();
    case .blinkHost: src = _allBlinkHosts();
    case .blinkGeo: src = ["track", "lock", "stop", "current", "authorize", "last"]
    default: break
    }
    
    return src.filter( {$0.hasPrefix(input)} ).sorted()
  }
  
  private static func _allBlinkHosts() -> [String] {
    let hosts: Set<String> = Set(
      (BKHosts.all() ?? [])
        .compactMap({$0 as? BKHosts})
        .compactMap({$0.host})
    )
    
    return Array(hosts)
  }
  
  private static func _allPaths(prefix: String, skipFiles: Bool) -> [String] {
    let arg = prefix as NSString
    var dir: String
    var isDir: ObjCBool = false
    let fm = FileManager.default
    var result: [String] = []
  
    if fm.fileExists(atPath: arg as String, isDirectory: &isDir) && isDir.boolValue {
      if arg.lastPathComponent == "." && arg != "." {
        dir = arg.deletingLastPathComponent
      } else {
        dir = arg as String
      }
    } else {
      dir = arg.deletingLastPathComponent
      if dir.isEmpty {
        dir = "."
      }
    }
    dir = (dir as NSString).expandingTildeInPath

    guard fm.fileExists(atPath: dir, isDirectory: &isDir) && isDir.boolValue
    else {
      return result
    }
    
    let filesAndFolders = (try? fm.contentsOfDirectory(atPath: dir)) ?? []
    
    let deeper = dir != "."
    let nsDir = dir as NSString
    for fileOrFolder in filesAndFolders {
      let folder = deeper ? nsDir.appendingPathComponent(fileOrFolder) : fileOrFolder
      if fm.fileExists(atPath: folder, isDirectory: &isDir) {
        if skipFiles && !isDir.boolValue {
          continue
        }
        result.append(folder)
      }
    }
    return result;
  }

}
