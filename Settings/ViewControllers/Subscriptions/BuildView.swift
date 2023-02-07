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
import RevenueCat
import Charts

struct BuildRegionPickerView: View {
   @Binding var currentValue: BuildRegion
   @EnvironmentObject var nav: Nav

   var body: some View {
     GeometryReader { proxy in
       let compact = proxy.size.width < 400
       List {
         Section(header: Text("Choose nearest region")) {
           ForEach(BuildRegion.envAvailable(), id: \.self) { value in
             HStack {
               if compact {
                 value.fullTitleLabel()
               } else {
                 value.largeTitleLabel()
               }
               Spacer()
               Checkmark(checked: currentValue == value)
             }
             .contentShape(Rectangle())
             .onTapGesture {
               currentValue = value
               nav.navController.popViewController(animated: true)
             }
           }
         }
       }
     }
     .listStyle(InsetGroupedListStyle())
     .navigationTitle("Build Region")
     .tint(Color("BuildColor"))
   }
 }

struct BasicMachineSection: View {
  let nspace : Namespace.ID;
  
  var body: some View {
    Section(
      header:VStack(alignment: .leading) {
        HStack {
          Spacer()
          Image("build-logo").matchedGeometryEffect(id: "logo", in: self.nspace)
          Spacer()
        }.padding(.bottom).offset(y: -32)
        HStack {
          Text("Machine")
        }
      }
    ) {
      Label {
        Text("4 GiB of RAM")
      } icon: {
        Image(systemName: "memorychip")
          .foregroundColor(.green)
        
      }
      Label {
        Text("2 vCPUs")
      } icon: {
        Image(systemName: "cpu")
          .foregroundColor(.green)
      }
      Label {
        Text("4,000 GiB Transfer")
      } icon: {
        Image(systemName: "network")
          .foregroundColor(.green)
      }
      Label {
        Text("60 GiB Ephemeral SSD")
      } icon: {
        Image(systemName: "internaldrive")
          .foregroundColor(.green)
      }
      Label {
        Text("50 Credits (1 credit/hour)")
      } icon: {
        Image(systemName: "timer")
          .foregroundColor(.green)
      }
    }
  }
}

struct BasicMachinePlanView: View {
  @ObservedObject private var _purchases: PurchasesUserModel = .shared
  @ObservedObject private var _account: BuildAccountModel = .shared
  
  let nspace : Namespace.ID;
  
  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 400
      
      List {
        BasicMachineSection(nspace: self.nspace)
        Section(header: Text("Storage")) {
          Label {
            Text("5 GiB Main Cloud Disk")
          } icon: {
            Image(systemName: "externaldrive.badge.icloud")
              .foregroundColor(.green)
          }
        }
        
        Section(header: Text("Available Regions")) {
          ForEach(BuildRegion.envAvailable()) { region in
            if compact {
              region.fullTitleLabel()
            } else {
              region.largeTitleLabel()
            }
          }
        }
        
        Section(header: Text("Price")) {
          Label("First month free with Blink+, \(_purchases.formattedBuildPriceWithPeriod() ?? "") thereafter.", systemImage: "bag")
        }
        Section {
          Button(action: {
            _account.openTermsOfService()
          }, label:  { Label("Terms of Service", systemImage: "link").foregroundColor(.green) })
        }
      }
    }
    .toolbar(content: {
      Button(action: {
          _account.showInfo = false
      }, label:  { Label("", systemImage: "xmark.circle").foregroundColor(.green) })
      .symbolRenderingMode(.hierarchical)
    })
    .tint(.green)
    .onDisappear {
      _account.showInfo = false
    }
  }
}

struct BuildView: View {
  @ObservedObject private var _purchases: PurchasesUserModel = .shared
  @ObservedObject private var _account: BuildAccountModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  @Namespace var nspace;
  
