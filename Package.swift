// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TwilioCall",
    platforms: [.iOS(SupportedPlatform.IOSVersion.v13)],
    products: [
        .library(
            name: "TwilioCall",
            targets: ["TwilioCall"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        .package(name: "TwilioVoice", url: "https://github.com/twilio/twilio-voice-ios", from: "6.3.0"),
    ],
    targets: [
        .target(
            name: "TwilioCall",
            dependencies: ["TwilioVoice"],
            resources: [.copy("sounds/incoming.wav"), .copy("sounds/ringback.wav")]),
        .testTarget(
            name: "TwilioCallTests",
            dependencies: ["TwilioCall"]),
    ]
)
