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

struct Completions {
  
  func _commands() -> [String: String] {
    [
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
  }

  func complete(str: String) {
    
  }
}
