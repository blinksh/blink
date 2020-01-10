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

struct StuckView: View {
  private var _emojies = ["😱", "🤪", "🧐", "🥺", "🤔", "🤭", "🙈", "🙊"]
  var keyCode: KeyCode
  var dismissAction: () -> ()
  
  init(keyCode: KeyCode, dismissAction: @escaping () -> ()) {
    self.keyCode = keyCode
    self.dismissAction = dismissAction
  }
  
  var body: some View {
      VStack {
        HStack {
          Spacer()
          Button("Close", action: dismissAction)
        }.padding()
        Spacer()
        Text(_emojies.randomElement() ?? "🤥").font(.system(size: 60)).padding(.bottom, 26)
        Text("Stuck key detected.").font(.headline).padding(.bottom, 30)
        Text("Press \(keyCode.fullName) key").font(.system(size: 30))
        Spacer()
        HStack {
          Text("Also, please")
          Button("file radar.") {
            let url = URL(string: "https://github.com/blinksh/blink/wiki/Known-Issue:Cmd-key-stuck-while-switching-between-apps-with-Cmd-Tab")!
            blink_openurl(url)
          }
        }.padding()
      }
  }
}


struct StuckView_Previews: PreviewProvider {
    static var previews: some View {
      StuckView(keyCode: .commandLeft) {
        
      }
    }
}
