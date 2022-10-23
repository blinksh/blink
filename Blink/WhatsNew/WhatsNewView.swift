////////////////////////////////////////////////////////////////////////////////
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
import CachedAsyncImage


struct ScaleButtonStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.95 : 1)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}

struct WhatsNewView<ViewModel: RowsProvider>: View {
  @StateObject var rowsProvider: ViewModel
  @State var error: Error?
  var ipad = false
  
  @ViewBuilder
  var body: some View {
    if let _ = error {
      UnavailErrorView(retry: fetchData)
    } else if !rowsProvider.hasFetchedData {
      ProgressView().task {
        await fetchData()
      }
    } else {
      // Refs https://developer.apple.com/videos/play/wwdc2020/10031/
      // https://www.reddit.com/r/SwiftUI/comments/jseuwb/how_to_make_a_lazyvstack_with_dynamic_items_width/
      // NOTE We could use a StickyHeader for the versions
      // https://prafullkumar77.medium.com/swiftui-how-to-make-sticky-header-with-grid-stack-views-c3505cea6400
      GeometryReader {
        let size = $0.size
        let hPadding = max(15, (size.width - 820) * 0.5);
        ScrollView {
          VStack(alignment: .leading) {
            ForEach(rowsProvider.rows) { row in
              switch row {
              case .oneCol(let feature):
                BasicFeatureCard(feature: feature)
              case .twoCol(let left, let right):
                if size.width > 665 {
                  HStack(alignment: .top, spacing: 15) {
                    FeatureStack(features: left)
                    FeatureStack(features: right)
                  }
                } else {
                  FeatureStack(features: left)
                  FeatureStack(features: right)
                }
              case .versionInfo(let info):
                VersionSeparator(info: info)
              }
            }
          }
          .redacted(reason: rowsProvider.hasFetchedData ? [] : .placeholder )
          .padding(.init(top: 15, leading: hPadding, bottom: 15, trailing: hPadding))
        }
      }
      .overlay(alignment: .top) {
        if self.ipad {
          Rectangle()
            .frame(height: 24)
            .foregroundColor(Color(UIColor.systemBackground))
            .background(.regularMaterial)
            .opacity(0.3)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
      }
    }
  }
  
  private func fetchData() async {
    do {
      self.error = nil
      try await rowsProvider.fetchData()
    } catch (let err) {
      self.error = err
      print("Error!")
    }
  }
}

extension Feature {
  fileprivate func colorPalette(for scheme: ColorScheme) -> FeatureColorPalette {
    switch color {
    case .blue:
      return scheme == .light ? LightBlueColorPalette() : DarkBlueColorPalette()
    case .yellow:
      return scheme == .light ? LightYellowColorPalette() : DarkYellowColorPalette()
    case .orange:
      return scheme == .light ? LightOrangeColorPalette() : DarkOrangeColorPalette()
    case .purple:
      return scheme == .light ? LightPurpleColorPalette() : DarkPurpleColorPalette()
    }
  }
}

struct FeatureStack: View {
  let features: [Feature]
  var body: some View {
    
    VStack(alignment:.leading) {
      ForEach(features) { feature in
        BasicFeatureCard(feature: feature)
      }
    }
    
  }
}


struct BasicFeatureCard: View {
  @Environment(\.colorScheme) var colorScheme
  
  let feature: Feature
  
  var body: some View {
    let palette = feature.colorPalette(for: colorScheme)
    
    Button(action: {
      if let url = feature.link {
        UIApplication.shared.open(url)
      }
    }, label: {
      VStack(alignment: .leading, spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          Image(systemName: feature.symbol)
            .font(.system(size: 25))
          //.imageScale(.large)
            .foregroundColor(palette.iconForeground)
          //.frame(width: 70, height: 70)
            .padding()
            .background(
              RoundedRectangle(cornerRadius: 8, style: .continuous)
                .foregroundColor(palette.iconBackground)
            )
          //          VStack(alignment:.leading) {
          //            Text(feature.title).font(.system(.headline, design: .rounded))
          //            Text(feature.description).font(.system(.subheadline))
          VStack(alignment: .leading, spacing: 0.2) {
            Text(feature.title).font(.system(.headline))
            Text(feature.description).font(.system(.body))
          }.padding(.leading, 15)
        }
        HStack { Spacer() }.frame(height: 15)
        Spacer(minLength: 5)
        
        if let images = feature.images,
           // Atm just a single image
           let imageURL = images[0] {
          CachedAsyncImage(url: imageURL, urlCache: .imageCache) {
            $0.resizable().scaledToFit().cornerRadius(8)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(Color(UIColor.systemGray2), lineWidth: 1)
              )
          } placeholder: {
            palette.iconBackground
          }
          .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
        }
      }
      .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
      .background(
        RoundedRectangle(cornerRadius: 21, style: .continuous)
          .foregroundColor(palette.background)
          .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.13), radius: 45)
      )
    })
    .buttonStyle(ScaleButtonStyle())
    .padding(.bottom, 15)
    
  }
}

struct VersionSeparator: View {
  let info: VersionInfo
  
  var body: some View {
    HStack {
      Spacer()
      Button(action: {
        if let url = info.link {
          UIApplication.shared.open(url)
        }
      }) {
        Text("View all changes in \(info.number)")
        Image(systemName: "arrow.forward.circle")
          .imageScale(.medium)
        
      }
      .font(.callout)
      //.fontWeight(.bold)
      .foregroundColor(.blue)
      .buttonStyle(.borderless)
      
    }.padding(20)
  }
}

struct WhatsNewView_Previews: PreviewProvider {
  static var previews: some View {
    WhatsNewView(rowsProvider: RowsViewModelDemo())
    // ContentView(rowsProvider: RowsViewModel())
  }
}
