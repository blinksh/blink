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

class SmarterTermInput: TermInput {
  
  private var _kbView: KBView
  var kbView: KBView { _kbView }
  
  override init(frame: CGRect, textContainer: NSTextContainer?) {
    _kbView = KBView()
    
    super.init(frame: frame, textContainer: textContainer)
    
    if traitCollection.userInterfaceIdiom == .pad {
      setupAssistantItem()
    } else {
      setupAccessoryView()
    }
    
    _kbView.keyInput = self
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
    guard
      let window = window,
      let scene = window.windowScene
    else {
      return
    }
    if traitCollection.userInterfaceIdiom == .phone {
      _kbView.traits.isPortrait = scene.interfaceOrientation.isPortrait
    }
  }
  
  override func insertText(_ text: String) {
    
    let traits = _kbView.traits
    if traits.contains([.altOn, .ctrlOn]) {
      escCtrlSeq(withInput:text)
    } else if traits.contains(.altOn) {
      escSeq(withInput: text)
    } else if traits.contains(.ctrlOn) {
      ctrlSeq(withInput: text)
    } else {
      super.insertText(text)
    }
  }
  
  override func deviceWrite(_ input: String!) {
    super.deviceWrite(input)
    _kbView.turnOffUntracked()
  }
  
  func setupAccessoryView() {
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = []
    inputAccessoryView = KBAccessoryView(kbView: kbView)
  }
  
  func setupAssistantItem() {
    inputAccessoryView = nil
    let proxy = KBProxy(kbView: kbView)
    let item = UIBarButtonItem(customView: proxy)
    inputAssistantItem.leadingBarButtonGroups = []
    inputAssistantItem.trailingBarButtonGroups = [UIBarButtonItemGroup(barButtonItems: [item], representativeItem: nil)]
  }
  

  static let shared = SmarterTermInput()
}

