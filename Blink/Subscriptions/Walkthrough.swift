//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2025 Blink Mobile Shell Project
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

struct PageInfo: Identifiable {
  let title: String
  let info: Text
  let image: String
  let verticalImage: String?
  let imageMaxSize: CGSize
  let url: URL
  let linkText: Text
  let compactInfo: Text

  var id: String { title }

  init(title: String, linkText: Text, url: URL, info: Text, compactInfo: Text, image: String, imageMaxSize: CGSize = CGSize(width: 700, height: 450)) {
    self.title = title
    self.linkText = linkText
    self.url = url
    self.info = info
    self.compactInfo = compactInfo
    self.image = image
    self.verticalImage = nil
    self.imageMaxSize = imageMaxSize
  }

  init(title: String, linkText: Text, url: URL, info: Text, compactInfo: Text, image: String, verticalImage: String, imageMaxSize: CGSize = CGSize(width: 700, height: 450)) {
    self.title = title
    self.linkText = linkText
    self.url = url
    self.info = info
    self.compactInfo = compactInfo
    self.image = image
    self.verticalImage = verticalImage
    self.imageMaxSize = imageMaxSize
  }

  // TODO Don't like having full fields hanging here. Maybe just "Strings"
  static let multipleTerminalsInfo = PageInfo(
    title: "MULTIPLE TERMINALS & WINDOWS",
    linkText: Text("READ DOCS"),
    url: URL(string: "https://docs.blink.sh")!,
    info: Text("Use **pinch** to zoom. **Two finger tap** to create a new shell. **Slide** to move between shells. **Double tap ⌘ or Home bar** for menu.\nType **help** if you need it."),
    compactInfo: Text("Not to use in compact"),
    image: "intro-windows"

  )

  static let hostsKeysEverywhereInfo = PageInfo(
    title: "YOUR HOSTS & KEYS, EVERYWHERE",
    linkText: Text("READ DOCS"),
    url: URL(string: "https://docs.blink.sh/basics/hosts")!,
    info: Text("Type **`config`** for configuration. Use **Hosts** and **Keys** to setup remote connections. **Keyboard** for modifiers and shortcuts. **Appearance** for fonts and themes."),
    compactInfo: Text("Not to use in compact"),
    image: "intro-settings"
  )

  static let sshMoshToolsInfo = PageInfo(
    title: "SSH, MOSH & BASIC TOOLS",
    linkText: Text("\(Image(systemName: "play.rectangle.fill")) WATCH"),
    url: URL(string: "https://youtube.com/shorts/VYmrSlG9lX0")!,
    info: Text("Type **`mosh`** for high-performance remote shells. Type **`ssh`** for secure shells and tunnels. Type **`sftp`** or **`scp`** for secure file transfer. Use **tab** to list tools like **`vim`**, **`ping`**, etc..."),
    compactInfo: Text("SSH & Mosh • Secure Keys, Certificates & HW • Jump Hosts • Agent • SFTP"),
    image: "intro-commands"
  )

  static let blinkCodeInfo = PageInfo(
    title: "BLINK CODE, YOUR NEW SUPERPOWER",
    linkText: Text("READ DOCS"),
    url: URL(string: "https://docs.blink.sh/advanced/code")!,
    info: Text("Use **`code`** for VS Code editor capabilities. Edit local files, remote files, and even connect to GitHub Codespaces, GitPod or others. All within a first class iOS experience adapted to your device."),
    compactInfo: Text("Edit local files • Edit remote files • Interface adapted to your mobile device"),
    image: "intro-code",
    imageMaxSize: CGSize(width: 680, height: 400)
  )

  static let blinkBuildInfo = PageInfo(
    title: "BUILD YOUR DEV ENVIRONMENTS",
    linkText: Text("\(Image(systemName: "play.rectangle.fill")) WATCH"),
    url: URL(string: "https://youtu.be/78XukJvz5vg")!,
    info: Text("Use **`build`** to access instant dev environments for any task. Use our default Hacker Tools container for coding on Python, JS, Go, Rust, C, etc... Connect your containers to run any application."),
    compactInfo: Text("Run Python, Go, Rust, and others •\u{00a0}2\u{00a0}vCPU •\u{00a0}4\u{00a0}GB\u{00a0}RAM •\u{00a0}50\u{00a0}hours/month"),
    image: "intro-build-horizontal",
    verticalImage: "intro-build-vertical"
  )
}

struct WalkthroughProgressButtons: View {
  let ctx: PageCtx
  let url: URL
  let text: Text
  let urlHandler: (URL) -> ()
  let dismissHandler: () -> ()

