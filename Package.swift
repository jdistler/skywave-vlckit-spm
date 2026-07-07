// swift-tools-version: 5.9
import PackageDescription

// Skywave fork: VLCKit built from jdistler/skywave-vlckit, which carries extra libVLC
// patches: 0013 exposes :audio-resync-tolerance / :audio-late-tolerance (fixes the iOS
// segmented-HLS audio flush-loop freeze); 0014 adds :adaptive-ts-keep-raw; 0015 adds
// :adaptive-ts-force-playlist — forces ONE monotonic timeline across the segments'
// inconsistent per-segment PTS (shared offset re-anchored on any jump, applied to every ES
// + PCR) so segment-boundary backward jumps can't stall the clock; 0016 survives broken-panel
// HLS media-sequence anomalies (forward gaps used to assert(duration)+abort, backward resets
// used to stall the playlist forever); 0017 makes the aout late-flush queue-aware (a
// transient late drift against a deep queued buffer no longer dumps the whole queue into
// seconds of silence — only true starvation flushes); 0018 anchors the avsamplebuffer start at the intended
// host time (setRate:time:atHostTime:), killing the constant ~160ms audio-late startup
// drift / 15-20s lip-sync slew after every open; 0019 fixes 0018's anchor gate (deadline
// is always us-past after the timedwait — anchor up to 1s past) and warns on multi-second
// start gaps (route-change lost-queue, AirPods in/out) so the app can reconnect instead of
// sitting silent for queue-depth seconds. URL + checksum track the release.
let vlcBinary = Target.binaryTarget(
    name: "VLCKit",
    url: "https://github.com/jdistler/skywave-vlckit/releases/download/patched-13/VLCKit.xcframework.zip",
    checksum: "60d7ff57396caa81aae03d510e33efa8bc3b5c8708e1530f4fa165e30d4a0cde"
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
