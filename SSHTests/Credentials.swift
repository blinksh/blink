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

import Foundation

struct Credentials {
  let user: String
  let password: String
  let host: String
  
  static let regularUser: String = "regular"
  static let regularUserPassword: String = "regular"
  
  static let port: String = "2222"
  static let dropBearPort: String = "2223"
  static let host: String = "localhost"
  static let incorrectIpHost: String = "256.8.4.2"
    
  /// This one assumes another nonexistent machine on the same network, so it cannot be resolved.
  static let timeoutHost = Credentials(user: "asdf", password: "zxcv", host: "192.168.1.155")
  
  /// Incorrect credentials for a server to test failure
  static let wrongPassword = Credentials(user: Self.regularUser, password: "1234567890", host: Self.host)
  
  static let wrongHost = Credentials(user: Self.regularUser, password: "1234567890", host: "asdf")
  
  static let interactive = Credentials(
    user: Self.regularUser,
    password: Self.regularUserPassword,
    host: Self.host
  )
  
  static let none = Credentials(user: "no-password", password: "", host: Self.host)
  
  static let password = Credentials(
    user: Self.regularUser,
    password: Self.regularUserPassword,
    host: Self.host
  )
  
  static let partialAuthentication = Credentials(
    user: "partial",
    password: "partial",
    host: Self.host
  )
  
  static let publicKeyAuthentication = Credentials(
    user: Self.regularUser,
    password: "",
    host: Self.host
  )
  
