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

import Foundation
import SwiftUI
import BlinkSnippets

public struct SnippetsListView: View {
  @ObservedObject var model: SearchModel
  @Environment(\.colorScheme) var colorScheme
 
  @ViewBuilder
  func snippetView(for snippet: Snippet, selected: Bool) -> some View {
    let fuzzyMode = model.searchResults.query.isEmpty
    let index = model.fuzzyResults.matchesMap[snippet]!
    let content = model.searchResults.contentMap[snippet] ?? model.fuzzyResults.contentMap[snippet]!
    SnippetView(
      fuzzyMode: fuzzyMode, index: index, content: content, selected: selected, snippet: snippet, model: model
    ).id(snippet.id)
  }
  
  @ViewBuilder
  public var body: some View {
      VStack {
        let displayResults = model.displayResults
        if displayResults.isEmpty {
          
        } else {
          let selectedIndex = self.model.selectedSnippetIdx!
          ViewThatFits(in: .vertical) {
            VStack() {
              ForEach(displayResults) { snippet in
                let selected = displayResults[selectedIndex] == snippet
                snippetView(for: snippet, selected: selected)
                  .scaleEffect(CGSize(width: 1.0, height: -1.0), anchor: .center)
              }
            }
            .scaleEffect(CGSize(width: 1.0, height: -1.0), anchor: .center)
            .padding([.top], 10)
            ScrollViewReader { value in
              ScrollView {
                ForEach(displayResults) { snippet in
                  let selected = displayResults[selectedIndex] == snippet
                  snippetView(for: snippet, selected: selected)
                    .rotationEffect(Angle(degrees: 180))
                    .scaleEffect(CGSize(width: -1.0, height: 1), anchor: .center)
                }
              }
              .onChange(of: self.model.selectedSnippetIdx) { newValue in
                if let snippet = self.model.currentSelection {
                  withAnimation {
                    value.scrollTo(snippet.id, anchor: .bottom)
                  }
                }
              }
              // Rotate and mirror to put scrollbar in correct place
              .rotationEffect(Angle(degrees: 180))
              .scaleEffect(CGSize(width: -1.0, height: 1), anchor: .center)
            }
          }
        }
        SearchView(model: model)
          .frame(maxHeight:44)
          .padding([.top, .bottom], 3)
          .onAppear {
            model.focusOnInput()
          }
      }
      .padding([.leading, .trailing], 8)
      .onChange(of: self.colorScheme) { newValue in
        if newValue == .dark {
          self.model.style = .dark(.google)
        } else  {
          self.model.style = .light(.google)
        }
      }
  }
}
