// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Sagaa",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Sagaa", targets: ["Sagaa"])
    ],
    targets: [
        .executableTarget(
            name: "Sagaa",
            path: "Sources",
            resources: [
                .copy("../Models/vocab.json"),
                .copy("../Models/cmvn.json"),
                .copy("../Models/mel_filters.json"),
                .copy("../Models/BurmeseASR.mlpackage")
            ]
        )
    ]
)

