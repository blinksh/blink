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
  @Namespace var nspace;
  
  @State var transitionFrame: CGRect? = nil
  
  var body: some View {
    HStack(alignment: .top) {
      if model.editingSnippet == nil && model.newSnippetPresented == false {
        Spacer()
        VStack {
          Spacer().onAppear {
            withAnimation(.easeOut(duration: 0.33)) {
              transitionFrame = nil
            }
          }
          
          SnippetsListView(model: model, nspace: nspace)
            .frame(maxWidth: transitionFrame == nil ? 560 : nil)
            .frame(minWidth: transitionFrame?.width, maxWidth: transitionFrame?.width, minHeight: transitionFrame?.height, maxHeight: transitionFrame?.height)
            .background(
              .regularMaterial,
              in: RoundedRectangle(cornerRadius: 15, style: .continuous)
            )
        }
        
        Spacer()
      }
    }
    .padding([.leading, .trailing, .top])
    .padding(.bottom, 20)
//    .contentShape(Rectangle())
    .gesture(TapGesture().onEnded {
      if model.editingSnippet == nil && model.newSnippetPresented == false {
        model.close()
      }
    })
    .ignoresSafeArea(.all)
  }
}

class SnippetsViewController: UIHostingController<SwiftUISnippetsView> {
  var model: SearchModel!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.view.backgroundColor = .clear
  }
  
  public static func create(context: (any SnippetContext)?, transitionFrame: CGRect?) throws -> SnippetsViewController {
    let model = try SearchModel()
    model.snippetContext = context
    let rootView = SwiftUISnippetsView(model: model, transitionFrame: transitionFrame)
    let ctrl = SnippetsViewController(rootView: rootView)
    ctrl.model = model
    model.rootCtrl = ctrl
    return ctrl
  }
  
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    self.model.inputView?.becomeFirstResponder()
  }
}

