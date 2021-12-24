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
  @State private var _xCallbackUrlOn = BKDefaults.isXCallBackURLEnabled()
  @State private var _defaultUser = BKDefaults.defaultUserName() ?? ""
  
  var body: some View {
    List {
      Section("Subscription") {
        NavigationLink(destination: {
          EmptyView()
        }, label: {
          Label("Subscription", systemImage: "bag")
          Spacer()
          Text("Free Plan").foregroundColor(.secondary)
        })
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
        RowWithStoryBoardId(content: {
          HStack {
            Label("Default User", systemImage: "person")
            Spacer()
            Text(_defaultUser).foregroundColor(.secondary)
          }
        }, storyBoardId: "BKDefaultUserViewController")
      }
      
      Section("Terminal") {
        RowWithStoryBoardId(content: {
          Label("Appearance", systemImage: "paintpalette")
        }, storyBoardId: "BKAppearanceViewController")
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
//
      }
      
      Section("Configuration") {
        RowWithStoryBoardId(content: {
          HStack {
            Label("iCloud Sync", systemImage: "icloud")
            Spacer()
            Text(_iCloudSyncOn ? "On" : "Off").foregroundColor(.secondary)
          }
        }, storyBoardId: "BKiCloudConfigurationViewController")
        
        RowWithStoryBoardId(content: {
          HStack {
            if _biometryType == .faceID {
              Label("Auto Lock", systemImage: "faceid")
            } else {
              Label("Auto Lock", systemImage: "touchid")
            }
            Spacer()
            Text(_autoLockOn ? "On" : "Off").foregroundColor(.secondary)
          }
        }, storyBoardId: "BKSecurityConfigurationViewController")
        RowWithStoryBoardId(content: {
          HStack {
            Label("X Callback Url", systemImage: "link")
            Spacer()
            Text(_xCallbackUrlOn ? "On" : "Off").foregroundColor(.secondary)
          }
        }, storyBoardId: "BKXCallBackUrlConfigurationViewController")
      }
      
      Section("Get in touch") {
        RowWithStoryBoardId(content: {
          Label("Feedback", systemImage: "bubble.left")
        }, storyBoardId: "BKFeedbackViewController")
        
        RowWithStoryBoardId(content: {
          Label("Support", systemImage: "book")
        }, storyBoardId: "BKSupportViewController")
      }
      
      Section {
        RowWithStoryBoardId(content: {
          HStack {
            Label("About", systemImage: "questionmark.circle")
            Spacer()
            Text(_blinkVersion).foregroundColor(.secondary)
          }
        }, storyBoardId: "BKAboutViewController")
      }
    }
    .onAppear {
      _iCloudSyncOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigiCloud)
      _autoLockOn = BKUserConfigurationManager.userSettingsValue(forKey: BKUserConfigAutoLock)
      _xCallbackUrlOn = BKDefaults.isXCallBackURLEnabled()
      _defaultUser = BKDefaults.defaultUserName() ?? ""
    }
    .listStyle(.grouped)
    .navigationTitle("Settings")
    
  }
}
