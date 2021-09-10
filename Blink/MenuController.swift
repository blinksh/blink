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
import UIKit


//To rebuild a menu, call the setNeedsRebuild method. Call setNeedsRevalidate when you need the menu system to revalidate a menu.
@objc public class MenuController: NSObject {
  enum ShellMenu: String, CaseIterable {
    case windowNew
    case windowClose
    case tabNew
    case tabClose
    case configShow
  }

  enum EditMenu: String, CaseIterable {
    case clipboardCopy
    case clipboardPaste
    case selectionGoogle
    case selectionStackOverflow
    case selectionShare
  }
  
  enum ViewMenu: String, CaseIterable {
    case toggleKeyCast
    case zoomIn
    case zoomOut
    case zoomReset
  }
  
  enum WindowMenu: String, CaseIterable {
    case windowFocusOther
    case tabMoveToOtherWindow
    case tabNext
    case tabPrev
    case tabLast
  }

  override private init() {}
  
  @objc public class func buildMenu(with builder: UIMenuBuilder) {
    // We will embed our own textSize inside View, so just remove to avoid collisions.
    builder.remove(menu: .textSize)
    
    let shellMenuCommands:  [UICommand] = ShellMenu.allCases.map  { generate(Command(rawValue: $0.rawValue)!) }
    let editMenuCommands:   [UICommand] = EditMenu.allCases.map   { generate(Command(rawValue: $0.rawValue)!) }
    let viewMenuCommands:   [UICommand] = ViewMenu.allCases.map   { generate(Command(rawValue: $0.rawValue)!) }
    let windowMenuCommands: [UICommand] = WindowMenu.allCases.map { generate(Command(rawValue: $0.rawValue)!) }

    builder.insertSibling(UIMenu(title: "Shell",
                                 image: nil,
                                 identifier: UIMenu.Identifier("com.example.apple-samplecode.menus.shellMenu"),
                                 options: [],
                                 children: shellMenuCommands), beforeMenu: .edit)
    
    // Note we are assuming that shortcuts here are already unique.
    // The same shortcut, or the same action, will make this crash with a
    // 'NSInternalInconsistencyException', reason: 'replacement menu has duplicate submenu,
    // command or key command, or a key command is missing input or action'.
    builder.replaceChildren(ofMenu: .standardEdit) { _ in editMenuCommands   }
    builder.replaceChildren(ofMenu: .view)         { _ in viewMenuCommands  }
    builder.replaceChildren(ofMenu: .window)       { _ in windowMenuCommands }
    
    // TODO 'NSInternalInconsistencyException', reason: 'replacement menu has duplicate submenu, command or key command, or a key command is missing input or action'
    // The action also must be different, or at least have propertyList that identifies as different.
    // We need to take into account that the stored shortcuts must not collide, otherwise things will break.
    
    // There is an additional problem, which is that maybe a user by mistake may have that same
    // combination. We should clean it up. We could remove the dupes at the storage,
    // and then use that same function to make sure there are none during creation.
  }

  private class func generate(_ command: Command) -> UICommand {
    let kbConfig = KBTracker.shared.loadConfig()

    // For the action to be different, we are passing it as part of the PropertyList.
    if let shortcut = kbConfig.shortcuts.first(
      where: { s in // s.triggers(command)
        if case .command(let cmd) = s.action,
           case command = cmd
        {
          return true
        }
        return false
      })
    {
      return UIKeyCommand(title: command.title,
                          action: #selector(SpaceController._onShortcut(_:)),
                          input: shortcut.input,
                          modifierFlags: shortcut.modifiers,
                          propertyList: ["Command": command.rawValue])
    } else {
      return UICommand(
        title: command.title,
        image: nil,
        action: #selector(SpaceController._onShortcut(_:)),
        propertyList: ["Command": command.rawValue]
      )
    }
  }
}

