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
    "509bf7d6ece0bafeb108e8dd3d310779911f297f1628bb9a3bc753a8f33dbe07",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.5/LibSSH-static.xcframework.zip"
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
    "93f337df76ebf6346e36a64c715829a03679e5aca1b7882087593d84f66050f0",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "dd41e8940066aefd0e21c24e0c8b8b46f34005f840f96ace2b870369eef3fcbc",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/awk.xcframework.zip"
  ),
  (
    "files",
    "75589e8591a66f7c95a10fabc3302efec0ddf4ca04e86228d5adfdd752a18a67",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/files.xcframework.zip"
  ),
  (
    "shell",
    "41657942cbfb4fe12cd96f6557dfa46a7ae07cbbcec935e0c881b78fd5bf3dbd",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "2e59319d045dd586e2be33e3cfc54d8421476e27fda75a2b64b17b393de05da8",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "ce5b979f5d3fca6dbcbdc9c88302830481f0649a8eb984a9a73d184d71ee5d92",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/tar.xcframework.zip"
  ),
  (
    "text",
    "f1c1cfe124fe6ddf922d80446d60b8faa80233742630b6caa2d9c0482ede84c6",
    "https://github.com/yury/ios_system/releases/download/v2.9.1/text.xcframework.zip"
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
    .package(url: "https://github.com/blinksh/swift-argument-parser", .upToNextMinor(from: "0.5.1")),
    .package(url: "https://github.com/blinksh/BlinkBuild", from: "0.0.22"),
    .package(url: "https://github.com/yury/SSHConfig", from: "0.0.3"),
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build-project",
      dependencies: ["FMake"]
    ),
  ]
)
