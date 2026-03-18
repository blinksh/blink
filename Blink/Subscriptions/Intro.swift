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

import ConfettiSwiftUI

enum BlinkColors {
  static let bg = Color(red: 20.0 / 256.0, green: 30.0 / 256.0 , blue: 33.0  / 256.0)
//  static let yellow = Color(red: 255.0 / 256.0, green: 184.0 / 256.0, blue: 0.0 / 256.0)
  static let blink = Color(red: 10.0 / 256.0, green: 224.0 / 256.0, blue: 240.0 / 256.0)
  static let build = Color(red: 116.0 / 256.0, green: 251.0 / 256.0, blue: 152.0 / 256.0)
  static let code = Color(red: 255.0 / 256.0, green: 184.0 / 256.0, blue: 0.0 / 256.0)

  static let secondaryBtnBG = Color(red: 16.0 / 256.0, green: 40.0 / 256.0, blue: 41.0 / 256.0)
  static let secondaryBtnText = Color(red: 10.0 / 256.0, green: 224.0 / 256.0, blue: 240.0 / 256.0)
  static let secondaryBtnBorder = Color(red: 42.0 / 256.0, green: 80.0 / 256.0, blue: 83.0 / 256.0)

  static let primaryBtnBG = Color(red: 86.0 / 256.0, green: 62.0 / 256.0, blue: 0.0 / 256.0)
  static let primaryBtnText = BlinkColors.code
  static let primaryBtnBorder = Color(red: 168.0 / 256.0, green: 121.0 / 256.0, blue: 0.0 / 256.0)

  static let ctaBtnBG = Color(red: 1.0 / 256.0, green: 67.0 / 256.0, blue: 76.0 / 256.0)
  static let ctaBtnText = BlinkColors.blink
  static let ctaBtnBorder = BlinkColors.blink

  static let headerText = BlinkColors.code
  static let infoText = Color(red: 195.0 / 256.0, green: 219.0 / 256.0, blue: 219.0 / 256.0)

  static let linearGradient1 = Color(red: 40.0 / 256.0, green: 100.0 / 256.0, blue: 111.0 / 256.0)
//  static let linearGradient2 = Color(red: 9.0 / 256.0, green: 13.0 / 256.0, blue: 14.0 / 256.0)
  static let linearGradient2 = Color(red: (10 + 9.0) / 256.0, green: (10 + 13.0) / 256.0, blue: (10 + 14.0) / 256.0)

  static let radialGradient1 = Color(red: 1.0 / 256.0, green: 4.0 / 256.0, blue: 4.0 / 256.0)
  static let radialGradient2 = Color(red: 20.0 / 256.0, green: 33.0 / 256.0, blue: 33.0 / 256.0, opacity: 0)

  static let blinkBG = Color(red: 16.0 / 256.0, green: 40.0 / 256.0, blue: 41.0 / 256.0)
  static let buildBG = Color(red: 24.0 / 256.0, green: 56.0 / 256.0, blue: 32.0 / 256.0)
  static let codeBG = Color(red: 86.0 / 256.0, green: 62.0 / 256.0, blue: 0.0 / 256.0)

  static let blinkText = Color(red: 195.0 / 256.0, green: 219.0 / 256.0, blue: 219.0 / 256.0)
  static let buildText = Color(red: 207.0 / 256.0, green: 241.0 / 256.0, blue: 216.0 / 256.0)
  static let codeText = Color(red: 240.0 / 256.0, green: 221.0 / 256.0, blue: 171.0 / 256.0)

  static let termsText = Color(red: 92.0 / 256.0, green: 117.0 / 256.0, blue: 117.0 / 256.0)

  static let purchase = Color(red: 149.0 / 256.0, green: 104.0 / 256.0, blue: 203.0 / 256.0)

//  #5C7575
}

let BLINK_APP_FONT_NAME: String = Bundle.main.infoDictionary?["BLINK_APP_FONT"] as? String ?? "JetBrains Mono"

public enum BlinkFonts {
  static let header = Font.custom(BLINK_APP_FONT_NAME, size: 34, relativeTo: .title)
  static let headerCompact = Font.custom(BLINK_APP_FONT_NAME, size: 28, relativeTo: .title)

