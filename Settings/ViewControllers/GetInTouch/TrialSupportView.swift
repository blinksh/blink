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


import MessageUI
import SwiftUI

private let EmailAddress = "support+trial"
private let EmailSubject = "Trial Support request"

private let EmailContent = """
What I'm trying to do:
  <Explain what you are trying to configure, or connect to, etc.>

Where I'm getting stuck:
  <Explain what you have tried so far to make it work.>
"""

struct TrialSupportView: View {
  @EnvironmentObject private var _nav: Nav
  @State var failedSendTalkToUs = false

  var body: some View {
    VStack {
      AsyncImage(
        url: URL(string: "https://blink-363718.web.app/trial/ipad_setup.jpeg"),
        content: {
          $0.resizable()
            .aspectRatio(contentMode: .fit)
        },
        placeholder: { ProgressView() }
      )

      List {
        Section {
          Button {
            sendTalkToUs()
          } label: {
            Label(title: {
              VStack(alignment: .leading, spacing: 1) {
                Text("Talk to us")
                Text("Whether configuring your external keyboard or problems connecting to a remote. Send us a few details, and we will provide the best answer.").foregroundColor(.secondary).font(.subheadline)
              }
            }, icon: { Image(systemName: "bubble.left.and.bubble.right") })
          }
        }

        Section("Other resources") {
          HStack {
            Button {
              BKLinkActions.sendToDocumentation()
            } label: {
              Label("Documentation", systemImage: "book")
            }
            Spacer()
            Text("").foregroundColor(.secondary)
          }
          HStack {
            Button {
              BKLinkActions.sendToGithubDiscussions()
            } label: {
              Label("GitHub", systemImage: "exclamationmark.bubble")
            }

            Spacer()
            Text("Discussions").foregroundColor(.secondary)
          }
        }
      }
    }.alert("Could not open your Default Mail app",
            isPresented: $failedSendTalkToUs,
            actions: { Button("Ok") {} },
            message: {
      Text("Please send an email to \(EmailAddress)@blink.sh. Make sure to include: \(EmailContent)")
    })
  }

  private func sendTalkToUs() {
    let mailToString = "mailto:\(EmailAddress)@blink.sh?subject=\(EmailSubject)&body=\(EmailContent)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
    print(mailToString)
    let mailToURL = URL(string: mailToString)!
    UIApplication.shared.open(mailToURL) { success in
      if !success {
        // This also works if there is no default app (even after showing the "install mail.app")
        failedSendTalkToUs = true
      }
    }
  }
}
