//
//  Chevron.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct Chevron: View {
  var body: some View {
    Image(systemName:"chevron.right")
      .foregroundColor(Color(UIColor.systemGray5))
      .font(Font.subheadline.weight(Font.Weight.semibold))
  }
}

struct Chevron_Previews: PreviewProvider {
  static var previews: some View {
    Chevron()
  }
}
