// swift-tools-version:5.3
import PackageDescription

var binaryTargets: [PackageDescription.Target] = [
  ( 
    "Protobuf_C_",
    "a74e23890cf2093047544e18e999f493cf90be42a0ebd1bf5d4c0252d7cf377a",
    "https://github.com/blinksh/protobuf-apple/releases/download/v3.21.1/Protobuf_C_-static.xcframework.zip"
  ),
  (
    "mosh",
    "cd92212248429478a0f24346ca48397191409be0c8692b067a13eb9b17e50f27",
    "https://github.com/blinksh/mosh-apple/releases/download/v1.4.0/mosh.xcframework.zip"
  ),
  (
    "LibSSH",
    "f03487ca3affb1d79d1bfb42f6406b92f2f406d9f58acd007b56f1a46af2d1f4",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.8/LibSSH-static.xcframework.zip"
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
    "f8e1364037de546809065ecdf804277fa7b95faffc32604e91ecb4de44d6294e",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "73abc0d502eab50e6bbdd0e49b0cf592f3a85b3843c43de6d7f42c27cde9b953",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/awk.xcframework.zip"
  ),
  (
    "files",
    "d0643e2244009fc5279f1f969c6da47ca197b4e7c9dac27dea09ba0a5f1567d7",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/files.xcframework.zip"
  ),
  (
    "shell",
    "876b709c1b76cbc1748d434fcbc2cea1aea2e281572e5fadc40244dd8a549757",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "342065209123f54c92eb78a0fbda579e61948443e5f60e41d8fe356a3fe8f2ff",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "6ffe4ed265060f971df229dd1d2bff90e7bc78c80c50dcc3a0a633face440bc4",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/tar.xcframework.zip"
  ),
  (
    "text",
    "697bee697b509d0dc8acc156a7430f453c29878d8af273adfb8902643c70ea0f",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.2/text.xcframework.zip"
  ),
  (
    "network_ios",
    "9fe5f119b2d5568d2255e2540f36e76525bfbeaeda58f32f02592ca8d74f4178",
    "https://github.com/holzschu/network_ios/releases/download/v0.3/network_ios.xcframework.zip"
  )
].map { name, checksum, url in PackageDescription.Target.binaryTarget(name: name, url: url, checksum: checksum)}

_ = Package(
  name: "deps",
  platforms: [.macOS("11")],
  dependencies: [
    .package(url: "https://github.com/blinksh/FMake", from: "0.0.15"),
    .package(url: "https://github.com/blinksh/swift-argument-parser", .upToNextMinor(from: "0.5.1")),
    .package(url: "https://github.com/blinksh/SSHConfig", from: "0.0.5"),
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build-project",
      dependencies: ["FMake"]
    ),
  ]
)
