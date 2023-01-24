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


import Foundation
import RevenueCat

enum BuildAPIError: Error, LocalizedError {
  case invalidResponse
  case unexpectedResponseStatus(Int)
  case noReceipt
  
  var errorDescription: String? {
    switch self {
    case .invalidResponse: return "Invalid Response from server."
    case .unexpectedResponseStatus(let code): return "Unexpected code \(code)."
    case .noReceipt: return "No receipt"
    }
  }
}


enum BuildAPI {
  
  static func requestService(_ request: URLRequest) async -> (Int32, Data) {
    var signal: TokioSignals!
    
    return await withTaskCancellationHandler(operation: {
      await withCheckedContinuation { (c: CheckedContinuation<(Int32, Data), Never>) in
        let ctx = UnsafeMutablePointer<CheckedContinuation<(Int32, Data), Never>>.allocate(capacity: 1)
        ctx.initialize(to: c)
        
        signal = TokioSignals.requestService(request, auth: true, ctx: ctx) { ctx, w in
          let ref = UnsafeMutablePointer<CheckedContinuation<(Int32, Data), Never>>(OpaquePointer(ctx))
          let c = ref.move()
          ref.deallocate()
          let data = Data(bytes: w.pointee.body, count: Int(w.pointee.body_len));
          c.resume(returning: (w.pointee.code, data))
        }
      }
    }, onCancel: { [signal] in
      signal?.signalCtrlC()
    })
    
  }
  
  public static func accountInfo() async {
    
    let (code, data) = try await requestService(.init(getJson: _path("/account")))
    let s = String(data: data, encoding: .utf8)!;
    if code == 200 {
      print(s)
    }
  }
  
  private static func _baseURL() -> String {
    let options = PublishingOptions.current;
    if options.intersection([PublishingOptions.testFlight, PublishingOptions.developer]).isEmpty {
      return "https://api.blink.build"
    } else {
      return "https://raw.api.blink.build"
    }
  }
  
  private static func _path(_ path: String) -> URL {
    URL(string: "\(_baseURL())\(path)")!
  }
  
  private static func _post(_ url: URL, params: [String: Any]) async throws -> (Int, Data, [String: Any]) {
    
    let (data, response) = try await URLSession.shared.data(for: .init(postJson: url, params: params))
    
    guard let response = response as? HTTPURLResponse else {
      throw BuildAPIError.invalidResponse
    }
    
    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      let originalResponse = String(data: data, encoding: .utf8) ?? "Not a string"
      return (response.statusCode, data, ["originalResponse": originalResponse])
    }
    
    return (response.statusCode, data, obj)
  }
  
  private static func _get(_ url: URL, params: [String: Any] = [:]) async throws -> (Int, Data, [String: Any]) {
    
    let (data, response) = try await URLSession.shared.data(for: .init(getJson: url, params: params))
    
    guard let response = response as? HTTPURLResponse else {
      throw BuildAPIError.invalidResponse
    }
    
    guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      let originalResponse = String(data: data, encoding: .utf8) ?? "Not a string"
      return (response.statusCode, data, ["originalResponse": originalResponse])
    }
    
    return (response.statusCode, data, obj)
  }
  
  static func signup(email: String, region: BuildRegion) async throws {
    guard let receiptB64 = Bundle.main.receiptB64() else {
      throw BuildAPIError.noReceipt
    }
    
    let (code, data, _) = try await _post(
      _path("/application/signup"),
      params: [
        "email": email,
        "region": region.rawValue,
        "rev_cat_user_id": Purchases.shared.appUserID,
        "receipt_b64": receiptB64
      ]
    )

    // 409 account exists
    // 200 ok
    
    if code == 200 {
      try await loginWithToken(token: data)
    } else if code == 409 {
      try await self.signin()
    } else {
      throw BuildAPIError.unexpectedResponseStatus(code)
    }
  }
  
  static func signin() async throws  {
    guard let receiptB64 = Bundle.main.receiptB64() else {
      throw BuildAPIError.noReceipt
    }
    
    let (code, data, _) = try await _post(
      _path("/application/signin"), params: [
        "receipt_b64": receiptB64
      ]
    )
    // 409 account exists
    // 200 OK?
    
    if code == 200 {
      try await loginWithToken(token: data)
    } else {
      throw BuildAPIError.unexpectedResponseStatus(code)
    }
  }
  
  static func trySignin() async throws {
    guard let receiptB64 = Bundle.main.receiptB64() else {
      throw BuildAPIError.noReceipt
    }
    
    let (code, data, _) = try await _post(
      _path("/application/signin"), params: [
        "receipt_b64": receiptB64
      ]
    )
    
    if code == 200 {
        try await loginWithToken(token: data)
    }
  }
  
  static func loginWithToken(token: Data) async throws {
    try token.write(to: BlinkPaths.blinkBuildTokenURL()!)
    if let buildId = TokioSignals.getBuildId() {
      let _ = try await Purchases.shared.logIn(buildId)
    }
  }
}


extension URLRequest {
  init(postJson url: URL, params: [String: Any]) throws {
    self.init(url: url)
    self.httpMethod = "POST"
    self.httpBody = try JSONSerialization.data(withJSONObject: params)
    self.addValue("application/json", forHTTPHeaderField: "Content-Type")
  }
  
  init(getJson url: URL, params: [String: Any] = [:]) {
    
    // TODO: handle params
    self.init(url: url)
    self.httpMethod = "GET"
    self.addValue("application/json", forHTTPHeaderField: "Content-Type")
  }
}
