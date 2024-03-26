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
    "50f1692873e73fd862f45f73f2c08745e822c01ff5e0a0e0aec7fed6bb946e7f",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/ios_system.xcframework.zip"
  ),
  (
    "awk",
    "428de9776d73b5ef6865b2b0057e962ebe680cff4e977d2cd038455b4728bbac",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/awk.xcframework.zip"
  ),
  (
    "files",
    "3224a690a41747bd85e0e5d7868979cc83884e3517b39648e1f6a171ad192e21",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/files.xcframework.zip"
  ),
  (
    "shell",
    "7c0c3321155a7e1df609566d6d4d887003cb68f5bf1bcc6eab2ca56f75f46758",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/shell.xcframework.zip"
  ),
  (
    "ssh_cmd",
    "c7b197f5aeff4f6ba153b94d979e57916dc99a9afc9c37b394477b513f5fb8cd",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/ssh_cmd.xcframework.zip"
  ),
  (
    "tar",
    "8cddd932df4ea609205372c657dee827aa8422fa6d21942d9bf1c7e8148b1ab3",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/tar.xcframework.zip"
  ),
  (
    "text",
    "b1244f7612f755d5b1c04252955e37e5a8578c5cc7fd26b28b9bee3294f4e3d1",
    "https://github.com/holzschu/ios_system/releases/download/v3.0.3/text.xcframework.zip"
  ),
  (
    "network_ios",
    "9fe5f119b2d5568d2255e2540f36e76525bfbeaeda58f32f02592ca8d74f4178",
    "https://github.com/holzschu/network_ios/releases/download/v0.3/network_ios.xcframework.zip"
  ),
  (
    "bc",
    "e3d72c562f726614e273efb06f6e63ccd23f9e38b14c468cf9febd4302df5fdd",
    "https://github.com/holzschu/bc/releases/download/v1.0/bc_ios.xcframework.zip"
  ),
  (
    "vim",
    "782fba9fe318a39c8cebb52ff71efc8cbc3b97ba748a5a60fe11bee6c473b32c",
    "https://github.com/blinksh/vim/releases/download/v9.1.0187/vim.xcframework.zip"
  ),
  (
    "xxd",
    "eb44e4567287ccd13d98f10f727600e6e806abd968369e96c9b7d700276961c7",
    "https://github.com/blinksh/vim/releases/download/v9.1.0187/xxd.xcframework.zip"
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
