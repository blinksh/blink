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
import SwiftUI

import RevenueCat

extension Publisher {
  func tap(_ handler: @escaping () -> () ) -> AnyPublisher<Output, Failure> {
    self.handleEvents(receiveOutput: { _ in handler() })
      .receive(on: DispatchQueue.main)
      .eraseToAnyPublisher()
  }
}


enum SKStoreError: Error {
  case notFound
  case fetchError
  case requestError(Error)
}

@objc class SKStore: NSObject {
  private var _skReq: SKReceiptRefreshRequest? = nil
  private var _publisher: PassthroughSubject<URL, Error>? = nil
  
  func fetchReceiptURLPublisher() -> AnyPublisher<URL, Error> {
    
    let pub = PassthroughSubject<URL, Error>()
    _publisher = pub
    return pub.buffer(size: 1, prefetch: .byRequest, whenFull: .dropNewest)
      .handleEvents(
      receiveCancel: {
        self._skReq?.delegate = nil
        self._skReq?.cancel()
      },
      receiveRequest: { _ in
        guard let url = Bundle.main.appStoreReceiptURL
        else {
          return pub.send(completion: .failure(SKStoreError.notFound))
        }
        
        if FileManager.default.fileExists(atPath: url.path) {
          pub.send(url)
          pub.send(completion: .finished)
          return
        }
        
        let skReq = SKReceiptRefreshRequest(receiptProperties: nil)
        self._skReq = skReq
        skReq.delegate = self
        skReq.start()
      }).eraseToAnyPublisher()
  }
}

extension SKStore: SKRequestDelegate {
  func requestDidFinish(_ request: SKRequest) {
    guard let url = Bundle.main.appStoreReceiptURL,
          FileManager.default.fileExists(atPath: url.path)
    else {
      _publisher?.send(completion: .failure(SKStoreError.notFound))
      return
    }
    
    _publisher?.send(url)
    _publisher?.send(completion: .finished)
  }
  
  func request(_ request: SKRequest, didFailWithError error: Error) {
    _publisher?.send(completion: .failure(SKStoreError.requestError(error)))
  }
}
