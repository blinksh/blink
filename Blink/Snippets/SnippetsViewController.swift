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
import SwiftUI
import BlinkSnippets

struct SwiftUISnippetsView: View {
  @ObservedObject var model: SearchModel
  var body: some View {
    HStack(alignment: .top) {
      if model.editingSnippet == nil {
        Spacer()
        VStack {
          Spacer()
          SnippetsListView(model: model)
            .frame(maxWidth: 560)
            .background(
              .ultraThinMaterial,
              in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .shadow(color: .secondary, radius: 1, x: 0, y: 0)
        }.padding()
        Spacer()
      }
    }
  }
}

class SnippetsViewController: UIHostingController<SwiftUISnippetsView> {
  var model: SearchModel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .clear
  }
  
  public static func create(context: (any SnippetContext)?) -> SnippetsViewController {
    let model = SearchModel()
    model.snippetContext = context
    let rootView = SwiftUISnippetsView(model: model)
    let ctrl = SnippetsViewController(rootView: rootView)
    ctrl.model = model
    model.rootCtrl = ctrl
    model.isOn = true
    return ctrl
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.model.inputView?.becomeFirstResponder()
  }
}
