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
    List {
      Section() {
        ForEach(BuildRegion.all(), id: \.self) { value in
          HStack {
            value.full_title_label()
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
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Build Region")
  }
}

struct BasicMachineSection: View {
  let formattedPrice: String
  var body: some View {
    Section(
      header: Text("Build Machine"),
      footer: Text("Plan auto-renews for \(formattedPrice) until canceled.")
    ) {
      Label {
        Text("8 GiB of RAM")
      } icon: {
        Image(systemName: "memorychip")
          .foregroundColor(.green)
        
      }
      Label {
        Text("4 vCPUs")
      } icon: {
        Image(systemName: "cpu")
          .foregroundColor(.green)
      }
      Label {
        Text("5,000 GiB Transfer")
      } icon: {
        Image(systemName: "network")
          .foregroundColor(.green)
      }
      Label {
        Text("160 GiB Ephemeral SSD")
      } icon: {
        Image(systemName: "internaldrive")
          .foregroundColor(.green)
      }
      Label {
        Text("2 GiB Main Cloud Disk")
      } icon: {
        Image(systemName: "externaldrive.badge.icloud")
          .foregroundColor(.green)
      }
      Label {
        Text("50 Hours")
      } icon: {
        Image(systemName: "timer")
          .foregroundColor(.green)
      }
    }
  }
}

struct BuildView: View {
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  
  var body: some View {
    if _entitlements.build.active {
      BuildAccountView()
    } else {
      BuildPurchaseView()
    }
  }
}

struct BuildAccountView: View {
  
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
      Section(header: Text("Account")) {
        Label {
          Text(verbatim: "yury@build.sh")
        } icon: {
          Image(systemName: "envelope.badge")
            .symbolRenderingMode(.monochrome)
        }
        _model.buildRegion.full_title_label()
      }
      Section(header: Text("Usage")) {
        list().accentColor(.green)
      }
    }
    .alert(errorMessage: $_model.alertErrorMessage)
    .navigationTitle("Blink Build")
  }
}

struct BuildPurchaseView: View {
  
  @ObservedObject private var _model: PurchasesUserModel = .shared
  @ObservedObject private var _entitlements: EntitlementsManager = .shared
  
  
  var body: some View {
    List {
      BasicMachineSection(formattedPrice: _model.formattedBuildPriceWithPeriod() ?? "")
      if _entitlements.earlyAccessFeatures.active == true {
        Section() {
          Row(
            content: {
              _model.buildRegion.full_title_label()
            },
            details: {
              BuildRegionPickerView(currentValue: $_model.buildRegion)
            }
          )
          Label {
            TextField(
              "Your Email for Notifications", text: $_model.email
            )
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .submitLabel(.go)
            .onSubmit {
              Task {
                await _model.purchaseBuildBasic()
              }
            }
          } icon: {
            Image(systemName: "envelope.badge")
              .symbolRenderingMode(_model.emailIsValid ? .monochrome : .multicolor)
          }
        }
      } else {
        Section() {
          Label {
            Text("This is Early Access Blink+ Service")
          } icon: {
            Image(systemName: "plus")
              .foregroundColor(.green)
          }
          Row {
            HStack {
              Label {
                Text("Compare Plans")
              } icon: {
                Image(systemName: "bag.badge.questionmark")
                  .foregroundColor(.green)
              }
              Spacer()
              Text(_entitlements.currentPlanName())
                .foregroundColor(.secondary)
            }
          } details: {
            PlansView()
          }
        }
      }
      
      Section() {
        HStack {
          Button {
            _model.openPrivacyAndPolicy()
          } label: {
            Label("Learn More about Blink Build", systemImage: "questionmark")
          }
        }
      }
      
      if let _ = _model.plusProduct {
        
      }
      
      Section {
        HStack {
          if _model.restoreInProgress {
            ProgressView()
            Text("restoring purchases....").padding(.leading, 10)
          } else {
            Button {
              _model.restorePurchases()
            } label: {
              Label("Restore Purchases", systemImage: "bag")
            }
          }
        }
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
    .disabled(_model.purchaseInProgress || _model.restoreInProgress)
    .alert(errorMessage: $_model.alertErrorMessage)
    .navigationTitle("Blink Build")
    .toolbar {
      if _model.purchaseInProgress {
        ProgressView()
      } else {
        Button("Subscribe") {
          Task {
            await _model.purchaseBuildBasic()
          }
        }.disabled(!_model.emailIsValid || _model.restoreInProgress)
      }
    }
  }
}
