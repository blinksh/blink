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


let p12Cert = """
  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
  LN/Xy2AzvAQIwSGIMRRHzLwCAggA
  
  """
let pemCert = """
  -----BEGIN CERTIFICATE-----
  MIIEpDCCAowCCQCwoT5TbovoTTANBgkqhkiG9w0BAQsFADAUMRIwEAYDVQQDDAls
  b2NhbGhvc3QwHhcNMjExMDIyMTYzNjE3WhcNMjIxMDIyMTYzNjE3WjAUMRIwEAYD
  VQQDDAlsb2NhbGhvc3QwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDE
  h14K/KK8o3VOumeaD8x5Zf13iWApq1Fx6rjRuKh1K7yrI53q38nw/Q1ul782lbxI
  iw8JaMiX4V6nPE+5Kej8LFyy98w46VsBnYs968AL42ordB3nPC8zwVbfPYrHv1oy
  +cBcmcULtq750fvWP1acCiBqdgMSnF0omSTkTU/D3lIUqpwgpQl2/VlhtpWlPyoM
  Aq4DO+Vmye9NUMOZQceApIb0sH6a0JrB5jD91h9sgVWayNMVxju7GziPBzmRiuMV
  wDD2rMjo7gFJLjB5XagTYXtiIpojzk5rKpZAxTktHYiP1poN/aHnqCjlmzvICR88
  8BL6JEfcj3p9NSIi344MagdWmRQt19bEXpEHVLJn2SAE/TvyNmchAevYtlsIaUDW
  Y1iabuxIA4QxWCAWteh/LPuLKP+hicVJ/mGZ1XVRKl6iVvUgDCJaPCJOcUnPZJxK
  bOvGkW87VeLaC39T30WDXaujhrBNTU2uDDZgcfWZs8DVimofKXUwkGVx4MROrntX
  +td2YqX6UKKYqXebkdgE1TSZeW82ECmwZo0n8C5jT8PUbGYk1Os4CSLYUasGQtHN
  UPP3yOv44eJ+4Af+ZS+XkUlEkC3UB0ZyiStzdpT7QDpNBsNgE7DZ6RyB7Q47Vxzn
  tj7l5kNbW2yrHWcqvTWBq3d8WP4oI6N13y1fjh1yrwIDAQABMA0GCSqGSIb3DQEB
  CwUAA4ICAQAA/PI4+iSy9zys2i/uJs7qtz/Omi0RJjnz9lKm1K1Cr7apedm8aIWm
  ZhRLFJt4LdchjqT+dAVH+E0Su1wiF5EafvRoXMEfHJ1BW7rXyZlrvvIyVtqxvAeN
  PfkHhyjPS7n5P2C7hHOEqmeQilbuagc28/HIVDdoXyXighjZWnHGGMPVCwpTPHbO
  OtjyU6HF5Dujv+8lFVr1tgdexfKnC9tm3puYO81rDDzENV9VHp18NqKznD5mLLYK
  Ngx2yyqJNxppJlenlP+1ryLd061EG/GnaiPJ65eaQKtz+mUXoWBnSeUZCUarxc5T
  OwyMU3OPGE5ZVgXAb6LlaGtOF3kzWCSDeWzZQnnlzrta1pkGw35OEEIZMngMfQTn
  edoo1PQQZqf9rAdFQd/c4m7HMPfnvxRlVt0sl55Q/B+vGdIfQOCxUtChaP+PZhjQ
  WlkLL6lBVfyrk+tDYny4pBpr+nBgaLUDHCZLFi5//SXUFvMH/98xj1VNQX1DGj/R
  GBgfOTsmbov33hOiR9l4jqbPW8lV0RRfnRVfdWT8Q6rrb3BARqwCtOcbp7CMpn2s
  j4MEhnQnIoFDIwV0kUbJDVIM2JNnv0OthZcJNqWPjPEdHwAhjYsa4O25zuBsVw1S
  VNRsYjq7Hbq4nYioPS6Og942BbwtjHTPf77ALvHZVDBVY0upPZXYvA==
  -----END CERTIFICATE-----
  """

