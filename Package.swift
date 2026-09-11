// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MailSwitch",
    platforms: [.macOS(.v10_15)],
    products: [.executable(name: "MailSwitch", targets: ["MailSwitch"])],
    targets: [
        .target(name: "MailSwitchCore"),
        .executableTarget(name: "MailSwitch", dependencies: ["MailSwitchCore"]),
        .testTarget(name: "MailSwitchCoreTests", dependencies: ["MailSwitchCore"])
    ]
)
