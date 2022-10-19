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


struct WhatsNewView<ViewModel: RowsProvider>: View {
    @StateObject var rowsProvider: ViewModel
    @State var error: Error?
    
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
            GeometryReader { metrics in
                ScrollView {
                    VStack {
                        ForEach(rowsProvider.rows) { row in
                            switch row {
                            case .oneCol(let feature):
                                BasicFeatureCard(feature: feature).frame(maxWidth: .infinity)
                            case .twoCol(let left, let right):
                                LazyVGrid(columns: [
                                    GridItem(
                                        .adaptive(minimum: max(metrics.size.width * 0.47, 300))
                                    )]) {
                                        FeatureStack(features: left)
                                        FeatureStack(features: right)
                                    }.frame(maxWidth: .infinity)
                            case .versionInfo(let info):
                                VersionSeparator(info: info)
                            }
                        }
                    }
                    .padding()
                    .redacted(reason: rowsProvider.hasFetchedData ? [] : .placeholder )
                }
//            }.refreshable {
//              await fetchData()
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
    VStack(alignment:.leading, spacing: 15) {
      ForEach(features) { feature in
        BasicFeatureCard(feature: feature)
      }
    }
  }
}

protocol FeatureColorPalette {
    var background: Color { get }
    var iconBackground: Color { get }
    var iconForeground: Color { get }
}

struct LightBlueColorPalette: FeatureColorPalette {
    var background: Color { Color(red: 0.99, green: 1.0, blue: 1.0) }
    var iconBackground: Color { Color(red: 0.87, green: 0.93, blue: 1.0) }
    var iconForeground: Color { Color(red: 0.09, green: 0.47, blue: 0.95) }
}

struct LightOrangeColorPalette: FeatureColorPalette {
    var background: Color { Color(red: 1, green: 0.982, blue: 0.979) }
    var iconBackground: Color { Color(red: 1, green: 0.88, blue: 0.858) }
    var iconForeground: Color { Color(red: 1.00, green: 0.27, blue: 0.13) }
}

struct LightYellowColorPalette: FeatureColorPalette {
    var background: Color { Color(red: 1, green: 0.993, blue: 0.975) }
    var iconBackground: Color { Color(red: 1, green: 0.929, blue: 0.746)}
    var iconForeground: Color { Color(red: 1.00, green: 0.72, blue: 0.00) }
}

struct LightPurpleColorPalette: FeatureColorPalette {
    var background: Color { Color(red: 0.993, green: 0.983, blue: 1) }
    var iconBackground: Color { Color(red: 0.954, green: 0.896, blue: 1)}
    var iconForeground: Color { Color(red: 0.62, green: 0.13, blue: 1.00) }
}

class DarkColorPalette: FeatureColorPalette {
    var background: Color { Color(red: 0.11, green: 0.122, blue: 0.137) }
    var iconBackground: Color { Color(red: 0.022, green: 0.033, blue: 0.042) }
    var iconForeground: Color { .white }
}

class DarkBlueColorPalette: DarkColorPalette {
    override var iconForeground: Color { LightBlueColorPalette().iconForeground }
}

class DarkOrangeColorPalette: DarkColorPalette {
    override var iconForeground: Color { LightOrangeColorPalette().iconForeground }
}

class DarkYellowColorPalette: DarkColorPalette {
    override var iconForeground: Color { LightYellowColorPalette().iconForeground }
}

class DarkPurpleColorPalette: DarkColorPalette {
    override var iconForeground: Color { LightPurpleColorPalette().iconForeground }
}

struct BasicFeatureCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    let feature: Feature
    var body: some View {
        let palette = feature.colorPalette(for: colorScheme)
        
        VStack(spacing: 0) {
            HStack {
                VStack {
                    Image(systemName: feature.symbol)
                        .imageScale(.large)
                        .foregroundColor(palette.iconForeground)
                        .padding()

                        .background(
                          RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .foregroundColor(palette.iconBackground)
                          )
                    Spacer()
                }
                VStack(alignment:.leading) {
                    Text(feature.title).font(.system(.headline, design: .rounded))
                    Text(feature.description).font(.system(.subheadline))
                    Spacer()
                }
                Spacer()
            }.frame(alignment: .leading)

            if let imageURL = feature.image {
                AsyncImage(url: imageURL) {
                    $0.resizable()
                        .scaledToFill()
                } placeholder: {
                    palette.iconBackground
                }
            }
        }
        .onTapGesture {
            if let url = feature.link {
                UIApplication.shared.open(url)
            }
        }
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
        .background(
          RoundedRectangle(cornerRadius: 15, style: .continuous)
            .foregroundColor(palette.background)
            .shadow(color: Color(red: 0, green: 0, blue: 0, opacity: 0.13), radius: 45)
        )
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
