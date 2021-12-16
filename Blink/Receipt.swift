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


import Combine
import CryptoKit
import Foundation
import StoreKit


fileprivate let endpointURL = URL(string: "https://us-central1-gold-stone-332203.cloudfunctions.net/receiptEntitlement")!


struct MigrationToken: Codable {
  let token: String
  let data:  String

  public static func requestTokenForMigration(receiptData: String, attachedTo originalUserId: String) -> AnyPublisher<Data, Error> {
    Just(["receiptData": receiptData,
          "originalUserId": originalUserId])
  // NOTE Leaving this for reference. This is now responsibility of other layers.
  //  SKStore()
  //    .fetchReceiptURLPublisher()
  //    .tryMap { receiptURL -> [String:String] in
  //      let d = try Data(contentsOf: receiptURL, options: .alwaysMapped)
  //      let receipt = d.base64EncodedString(options: [])
  //      return  ["receiptData": receipt,
  //               "originalUserId": originalUserId]
  //    }
      .encode(encoder: JSONEncoder())
      .map { data -> URLRequest in
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        return request
      }
      .flatMap {
        URLSession.shared.dataTaskPublisher(for: $0)
        .tryMap { element -> Data in
          guard let httpResponse = element.response as? HTTPURLResponse else {
            throw ReceiptMigrationError.RequestError
          }
          let statusCode = httpResponse.statusCode
          guard statusCode == 200 else {
            let errorMessage = try? JSONDecoder().decode(ErrorMessage.self, from: element.data)
            switch statusCode {
              case 409:
              throw ReceiptMigrationError.ReceiptExists
              case 400:
              throw ReceiptMigrationError.InvalidAppReceipt(error: errorMessage)
              default:
              throw ReceiptMigrationError.RequestError
            }
          }
          return element.data
        }
      }.eraseToAnyPublisher()
  }

  public func validateReceiptForMigration(attachedTo originalUserId: String) throws {
    let dataComponents = data.components(separatedBy: ":")
    let currentTimestamp = Int(Date().timeIntervalSince1970)

    // Check the user coming from signature and params match.
    // Check the timestamp is within a range, to prevent reuse.
    guard dataComponents.count == 3,
      dataComponents[1] == originalUserId,
      let receiptTimestamp = Int(dataComponents[2]),
      // 60s margin for timestamp. It is rare that it takes more than 15 secs.
      (currentTimestamp - receiptTimestamp) < 60 else {
        throw ReceiptMigrationError.InvalidMigrationReceipt
      }
    guard isSignatureVerified else {
      throw ReceiptMigrationError.InvalidMigrationReceiptSignature
    }
  }

  private let publicKeyStr = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEO5gruKzo5hnh8eiaakwZgliooXEWS+0180oEeF2m1jUtTlje6AL/ybNTkXdAtxz3DtBUEGI9VIVvtN5eNBYbpg=="
  //private let publicKeyStr = "MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEsuI2ZyUFD45NRAH4OEu4GvrOmdv4X4Ti49pbhbLY2fvQNEHI6fp/5Ndawwnp5uK2GIDk0e1E//uV3GEiPT8vOA=="
  private var publicKey: CryptoKit.P256.Signing.PublicKey {
    get {
      let pemKeyData = Data(base64Encoded: publicKeyStr)!

      return (pemKeyData.withUnsafeBytes { bytes in
        return try! CryptoKit.P256.Signing.PublicKey(derRepresentation: bytes)
      })
    }
  }

  private var isSignatureVerified: Bool {
    guard
      let data = data.data(using: .utf8),
      let signedRawRS = Data(base64Encoded: token),
      let signature = try? CryptoKit.P256.Signing
        .ECDSASignature(rawRepresentation: signedRawRS) else {
      return false
    }

    return publicKey.isValidSignature(signature, for: data as NSData)
  }
}

struct ErrorMessage: Codable, Equatable {
  let error: String
}

enum ReceiptMigrationError: Error, Equatable {
  // 409 - we may want to drop the ID in this scenario.
  case ReceiptExists
  // 40X
  case InvalidAppReceipt(error: ErrorMessage?)
  case InvalidMigrationReceipt
  case InvalidMigrationReceiptSignature
  // Everything else
  case RequestError
}

enum SKStoreError: Error {
  case notFound
  case fetchError
  case requestError(Error)
}

@objc class SKStore: NSObject {
  var done: ((URL?, Error?) -> Void)!
  var skReq: SKReceiptRefreshRequest? = nil

  func fetchReceiptURLPublisher() -> AnyPublisher<URL, Error> {
    return Future<URL, Error> { promise in
      self.fetchReceiptURL { (url, error) in
        if let url = url {
          promise(.success(url))
        } else {
          promise(.failure(error ?? SKStoreError.fetchError))
        }
      }
    }.eraseToAnyPublisher()
  }

  func fetchReceiptURL(_ done: @escaping (URL?, Error?) -> Void) {
    self.done = done

    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
      return done(nil, SKStoreError.notFound)
    }
    if !FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
      let skReq = SKReceiptRefreshRequest(receiptProperties: nil)
      skReq.delegate = self
      skReq.start()
      self.skReq = skReq
    } else {
      done(appStoreReceiptURL, nil)
    }

  }
}

extension SKStore: SKRequestDelegate {
  func requestDidFinish(_ request: SKRequest) {
    if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL,
       FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
      return done(appStoreReceiptURL, nil)
    } else {
      return done(nil, SKStoreError.notFound)
    }
  }
  func request(_ request: SKRequest, didFailWithError error: Error) {
    return done(nil, SKStoreError.requestError(error))
  }
}