  var body: some View {
    BuildAccountView(nspace: self.nspace)
//    BuildCreateAccountView(nspace: self.nspace)
//    if _account.showInfo {
//      BasicMachinePlanView(nspace: self.nspace)
//    } else {
//      BuildIntroView(nspace: self.nspace)
//    }
//    BuildAccountView(nspace: self.nspace)
    
//    if _model.flow == 0 {
//      BuildIntroView(nspace: self.nspace)
//    } else if _model.flow == 1 {
//      BuildCreateAccountView(nspace: self.nspace)
//    } else {
//      BuildAccountView(nspace: self.nspace)
//    }
    
    
//    if _account.hasBuildToken {
//      BuildAccountView(nspace: self.nspace)
//    } else if _entitlements.build.active && !_purchases.purchaseInProgress {
//      BuildCreateAccountView(nspace: self.nspace)
//    } else {
//      if _account.showInfo {
//        BasicMachinePlanView(nspace: self.nspace)
//      } else {
//        BuildIntroView(nspace: self.nspace)
//      }
//    }
  }
}

private struct LayoutProps {
  let h1: CGFloat
  let h2: CGFloat
  let button: CGFloat
  let padding: Edge.Set
  let gridScale: CGFloat
  let gridOffset: CGSize
  let gridOpacity: CGFloat
  
  init(size: CGSize) {
    if UIDevice.current.userInterfaceIdiom == .phone {
      var gridScale: CGFloat = 1.0
      var gridOffset: CGSize = .zero
      
      if size.width > size.height {
        gridOffset =  CGSize(width: 100, height: 46)
        gridScale = 0.8
      }
      
      self.h1 = 28
      self.h2 = 14
      self.button = 50
      self.padding = [.leading, .trailing]
      self.gridScale = gridScale
      self.gridOffset = gridOffset
      self.gridOpacity = 1.0
    } else {
      var h1: CGFloat = 32
      var h2: CGFloat = 20
      var button: CGFloat = 70
      var gridScale: CGFloat = 0.8
      var gridOffset: CGSize = .zero
      var padding: Edge.Set = []
      var gridOpacity: CGFloat = 1.0
      
      if size.height < 500 {
        h1 = 28
        h2 = 18
        button = 60
        gridScale = 0.5
        gridOffset =  CGSize(width: 70, height: 0)
      } else if size.height < 600 {
        h1 = 30
        h2 = 18
        gridScale = 0.7
      }
      
      if size.width < 328 {
        h1 = 22
        h2 = 14
        button = 50
        gridScale = 0.6
      }
      
//      if size.width < 450 {
      if size.width < 570 {
        padding = [.leading, .trailing]
        if size.height < 640 {
          gridOpacity = 0.5
        }
      }
      
      self.h1 = h1
      self.h2 = h2
      self.button = button
      self.padding = padding
      self.gridScale = gridScale
      self.gridOffset = gridOffset
      self.gridOpacity = gridOpacity
    }
    
  }
}

struct BuildIntroView: View {
  @State var scale = 1.3
  @ObservedObject private var _purchases: PurchasesUserModel = .shared
  @ObservedObject private var _account: BuildAccountModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  @EnvironmentObject private var _nav: Nav
  let nspace : Namespace.ID
  @Environment(\.openURL) private var openURL
  
