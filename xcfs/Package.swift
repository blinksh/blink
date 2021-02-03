// swift-tools-version:5.3
import PackageDescription

var binaryTargets: [PackageDescription.Target] = [
  ( 
    "Protobuf_C_",
    "69e60a51a6aa63b86c00d86c7594538ba7f15e6377b0eadf458c6294ef13c97e",
    "https://github.com/yury/protobuf-cpp-apple/releases/download/v3.14.0/Protobuf_C_-static.xcframework.zip"
  ),
  (
    "mosh",
    "727d404455b94de3fa9834441b19cf6c51e93db64cd91f7dd31d0683e42b52ad",
    "https://github.com/yury/mosh-apple/releases/download/v1.3.2/mosh.xcframework.zip"
  ),
  (
    "libssh",
    "9779da1a08e3a23bd1f2534da9c33f5f2075b9206283d106f454d881cc26d12a",
    "https://github.com/yury/libssh-apple/releases/download/v0.9.4/LibSSH-dynamic.xcframework.zip"
  ),
  (
    "OpenSSH",
    "62819e6ede23243fb370b452fc288e0c61eaf468cd692b7ea4473f245504f7d8",
    "https://github.com/yury/openssh-apple/releases/download/v8.4.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "d07917d2db5480add458a7373bb469b2e46e9aba27ab0ebd3ddc8654df58e60f",
    "https://github.com/yury/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip"
  ),

  (
    "libssh2",
    "07952e484eb511b1badb110c15d4621bb84ef98b28ea4d6e1d3a067d420806f5",
    "https://github.com/yury/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip"
  ),
  (
    "ios_system",
    "e98c075c088f916649426720afa50df03904aa36d321fe072c9bd6ccbc12806c",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "663554d7fca4fcdc670ab91c2f10c175bd10ca8dca3977fbeb6ee8dcd9571e05",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/awk.xcframework.zip"
  ),
  (
    "curl_ios",
    "bd1b1f430693c3dc3c0e03bccea810391e5d0d348fbd3ca2d31ff56b5026d1bb",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/curl_ios.xcframework.zip"
  ),
  (
    "files",
    "c1fbd93d35d3659d3f600400f079bfd3b29f9f869be6d1c418e3ac0e7ad8e56a",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/files.xcframework.zip"
  ),
  (
    "shell",
    "726bafd246106424b807631ac81cc99aed42f8d503127a03ea6d034c58c7e020",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "8c769ad16bdab29617f59a5ae4514356be5296595ec5daf4300440a1dc7b3bf7",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "25b817baab9229952c47babc2a885313070a0db1463d7cd43d740164bd1f951b",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/tar.xcframework.zip"
  ),
  (
    "text",
    "54acd52b21ae9cfa85e3c54d743009593dd78bf6b53387185fd81cf95d8ddf05",
    "https://github.com/holzschu/ios_system/releases/download/v2.7.0/text.xcframework.zip"
  ),
  (
    "network_ios",
    "89a465b32e8aed3fcbab0691d8cb9abeecc54ec6f872181dad97bb105b72430a",
    "https://github.com/holzschu/network_ios/releases/download/v0.2/network_ios.xcframework.zip"
  )
].map { name, checksum, url in PackageDescription.Target.binaryTarget(name: name, url: url, checksum: checksum)}

_ = Package(
  name: "deps",
  platforms: [.macOS("11")],
  dependencies: [
    .package(url: "https://github.com/yury/FMake", from: "0.0.15"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.0"))
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build",
      dependencies: ["FMake"]
    ),
  ]
)
