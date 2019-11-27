//
//  KeySection.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct KeySection: View {
  var title: String = ""
  @ObservedObject var key: KeyConfig
  
  var body: some View {
    Section(header: Text(title)) {
      DefaultRow(title: "Down", description: key.down.description) {
        KeyActionPicker(action: self.$key.down).navigationBarTitle("Down Action")
      }
      DefaultRow(title: "Modifier", description: key.mod.description) {
        KeyModifierPicker(modifier: self.$key.mod).navigationBarTitle("Modifier")
      }
      DefaultRow(title: "Up", description: key.up.description) {
        KeyActionPicker(action: self.$key.up).navigationBarTitle("Up Action")
      }
      if key.code.hasAccents {
        Toggle(isOn: self.$key.skipAccents, label: { Text("Skip Accents") })
      }
    }
  }
}


struct KeySection_Previews: PreviewProvider {
  static var previews: some View {
    KeySection(title: "Test", key: KeyConfig.capsLock)
  }
}
