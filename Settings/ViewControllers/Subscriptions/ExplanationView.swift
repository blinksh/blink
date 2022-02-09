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

struct ExplanationView: View {
    var body: some View {
      VStack {
        Text("Letter from dev team").font(.largeTitle)
        Spacer().frame(maxHeight: 30)
        Text("""
Today we are releasing Blink Shell 15. It is a new app, and it is a free download with all the features, including Code, available to everyone.

The only catch? Free-casual users are shown three subscription nags in the first 90 minutes of use per day. After that, no interruptions.

If you purchased the previous Blink app, we grandfather you in the new version of the app. You will continue receiving updates and features, just like before. It is our way to thank you for your support all these years!

It is time to push things forward as when we first launched. Blink Code is just the first step. Our Blink Plus subscription will support us and plug you into the future of Blink.

Purchasing Blink Plus will help us improve our terminal and create new services that we would not be able to do otherwise. We need more resources. It is time to go big or go home.

See you on Blink Shell 15!

""").padding([.top, .leading, .trailing]).padding([.top, .leading, .trailing])
        HStack {
          Spacer()
          VStack {
            Text("_Carlos and Yury_")
            Text("_9 Feb 2022_")
          }
        }.padding([.leading, .bottom, .trailing]).padding([.bottom, .leading, .trailing])
        Button {
          let url = URL(string: "https://itunes.apple.com/app/id1594898306")!
          blink_openurl(url)
        } label: {
          Label("Download Now", systemImage: "applelogo")
        }
        Spacer(minLength: 80)
      }
    }
}

