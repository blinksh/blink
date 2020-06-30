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


import SwiftUI

class CaptureController: UIViewController {
  var _keyCommands: Array<UIKeyCommand> = []
  var shortcut: KeyShortcut = .init(.clipboardCopy, [], "")
  
  private func _generateCommands() -> Array<UIKeyCommand> {
    var result:Array<UIKeyCommand> = []
    let chars = "`1234567890-=\u{8}\tqwertyuiop[]\\asdfghjkl;'\rzxcvbnm,./ "
      + "§±^°‹›|"
      + "<>" // for German dedicated key
    let inputs = chars.map({String($0)}) + [
      UIKeyCommand.inputUpArrow,
      UIKeyCommand.inputDownArrow,
      UIKeyCommand.inputLeftArrow,
      UIKeyCommand.inputRightArrow,
      UIKeyCommand.inputEscape
    ]
    let modifiers: [UIKeyModifierFlags] = [.shift, .control, .alternate, .command]
    var mods: Set<Int> = [0]
    
    for i in modifiers {
      mods.insert(i.rawValue)
      for j in modifiers {
        mods.insert(UIKeyModifierFlags([i, j]).rawValue)
        for z in modifiers {
          mods.insert(UIKeyModifierFlags([i, j, z]).rawValue)
          for h in modifiers {
            mods.insert(UIKeyModifierFlags([i, j, z, h]).rawValue)
          }
        }
      }
    }

    for input in inputs {
      for mod in mods {
        let cmd = UIKeyCommand(input: input, modifierFlags: UIKeyModifierFlags(rawValue: mod), action: #selector(_capture(cmd:)))
        result.append(cmd)
      }
    }
    
    return result
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    DispatchQueue.global().async {
      let commands = self._generateCommands()
      DispatchQueue.main.async {
        self._keyCommands = commands
        self.reloadInputViews()
      }
    }
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    becomeFirstResponder()
  }
  
  override var keyCommands: [UIKeyCommand]? { _keyCommands }
  override var canBecomeFirstResponder: Bool { true }
  
  @objc func _capture(cmd: UIKeyCommand) {
    shortcut.input = cmd.input ?? ""
    shortcut.modifiers = cmd.modifierFlags
  }
  
}

struct KeyCaptureView: UIViewControllerRepresentable {
  @ObservedObject var shortcut: KeyShortcut
  
  typealias UIViewControllerType = CaptureController
  
  func makeUIViewController(context: Self.Context) -> CaptureController {
    let c = CaptureController()
    c.shortcut = shortcut
    return c
  }
  
  func updateUIViewController(_ uiViewController: CaptureController, context: UIViewControllerRepresentableContext<KeyCaptureView>) {
    
  }
}
