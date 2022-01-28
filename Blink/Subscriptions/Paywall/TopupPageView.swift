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

import Foundation
import SwiftUI

fileprivate let blinkColor = Color(red:10.0 / 255.0,  green:224.0 / 255.0, blue:240.0 / 255.0)



struct TopupPageView: Page {
  init(horizontal: Bool, switchTab: @escaping (_ idx: Int) -> ()) {
    self.horizontal = horizontal
    self.switchTab = switchTab
  }
  
  var horizontal: Bool
  var switchTab: (_ idx: Int) -> ()
  
  @StateObject var tracker = ShakeDetector()
  
  var body: some View {
    VStack(alignment: .leading) {
      Spacer()
      GeometryReader { p in
      HStack {
        Spacer()
          Color.secondary
            .frame(maxWidth: 90)
            .overlay(alignment: .bottom) {
              blinkColor.frame(maxHeight: p.size.height * self.tracker.progress)
            }
            .cornerRadius(10)
        .padding()
        
        header()
        Spacer()
      }
      }.frame(maxHeight: 300)
      Spacer().frame(maxHeight: horizontal ? 20 : 30)
      Spacer()
      HStack {
        Spacer()
        Text("Shake")
          .font(.footnote)
          .scaleEffect(tracker.shakeHintIsOn ? 1.4 : 1.0)
          .offset(x: 3, y: tracker.shakeHintIsOn ? -10 : 0)
          .animation(Animation.default.speed(4).repeatCount(3), value: tracker.shakeHintIsOn)
        
        
        Text("your device until the bar is filled.")
          .font(.footnote)
        Spacer()
      }
      Spacer().frame(maxHeight:8)
      HStack {
        Spacer()
        Button("Consider purchase", action: {
          withAnimation {
            switchTab(0)
          }
        }).padding(.trailing)
        Button("Migrate from old Blink", action: {
          withAnimation {
            switchTab(2)
          }
        })
        
        Spacer()
      }
      .font(.footnote)
      .padding(.bottom, self.horizontal ? 32 : 40)
    }.padding()
      .frame(maxWidth: horizontal ? 700 : 460)
  }
  
  func header() -> some View {
    Text("Top up\nyour free\nminutes")
      .fontWeight(.bold)
      .font(.largeTitle)
  }
  
  func rows() -> some View {
    GroupBox() {
      CheckmarkRow(text: "Get access to new features and services.")
      Spacer().frame(maxHeight: 10)
      CheckmarkRow(text: "Continue supporting future updates.")
    }
  }
}