  static let info = Font.system(.title3)
  static let infoCompact = Font.system(.body)
  static let btn = Font.custom(BLINK_APP_FONT_NAME, size: 16, relativeTo: .body)
  static let btnSub = Font.custom(BLINK_APP_FONT_NAME, size: 12, relativeTo: .body)

  static let bullet = Font.custom(BLINK_APP_FONT_NAME, size: 24, relativeTo: .body).weight(.bold)
  static let bulletCompact = Font.custom(BLINK_APP_FONT_NAME, size: 18, relativeTo: .body).weight(.bold)
  static let bulletText = Font.custom(BLINK_APP_FONT_NAME, size: 18, relativeTo: .body).weight(.bold)
  static let bulletTextCompact = Font.custom(BLINK_APP_FONT_NAME, size: 14, relativeTo: .body).weight(.bold)

  static let offeringSubheader = Font.body.weight(.bold)
  static let offeringCompactSubheader = Font.footnote.weight(.bold)
  static let offeringInfo = Font.system(.body)
  static let offeringInfoCompact = Font.footnote
}

extension Shape {
    func fill<Fill: ShapeStyle, Stroke: ShapeStyle>(_ fillStyle: Fill, strokeBorder strokeStyle: Stroke, lineWidth: Double = 1) -> some View {
        self
            .stroke(strokeStyle, lineWidth: lineWidth)
            .background(self.fill(fillStyle))
    }
}

struct BlinkButtonWithoutHoverStyle: ButtonStyle {
  let textColor: Color
  let bgColor: Color
  let borderColor: Color
  let disabled: Bool
  let inProgress: Bool
  let minWidth: CGFloat?

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .multilineTextAlignment(.center)
      .lineSpacing(5.0)
      .font(BlinkFonts.btn)
      .foregroundColor(inProgress ? bgColor : textColor)

      .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
      .frame(minWidth: minWidth)
      .background(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
          .fill((configuration.isPressed) ?  borderColor : bgColor, strokeBorder: borderColor)

      )
      .opacity((disabled && !inProgress) ? 0.5 : 1.0)

      .overlay(Group {
        if inProgress {
          ProgressView().tint(textColor)
        }
      })
  }

  static func secondary(disabled: Bool, inProgress: Bool, minWidth: CGFloat? = nil) -> Self {
    Self(
      textColor: BlinkColors.secondaryBtnText,
      bgColor: BlinkColors.secondaryBtnBG,
      borderColor: BlinkColors.secondaryBtnBorder,
      disabled: disabled,
      inProgress: inProgress,
      minWidth: minWidth
    )
  }

  static func primary(disabled: Bool, inProgress: Bool, minWidth: CGFloat? = nil) -> Self {
    Self(
      textColor: BlinkColors.primaryBtnText,
      bgColor: BlinkColors.primaryBtnBG,
      borderColor: BlinkColors.primaryBtnBorder,
      disabled: disabled,
      inProgress: inProgress,
      minWidth: minWidth
    )
  }
}

struct BlinkButtonStyle: ButtonStyle {
  let textColor: Color
  let bgColor: Color
  let borderColor: Color
  let disabled: Bool
  let inProgress: Bool
  let minWidth: CGFloat?
  let cta: Bool

  func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .multilineTextAlignment(.center)
        .lineSpacing(5.0)
        .font(cta ? BlinkFonts.offeringSubheader : BlinkFonts.btn)
        .foregroundColor(inProgress ? bgColor : textColor)
        .padding(EdgeInsets(top: 16, leading: 28, bottom: 16, trailing: 28))
        .frame(minWidth: minWidth)
        .background(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill((configuration.isPressed) ?  borderColor : bgColor, strokeBorder: borderColor, lineWidth: cta ? 2.0 : 1.0)

        )
        .opacity((disabled && !inProgress) ? 0.5 : 1.0)
        .overlay(Group {
          if inProgress {
            ProgressView().tint(textColor)
          }
        })
        .hoverEffect(.lift)
  }

  static func cta(disabled: Bool, inProgress: Bool, minWidth: CGFloat? = nil) -> Self {
    Self(
      textColor: BlinkColors.ctaBtnText,
      bgColor: BlinkColors.ctaBtnBG,
      borderColor: BlinkColors.ctaBtnBorder,
      disabled: disabled,
      inProgress: inProgress,
      minWidth: minWidth,
      cta: true
    )
  }

  static func secondary(disabled: Bool, inProgress: Bool, minWidth: CGFloat? = nil) -> Self {
    Self(
      textColor: BlinkColors.secondaryBtnText,
      bgColor: BlinkColors.secondaryBtnBG,
      borderColor: BlinkColors.secondaryBtnBorder,
      disabled: disabled,
      inProgress: inProgress,
      minWidth: minWidth,
      cta: false
    )
  }

  static func primary(disabled: Bool, inProgress: Bool, minWidth: CGFloat? = nil) -> Self {
    Self(
      textColor: BlinkColors.primaryBtnText,
      bgColor: BlinkColors.primaryBtnBG,
      borderColor: BlinkColors.primaryBtnBorder,
      disabled: disabled,
      inProgress: inProgress,
      minWidth: minWidth,
      cta: false
    )
  }
}