  var body: some View {
    
    GeometryReader { proxy in
      let size = proxy.size
      let props = LayoutProps(size: size)
      
      VStack() {
        Spacer()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .overlay(
            Image("iso-grid")
              .scaleEffect(props.gridScale)
              .scaleEffect(scale)
              .offset(props.gridOffset)
              .opacity(props.gridOpacity)
          )
          .onAppear( perform: {
            withAnimation(.easeIn) {
              self.scale = 1.0
            }
          })
        
        
        VStack(alignment: .leading) {
          Image("build-logo").matchedGeometryEffect(id: "logo", in: self.nspace)
          
          if  !_entitlements.earlyAccessFeatures.active {

            Text("Get a free month to Build")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h1, weight: .bold))
              .padding([.top])

            Text("Run work environments from all your devices.")
              .font(.system(size: props.h2))
            Text("[Basic plan](#info) 1\u{00a0}month\u{00a0}free, then \(_purchases.formattedBuildPriceWithPeriod() ?? "").")
                .fixedSize(horizontal: false, vertical: true)
                .font(.system(size: props.h2))
                .padding([.bottom])
                .environment(\.openURL, OpenURLAction(handler: { url in
                  withAnimation {
                    _account.showInfo = true
                  }
                  return .handled
                }))

            if _purchases.restoreInProgress || _purchases.purchaseInProgress || _account.hasBuildToken {
              ProgressView()
                .frame(maxWidth: .infinity, minHeight: props.button, maxHeight: props.button)
                .padding([.top, .bottom])
            } else {
              Button {
                Task {
                  await _purchases.purchaseBuildBasic()
                }
              } label: {
                Text("Try it Free")
                  .font(.system(size: props.h2, weight: .bold))
                  .frame(maxWidth: .infinity, maxHeight: .infinity)
              }.foregroundColor(Color.black)
                .buttonStyle(.borderedProminent)
                .frame(minHeight: props.button, maxHeight: props.button)
                .padding([.top, .bottom])
            }
            HStack {
              Spacer()
              Button("Terms of Use", action: {
                _account.openTermsOfService()
              }).padding(.trailing)
              Button("Restore Purchases", action: {
                _purchases.restorePurchases()
              })
              Spacer()
            }.padding(.bottom).disabled(_purchases.restoreInProgress)
          } else {
            Text("Beta exclusive to Blink+ users")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h1, weight: .bold))
              .padding([.top])
            Text("Run work environments from all your devices.\nFirst month free with Blink+,  \(_purchases.formattedBuildPriceWithPeriod() ?? "") thereafter.")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h2))
              .padding([.bottom])
            Button {
              let vc = UIHostingController(rootView: PlansView())
              _nav.navController.pushViewController(vc, animated: true)
            } label: {
              Text("Compare Plans  \(Image(systemName: "bag.badge.questionmark"))")
                .font(.system(size: props.h2, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }.foregroundColor(Color("BuildColor"))
              .buttonStyle(.plain)
              .frame(minHeight: props.button, maxHeight: props.button)
              .padding([.top, .bottom])
          }
        }
        .frame(maxWidth: 574)
        .alert(errorMessage: $_purchases.alertErrorMessage)
        .padding(props.padding)
      }
      .navigationTitle("")
      .padding(.bottom)
      .tint(Color("BuildColor"))
    }
  }
}

struct BuildCreateAccountView: View {
  enum Field: Hashable {
      case email
  }

  @State var showAllRegions = false
  @State var idiom = UIDevice.current.userInterfaceIdiom
  @ObservedObject private var _account: BuildAccountModel = .shared
  @ObservedObject private var _purchases: PurchasesUserModel = .shared

  let nspace : Namespace.ID;
  @FocusState private var focusedField: Field?
  
