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
// sitting silent for queue-depth seconds; 0020 survives garbage NEGATIVE
// EXT-X-MEDIA-SEQUENCE values ("-1"/"-3" wrap near UINT64_MAX through the unsigned parse —
// used to instant-EOF when heading the list, or abort in updateWith's prune-all path via
// assert(segments.empty()) on PDT playlists: the 2026-07-06 on-device mid-stream SIGABRT);
// 0021 differentiates a route-change lost-queue (0019's intended fix) from a fresh open on
// a stream whose source has a systematic audio-video PTS offset — same "start deferred"
// magnitude (~36s on MLB Network via fullent) but opposite fix, so a distinct log message
// ("skywave-avsb: initial start skew N ms") lets the app skip the reconnect that only
// thrashes stream-property offsets. 0022 fixes the same class of desync at the DEMUX layer
// (not aout): detects the first video-audio PES PTS diff in EITHER es_out.c (raw TS) OR
// FakeESOut (adaptive HLS) and applies i_audio_delay / an inline PTS shift to compensate,
// so MLB Network plays synced from open — no 36s silent-video wait, no user notice.
// URL + checksum track the release.
let vlcBinary = Target.binaryTarget(
    name: "VLCKit",
    url: "https://github.com/jdistler/skywave-vlckit/releases/download/patched-16/VLCKit.xcframework.zip",
    checksum: "8595d3c8a9a85cbcd23f22598b3c2f1409748738d6f0496fee1c3b2770ebb4b6"
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