struct PageCtx {
  let proxy: GeometryProxy
  let dynamicTypeSize: DynamicTypeSize
  var horizontalCompact: Bool = false
  var verticalCompact: Bool = false
  let portrait: Bool

  func pagePadding() -> EdgeInsets {
    if proxy.size.width < 500 || proxy.size.height < 600 {
      return EdgeInsets(top: 20, leading: 10, bottom: 20, trailing: 10)
    } else {
      return EdgeInsets(top: 30, leading: 30, bottom: 30, trailing: 30)
    }
  }

  func outterPadding() -> CGFloat? {
    if proxy.size.width < 500 || proxy.size.height < 600 {
      return 0
    }
    return nil
  }

  func pagingPadding() -> EdgeInsets {
    if proxy.size.width < 500 {
      return EdgeInsets(top: 50, leading: -12, bottom: 50, trailing: -12)
    } else if proxy.size.width < 700 {
      return EdgeInsets(top: 50, leading: 0, bottom: 50, trailing: 0)
    } else {
      return EdgeInsets(top: 50, leading: 34, bottom: 50, trailing: 34)
    }
  }

  func headerFont() -> Font {
    verticalCompact ? BlinkFonts.headerCompact : BlinkFonts.header
  }

  func infoFont() -> Font {
    (verticalCompact || horizontalCompact) ? BlinkFonts.infoCompact : BlinkFonts.info
  }

  func offeringHeaderFont() -> Font {
    verticalCompact ? BlinkFonts.headerCompact : BlinkFonts.header
  }

  func offeringSubheaderFont() -> Font {
    verticalCompact ? BlinkFonts.offeringCompactSubheader : BlinkFonts.offeringSubheader
  }

  func offeringInfoFont() -> Font {
    (verticalCompact || horizontalCompact) ? BlinkFonts.offeringInfoCompact : BlinkFonts.offeringInfo
  }

  func bulletPadding() -> EdgeInsets {
    if dynamicTypeSize.isAccessibilitySize {
      return EdgeInsets(top: 2, leading: 2, bottom: 2, trailing: 2)
    }
    return horizontalCompact
    ? EdgeInsets(top: 4, leading: 6, bottom: 4, trailing: 6)
    : EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
  }

  func bulletFont() -> Font {
    verticalCompact ? BlinkFonts.bulletCompact : BlinkFonts.bullet
  }

  func bulletTextFont() -> Font {
    verticalCompact ? BlinkFonts.bulletTextCompact : BlinkFonts.bulletText
  }

  func pageMaxHeight() -> CGFloat {
    if dynamicTypeSize <= .medium {
      return 780
    }

    if dynamicTypeSize <= .large {
      return 820
    }

    if dynamicTypeSize <= .xLarge {
      return 900
    }

    if dynamicTypeSize <= .xxLarge {
      return 1000
    }

    return 1200
  }

  init(
    proxy: GeometryProxy,
    dynamicTypeSize: DynamicTypeSize
  ) {
    self.proxy = proxy
    self.dynamicTypeSize = dynamicTypeSize
    self.horizontalCompact =  proxy.size.width < 400
    self.verticalCompact = proxy.size.height < 706
    self.portrait = proxy.size.width < proxy.size.height
  }
}