  var body: some View {
    GeometryReader { proxy in
      let compact = proxy.size.width < 400
      
      List {
        BasicMachineSection(nspace: self.nspace)
          .onTapGesture {
            self.focusedField = nil
          }
        Section(header: Text("Storage")) {
          Label {
            Text("5 GiB Main Cloud Disk")
          } icon: {
            Image(systemName: "externaldrive.badge.icloud")
              .foregroundColor(.green)
          }
        }.onTapGesture {
          self.focusedField = nil
        }
        
        Section(
          header: Text("Setup your Account"),
          footer: Text("We will send you verification email.")
        )
        {
          Row(
            content: {
              Group {
                if compact {
                  _account.buildRegion.fullTitleLabel()
                } else {
                  _account.buildRegion.largeTitleLabel()
                }
              }
            },
            details: {
              BuildRegionPickerView(currentValue: $_account.buildRegion)
            }
          )
          Label {
            self.emailTextField()
              .focused($focusedField, equals: .email)
              .textContentType(.emailAddress)
              .keyboardType(.emailAddress)
              .submitLabel(.go)
              .onSubmit {
                Task {
                  await _account.signup()
                }
              }
          } icon: {
            Image(systemName: "envelope.badge")
              .symbolRenderingMode(_account.emailIsValid ? .monochrome : .multicolor)
          }
        }
        Section(footer: VStack {
          if _account.signupInProgress {
            HStack {
              Spacer()
              ProgressView().frame(minHeight: 70, maxHeight: 70).padding([.top, .bottom])
              Spacer()
            }
          } else {
            Button {
              Task {
                //          withAnimation {
                //            self._model.flow = 2
                //          }
                await _account.signup()
              }
            } label: {
              Text("Sign up")
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }.foregroundColor(Color("BuildColor"))
              .buttonStyle(.plain)
              .frame(minHeight: 70, maxHeight: 70)
              .padding([.top, .bottom])
              .opacity(self.idiom == .phone && self.focusedField == .email ? 0 : 1)
          }
        }) {
          EmptyView()
          //        Button(
          //          action: { _account.openTermsOfService() },
          //          label:  { Label("Terms of Service", systemImage: "link").foregroundColor(.green) }
          //        )
        }
      }
    }
    .disabled(_purchases.purchaseInProgress || _purchases.restoreInProgress || _account.signupInProgress)
    .alert(errorMessage: $_account.alertErrorMessage)
    .navigationTitle("")
    .toolbar {
      if self.idiom == .phone && focusedField == .email && !_account.signupInProgress {
        Button("Signup") {
          Task {
            await _account.signup()
          }
        }
      }
    }
    
    .tint(.green)
  }
  
  @ViewBuilder
  func emailTextField() -> some View {
    if #available(iOS 16.0, *) {
      TextField(
        "Your Email for Notifications", text: $_account.email
      )
      .scrollDismissesKeyboard(.interactively)
    } else {
      TextField(
        "Your Email for Notifications", text: $_account.email
      )
    }
  }
}

struct BuildPeriodSection: View {
  let balance: BuildUsageBalance
  
  var body: some View {
    Section(header: Text("Period")) {
      HStack {
        Label("Start", systemImage: "calendar")
        Spacer()
        Text(balance.periodStartDate.formatted())
      }
      HStack {
        Label("End", systemImage: "calendar.badge.clock")
        Spacer()
        Text(balance.periodEndDate.formatted())
      }
      HStack {
        Label("Status", systemImage: "wallet.pass")
        Spacer()
        Text(balance.status)
      }
    }
  }
}


struct BuildCreditsSection: View {
  let balance: BuildUsageBalance
  
  var body: some View {
    Section(header: Text("Credits")) {
      HStack {
        Label("Consumed", systemImage: "number.circle")
        Spacer()
        Text("\(balance.credits_consumed)")
      }
      HStack {
        Label("Available", systemImage: "number.circle.fill")
        Spacer()
        Text("\(balance.credits_available)")
      }
    }
  }
}

struct BuildAccountView: View {
  let nspace : Namespace.ID;
  @State var showHelp: Bool = false
  @ObservedObject private var _model: BuildAccountModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  @State var showDeleteAccountAlert = false
  @EnvironmentObject var _nav: Nav;
  
