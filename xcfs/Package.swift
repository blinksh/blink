// swift-tools-version:5.3
import PackageDescription

var binaryTargets: [PackageDescription.Target] = [
  ( "Protobuf_C_", "07433ba7926493200ff7ad31412bc9247d6ddc092b4fa5e650b01c6f36a35559", "https://github.com/yury/protobuf-cpp-apple/releases/download/v3.14.0/Protobuf_C_-static.xcframework.zip" ),
  ( "mosh"       , "727d404455b94de3fa9834441b19cf6c51e93db64cd91f7dd31d0683e42b52ad", "https://github.com/yury/mosh-apple/releases/download/v1.3.2/mosh.xcframework.zip" ),
  ( "OpenSSH"    , "9bd2b5bf5167b38e27d500ab1dfd7fcdb3fe48aad464dedf1ab980238956c9de", "https://github.com/yury/openssh-apple/releases/download/v8.4.0/OpenSSH-static.xcframework.zip" ),
  ( "libssh2"    , "07952e484eb511b1badb110c15d4621bb84ef98b28ea4d6e1d3a067d420806f5", "https://github.com/yury/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip" ),
  ( "ios_system" , "a3ec1c198b944b7d0e8932b7da447b164ae9b869c11c8f0f35cc7b5f09129fe2", "https://github.com/yury/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip" ),
  ( "awk"        , "d130cff498a50d3b5f0e6161488e4c768e815c866df448257f391ab620c2676c", "https://github.com/yury/ios_system/releases/download/v2.7.0/awk.xcframework.zip" ),
  ( "curl_ios"   , "57beebc661ce6a68c796fc47e872ee1bdeaae25053bb80ca77dd2e04f75a0c7b", "https://github.com/yury/ios_system/releases/download/v2.7.0/curl_ios.xcframework.zip" ),
  ( "files"      , "248243920e0b9dc45bbba279d31f83191abf69b5e98d909ce245baf37a749837", "https://github.com/yury/ios_system/releases/download/v2.7.0/files.xcframework.zip" ),
  ( "shell"      , "cf0f5e0cad1ac0b28efbf5b4a382053fa8d83e1ea30d8457ae30b056d6ce6fda", "https://github.com/yury/ios_system/releases/download/v2.7.0/shell.xcframework.zip" ),
  ( "ssh_cmd"    , "5df5ab2568954953367c37e7f2a937b4475c404d996330ce3096742798e00cfc", "https://github.com/yury/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip" ),
  ( "tar"        , "1c259d4c13c665732da35978456345415540aa1c4f0dd597616145ceeb6a9237", "https://github.com/yury/ios_system/releases/download/v2.7.0/tar.xcframework.zip" ),
  ( "text"       , "31dadcea8823a79b9425eb752fc76d14c8d784217e7a9b7d18cb387006b14f67", "https://github.com/yury/ios_system/releases/download/v2.7.0/text.xcframework.zip" ),
  ( "openssl"    , "d07917d2db5480add458a7373bb469b2e46e9aba27ab0ebd3ddc8654df58e60f", "https://github.com/yury/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip" ),
  ( "libssh"     , "9779da1a08e3a23bd1f2534da9c33f5f2075b9206283d106f454d881cc26d12a", "https://github.com/yury/libssh-apple/releases/download/v0.9.4/LibSSH-dynamic.xcframework.zip" ),
  ( "network_ios", "ec5860ecd720ccaaa298ab02766d8469c21f5fe5d3bab5a43bab090001dafa9c", "https://github.com/yury/network_ios/releases/download/v0.2/network_ios.xcframework.zip" )
].map { name, checksum, url in PackageDescription.Target.binaryTarget(name: name, url: url, checksum: checksum)}

_ = Package(
    name: "deps",
    platforms: [.macOS("11")],
    dependencies: [
        .package(url: "https://github.com/yury/FMake", from: "0.0.15")
    ],
    
    targets: binaryTargets + [
        .target(
            name: "build",
            dependencies: ["FMake"]
        ),
    ]
)
