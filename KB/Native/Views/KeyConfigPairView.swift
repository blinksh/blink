//
//  KeySettings.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/22/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI
 
struct KeyConfigPairView: View {
  @ObservedObject var pair: KeyConfigPair
  
  var body: some View {
    List {
      Toggle("Same for both sides", isOn: $pair.bothAsLeft)
      if pair.bothAsLeft {
        KeySection(title: "Left and Right", key: pair.left)
      } else {
        KeySection(title: "Left", key: pair.left)
        KeySection(title: "Right", key: pair.right)
      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle(pair.fullName)
  }
}

struct KeyConfigPairView_Previews: PreviewProvider {
  static var previews: some View {
    KeyConfigPairView(pair: KeyConfigPair.shift)
  }
}