  var body: some View {
    HStack {
      Button(
        action: { urlHandler(url) },
        label: { text }
      )
        .buttonStyle(BlinkButtonStyle.secondary(disabled: false, inProgress: false))
      Spacer().frame(width: 20)

      Button("GO TO SHELL") {
        dismissHandler()
      }.buttonStyle(BlinkButtonStyle.primary(disabled: false, inProgress: false))
    }
      .padding(.bottom, ctx.portrait ? 26 : 0)
  }
}

struct WalkthroughTabViewControls: View {
  @Binding var pageIndex: Int
  let firstPageIndex: Int
  let lastPageIndex: Int

  var body: some View {
    HStack {
      Button {
        if self.pageIndex > self.firstPageIndex {
          withAnimation {
            self.pageIndex -= 1
          }
        }
      } label: {
        Image(systemName: "chevron.compact.left").font(.title).foregroundColor(BlinkColors.code)
          .padding()
      }
        .opacity(pageIndex == self.firstPageIndex ? 0.3 : 1.0).disabled(pageIndex == self.firstPageIndex)
        .hoverEffect(.highlight)
        .keyboardShortcut(.leftArrow)
      Spacer()
      Button {
        if self.pageIndex < lastPageIndex {
          withAnimation {
            self.pageIndex += 1
          }
        }
      } label: {
        Image(systemName: "chevron.compact.right").font(.title).foregroundColor(BlinkColors.code)
          .padding()
      }
        .opacity(pageIndex == lastPageIndex ? 0.3 : 1.0).disabled(pageIndex == lastPageIndex)
        .hoverEffect(.highlight)
        .keyboardShortcut(.rightArrow)

    }
  }
}

struct WalkthroughPageView: View {
  let ctx: PageCtx
  let info: PageInfo
  let urlHandler: (URL) -> ()
  let dismissHandler: () -> ()

  var body: some View {
    VStack {
      Text(info.title)
        .font(ctx.headerFont())
        .foregroundColor(BlinkColors.headerText)
        .multilineTextAlignment(.center)
      Spacer()
      Image(ctx.portrait ? info.verticalImage ?? info.image : info.image)
        .resizable()
        .scaledToFit()
        .frame(maxWidth: info.imageMaxSize.width , maxHeight: info.imageMaxSize.height)
        .padding()
      Spacer()
      info.info
        .font(ctx.infoFont())
        .multilineTextAlignment(.center)
        .foregroundColor(BlinkColors.infoText)
        .frame(maxWidth: 810)
        .padding(.bottom)
      Spacer()
      WalkthroughProgressButtons(ctx: ctx, url: info.url, text: info.linkText,
                                 urlHandler: urlHandler, dismissHandler: dismissHandler)
    }.padding(ctx.pagePadding())
  }
}

struct WalkthroughView: View {
  let ctx: PageCtx
  let urlHandler: (URL) -> ()
  let dismissHandler: () -> ()

  @Environment(\.dynamicTypeSize) var dynamicTypeSize
  let pages: [PageInfo] = [
    PageInfo.multipleTerminalsInfo,
    PageInfo.hostsKeysEverywhereInfo,
    PageInfo.sshMoshToolsInfo,
    PageInfo.blinkCodeInfo,
    PageInfo.blinkBuildInfo
  ]

  @StateObject var _purchases = PurchasesUserModel.shared
  @StateObject var _entitlements = EntitlementsManager.shared

  @State var pageIndex = 0

  init(ctx: PageCtx, urlHandler: @escaping (URL) -> Void, dismissHandler: @escaping () -> Void) {
    self.ctx = ctx
    self.urlHandler = urlHandler
    self.dismissHandler = dismissHandler
  }

  var body: some View {
    TabView(selection: $pageIndex) {
      ForEach(Array(zip(pages.indices, pages)), id: \.0) { index, info in
        WalkthroughPageView(ctx: ctx, info: info, urlHandler: urlHandler, dismissHandler: dismissHandler).tag(index)
      }
    }
      .tabViewStyle(.page(indexDisplayMode: ctx.portrait ? .always : .never))
      .overlay(
        HStack {
          if !ctx.portrait {
            WalkthroughTabViewControls(pageIndex: $pageIndex, firstPageIndex: 0, lastPageIndex: pages.count - 1)
          }
        }
      )
      .background(.black)
  }
}

struct WalkthroughsPreview: PreviewProvider {
  static var previews: some View {
    GeometryReader { proxy in
      WalkthroughPreviewWrapper(proxy: proxy)
    }
  }
}

fileprivate struct WalkthroughPreviewWrapper: View {
  let proxy: GeometryProxy
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize  // Move @Environment inside a View

  var body: some View {
    let ctx = PageCtx(
      proxy: proxy,
      dynamicTypeSize: dynamicTypeSize
    )
    return WalkthroughView(ctx: ctx, urlHandler: { _ in }, dismissHandler: {})
  }
}

