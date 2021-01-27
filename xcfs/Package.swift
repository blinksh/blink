// swift-tools-version:5.3
import PackageDescription

_ = Package(
    name: "deps",
    platforms: [.macOS("11")],
    dependencies: [
        .package(url: "https://github.com/yury/FMake", from: "0.0.15")
    ],
    
    targets: [
        .binaryTarget(
            name: "Protobuf_C_",
            url: "https://github.com/yury/protobuf-cpp-apple/releases/download/v3.14.0/Protobuf_C_-static.xcframework.zip",
            checksum: "07433ba7926493200ff7ad31412bc9247d6ddc092b4fa5e650b01c6f36a35559"
        ),

        .binaryTarget(
            name: "mosh",
            url: "https://github.com/yury/mosh-apple/releases/download/v1.3.2/mosh.xcframework.zip",
            checksum: "727d404455b94de3fa9834441b19cf6c51e93db64cd91f7dd31d0683e42b52ad"
        ),

        .binaryTarget(
            name: "OpenSSH",
            url: "https://github.com/yury/openssh-apple/releases/download/v8.4.0/OpenSSH-static.xcframework.zip",
            checksum: "82b57892d1656980ee710b27ea3aacd436c52f4e85212c2a74aa2f3cea588de2"
        ),

        .binaryTarget(
            name: "libssh2",
            url: "https://github.com/yury/libssh2-apple/releases/download/v1.9.0/libssh2-dynamic.xcframework.zip",
            checksum: "07952e484eb511b1badb110c15d4621bb84ef98b28ea4d6e1d3a067d420806f5"
        ),

        .binaryTarget(
            name: "ios_system",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/ios_system.xcframework.zip",
            checksum: "a3ec1c198b944b7d0e8932b7da447b164ae9b869c11c8f0f35cc7b5f09129fe2"
        ),

        .binaryTarget(
            name: "awk",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/awk.xcframework.zip",
            checksum: "d130cff498a50d3b5f0e6161488e4c768e815c866df448257f391ab620c2676c"
        ),

        .binaryTarget(
            name: "curl_ios",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/curl_ios.xcframework.zip",
            checksum: "57beebc661ce6a68c796fc47e872ee1bdeaae25053bb80ca77dd2e04f75a0c7b"
        ),

        .binaryTarget(
            name: "files",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/files.xcframework.zip",
            checksum: "248243920e0b9dc45bbba279d31f83191abf69b5e98d909ce245baf37a749837"
        ),

        .binaryTarget(
            name: "shell",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/shell.xcframework.zip",
            checksum: "cf0f5e0cad1ac0b28efbf5b4a382053fa8d83e1ea30d8457ae30b056d6ce6fda"
        ),

        .binaryTarget(
            name: "ssh_cmd",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/ssh_cmd.xcframework.zip",
            checksum: "5df5ab2568954953367c37e7f2a937b4475c404d996330ce3096742798e00cfc"
        ),

        .binaryTarget(
            name: "tar",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/tar.xcframework.zip",
            checksum: "1c259d4c13c665732da35978456345415540aa1c4f0dd597616145ceeb6a9237"
        ),

        .binaryTarget(
            name: "text",
            url: "https://github.com/yury/ios_system/releases/download/v2.7.0/text.xcframework.zip",
            checksum: "31dadcea8823a79b9425eb752fc76d14c8d784217e7a9b7d18cb387006b14f67"
        ),

        .binaryTarget(
            name: "openssl",
            url: "https://github.com/yury/openssl-apple/releases/download/v1.1.1i/openssl-dynamic.xcframework.zip",
            checksum: "d07917d2db5480add458a7373bb469b2e46e9aba27ab0ebd3ddc8654df58e60f"
        ),

        .binaryTarget(
            name: "libssh",
            url: "https://github.com/yury/libssh-apple/releases/download/v0.9.4/LibSSH-dynamic.xcframework.zip",
            checksum: "9779da1a08e3a23bd1f2534da9c33f5f2075b9206283d106f454d881cc26d12a"
        ),

        .binaryTarget(
            name: "network_ios",
            url: "https://github.com/yury/network_ios/releases/download/v0.2/network_ios.xcframework.zip",
            checksum: "ec5860ecd720ccaaa298ab02766d8469c21f5fe5d3bab5a43bab090001dafa9c"
        ),

        .target(
            name: "build",
            dependencies: ["FMake"]
        ),
    ]
)