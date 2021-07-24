// swift-tools-version:5.3
import PackageDescription

var binaryTargets: [PackageDescription.Target] = [
  ( 
    "Protobuf_C_",
    "a90dbb75b3ef12224d66cddee28073066e0cab6453f79392d8f954b5904b8790",
    "https://github.com/blinksh/protobuf-apple/releases/download/v3.14.0/Protobuf_C_-static.xcframework.zip"
  ),
  (
    "mosh",
    "f564b29d11bed18b64c780f90bfd9fd188f145dd849565f90664f3023808370d",
    "https://github.com/blinksh/mosh-apple/releases/download/v1.3.2/mosh.xcframework.zip"
  ),
  (
    "libssh",
    "3853a96fdcb37bd843ccd4fd00f760b9cf3def1260befda1ecb34e65b904e08c",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.4/LibSSH-static.xcframework.zip"
  ),
  (
    "OpenSSH",
    "cf74b2265618df037096dc3c013af84854e901097fc6304a22c1c5a0f781a7d5",
    "https://github.com/blinksh/openssh-apple/releases/download/v8.6.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "6ab47a85acb5d70318877b11bf38b9154b25faab3c78cbade384dc23d870bf34",
    "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1i/openssl-static.xcframework.zip"
  ),
//  (
//    "openssl",
//    "7f7e7cf7a1717dde6fdc71ef62c24e782f3c0ca1a2621e9376699362da990993",
//    "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip"
//  ),
  (
    "libssh2",
    "6a14c161ee389ef64dfd4f13eedbdf8628bbe430d686a08c4bf30a6484f07dcb",
    "https://github.com/blinksh/libssh2-apple/releases/download/v1.9.0/libssh2-static.xcframework.zip"
  ),

  (
    "ios_system",
    "b4c982131b2c7e641d22be5bc4ae1d8046ba8ad7afd4a16df368da1267a01777",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "16e60005194c8b0dc0a43b254a4f34a60cf7e759953e43dba2a2ec83cd4d0261",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/awk.xcframework.zip"
  ),
  (
    "files",
    "d1c464c0abc010fb66b6514396836676d77195fa6b3e4207c8a27aa0e63e69c0",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/files.xcframework.zip"
  ),
  (
    "shell",
    "d4763e81ae2be69479bcac87217ff1bafd20fab4aa4be489fafbc51ff61f8b31",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "6d1f643084560aae6185a13cfdc210875169cb6b25b0dc3c705bb3cd10c79cc7",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "f161dc5c43a721b5ca98ba0ccac539b12014975a9b855f4fc52e8a78eb9a57ec",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/tar.xcframework.zip"
  ),
  (
    "text",
    "d8e54a9cf1f41bc0f20edea5778767b64bef473301081d60044cb6e387fffe8a",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/text.xcframework.zip"
  ),
  (
    "network_ios",
    "7a8153411db8b8758fae41624933052f073b56c8eefdb421a8651cd46f7b8edb",
    "https://github.com/yury/network_ios/releases/download/v0.2/network_ios.xcframework.zip"
  )
].map { name, checksum, url in PackageDescription.Target.binaryTarget(name: name, url: url, checksum: checksum)}

_ = Package(
  name: "deps",
  platforms: [.macOS("11")],
  dependencies: [
    .package(url: "https://github.com/yury/FMake", from: "0.0.15"),
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.4.0")),
    .package(url: "https://github.com/blinksh/BlinkBuild", from: "0.0.10"),
    .package(url: "https://github.com/yury/SSHConfig", from: "0.0.1"),
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build-project",
      dependencies: ["FMake"]
    ),
  ]
)
