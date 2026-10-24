// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "macprinter",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "macprinter", targets: ["MacPrinterApp"]),
        .executable(name: "macprinter-backend", targets: ["macprinter-backend"]),
    ],
    targets: [
        .target(name: "MacPrinterCore"),
        .executableTarget(name: "macprinter-backend", dependencies: ["MacPrinterCore"]),
        .executableTarget(name: "MacPrinterApp", dependencies: ["MacPrinterCore"]),
        .testTarget(name: "MacPrinterCoreTests", dependencies: ["MacPrinterCore"]),
    ]
)
