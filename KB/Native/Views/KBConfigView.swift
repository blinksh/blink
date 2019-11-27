//
//  KBSettings.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/22/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

private func _row(_ key: KeyConfig) -> some View {
  DefaultRow(title: key.fullName, description: key.description) {
    KeyConfigView(key: key)
  }
}

private func _pairRow(_ pair: KeyConfigPair) -> some View {
  DefaultRow(title: pair.fullName, description: pair.description) {
    KeyConfigPairView(pair: pair)
  }
}

struct KBConfigView: View {
  @ObservedObject var config: KBConfig
  
  var body: some View {
    List() {
      Section(header: Text("Terminal")) {
        _row(config.capsLock)
        _pairRow(config.shift)
        _pairRow(config.control)
        _pairRow(config.option)
        _pairRow(config.command)
      }
      Section(header: Text("Blink")) {
        Text("Shortcuts")
      }
    }
    .listStyle(GroupedListStyle())
    .navigationBarTitle("Keyboard")
  }
}

struct KBSettings_Previews: PreviewProvider {
  static var previews: some View {
    KBConfigView(config: KBConfig())
  }
}
