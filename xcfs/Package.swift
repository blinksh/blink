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
    "d6dce7664ecce1b15931d6b0b8aaf3b1cacebe390669df960fe47318cb0dda05",
    "https://github.com/blinksh/mosh-apple/releases/download/v1.4.0+blink-18.4.5/mosh.xcframework.zip"
  ),
  (
    "LibSSH",
    "6e44c4da3de8268c708c4b111aa1e9043bbd0d6977addd95377289470fd812ab",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.12.0/LibSSH-static.xcframework.zip"
  ),
  (
    "OpenSSH",
    "ba68c1d2482ae963943d183f21caa5ec578a627d38764c2da65abf70089ec2c6",
    "https://github.com/blinksh/openssh-apple/releases/download/v8.9.0+blink-18.7.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "f2954129976a2d990d20e371d837163f9cc6b7d9191e07380b8690ef7322bf50",
    "https://github.com/krzyzanowskim/OpenSSL/releases/download/3.6.0001/OpenSSL.xcframework.zip"
  ),
  (
    "ios_system",
    "91eee24081c6552b71be06660aed4f0f96b3f1cadfa0673307e73a34ca635141",
    "https://github.com/blinksh/ios_system/releases/download/v3.0.3+blink-18.7.0/ios_system.xcframework.zip"
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
    "curl_ios",
    "46a85d91f5f79a5718ead9240f2a1bc87bde9c54dc2e19628bd9d3aa896d39ae",
    "https://github.com/blinksh/ios_system/releases/download/v3.0.3+blink-18.7.0/curl_ios.xcframework.zip"
  ),
  (
    "bc",
    "e3d72c562f726614e273efb06f6e63ccd23f9e38b14c468cf9febd4302df5fdd",
    "https://github.com/holzschu/bc/releases/download/v1.0/bc_ios.xcframework.zip"
  ),
  (
    "vim",
    "81fd7d57cb9cb9549db1f4514dbf93b3c0e67bd5ba8d07ae43735f7916ff8e88",
    "https://github.com/blinksh/vim/releases/download/v9.1.0187%2Bblink-17.3.0/vim.xcframework.zip"
  ),
  (
    "xxd",
    "eb8f86526fae0165b36c08d6eec05d87b48c742f624a3e13b9a885f357ab61e0",
    "https://github.com/blinksh/vim/releases/download/v9.1.0187%2Bblink-17.3.0/xxd.xcframework.zip"
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
