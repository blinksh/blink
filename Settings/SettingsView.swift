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


import Foundation
import SwiftUI
import LocalAuthentication

struct SettingsView: View {

  @EnvironmentObject private var _nav: Nav
  @State private var _biometryType = LAContext().biometryType
  @State private var _blinkVersion = UIApplication.blinkShortVersion() ?? ""
  @State private var _iCloudSyncOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigiCloud)
  @State private var _autoLockOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigAutoLock)
  @State private var _defaultUser = BLKDefaults.defaultUserName() ?? ""
  @StateObject private var _entitlements: EntitlementsManager = .shared
  @StateObject private var _model = PurchasesUserModel.shared
  @State private var _displayBlinkClassicToPlus = false

  var body: some View {
    List {
      if _entitlements.earlyAccessFeatures.active && _entitlements.earlyAccessFeatures.period == .Trial {
        Section {
          Row {
            Label(title: {
                    VStack(alignment: .leading, spacing: 1) {
                      Text("Need extra help?")
                      Text("Don't be shy. We want Blink to work for you. Ask us questions during your trial.").foregroundColor(.secondary).font(.subheadline)
                    }
                  }, icon: { Image(systemName: "questionmark.bubble") })
          } details: {
            TrialSupportView()
          }
        } header: {
          Text("Trial support")
        }
      }

      Section("Subscription") {
        HStack {
          Label(_entitlements.currentPlanName(), systemImage: "bag")
          Spacer()
          if !(_entitlements.earlyAccessFeatures.active || FeatureFlags.earlyAccessFeatures) {
            Button("Get Blink+") { _displayBlinkClassicToPlus = true }
          }
        }
        if _entitlements.earlyAccessFeatures.active {
          Row {
            HStack {
              Label("Build Beta", systemImage: "hammer.circle")
              Spacer()
              if _entitlements.earlyAccessFeatures.period == .Trial {
                Text("Not available in trial")
              } else {
                Text("") // TODO: show status?
                  .foregroundColor(.secondary)
              }
            }
          } details: {
              BuildView().onAppear(perform: {
                BuildAccountModel.shared.checkBuildToken(animated: false)
              })
          }.disabled(_entitlements.earlyAccessFeatures.period != .Normal)
        }
      }
      Section("Connect") {
        Row {
          Label("Keys & Certificates", systemImage: "key")
        } details: {
          KeyListView()
        }
        Row {
          Label("Hosts", systemImage: "server.rack")
        } details: {
          HostListView()
        }
        Row {
          Label("Default Agent", systemImage: "key.viewfinder")
        } details: {
          DefaultAgentSettingsView()
        }
        RowWithStoryBoardId(content: {
          HStack {
            Label("Default User", systemImage: "person")
            Spacer()
            Text(_defaultUser).foregroundColor(.secondary)
          }
        }, storyBoardId: "BKDefaultUserViewController")
      }

      Section("Terminal") {
        Row {
          Label("Style", systemImage: "paintpalette")
        } details: {
          StyleCustomizationView()
        }
        Row {
          Label("Display", systemImage: "display")
        } details: {
          DisplaySettingsView()
        }
        Row {
          Label("Keyboard", systemImage: "keyboard")
        } details: {
          KBConfigView(config: KBTracker.shared.loadConfig())
        }
        RowWithStoryBoardId(content: {
          Label("Smart Keys", systemImage: "keyboard.badge.ellipsis")
        }, storyBoardId: "BKSmartKeysConfigViewController")
        Row {
          Label("Notifications", systemImage: "bell")
        } details: {
          BKNotificationsView()
        }
#if TARGET_OS_MACCATALYST
        Row {
          Label("Gestures", systemImage: "rectangle.and.hand.point.up.left.filled")
        } details: {
          GesturesView()
        }
#endif
      }

      Section("Configuration") {
        Row {
          Label("Bookmarks", systemImage: "bookmark")
        } details: {
          BookmarkedLocationsView()
        }

        Row {
          Label("Snips", systemImage: "chevron.left.square")
        } details: {
          SnippetsConfigView()
        }

        RowWithStoryBoardId(content: {
          HStack {
            Label("iCloud Sync", systemImage: "icloud")
            Spacer()
            Text(_iCloudSyncOn ? "On" : "Off").foregroundColor(.secondary)
          }
        }, storyBoardId: "BKiCloudConfigurationViewController")

        RowWithStoryBoardId(content: {
          HStack {
            Label("Auto Lock", systemImage: _biometryType == .faceID ? "faceid" : "touchid")
            Spacer()
            Text(_autoLockOn ? "On" : "Off").foregroundColor(.secondary)
          }
        }, storyBoardId: "BKSecurityConfigurationViewController")
      }

      Section("Get in touch") {
        Row {
          Label("Support", systemImage: "book")
        } details: {
          SupportView()
        }
        Row {
          Label("Community", systemImage: "bubble.left")
        } details: {
          FeedbackView()
        }
        // HStack {
        //   Button {
        //     BKLinkActions.sendToAppStore()
        //   } label: {
        //     Label("Rate Blink", systemImage: "star")
        //   }

        //   Spacer()
        //   Text("App Store").foregroundColor(.secondary)
        // }
      }

      Section {
        RowWithStoryBoardId(content: {
          HStack {
            Label("About", systemImage: "questionmark.circle")
            Spacer()
            Text(_blinkVersion).foregroundColor(.secondary)
          }
        }, storyBoardId: "BKAboutViewController")
        HStack {
          Button {
            _model.openPrivacyAndPolicy()
          } label: {
            Label("Privacy Policy", systemImage: "link")
          }
        }
        HStack {
          Button {
            _model.openTermsOfUse()
          } label: {
            Label("Terms of Use", systemImage: "link")
          }
        }
      }
    }
    .onAppear {
      _iCloudSyncOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigiCloud)
      _autoLockOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigAutoLock)
      _defaultUser = BLKDefaults.defaultUserName() ?? ""

    }
    .listStyle(.grouped)
    .navigationTitle("Settings")
    .sheet(isPresented: $_displayBlinkClassicToPlus) {
      BlinkClassicToPlusWindow(urlHandler: blink_openurl, dismissHandler: { _displayBlinkClassicToPlus = false })
    }

  }
}

fileprivate struct BlinkClassicToPlusWindow: View {
  let urlHandler: (URL) -> ()
  let dismissHandler: () -> ()

  @Environment(\.dynamicTypeSize) var dynamicTypeSize

  var body: some View {
    GeometryReader { proxy in
      let ctx = PageCtx(
        proxy: proxy,
        dynamicTypeSize: dynamicTypeSize
      )

      NewOfferingsView(classicOffering: true, ctx: ctx, purchaseCompletedHandler: dismissHandler, urlHandler: urlHandler, dismissHandler: dismissHandler)
        .frame(width: proxy.size.width, height: proxy.size.height)
    }
    .background(.black)
  }
}