struct BlinkClassicBulletPoints: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "sparkles")
          .foregroundColor(BlinkColors.blink)
          .padding(.top, 2)
        Text("**Invest in what you use**, support sustainable development that puts users first.")
          .foregroundColor(BlinkColors.blinkText)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack(alignment: .top, spacing: 12) {
        Image(systemName: "person.3.fill")
          .foregroundColor(BlinkColors.blink)
          .padding(.top, 2)
        Text("**Join the pro crowd**, get access to the same tools top users rely on every day.")
          .foregroundColor(BlinkColors.blinkText)
          .multilineTextAlignment(.leading)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

struct NewOfferingTermsButtons: View {
  let ctx: PageCtx
  @StateObject var _purchases = PurchasesUserModel.shared
  @State var opacity: CGFloat = 0.5
  let purchaseCompletedHandler: () -> ()
  let urlHandler: (URL) -> ()

  var body: some View {
    VStack {
      HStack {
        Button("RESTORE") {
          Task {
            // The UI will show an alert and transition there. No need to check the status here.
            let _ = await _purchases.restoreActiveAppSubscriptions(alertIfNone: true)
          }
        }
          .foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Text("•").foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Button("FAQ") {
          urlHandler(URL(string: "https://docs.blink.sh/faq#pricing")!)
        }
          .foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Text("•").foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Button("PRIVACY") {
          _purchases.openPrivacyAndPolicy()
        }
          .foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)
        
        Text("•").foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Button("TERMS") {
          _purchases.openTermsOfUse()
        }
          .foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

        Text("•").foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)
        Button("COPY ID") {
          UIPasteboard.general.string = _purchases.getUserID()
        }
          .foregroundColor(BlinkColors.termsText).font(BlinkFonts.btnSub)

      }
        .padding()
      Text("\(UIApplication.blinkShortVersion() ?? "untagged version")")
        .foregroundColor(BlinkColors.termsText)
        .font(BlinkFonts.btnSub)

    }
  }
}

let minButtonWidth: CGFloat = 300

struct PurchaseCompletedView: View {
  let ctx: PageCtx
  let walkthroughHandler: () -> ()
  let dismissHandler: () -> ()

  @State private var startConfetti = false

  var body: some View {
    ZStack {
      VStack(spacing: 8) {
        // TODO Same as with Build
        Spacer()
        Text("WELCOME TO BLINK SHELL!")
          .font(ctx.offeringHeaderFont())
          .foregroundColor(BlinkColors.blinkText)
          .multilineTextAlignment(.center)
          .padding(.bottom, 30)
        Text("Your device is small, but with Blink, it can take on Big Jobs. Let's get to work!")
          .font(ctx.offeringSubheaderFont())
          .foregroundColor(BlinkColors.blinkText)
          .multilineTextAlignment(.center)
        VStack {
          Button("Walkthrough the app.") { walkthroughHandler() }
            .buttonStyle(BlinkButtonStyle.primary(disabled: false, inProgress: false))
          Spacer().frame(width: 20)
          Button("Go to the shell.") { dismissHandler() }
            .buttonStyle(BlinkButtonStyle.secondary(disabled: false, inProgress: false))
        }
        Spacer()
      }
        .onAppear { startConfetti = true }
        .confettiCannon(trigger: $startConfetti, repetitions: 3)
    }.frame(maxWidth: .infinity)
      .background(.black)
  }
}

struct IntroSetupsCarouselView: View {
  @State private var carrouselIndex = 0
  private let images = ["intro-1", "intro-2", "intro-3", "intro-4", "intro-5", "intro-6"]
  private let timer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
  @State private var opacity: Double = 1.0

  var body: some View {

    GeometryReader { geo in
      VStack {
        Spacer(minLength: geo.size.height * 0.05)

        carousel
          .clipShape(RoundedRectangle(cornerRadius: 15)) // Properly clips to rounded rect
          .overlay(
            RoundedRectangle(cornerRadius: 15)
              .stroke(BlinkColors.blinkBG, lineWidth: 2)
          )
          .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
              opacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
              carrouselIndex = (carrouselIndex + 1) % images.count
              withAnimation(.easeInOut(duration: 0.5)) {
                opacity = 1.0
              }
            }
          }
        .frame(maxWidth: .infinity)
      }
    }
  }

  var carousel: some View {
      ZStack {
        ForEach(images.indices) { index in
          if index == carrouselIndex {
            Image(images[index])
              .resizable()
              .scaledToFit()
              .opacity(opacity)
          }
        }
      }
//      .frame(maxWidth: .infinity)
//     TabView(selection: $carrouselIndex) {
//       ForEach(Array(zip(images.indices, images)), id: \.0) { index, image in
//         Image(image)
//           .resizable()
//           .aspectRatio(contentMode: .fill)
//           .frame(maxWidth: .infinity)
//           .clipped() // Prevents overflow
//           .tag(index)
//       }
//     }
  }

}

