// swift-tools-version: 5.9
import PackageDescription

// Skywave fork: VLCKit built from jdistler/skywave-vlckit, which carries extra libVLC
// patches: 0013 exposes :audio-resync-tolerance / :audio-late-tolerance (fixes the iOS
// segmented-HLS audio flush-loop freeze); 0014 adds :adaptive-ts-keep-raw to ignore the
// inconsistent per-segment Apple ID3 timestamp mapping that flips the HLS timeline between
// two bases and freezes playback. URL + checksum track that repo's release.
let vlcBinary = Target.binaryTarget(
    name: "VLCKit",
    url: "https://github.com/jdistler/skywave-vlckit/releases/download/patched-3/VLCKit.xcframework.zip",
    checksum: "76f804f8e4cec6c570a5d636e3201981ae79d2330d3167839f87ed407650f56a"
)

let package = Package(
    name: "VLCKitSPM",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "VLCKitSPM", targets: ["VLCKitSPM"])
    ],
    dependencies: [],
    targets: [
        vlcBinary,
        .target(
            name: "VLCKitSPM",
            dependencies: [.target(name: "VLCKit")],
            linkerSettings: [
                // iOS/tvOS frameworks
                .linkedFramework("QuartzCore", .when(platforms: [.iOS])),
                .linkedFramework("CoreText", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("AVFoundation", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("Security", .when(platforms: [.iOS])),
                .linkedFramework("CFNetwork", .when(platforms: [.iOS])),
                .linkedFramework("AudioToolbox", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("OpenGLES", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreGraphics", .when(platforms: [.iOS])),
                .linkedFramework("VideoToolbox", .when(platforms: [.iOS, .tvOS])),
                .linkedFramework("CoreMedia", .when(platforms: [.iOS, .tvOS])),
                // macOS frameworks
                .linkedFramework("Foundation", .when(platforms: [.macOS])),
                // System libraries
                .linkedLibrary("c++", .when(platforms: [.iOS, .tvOS, .macOS])),
                .linkedLibrary("xml2", .when(platforms: [.iOS, .tvOS, .macOS])),
                .linkedLibrary("z", .when(platforms: [.iOS, .tvOS, .macOS])),
                .linkedLibrary("bz2", .when(platforms: [.iOS, .tvOS, .macOS])),
                .linkedLibrary("iconv")
            ]
        )
    ]
)
