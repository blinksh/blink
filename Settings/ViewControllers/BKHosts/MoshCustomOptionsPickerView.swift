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

extension BKMoshPrediction: Hashable {
  var label: String {
    switch self {
    case BKMoshPredictionAdaptive: return "Adaptive"
    case BKMoshPredictionAlways: return "Always"
    case BKMoshPredictionNever: return "Never"
    case BKMoshPredictionExperimental: return "Experimental"
    case _: return ""
    }
  }
  
  var hint: String {
    switch self {
    case BKMoshPredictionAdaptive: return "Local echo for slower links [default]"
    case BKMoshPredictionAlways: return "Use local echo even on fast links"
    case BKMoshPredictionNever: return "Never use local echo"
    case BKMoshPredictionExperimental: return "Aggressively echo even when incorrect"
    case _: return ""
    }
  }

  static var all: [BKMoshPrediction] {
    [
      BKMoshPredictionAdaptive,
      BKMoshPredictionAlways,
      BKMoshPredictionNever,
      BKMoshPredictionExperimental
    ]
  }
}

extension BKMoshExperimentalIP: Hashable {
  var label: String {
    switch self {
    case BKMoshExperimentalIPNone: return "None"
    case BKMoshExperimentalIPLocal: return "Local"
    case BKMoshExperimentalIPRemote: return "Remote"
    case _: return ""
    }
  }
  
  var hint: String {
    switch self {
    case BKMoshExperimentalIPNone: return "No experimental IP resolution"
    case BKMoshExperimentalIPLocal: return "Resolve the IP locally"
    case BKMoshExperimentalIPRemote: return "Resolve the IP in the remote"
    case _: return ""
    }
  }

  static var all: [BKMoshExperimentalIP] {
    [
      BKMoshExperimentalIPNone,
      BKMoshExperimentalIPLocal,
      BKMoshExperimentalIPRemote,
    ]
  }
}

struct MoshCustomOptionsPickerView: View {
  @Binding var predictionValue: BKMoshPrediction
  @Binding var overwriteValue: Bool
  @Binding var experimentalIPValue: BKMoshExperimentalIP
  
  var body: some View {
    List {
      Section(footer: Text(predictionValue.hint)) {
        ForEach(BKMoshPrediction.all, id: \.self) { value in
          HStack {
            Text(value.label).tag(value)
            Spacer()
            Checkmark(checked: predictionValue == value)
          }
          .contentShape(Rectangle())
          .onTapGesture { predictionValue = value }
        }
      }
      Section(footer: Text("Prediction overwrites instead of inserting")) {
        HStack {
          Toggle("Overwrite", isOn: $overwriteValue)
        }
      }
      Section(footer: Text(experimentalIPValue.hint)) {
        ForEach(BKMoshExperimentalIP.all, id: \.self) { value in
          HStack {
            Text(value.label).tag(value)
            Spacer()
            Checkmark(checked: experimentalIPValue == value)
          }
          .contentShape(Rectangle())
          .onTapGesture { experimentalIPValue = value }
        }
      }
    }
    .listStyle(InsetGroupedListStyle())
    .navigationTitle("Mosh Options")
  }
}
