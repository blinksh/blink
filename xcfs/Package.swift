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
    "669cebea98edc69a9ba752b07cd2db002bd2e1df421b1fcd6d5175314479f583",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.4/LibSSH-dynamic.xcframework.zip"
  ),
  (
    "OpenSSH",
    "f55a92a497df09f31f5a138db459915fae7897263d807fe5fb486edfa7dafceb",
    "https://github.com/blinksh/openssh-apple/releases/download/v8.4.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "7f7e7cf7a1717dde6fdc71ef62c24e782f3c0ca1a2621e9376699362da990993",
    "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip"
  ),
  (
    "libssh2",
    "79b18673040a51e7c62259965c2310b5df2a686de83b9cc94c54db944621c32c",
    "https://github.com/blinksh/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip"
  ),

  (
    "ios_system",
    "394d519bf69f2a28da063a2fb9a163f623133d5769c114fb0bd6406b554e0473",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "4db4d54e2d3dd3f91582bf0c24a510e836d08438360636ecadbe1804b60694a1",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/awk.xcframework.zip"
  ),
  (
    "curl_ios",
    "b4b4c48ed0ffe95d37d73a2a8133c135319acb4f4aaa292a0d2b045cbaebadb9",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/curl_ios.xcframework.zip"
  ),
  (
    "files",
    "6748af398f6e988b9460982e5d3e7692dd229d4f87b734a1ec101e91eb712a04",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/files.xcframework.zip"
  ),
  (
    "shell",
    "a3aec5525853bd43aabb9fefa1f423b0f96f239bcb37485515b81bbe2705960c",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "295fb65b5bb049c9b724bf5123104f43abccbc50c8b9711972e674fe75911a70",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "4fe5a94b0404fc11f8b904e052e291d251bf20a19df2df8f4b15374a07b00dcf",
    "https://github.com/yury/ios_system/releases/download/v2.7.0/tar.xcframework.zip"
  ),
  (
    "text",
    "95ccb024511dae73efa480cfd7d09003f83b1e8ea3c6359be3e3a75cc2521251",
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
    .package(url: "https://github.com/apple/swift-argument-parser", .upToNextMinor(from: "0.3.0"))
  ],
  
  targets: binaryTargets + [
    .target(
      name: "build",
      dependencies: ["FMake"]
    ),
  ]
)
