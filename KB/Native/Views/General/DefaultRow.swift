//
//  DefaultRow.swift
//  SwiftKB
//
//  Created by Yury Korolev on 11/25/19.
//  Copyright © 2019 AnjLab. All rights reserved.
//

import SwiftUI

struct DefaultRow<Details: View>: View {
  @Binding var title: String
  @Binding var description: String?
  var details: () ->  Details
  
  init(title: String, description: String? = nil, details: @escaping () -> Details) {
    _title = .constant(title)
    _description = .constant(description)
    self.details = details
  }
  
  init(title: Binding<String>, description: Binding<String?> = .constant(nil), details: @escaping () -> Details) {
    _title = title
    _description = description
    self.details = details
  }
  
  var body: some View {
    Row(content: {
      HStack {
        Text(self.title).foregroundColor(.primary)
        Spacer()
        Text(self.description ?? "").foregroundColor(.secondary)
      }
    }, details: self.details)
  }
}


struct DefaultRow_Previews: PreviewProvider {
  static var previews: some View {
    DefaultRow(title: .constant("Title"), description: .constant("Description")) {
      EmptyView()
    }
  }
}
