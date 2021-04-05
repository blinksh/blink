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

class SSHKeysTests: XCTestCase {
  var bundle: Bundle! = nil
  
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.
    // TODO Create and store a key for later use.
    bundle = Bundle(for: type(of: self))
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  func testLoadKey() throws {
    let privPath = bundle.path(forResource: "id_ecdsa", ofType: nil)!
    var key = try? SSHKey(fromFile: privPath)
    XCTAssertNotNil(key)
    
    let pubPath = bundle.path(forResource: "id_ecdsa", ofType: "pub")!
    key = try? SSHKey(fromPublicKeyFile: pubPath)
    XCTAssertNotNil(key)
  }

  func testLoadFromBlob() throws {
    var bkey = try? SSHKey(fromFileBlob: keyNoNewLine.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromFileBlob: SSHKey.sanitize(key: keyNoNewLine).data(using: .utf8)!)
    XCTAssertNotNil(bkey)

    bkey = try? SSHKey(fromFileBlob: keyPrependedChars.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromFileBlob: SSHKey.sanitize(key: keyPrependedChars).data(using: .utf8)!)
    XCTAssertNotNil(bkey)
    
    bkey = try? SSHKey(fromFileBlob: keyIndented.data(using: .utf8)!)
    XCTAssertNil(bkey)
    bkey = try? SSHKey(fromFileBlob: SSHKey.sanitize(key: keyIndented).data(using: .utf8)!)
    XCTAssertNotNil(bkey)
    
    bkey = try? SSHKey(fromFileBlob: "bad key".data(using: .utf8)!)
    XCTAssertNil(bkey)
  }
  
  func testLoadFromPathWithPassphrase() throws {
    let keyPath = bundle.path(forResource: "id_ed25519-passphrase", ofType: nil)!
    XCTAssertNotNil(keyPath)
    
    let key = try SSHKey(fromFile: keyPath, passphrase: "passphrase")
    XCTAssertEqual(key.comment, "comment")
    XCTAssertEqual(key.sshKeyType, SSHKeyType.ed25519)
    
    do {
      _ = try SSHKey(fromFile: keyPath, passphrase: "wrong passphrase")
      XCTFail("Expected SSHKeyError.wrongPassphrase")
    } catch SSHKeyError.wrongPassphrase {
      
    } catch {
      XCTFail("Wrong error")
    }
  }

  func testCertificates() throws {
    var privPath = bundle.path(forResource: "id_ecdsa", ofType: nil)!
    let pubPath = bundle.path(forResource: "user_key-cert", ofType: "pub")!
    
    var key = try? SSHKey(fromFile: privPath, withPublicFileCert: pubPath)
    XCTAssertNil(key)
    
    privPath = bundle.path(forResource: "user_key", ofType: nil)!
    key = try? SSHKey(fromFile: privPath, withPublicFileCert: pubPath)
    XCTAssertNotNil(key)
  }
  
  func testCertificatesFromBlob() throws {
    var key = try? SSHKey(fromFileBlob: privkeyCertificate, withPublicFileCertBlob: publicKey.data(using: .utf8))
    XCTAssertNil(key)
    
    key = try SSHKey(fromFileBlob: privkeyCertificate, withPublicFileCertBlob: pubkeyCertificate)
    XCTAssertNotNil(key)
  }
  
  func testSignature() throws {
    continueAfterFailure = false
    let privPath = bundle.path(forResource: "id_ecdsa", ofType: nil)!
    let key = try SSHKey(fromFile: privPath)

    // SHA256 hash
    let helloWorld = Data("Hello World".utf8)
    let helloWorldHash = SHA256.hash(data: helloWorld).data
    let sig = try key.sign(helloWorldHash)
    let isValid = try key.verify(signature: sig, of: helloWorldHash)

    XCTAssertTrue(isValid)
  }
  
  func testAuthorizedKeyFormat() throws {
    let privPath = bundle.path(forResource: "id_ecdsa", ofType: nil)!
    let key = try SSHKey(fromFile: privPath)
    
    let pubAuthKey = try key.authorizedKey(withComment: key.comment ?? "")
    guard let pubPath = bundle.path(forResource: "id_ecdsa.pub", ofType: nil) else {
      XCTFail("Could not build bundle path")
      return
    }
    let readAuthKey = try String(contentsOfFile: pubPath).replacingOccurrences(of: "\n", with: "")
    
    XCTAssertTrue(pubAuthKey == readAuthKey)
    
    let components = pubAuthKey.components(separatedBy: " ")
    XCTAssertTrue(components.count == 3)

    guard let blob = Data(base64Encoded: components[1]) else {
      XCTFail("Could not decode key blob")
      return
    }
    
    // The key should be able to go back to OpenSSH
    let pubkey = try SSHKey(fromPublicBlob: blob)
    XCTAssertNotNil(pubkey)
  }
  
  func testCertAuthorizedKeyFormat() throws {
    let privPath = bundle.path(forResource: "user_key", ofType: nil)!
    let pubPath = bundle.path(forResource: "user_key-cert", ofType: "pub")!

    let key = try SSHKey(fromFile: privPath, withPublicFileCert: pubPath)
    let pubAuthKey = try key.authorizedKey(withComment: key.comment ?? "")
    let readAuthKey = try String(contentsOfFile: pubPath).replacingOccurrences(of: "\n", with: "")
    
    XCTAssertTrue(pubAuthKey == readAuthKey)
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

fileprivate let privkeyCertificate = """
-----BEGIN OPENSSH PRIVATE KEY-----
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
QFBg==
-----END OPENSSH PRIVATE KEY-----

""".data(using: .utf8)!

let pubkeyCertificate = """
ssh-rsa-cert-v01@openssh.com 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 carloscabanero@Carloss-Mac-mini.local
""".data(using: .utf8)!