struct NewOfferingsView: View {
  let classicOffering: Bool
  let ctx: PageCtx
  @StateObject var _purchases = PurchasesUserModel.shared
  //@State var isBlinkPlusIntroOfferAvailable: Bool = false
  @State var doTrialNotification = true
  let purchaseCompletedHandler: () -> ()
  let urlHandler: ((URL) -> ())
  let dismissHandler: (() -> ())?
  var osName: String {
    UIDevice.current.userInterfaceIdiom == .pad ? "iPadOS" : "iOS"
  }

  private var headerText: some View {
    TypingText(fullText: "THE PRO TERMINAL FOR \(osName)", cursor: "█", style:  {
                                                                          $0.font(ctx.offeringHeaderFont())
                                                                            .foregroundColor(BlinkColors.blinkText)
                                                                        })
      .fixedSize(horizontal: false, vertical: true)
      .multilineTextAlignment(.center)
  }
  
  var body: some View {
    VStack {
      VStack() {
        VStack(alignment: .center) {
          IntroSetupsCarouselView()

          if classicOffering {
            VStack {
              headerText
              BlinkClassicBulletPoints()
            }
            //.padding([.top, .bottom], 30)
            .frame(maxWidth: .infinity)
          } else {
            VStack {
              headerText
              Text("Fully customizable, always-on, and ready for anything. Your entire terminal workflow, now fits in your pocket.")
                .font(ctx.offeringSubheaderFont())
                .fixedSize(horizontal: false, vertical: true)
                .foregroundColor(BlinkColors.blinkText) // 3
                .multilineTextAlignment(.center)
            }
            .padding([.top, .bottom], ctx.outterPadding())
          }
        }
        .padding(ctx.pagePadding())
        .background(.black)

        Rectangle()
          .fill(BlinkColors.blink)
          .frame(height: 2)
          .padding(0)

        VStack {
          Button(blinkPlusSubscribeButtonText()) {
            Task {
              await self.purchaseBlinkPlus()
            }
          }.buttonStyle(BlinkButtonStyle.cta(disabled: _purchases.restoreInProgress || _purchases.purchaseInProgress,
                                             inProgress: _purchases.purchaseInProgress || _purchases.restoreInProgress || _purchases.formattedBlinkPlusPriceWithPeriod() == nil, minWidth: minButtonWidth))

          if _purchases.blinkPlusIntroOfferAvailable() {
            TrialSwitch(doTrialNotification: $doTrialNotification)
              .disabled(_purchases.restoreInProgress || _purchases.purchaseInProgress)
          }

          NewOfferingTermsButtons(ctx: ctx, purchaseCompletedHandler: purchaseCompletedHandler, urlHandler: urlHandler)
        }
        .padding(.top, 16)
        .background(BlinkColors.bg.opacity(0.2)) //
        .alert("Thank you!", isPresented: $_purchases.restoredPurchaseMessageVisible) {
          Button("OK") {
            self.purchaseCompletedHandler()
          }
        } message: {
          Text(_purchases.restoredPurchaseMessage)
        }
      }
    }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  func blinkPlusSubscribeButtonText() -> String {
    let price = _purchases.formattedPlusPriceWithPeriod()?.uppercased() ?? ""

    if _purchases.blinkPlusIntroOfferAvailable() {
      return "TRY IT FREE FOR 14 DAYS"
    } else {
      return "BUY \(price)"
    }
  }
  
  func purchaseBlinkPlus() async {
    // Restore before purchase and check entitlements, because Blink Plus may come from different groups on previous Blink+Build.
    if await _purchases.restoreBlinkPlusEntitlements(alertIfNone: false) {
      self.purchaseCompletedHandler()
      return
    }
    
    let trialSelection = _purchases.blinkPlusIntroOfferAvailable() ? doTrialNotification : false
    let success = await _purchases.purchaseBlinkPlusWithTrialValidation(setupTrial: trialSelection)
    if success {
      self.purchaseCompletedHandler()
    }
  }
}

struct TrialSwitch: View {
  @Binding var doTrialNotification: Bool

