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
    "LibSSH",
    "d41fbdd749a74ec6d5f728f94ab33281193b68b81db242e13e43993f4d6de58f",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.6/LibSSH-static.xcframework.zip"
  ),
  (
    "OpenSSH",
    "cf74b2265618df037096dc3c013af84854e901097fc6304a22c1c5a0f781a7d5",
    "https://github.com/blinksh/openssh-apple/releases/download/v8.6.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "9a7cc2686122e62445b85a8ce04f49379d99c952b8ea3534127c004b8a00af59",
    "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1k/openssl-dynamic.xcframework.zip"
  ),
  (
    "libssh2",
    "6a14c161ee389ef64dfd4f13eedbdf8628bbe430d686a08c4bf30a6484f07dcb",
    "https://github.com/blinksh/libssh2-apple/releases/download/v1.9.0/libssh2-static.xcframework.zip"
  ),

  (
    "ios_system",
    "908ab71b2218de791635ffa4928a819ff8e21dd7652a8e98057988b7db856b6e",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "4eae71d775e5bb304a9f4dde79cbba4b45586c344b21df1484e0a827fc049b5f",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/awk.xcframework.zip"
  ),
  (
    "files",
    "dce416ae2a9b3bf40399af67bee41a30a72df27038febdf61204b816664f4ff1",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/files.xcframework.zip"
  ),
  (
    "shell",
    "57452605a8f3d84212d2a6de0215c99df3ffd644fd6a400debf50d77faa5f404",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "7dbff3bac11e77f3a0dd154de237b28a6fd387b358dd54f2b46470e6b59c1236",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "c18a50dab43bf5ef583c07119f3c321374ccce692b7ad2967dbac0ebb5529c29",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/tar.xcframework.zip"
  ),
  (
    "text",
    "c91dea4306d0b8603aa7a390297ddc0947254b35faa9b07514ae34fcab6fe970",
    "https://github.com/yury/ios_system/releases/download/v2.9.3/text.xcframework.zip"
  ),
  (
    "network_ios",
    "18e96112ae86ec39390487d850e7732d88e446f9f233b2792d633933d4606d46",
    "https://github.com/holzschu/network_ios/releases/download/v0.2/network_ios.xcframework.zip"
  )
].map { name, checksum, url in PackageDescription.Target.binaryTarget(name: name, url: url, checksum: checksum)}

_ = Package(
  name: "deps",
  platforms: [.macOS("11")],
  dependencies: [
    .package(url: "https://github.com/yury/FMake", from: "0.0.15"),
    .package(url: "https://github.com/blinksh/swift-argument-parser", .upToNextMinor(from: "0.5.1")),
    .package(url: "https://github.com/yury/SSHConfig", from: "0.0.5"),
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build-project",
      dependencies: ["FMake"]
    ),
  ]
)
