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
        Text("Why we are doing this").font(.largeTitle)
        Spacer().frame(maxHeight: 30)
        Text("""
This is **markdown** explaining all the things.
           
Now that Christmas has come and passed, many people have opened up a brand new iPhone, iPad, Mac, Apple TV, or Apple Watch over the past few days. In this article we've rounded up the current best deals on official Apple iPhone cases, Apple Watch bands, power bricks, MagSafe accessories, and more, which should all be helpful for new Apple device owners. The sales below will be found at Amazon.

Now that Christmas has come and passed, many people have opened up a brand new iPhone, iPad, Mac, Apple TV, or Apple Watch over the past few days. In this article we've rounded up the current best deals on official Apple iPhone cases, Apple Watch bands, power bricks, MagSafe accessories, and more, which should all be helpful for new Apple device owners. The sales below will be found at Amazon.

Now that Christmas has come and passed, many people have opened up a brand new iPhone, iPad, Mac, Apple TV, or Apple Watch over the past few days. In this article we've rounded up the current best deals on official Apple iPhone cases, Apple Watch bands, power bricks, MagSafe accessories, and more, which should all be helpful for new Apple device owners. The sales below will be found at Amazon.


""").padding().padding([.leading, .trailing])
        Button {
          
        } label: {
          Label("Download Now", systemImage: "applelogo")
        }
        Spacer()
      }
    }
}

