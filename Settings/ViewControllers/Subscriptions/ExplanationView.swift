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

The only catch? Free-casual users will be shown three subscription opportunities in the first 90 minutes of usage per day. After that, no interruptions.

If you purchased the previous Blink app, you are grandfathered in the new version. You will continue receiving updates and features, just like before. It is our way to **THANK YOU** for being early adopters and for sticking with us all these years!

With Blink Shell 15, we are again taking the lead on what you can do with your iOS device. Code is just the first step. Our Blink Plus subscription will support us and plug you into the future of Blink.

Please consider subscribing to Blink Plus. You will help us improve our terminal and create new services. We need more resources, and we are counting on you to fuel our growth! It is time to go big or go home, and we are up to the challenge.

See you on Blink Shell 15 and beyond!

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

