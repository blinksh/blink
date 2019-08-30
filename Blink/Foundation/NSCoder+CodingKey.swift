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
import UIKit

extension NSCoder {
  
  func encode(_ value: Any?, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode<T>(for key: CodingKey) -> T? where T : NSObject, T : NSCoding {
    decodeObject(of: T.self, forKey: key.stringValue) as T?
  }
  
  func decode<T>(of: [AnyClass], for key: CodingKey) -> T? {
    decodeObject(of: of, forKey: key.stringValue) as? T
  }
  
  // MARK: - Data
  
  func encode(_ value: Data?, for key: CodingKey) {
    encode(value as NSData?, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> Data? {
    decodeObject(of: NSData.self, forKey: key.stringValue) as Data?
  }
  
  // MARK: - String
  
  func encode(_ value: String?, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> String? {
    decodeObject(of: NSString.self, forKey: key.stringValue) as String?
  }
  
  // MARK: - Bool
  
  func encode(_ value: Bool, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> Bool {
    decodeBool(forKey: key.stringValue)
  }
  
  // MARK: - Int
  
  func encode(_ value: Int, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> Int {
    decodeInteger(forKey: key.stringValue)
  }
  
  // MARK: - UInt
  
  func encode(_ value: UInt, for key: CodingKey) {
    encode(Int(value), forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> UInt {
    UInt(decodeInteger(forKey: key.stringValue))
  }
  
  // MARK: - CGRect
  
  func encode(_ value: CGRect, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> CGRect {
    decodeCGRect(forKey: key.stringValue)
  }
  
  // MARK: - CGSize
  
  func encode(_ value: CGSize, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> CGSize {
    decodeCGSize(forKey: key.stringValue)
  }
  
  // MARK: - CGPoint
  
  func encode(_ value: CGPoint, for key: CodingKey) {
    encode(value, forKey: key.stringValue)
  }
  
  func decode(for key: CodingKey) -> CGPoint {
    decodeCGPoint(forKey: key.stringValue)
  }
  
}

