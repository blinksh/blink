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


import UIKit

class BlinkCommand: UIKeyCommand {
  var bindingAction: KeyBindingAction = .none
}

class KBWebView: KBWebViewBase {
  
  private var _loaded = false
  private(set) var webViewReady = false
  private var _grabsCtrlSpace = false
  
  func configure(_ cfg: KBConfig) {
    _grabsCtrlSpace = matchCommand(input: " ", flags: [UIKeyModifierFlags.control]) != nil

    guard
      let data = try? JSONEncoder().encode(cfg),
      let json = String(data: data, encoding: .utf8)
    else {
      return
    }
    report("config", arg: json as NSString)
  }
  
  func matchCommand(input: String, flags: UIKeyModifierFlags) -> (UIKeyCommand, UIResponder)? {
    var result: (UIKeyCommand, UIResponder)? = nil

    var iterator: UIResponder? = self

    while let responder = iterator {
      if let cmd = responder.keyCommands?.first(
        where: { $0.input == input && $0.modifierFlags == flags}),
        let action = cmd.action,
        responder.canPerformAction(action, withSender: self)
        {
        result = (cmd, responder)
      }
      iterator = responder.next
    }

    return result
  }
  
  override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
    guard
      _grabsCtrlSpace,
      let key = presses.first?.key,
      key.keyCode == .keyboardSpacebar,
      key.modifierFlags.contains(.control),
      let (cmd, responder) = matchCommand(input: " ", flags: key.modifierFlags),
      let action = cmd.action
    else {
      super.pressesBegan(presses, with: event)
      return
    }
    
    responder.perform(action, with: cmd)
  }
  
  func contentView() -> UIView? {
    scrollView.subviews.first
  }
  
  func disableTextSelectionView() {
    let subviews = scrollView.subviews
    guard
      subviews.count > 2,
      let v = subviews[1].subviews.first
    else {
      return
    }
    NotificationCenter.default.removeObserver(v)
  }
  
  override func ready() {
    webViewReady = true
    super.ready()
    configure(KBTracker.shared.loadConfig())
  }
  
  private func _loadKB() {
    let bundle = Bundle.init(for: KBWebView.self)
    guard
      let path = bundle.path(forResource: "kb", ofType: "html")
    else {
      return
    }
    let url = URL(fileURLWithPath: path)
    loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
  }
  
  override func didMoveToSuperview() {
    super.didMoveToSuperview()
    if window != nil && !_loaded {
      _loaded = true
      _loadKB()
    }
  }
}
