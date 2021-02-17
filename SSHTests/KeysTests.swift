//////////////////////////////////////////////////////////////////////////////////
//
// B L I N K
//
// Copyright (C) 2016-2021 Blink Mobile Shell Project
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

// TODO Test loading keys from blob or file
// TODO Test loading certs from blob or file
// TODO Test corner cases when a key is not properly trimmed or presented.

import XCTest
import CryptoKit

@testable import SSH

class KeysTests: XCTestCase {
  var bundle: Bundle? = nil
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    // TODO Create and store a key for later use.
    bundle = Bundle(for: type(of: self))
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testLoadKey() throws {
    let privPath = bundle?.path(forResource: "id_ecdsa", ofType: nil)
    var key = try? SSHKey(fromFile: privPath!)
    XCTAssertNotNil(key)
    
    let pubPath = bundle?.path(forResource: "id_ecdsa", ofType: "pub")
    key = try? SSHKey(fromPublicKeyFile: pubPath!)
    XCTAssertNotNil(key)
  }

  func testLoadFromBlob() throws {
    var bkey = try? SSHKey(fromBlob: keyNoNewLine.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromBlob: SSHKey.sanitize(key: keyNoNewLine).data(using: .utf8)!)
    XCTAssertNotNil(bkey)

    bkey = try? SSHKey(fromBlob: keyPrependedChars.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromBlob: SSHKey.sanitize(key: keyPrependedChars).data(using: .utf8)!)
    XCTAssertNotNil(bkey)
    
    bkey = try? SSHKey(fromBlob: keyIndented.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromBlob: SSHKey.sanitize(key: keyIndented).data(using: .utf8)!)
    XCTAssertNotNil(bkey)
  }

  func testCertificates() throws {
    var privPath = bundle?.path(forResource: "id_ecdsa", ofType: nil)
    let pubPath = bundle?.path(forResource: "user_key-cert", ofType: "pub")
    var key = try? SSHKey(fromFile: privPath!, withPublicCert: pubPath!)
    XCTAssertNil(key)
    
    privPath = bundle?.path(forResource: "user_key", ofType: nil)
    key = try SSHKey(fromFile: privPath!, withPublicCert: pubPath!)
    XCTAssertNotNil(key)
  }
  
  func testSignature() throws {
    continueAfterFailure = false
    let privPath = bundle?.path(forResource: "id_ecdsa", ofType: nil)
    let key = try SSHKey(fromFile: privPath!)

    // SHA256 hash
    let helloWorld = Data("Hello World".utf8)
    let helloWorldHash = SHA256.hash(data: helloWorld).data
    let sig = try key.sign(helloWorldHash)
    let isValid = try key.verify(signature: sig, of: helloWorldHash)

    XCTAssertTrue(isValid)
  }
}

fileprivate let keyNoNewLine = """
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS
  1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQTaVgu9iAzo1RGgJ+TVdp67x3n42ZAK
  zSbAK8knXLuc2FRR88wxJs8CuDXfKMLPu40IdMsudN5J7dMiz1waaVowAAAAwB3H0ukdx9
  LpAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNpWC72IDOjVEaAn
  5NV2nrvHefjZkArNJsArySdcu5zYVFHzzDEmzwK4Nd8ows+7jQh0yy503knt0yLPXBppWj
  AAAAAgQELBR6zdFqqzyaGnAwcY0yZZ+fmBh7qV1fPYAUuyH+4AAAAlY2FybG9zY2FiYW5l
  cm9AQ2FybG9zcy1NYWMtbWluaS5sb2NhbAECAw==
  -----END OPENSSH PRIVATE KEY-----
  """

fileprivate let keyIndented = """
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS  \
  1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQTaVgu9iAzo1RGgJ+TVdp67x3n42ZAK  \
  zSbAK8knXLuc2FRR88wxJs8CuDXfKMLPu40IdMsudN5J7dMiz1waaVowAAAAwB3H0ukdx9  \
  LpAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNpWC72IDOjVEaAn
  5NV2nrvHefjZkArNJsArySdcu5zYVFHzzDEmzwK4Nd8ows+7jQh0yy503knt0yLPXBppWj
  AAAAAgQELBR6zdFqqzyaGnAwcY0yZZ+fmBh7qV1fPYAUuyH+4AAAAlY2FybG9zY2FiYW5l
  cm9AQ2FybG9zcy1NYWMtbWluaS5sb2NhbAECAw==
  -----END OPENSSH PRIVATE KEY-----

 """

fileprivate let keyPrependedChars = """

  b
  -----BEGIN OPENSSH PRIVATE KEY-----
  b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAaAAAABNlY2RzYS
  1zaGEyLW5pc3RwMjU2AAAACG5pc3RwMjU2AAAAQQTaVgu9iAzo1RGgJ+TVdp67x3n42ZAK
  zSbAK8knXLuc2FRR88wxJs8CuDXfKMLPu40IdMsudN5J7dMiz1waaVowAAAAwB3H0ukdx9
  LpAAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBNpWC72IDOjVEaAn
  5NV2nrvHefjZkArNJsArySdcu5zYVFHzzDEmzwK4Nd8ows+7jQh0yy503knt0yLPXBppWj
  AAAAAgQELBR6zdFqqzyaGnAwcY0yZZ+fmBh7qV1fPYAUuyH+4AAAAlY2FybG9zY2FiYW5l
  cm9AQ2FybG9zcy1NYWMtbWluaS5sb2NhbAECAw==
  -----END OPENSSH PRIVATE KEY-----  
  """

fileprivate let publicKey = """
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDPBHd16dB89jLVsLH0DhM0FzTsj0tZtyT95XPXQiEEA0nxqC0rKy8gMUAmbqQlh3QZizOEUeUZVwGMBFbjw9rZfjmY9Vdb3CvDhcK0t7ooZUTm6W+yrTKkbmSkWDbbQOemgNyy8biSc18168I/QCg9Ul8pAdLRQnCJd3mlUHX67yVoBAD2Jx/GGhPhmRsk1dDRhJjhyxyIAvjgwOhR+mbNp20MqTTz4MLScJvt9n1Hg5me24HJcYQrIq/2tbP37vKY4bjDkxIZAunkQDusx66/ZZ3tOrNIskKp1z9nxyqUTPqv/dOTmT5cTL/7dN/Sy+eCDK44CGWJT4T2uNGpwnmODkB0/2dX1ZcYScXLCj1kVVTfng1/yet9Lybh9uZ7OWWRttolEl+ShpFLO8DF8zZG5fI2qa6YLIWy4wqC7aMlEc6D+cxb04vBRXbgVvNj6xiSJF04cVd3NhGWGAoeQrOANieXaAG9Z9+K+i5rIDnYRzQ8YRIlLPUIF2dc6CGylCN8lcj8oWw6qAx1D+ficJUc0Jpn1R7v1SzowJfs8DpiUDN+isDsSyeS2y6xNfb1aqjH0gJgCngzBFHTXyJ8h223qqgsepUzckS5GQ5e99eoc6V3qBdJIdVo28FMo4UjfElrIVounPvnJQc1H6DsXVOtFefVz9uBu+yII52wHPWDoQ== javierdemartin@macbook-pro.lan
"""
