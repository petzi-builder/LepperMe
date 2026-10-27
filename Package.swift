// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LepperMe",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "LepperMe", targets: ["LepperMe"])
    ],
    targets: [
        .executableTarget(
            name: "LepperMe",
            path: "Sources/LepperMe",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("CoreMediaIO"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
