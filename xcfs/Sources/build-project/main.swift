// use it from root folder:
// `swift run --package-path xcfs build-project`

import Foundation
import FMake 

OutputLevel.default = .error

// TODO: We can add more platforms here
let platforms: [Platform] = [.iPhoneOS, .iPhoneSimulator]

let schemes = [ "SSH", "BlinkFiles" ]

var checksums: [[String]] = []

for scheme in schemes {
    try xcxcf(
        dirPath: ".build",
        project: "BlinkCore",
        scheme: scheme,
        platforms: platforms.map { ($0, excludedArchs: []) }
    )

    try cd(".build") {
        let zip = "\(scheme).xcframework.zip"
        try sh("zip -r \(zip) \(scheme).xcframework")
        let chksum = try sha(path: zip)
        checksums.append([zip, chksum])
    }
}

var releaseNotes =
"""
Release notes:

\( checksums.markdown(headers: "File", "SHA 256") )

"""

try write(content: releaseNotes, atPath: ".build/release.md")

