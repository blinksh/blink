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

//struct BuildRegionPickerView: View {
//  @Binding var currentValue: BuildRegion
//  @EnvironmentObject var nav: Nav
//
//  var body: some View {
//    List {
//      Section() {
//        ForEach(BuildRegion.all(), id: \.self) { value in
//          HStack {
//            value.fullTitleLabel()
//            Spacer()
//            Checkmark(checked: currentValue == value)
//          }
//          .contentShape(Rectangle())
//          .onTapGesture {
//            currentValue = value
//            nav.navController.popViewController(animated: true)
//          }
//        }
//      }
//    }
//    .listStyle(InsetGroupedListStyle())
//    .navigationTitle("Build Region")
//    .tint(Color("BuildColor"))
//  }
//}

struct BuildView: View {
  @ObservedObject private var _model: PurchasesUserModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  @Namespace var nspace;
  
  var body: some View {
//    BuildCreateAccountView(nspace: self.nspace)
//    if _model.flow == 0 {
//      BuildIntroView(nspace: self.nspace)
//    } else if _model.flow == 1 {
//      BuildCreateAccountView(nspace: self.nspace)
//    } else {
//      BuildAccountView(nspace: self.nspace)
//    }
    if _model.hasBuildToken {
      BuildAccountView(nspace: self.nspace)
    } else if _entitlements.build.active && !_model.purchaseInProgress {
      BuildCreateAccountView(nspace: self.nspace)
    } else {
      BuildIntroView(nspace: self.nspace)
    }
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
        gridOffset =  CGSize(width: 70, height: 24)
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
  @ObservedObject private var _model: PurchasesUserModel = .shared
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
          
          if  _entitlements.earlyAccessFeatures.active {

            Text("Get 2 Free months to Build")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h1, weight: .bold))
              .padding([.top])

            Text("Run work environments from all your devices.\n2\u{00a0}months\u{00a0}free, then $7.99/month.")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h2))
              .padding([.bottom])

            if _model.restoreInProgress || _model.purchaseInProgress || _model.hasBuildToken {
              ProgressView()
                .frame(maxWidth: .infinity, minHeight: props.button, maxHeight: props.button)
                .padding([.top, .bottom])
            } else {
              Button {
                Task {
                  await _model.purchaseBuildBasic()
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
          } else {
            Text("This is Early Access Blink+ Service")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h1, weight: .bold))
              .padding([.top])
            Text("Run work environments from all your devices.\n2\u{00a0}months\u{00a0}free, then $7.99/month.")
              .fixedSize(horizontal: false, vertical: true)
              .font(.system(size: props.h2))
              .padding([.bottom])
            Button {
//              withAnimation {
//                self._model.flow = 1
//              }
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
        .alert(errorMessage: $_model.alertErrorMessage)
        .padding(props.padding)
      }
      .navigationTitle("")
      .toolbar {
        Button(
          action: {
            openURL(URL(string: "https://blink.build")!)
          },
          label: { Label("", systemImage: "info.circle") }
        )
        .symbolRenderingMode(.hierarchical)
      }
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
  @ObservedObject private var _model: PurchasesUserModel = .shared

  let nspace : Namespace.ID;
  @FocusState private var focusedField: Field?
  
  var body: some View {
    List {
      Section(
        header:VStack(alignment: .leading) {
          HStack {
            Spacer()
            Image("build-logo").matchedGeometryEffect(id: "logo", in: self.nspace)
            Spacer()
          }.padding(.bottom).offset(y: -32)
          HStack {
            Text("Select region near you")
            Spacer()
            if FeatureFlags.blinkBuild {
              Button("...") {
                withAnimation {
                  self.showAllRegions.toggle()
                }
              }
            }
          }
        })
      {
        ForEach(showAllRegions ? BuildRegion.all() : BuildRegion.available(), id: \.self) { value in
          HStack {
            value.largeTitleLabel()
            Spacer()
            Checkmark(checked: _model.buildRegion == value)
          }
          .contentShape(Rectangle())
          .onTapGesture {
            _model.buildRegion = value
          }
        }
      }
      Section(
        header: Text("Contact"),
        footer:
          VStack {
            if _model.signupInProgress {
              HStack {
                Spacer()
                ProgressView()
                Spacer()
              }
            } else {
              Button {
                Task {
                  //          withAnimation {
                  //            self._model.flow = 2
                  //          }
                  await _model.signup()
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
          }
      )
      {
          Label {
            TextField(
              "Your Email for Notifications", text: $_model.email
            )
            .focused($focusedField, equals: .email)
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .submitLabel(.go)
            .onSubmit {
              Task {
                await _model.signup()
              }
            }
          } icon: {
            Image(systemName: "envelope.badge")
              .symbolRenderingMode(_model.emailIsValid ? .monochrome : .multicolor)
          }
        }
    }
    .disabled(_model.purchaseInProgress || _model.restoreInProgress || _model.signupInProgress)
    .alert(errorMessage: $_model.alertErrorMessage)
    .navigationTitle("")
    .onTapGesture {
      self.focusedField = nil
    }
    .toolbar {
      if self.idiom == .phone && focusedField == .email && !_model.signupInProgress {
        Button("Signup") {
          Task {
            await _model.signup()
          }
        }
      }
    }
    
    .tint(.green)
  }
}


struct BuildAccountView: View {
  let nspace : Namespace.ID;
  @ObservedObject private var _model: PurchasesUserModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  
  @ViewBuilder
  func list() -> some View {
    if #available(iOS 16.0, *) {
      Chart {
        BarMark(
          x: .value("Mount", "Mon"),
          y: .value("Value", 3)
        )
        BarMark(
          x: .value("Mount", "Tue"),
          y: .value("Value", 4)
        )
        BarMark(
          x: .value("Mount", "Wed"),
          y: .value("Value", 7)
        )
        BarMark(
          x: .value("Mount", "Thu"),
          y: .value("Value", 2)
        )
        
        BarMark(
          x: .value("Mount", "Fri"),
          y: .value("Value", 7)
        )
        BarMark(
          x: .value("Mount", "Sat"),
          y: .value("Value", 8)
        )
        BarMark(
          x: .value("Mount", "Sun"),
          y: .value("Value", 9)
        )
        RuleMark(
          y: .value("Average", 5.7)
        )
        .foregroundStyle(.yellow)
        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 5]))
        .annotation(position: .trailing, alignment: .leading) {
          Text("avg")
            .font(.caption2)
            .foregroundStyle(.yellow)
        }
      }
      .frame(height: 100)
    } else {
      EmptyView()
    }
  }
  
  var body: some View {
    List {
      Section(header: VStack(alignment: .leading) {
        Image("build-logo")
          .matchedGeometryEffect(id: "logo", in: self.nspace)
          .offset(x: -10, y: -32)
        Text("Account")
      })
      {
        Label {
          Text(verbatim: "yury@build.sh")
        } icon: {
          Image(systemName: "envelope.badge")
            .symbolRenderingMode(.monochrome)
        }
        _model.buildRegion.largeTitleLabel()
      }
      Section(header: Text("Usage")) {
        list().accentColor(.green)
      }.onAppear(perform: {
        Task {
          await BuildAPI.accountInfo()
        }
      })
    }
    .tint(.green)
    .alert(errorMessage: $_model.alertErrorMessage)
    .navigationTitle("")
  }
}