  var body: some View {
    if _model.email.isEmpty {
      VStack {
        Spacer()
        Image("build-logo")
          .matchedGeometryEffect(id: "logo", in: self.nspace)
        Spacer()
        if _model.accountInfoLoadingInProgress {
          ProgressView()
        } else {
          Button {
            Task {
              await _model.fetchAccountInfo()
            }
          } label: {
            Label("Retry", systemImage: "arrow.triangle.2.circlepath")
          }
        }
        Spacer()
      }
      .tint(.green)
      .alert(errorMessage: $_model.alertErrorMessage)
      .navigationTitle("")
      .toolbar(content: {
        if !_model.accountInfoLoadingInProgress {
          Button {
            let vc = UIHostingController(rootView: BuildSupportView(email: _model.email))
            _nav.navController.pushViewController(vc, animated: true)
          } label: {
            Label("Support", systemImage: "lifepreserver")
          }
        }
      })
      .task {
        if _model.email.isEmpty {
          await _model.fetchAccountInfo()
        }
      }
    } else {
      GeometryReader { proxy in
        let compact = proxy.size.width < 400
        
        List {
          Section(header: VStack(alignment: .leading) {
            Image("build-logo")
              .matchedGeometryEffect(id: "logo", in: self.nspace)
              .offset(x: -10, y: -32)
            Text("Account")
          })
          {
            Label {
              Text(_model.email)
            } icon: {
              Image(systemName: "envelope.badge")
                .symbolRenderingMode(.monochrome)
            }
            if compact {
              _model.buildRegion.fullTitleLabel()
            } else {
              _model.buildRegion.largeTitleLabel()
            }
          }
          if let balance = _model.usageBalance {
            BuildCreditsSection(balance: balance)
            BuildPeriodSection(balance: balance)
          }
          Section {
            Row {
              Label("Support", systemImage: "lifepreserver")
            } details: {
              BuildSupportView(email: _model.email)
            }
          }
          Section(header: Text("Danger Zone")) {
//            if FeatureFlags.blinkBuildStaging {
//              Toggle(isOn: $_model.isStagingEnv, label: {
//                Label("Staging env", systemImage: "wrench.and.screwdriver")
//              })
//            }
            Button {
              self.showDeleteAccountAlert = true
            } label: {
              Label("Delete Account", systemImage: "hand.raised").foregroundColor(.orange)
            }
            .alert(isPresented: $showDeleteAccountAlert, content: {
              Alert(
                title: Text("Warning"),
                message: Text("You account will be scheduled for deletion."),
                primaryButton: .destructive(Text("Delete"), action: {
                  Task {
                    await _model.requestAccountDelete()
                  }
                }),
                secondaryButton: .cancel()
              )
            })
          }
        }
      }
      .task {
        await _model.fetchUsageBalance()
      }
      .refreshable {
        await _model.fetchAccountInfo()
        await _model.fetchUsageBalance()
      }
      .tint(.green)
      .alert(errorMessage: $_model.alertErrorMessage)
      
      .navigationTitle("")
      .toolbar(content: {
        Button("Help", action: {
          self.showHelp.toggle()
        })
      })
      
      .overlay {
        if showHelp {
          SizedCmdListView()
            .padding([.leading, .trailing, .bottom])
            .padding(.bottom)
            .padding(.bottom)
            .background(
              Rectangle()
                .foregroundColor(Color(UIColor.systemBackground))
                .ignoresSafeArea(.all)
            )
        } else {
          EmptyView()
        }
      }
    }
  }
}


struct BuildSupportView: View {
  public let email: String
  
  func emailStr() -> String {
    if email.isEmpty {
      return ""
    }
    
    return " (\(email))"
  }
  
  var body: some View {
    VStack {
      ScrollView(.vertical) {
        VStack(alignment: .leading) {
          Text(
            "Thanks for using Blink Build and helping us make this app even more epic! "
          ).font(.title).fixedSize(horizontal: false, vertical: true)
            .padding(.bottom).padding(.bottom)
          Text(
            "If you’re facing any usage roadblocks, check out our documentation or Community Resources like [GitHub Discussions](https://github.com/blinksh/blink/discussions) or [Discord](https://discord.gg/ZTtMfvK)."
          )
          .padding(.bottom)
          Text(
            "If it's an account-related problem (e.g. machines, login, or accounting), send an email to support@blink.build from your registered account\(self.emailStr()). Our team will be on it ASAP to help resolve the issue."
          )
        }
        .frame(minWidth: 240, maxWidth: 600)
        .padding([.leading, .trailing])
        
        Spacer().frame(maxWidth: .infinity, minHeight: 620, maxHeight: .infinity)
          .overlay {
            VStack  {
              Spacer().frame(height: 40)
              Image("iso-grid")
              Spacer()
            }
          }
//        Spacer().background(content: { Image("iso-grid") })
//        Image("iso-grid").fixedSize().scaledToFit()
      }.ignoresSafeArea(edges: [.leading, .bottom, .trailing]).tint(.green)
    }
  }
}
