////////////////////////////////////////////////////////////////////////////////
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


struct ContentView3: View {
  var body: some View {
    GeometryReader { gr in
      if gr.frame(in: .local).height < 400 {
        PurchasePageView(horizontal: true, switchTab: {_ in})
          .position(
            x: gr.frame(in: .local).maxX * 0.5,
            y: gr.frame(in: .local).maxY * 0.5
          )
        closeButton(reader: gr)
      } else {
        PurchasePageView(horizontal: false, switchTab: {_ in})
          .position(
            x: gr.frame(in: .local).maxX * 0.5,
            y: gr.frame(in: .local).maxY * 0.5
          )
        closeButton(reader: gr)
      }
    }
  }
  
  func closeButton(reader: GeometryProxy) -> some View {
    Button(action: {
      
    }) {
      Image(systemName: "xmark.circle.fill")
        .resizable()
        .frame(width: 32, height: 32)
        .foregroundColor(Color.secondary.opacity(0.7))
    }
    .position(x: reader.frame(in: .local).maxX - 40,
              y: reader.frame(in: .local).minY + 40)
  }
}


protocol Page: View {
  init(horizontal: Bool, switchTab: @escaping (_ idx: Int) -> ())
}

struct PageContainer<T: Page>: View {
  
  var onSwitchTabHandler: (_ idx: Int) -> ()
  
  var body: some View {
    GeometryReader { gr in
      if gr.frame(in: .local).height < 400 {
        T(horizontal: true, switchTab: onSwitchTabHandler)
          .position(
            x: gr.frame(in: .local).maxX * 0.5,
            y: gr.frame(in: .local).maxY * 0.5
          )
      } else {
        T(horizontal: false, switchTab: onSwitchTabHandler)
          .position(
            x: gr.frame(in: .local).maxX * 0.5,
            y: gr.frame(in: .local).maxY * 0.5
          )
      }
    }
  }
}



struct PaywallView: View {
  @State private var tabIndex = 0
  @ObservedObject private var model: UserModel = .shared
  
  var body: some View {
    TabView(selection: $tabIndex) {
      PageContainer<PurchasePageView>(onSwitchTabHandler: _onSwitchTab).tag(0)
      PageContainer<TopupPageView>(onSwitchTabHandler: _onSwitchTab).tag(1)
      PageContainer<MigratePageView>(onSwitchTabHandler: _onSwitchTab).tag(2)
    }
    .tabViewStyle(.page)
    .indexViewStyle(.page(backgroundDisplayMode: .always))
    .disabled(model.purchaseInProgress)
  }
  
  private func _onSwitchTab(_ idx: Int) {
    self.tabIndex = idx
  }
}