  var body: some View {
    HStack {
      Spacer()
      Text("Get Trial Reminder")
        .foregroundColor(BlinkColors.infoText)
        .font(BlinkFonts.btnSub)
      Toggle("", isOn: $doTrialNotification)
        .toggleStyle(.switch)
        .labelsHidden()
        .scaleEffect(0.7)
        .tint(BlinkColors.primaryBtnBorder)
      Spacer()
    }.controlSize(.mini)
  }
}

struct NewIntroPageWindow: View {
  let urlHandler: (URL) -> Void
  let dismissHandler: () -> ()

  @Environment(\.dynamicTypeSize) var dynamicTypeSize
  @State var page = NewIntroPageState.offerings
  @StateObject var _purchases = PurchasesUserModel.shared

  var body: some View {
    GeometryReader { proxy in
      let ctx = PageCtx(
        proxy: proxy,
        dynamicTypeSize: dynamicTypeSize
      )

      let isPad = UIDevice.current.userInterfaceIdiom == .pad
      let width = proxy.size.width * (isPad ? (ctx.portrait ? 0.9 : 0.55) : 0.9)
      let height = proxy.size.height * (isPad ? (ctx.portrait ? 0.7 : 0.9) : (ctx.verticalCompact ? 0.9 : 0.7))
      Group {
        ZStack {
//        Text("hello world")
          switch page {
          case .offerings:
            NewOfferingsView(classicOffering: false, ctx: ctx, purchaseCompletedHandler: { page = .walkthrough }, urlHandler: urlHandler, dismissHandler: nil)
          case .purchaseCompleted:
            PurchaseCompletedView(ctx: ctx, walkthroughHandler: { page = .walkthrough }, dismissHandler: dismissHandler)
          case .walkthrough:
            WalkthroughView(ctx: ctx, urlHandler: urlHandler, dismissHandler: dismissHandler).transition(.move(edge: .trailing)).transition(.opacity)
          }
        }
      }
      .background(.black)
      .clipShape(RoundedRectangle(cornerRadius: 45))
      .overlay(
        RoundedRectangle(cornerRadius: 45)
          .stroke(BlinkColors.blink, lineWidth: 2)
      )
      .frame(width: width, height: height)
      .padding(.all, ctx.outterPadding())
      .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .alert(errorMessage: $_purchases.alertErrorMessage)

      .background(LinearGradient(
                    gradient: Gradient(colors: [BlinkColors.linearGradient1, Color.black]),
                    startPoint: .top,
                    endPoint: .bottom
                  ))
      .ignoresSafeArea(.all, edges: [.bottom, .horizontal])
  }
}

enum NewIntroPageState {
  case offerings
  case purchaseCompleted
  case walkthrough
}

struct NewOfferingsPreview: PreviewProvider {
  static var previews: some View {
    GeometryReader { proxy in
      NewOfferingsPreviewWrapper(proxy: proxy)
    }
  }
}

fileprivate struct NewOfferingsPreviewWrapper: View {
  let proxy: GeometryProxy
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize  // Move @Environment inside a View

  var body: some View {
    let ctx = PageCtx(
      proxy: proxy,
      dynamicTypeSize: dynamicTypeSize
    )
    return NewOfferingsView(classicOffering: true, ctx: ctx, purchaseCompletedHandler: {}, urlHandler: { _ in }, dismissHandler: {}).background(.black)
  }
}

struct NewIntroPagePreview: PreviewProvider {
  static var previews: some View {
//    NewIntroPageWindow(urlHandler: {_ in }, dismissHandler: { })
//      .environment(\.sizeCategory, .extraSmall)

    NewIntroPageWindow(urlHandler: {_ in }, dismissHandler: { })

//    NewIntroPageWindow(urlHandler: {_ in }, dismissHandler: { })
//      .environment(\.sizeCategory, .accessibilityExtraLarge)

  }
}
