//
//  KeyConfigView.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct KeyConfigView: View {
  @ObservedObject var key: KeyConfig
  
  var body: some View {
    List {
      KeySection(key: key)
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle(key.fullName)
  }
  
}

struct KeyConfigView_Previews: PreviewProvider {
  static var previews: some View {
    KeyConfigView(key: KeyConfig.capsLock)
  }
}
