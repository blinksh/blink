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
// RevenueCat import removed for privacy

struct SupportView: View {
  @EnvironmentObject private var _nav: Nav
  @State var displayWalkthrough = false

  var body: some View {
    List {
      Section(header: Text("Learn")) {
        HStack {
          Button { displayWalkthrough = true }
          label: {
            Label("Walkthrough", systemImage: "hand.tap")
          }
          Spacer()
          Text("").foregroundColor(.secondary)
        }
        HStack {
          Button {
            BKLinkActions.sendToDocumentation()
          } label: {
            Label("Documentation", systemImage: "book")
          }
          Spacer()
          Text("").foregroundColor(.secondary)
        }
      }
      Section(header: Text("Send Feedback")) {
        HStack {
          Button {
            BKLinkActions.send(toGitHub: "blink/discussions/new?category=support")
          } label: {
            Label("Ask a Question", systemImage: "questionmark.bubble")
          }

          Spacer()
          Text("").foregroundColor(.secondary)
        }
        HStack {
          Button {
            BKLinkActions.send(toGitHub: "blink/discussions/new?category=ideas")
          } label: {
            Label("Suggest a Feature", systemImage: "star.bubble")
          }

          Spacer()
          Text("").foregroundColor(.secondary)
        }

        HStack {
          Button {
            BKLinkActions.send(toGitHub: "blink/discussions")
          } label: {
            Label("Discussions", systemImage: "bubble")
          }

          Spacer()
          Text("Github").foregroundColor(.secondary)
        }

        HStack {
          Button {
            BKLinkActions.sendToDiscordSupport()
          } label: {
            Label("#support", systemImage: "ellipsis.bubble")
          }

          Spacer()
          Text("Discord").foregroundColor(.secondary)
        }
      }

      Section(header: Text("Internals")) {
        // Disabled: RevenueCat user ID copy removed for privacy.
      }
    }
      .listStyle(.grouped)
      .navigationTitle("Support")
      .sheet(isPresented: $displayWalkthrough) {
        WalkthroughWindow(urlHandler: blink_openurl, dismissHandler: { displayWalkthrough = false })
      }
  }
}

fileprivate struct WalkthroughWindow: View {
  let urlHandler: (URL) -> ()
  let dismissHandler: () -> ()

  @Environment(\.dynamicTypeSize) var dynamicTypeSize

  var body: some View {
    GeometryReader { proxy in
      let ctx = PageCtx(
        proxy: proxy,
        dynamicTypeSize: dynamicTypeSize
      )

      WalkthroughView(ctx: ctx, urlHandler: urlHandler, dismissHandler: dismissHandler)
    }
      .background(.black)
  }
}
