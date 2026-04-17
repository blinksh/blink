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
    "f03487ca3affb1d79d1bfb42f6406b92f2f406d9f58acd007b56f1a46af2d1f4",
    "https://github.com/blinksh/libssh-apple/releases/download/v0.9.8/LibSSH-static.xcframework.zip"
  ),
  (
    "OpenSSH",
    "6f6269790435a33c93abbe5ea4e3fe636c3fad6e176332f6f23d6ac9884fdeef",
    "https://github.com/blinksh/openssh-apple/releases/download/v8.9.0/OpenSSH-static.xcframework.zip"
  ),
  (
    "openssl",
    "cba8c2b41ab5dcd780c475466001573cb84e373f71e9c4e1b573717c91549633",
    "https://github.com/blinksh/openssl-apple/releases/download/v1.1.1w/openssl-dynamic.xcframework.zip"
  ),
  (
    "libssh2",
    "6a14c161ee389ef64dfd4f13eedbdf8628bbe430d686a08c4bf30a6484f07dcb",
    "https://github.com/blinksh/libssh2-apple/releases/download/v1.9.0/libssh2-static.xcframework.zip"
  ),
  (
    "ios_system",
    "e692102956d86b7ce8730c3bb02a964eff1d5aa5a91d617742091a6c4dbebb0d",
    "https://github.com/blinksh/ios_system/releases/download/v3.0.3+blink-18.6.0/ios_system.xcframework.zip"
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
    "f8215a3c2f135e37e0fb3662f78fdaffeb3f4e9c2bea55a0adbc10e5b983cd80",
    "https://github.com/blinksh/ios_system/releases/download/v3.0.3+blink-18.6.0/curl_ios.xcframework.zip"
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