  static let wrongPrivateKey: String = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    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
    -----END OPENSSH PRIVATE KEY-----
    """
  
  /**
   This should be a private key that's not copied to the server hence the authentication should fail if used.
   */
  static let notCopiedPrivateKey: String = """
    -----BEGIN OPENSSH PRIVATE KEY-----
    b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAACFwAAAAdzc2gtcn
    NhAAAAAwEAAQAAAgEAs8R5HjuE2nNbTx6qon0uA86o1Yy/2CYRT2Ws1Jr0p1zXudYWHPzW
    94LSdtuVJ2F7unMMyQ27QX7H8Hji5/U3mY+nM1rSGrAFquUJBDM/WdgcVA3jWUwEiexjOW
    GbbO4VnuW4TXI3ubYW4KUBU0guBtZlfRGXblmSkjzyEs7SCL0ZntbCfDvYFF/kK8aSi+l8
    brMYUeQlIO0hnfCy7AlvTLr/4B+1c3xGAxfrKxfasvqe0omh7j7SCGelSq3U37IOtSJ8xw
    UCaaWguCJzay4AV3ZkwpGeU1AHBNZNpNtVxcPAXMmRTb1QmjYyL8Ctu/lIX8LqByfATdKp
    d6tCZYTpTw5V1I64BR1ur+rpXu0T3AbhazKq0K4dwO5VBGOwryu1qgk42u9Bttg30hphqs
    bIwHLtfGxCz6dF1RGw9b2z+ckqckNzxAVRmdQ6LlfKI83tgMLCg9rZnPZt9v0pwUdaq6g8
    UJdYQOIOAZ2Az2Icn3BrG6EgsvAkCDTcpw/mlwpsrUyINBlwlEJuxFuXpcP3eOuxSJSNlE
    zEij2lFgr9vA6wVxrZe5wPs5aXv+OUvN4Jl4rRsEByQc3sLCl2CFHAoauBTCf7c713k9RF
    brRtIkEfPWCmh85cQ5D6S98KysNNB7XedGgi359iclDsJpH7soV+c7DuLZtYubUr6Ff4yy
    cAAAdYTO469kzuOvYAAAAHc3NoLXJzYQAAAgEAs8R5HjuE2nNbTx6qon0uA86o1Yy/2CYR
    T2Ws1Jr0p1zXudYWHPzW94LSdtuVJ2F7unMMyQ27QX7H8Hji5/U3mY+nM1rSGrAFquUJBD
    M/WdgcVA3jWUwEiexjOWGbbO4VnuW4TXI3ubYW4KUBU0guBtZlfRGXblmSkjzyEs7SCL0Z
    ntbCfDvYFF/kK8aSi+l8brMYUeQlIO0hnfCy7AlvTLr/4B+1c3xGAxfrKxfasvqe0omh7j
    7SCGelSq3U37IOtSJ8xwUCaaWguCJzay4AV3ZkwpGeU1AHBNZNpNtVxcPAXMmRTb1QmjYy
    L8Ctu/lIX8LqByfATdKpd6tCZYTpTw5V1I64BR1ur+rpXu0T3AbhazKq0K4dwO5VBGOwry
    u1qgk42u9Bttg30hphqsbIwHLtfGxCz6dF1RGw9b2z+ckqckNzxAVRmdQ6LlfKI83tgMLC
    g9rZnPZt9v0pwUdaq6g8UJdYQOIOAZ2Az2Icn3BrG6EgsvAkCDTcpw/mlwpsrUyINBlwlE
    JuxFuXpcP3eOuxSJSNlEzEij2lFgr9vA6wVxrZe5wPs5aXv+OUvN4Jl4rRsEByQc3sLCl2
    CFHAoauBTCf7c713k9RFbrRtIkEfPWCmh85cQ5D6S98KysNNB7XedGgi359iclDsJpH7so
    V+c7DuLZtYubUr6Ff4yycAAAADAQABAAACAG9yoPwjPiwIVFVq17LBFKP7nSQ3jEA+6YBl
    so5kOsT/hCaMGU2DWuo7yqsxWvj9MK3Y4dZLkwn5xY7KAzJ3Di8/phLqfVNaSUk3kS1vcB
    kNKBLcQVR9EltHmARdBPS1beYC2Q36f528y9YdtgKhvxcyF90/6LfbBElxS0ppukD8q0OU
    NSK8HywSfuy8wOHIsQIYOj2ayYHuQWcfcG1xM/VIAZY7Ukz0gJsuWvduZIGNaqVv+lovzB
    q11v3DYzQDuaaGaQEhk+tXaZp+kTujW0bd+X2+tX9FH/TZv20zJavjvgBIXrLpaW0RqG9+
    brcYxsvHlTs2Y7xbnAC6xgEWM2VrgTjk/6QOFrbGn8mPIAoftRgX9luRmN9PuVPJelgpmN
    giQaUNq+FvpWGOKwxPJs0GJ6NG0jJstdRBshlU1APYjLp4wo/fkoiMfD9vzGKpZ2JEy4fG
    qmY4GNdBfOWj5UL/b/6ppocMP8QLAeiCWfcDMtrFHNl/cJei4uYsjT1FDbRqG1mFRNwQ+Q
    vPfa7upPrTZnYG4ZdrWr0hgazwsuI7Ugkyk5V6InSQlHjOlylutmXNP/LTct7NcPeMPxZY
    f7Tm2yCErLooFSWyDKEl9fUn3ed2Dgrp8hlLWNpy/LjqO5os/S5IuSlXaMBA1kt4l9tMY+
    YfYx39FRnUCiQ/sTaRAAABABQkTeD62058t586IlRi6L+7EJVNoYNFQLaiTbZNUuRLSmOe
    DJIBdKQsaeFeYZmCtHiXR7hLl8UfjSGlE9NOznZzuzxt1Sb0Hrf4n34TXqC+HqLZtjz4zC
    hyI7qnkwIpq/3LrlH6WWRWJkCD8sXgKH4yj2zlErQOytU6cTyfStMIzHjrazkh/XtEGgq2
    q4EgspfPxuhf5JsLxVvK3JxYfq5gla6P/c0KArfhymM1sFZdTSuFjV7s5NIMFrAI2AzfqU
    /Yz6HFQ8PIqOmouO6W79Nn1TSUhdqZgHQ2A+rd1vdM7LtqnCfWzUyYKTDdrew8jdCA3szp
    Tdit0+jsyLNL+5UAAAEBAN4AMXPRTzpdtcbcquo8a+6mvIcDhnvqveH68BIkakkTGOVddn
    kpzrkPT3LJEO2NOBB791m+BNRVP6orVt0Z7kA7ZDEx8BRrAPYU7GV6TuGrw6z6Tp8ExLav
    EqhmJ6mkcLzhRi/d9vnwAJYuITCo01ITgmNWVp4AgECXNpuN4b2ROqgBue9IKvEmeOlX6Z
    W/qDCPsYE0FC4CJh3VQ6Xhuau+OFIm7ZdyfqQcFe5oE0EZYXqAlakdxak9yyKgVtqAMdBw
    k2UMg1raSoeEQIFuOUzm+zMfcIY4h4VnonJLX50WQwMmPRe19woGIhFmKgRUuK+auBCboF
    O+XQbHfJedJeMAAAEBAM9MeSpyuCtoJiZGy4hLU4QXMpoSThCmtqD7m9sBKcEr8BklqFZh
    zsU6heItQhcclRF5dl0MJmf59zUzqpqA6dJ/dkbMip/e0jxwD42AMYhm6kkfN8cqVysfdi
    Qr7v+++4q4ixfdyTPScYR+hjG9Ov31BF39YV9LUeWcv6Ihra/i7709BndW/aawQ9TiYVv5
    h4ODN7/KknMMyZcXv6EBbUV4GK5UhZbhY6ePejQuqoIvtQBKC+oF7OmRoPJT+2OUlMMVnX
    SICtSpn+cO6WdcV9+sLyZZE6CfAelb2+uMrD4kFx74g32xj60TepEQfOti+pCZThkpzW7M
    qV3uhOrt6O0AAAAeamF2aWVyZGVtYXJ0aW5AbWFjYm9vay1wcm8ubGFuAQIDBAU=
    -----END OPENSSH PRIVATE KEY-----
    """
  
  static let privateKey: String = """
        -----BEGIN OPENSSH PRIVATE KEY-----
        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
        -----END OPENSSH PRIVATE KEY-----
        """
  
  static let curvePrivateKey: String = """
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
}
