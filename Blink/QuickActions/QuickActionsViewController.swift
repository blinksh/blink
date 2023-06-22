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


import Foundation
import UIKit
import SwiftUI

struct MaterialButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration
      .label.font(.body)
      .padding(.horizontal)
      .padding(.vertical, 5)
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
      .opacity(configuration.isPressed ? 0.7 : 1.0)
      .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
  }
  
}

struct QuickActionButtons: View {
  public var delegate: CommandsHUDViewDelegate? = nil
  @State var visible: Bool = false
  @State var hasCorners = DeviceInfo.shared().hasCorners
  @State var supportsMultipleWindows = UIApplication.shared.supportsMultipleScenes
  @State var version: Int = 0
  
  var layoutModeText: String {
    if let mode = delegate?.currentTerm()?.sessionParams.layoutMode {
      return LayoutManager.layoutMode(toString: BKLayoutMode(rawValue: mode) ?? BKLayoutMode.default)
    }
    return LayoutManager.layoutMode(toString: BKLayoutMode.default)
  }
  
  var lockText: String {
    if delegate?.currentTerm()?.sessionParams.layoutLocked == true {
      return "Unlock"
    } else {
      return "Lock"
    }
  }
  
  func _nextLayoutMode(mode: BKLayoutMode?) -> BKLayoutMode {
      switch (mode) {
      case nil: fallthrough
      case .default:
        return .safeFit;
      case .safeFit:
        return .fill;
      case .fill:
        return .cover;
      case .cover:
        return .safeFit;
      @unknown default:
        return .safeFit
      }
    }
  
  var body: some View {
    HStack {
      Button("Snippets") {
        delegate?.spaceController()?.toggleQuickActionsAction()
        delegate?.spaceController()?.showSnippetsAction()
      }.buttonStyle(MaterialButtonStyle())
      
      if self.supportsMultipleWindows {
        Button("New Window") {
          delegate?.spaceController()?.toggleQuickActionsAction()
          delegate?.spaceController()?._newWindowAction()
        }.buttonStyle(MaterialButtonStyle())
      }
      
      Button("New Tab") {
        delegate?.spaceController()?.toggleQuickActionsAction()
        delegate?.spaceController()?.newShellAction()
      }.buttonStyle(MaterialButtonStyle())
      
      
      if self.hasCorners {
        Button(self.layoutModeText) {
          guard let term = delegate?.currentTerm()
          else {
            return
          }
          
          let params = term.sessionParams
          params.layoutMode = _nextLayoutMode(mode: BKLayoutMode(rawValue: params.layoutMode)).rawValue
          if (params.layoutLocked) {
            term.unlockLayout()
          }
          term.view?.setNeedsLayout()
          self.version += 1 // rerender self with new values
        }.buttonStyle(MaterialButtonStyle())
          .id("mode-\(self.version)")
      }
      
      Button(lockText) {
        guard let params = delegate?.currentTerm()?.sessionParams
        else {
          return
        }
        if params.layoutLocked {
          delegate?.spaceController()?.currentTerm()?.unlockLayout()
        } else {
          delegate?.spaceController()?.currentTerm()?.lockLayout()
        }
        self.version += 1
      }.buttonStyle(MaterialButtonStyle())
        .id("lock-\(self.version)")
      Button("Close Tab") {
        delegate?.spaceController()?.closeShellAction()
      }.buttonStyle(MaterialButtonStyle())
    }.padding(.horizontal)
      .offset(y: self.visible ? 0 : 10)
      .opacity(self.visible ? 1.0 : 0.0)
      .onAppear {
        withAnimation(.linear(duration: 0.150)) {
          self.visible = true
        }
      }
  }
}

struct QuickActionsView: View {
  public var delegate: CommandsHUDViewDelegate? = nil
  
  var body: some View {
    ViewThatFits(in: .horizontal) {
      QuickActionButtons(delegate: delegate)
      ScrollView(.horizontal) {
        QuickActionButtons(delegate: delegate)
      }
      .scrollIndicators(.never)
    }
  }
}

@objc protocol CommandsHUDViewDelegate: NSObjectProtocol {
  func currentTerm() -> TermController?
  func spaceController() -> SpaceController?
}


class QuickActionsViewController: UIHostingController<QuickActionsView> {
  init() {
    super.init(rootView: QuickActionsView())
    self.view.backgroundColor = .clear
  }
  
  var delegate: CommandsHUDViewDelegate? {
    get {
      self.rootView.delegate
    }
    set {
      self.rootView.delegate = newValue
    }
  }
  
  @MainActor required dynamic init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
