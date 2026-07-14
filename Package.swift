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
// thrashes stream-property offsets. 0022 detects the panel-side +36s audio-ahead labelling
// at the DEMUX layer (both raw TS via es_out.c AND adaptive HLS via FakeESOut). On TS it
// also passes the offset via EsOutSetDelay(-diff) as a drift-correction hint (stops the
// resampler from speeding audio up to catch imaginary lateness — the actual desync fix on
// the tape-delayed MLB feed). Both sites fire "skywave-avdiff" so the app's overlay
// (AudioCatchingUpOverlay) mounts on both transports.
// 0023 rejects a spliced outlier PCR at the input clock: some Xtream restream transcoders
// splice a stale near-max-33-bit PCR into an ongoing stream (verified strong RC: ECDF
// 2026-07-12), and VLC's default stream_diff<0 recovery re-anchors on the outlier via
// SetFirstPcr, permanently freezing the pipeline ('new clock context(1) @95443017689',
// kVTVideoDecoderBadDataErr). Now: if abs(new_PCR - cl->last.stream) > 10s once
// b_has_reference is set, drop the sample and keep the running reference; safety valve
// caps consecutive rejects at 10 so a real clock re-base still re-anchors. Marker line
// "skywave-stale-pcr:" for VLCLogTap. (Refined to asymmetric bounds: back 10s / fwd 60s.)
// 0024 caps 0022's avdiff tape-delay compensation to a plausible 3-60s window (fullent loop
// channels stamp video/audio PES ~105s apart though the content plays together; uncapped 0022
// set a bogus +105s audio_delay).
// 0025 drops a garbage 33-bit-max PCR spike at the DEMUX (ts.c PCRHandle), upstream of 0023.
// The 'side' panel emits ONE spurious PCR at the 33-bit maximum (~95443s) at an encoder
// restart, then resets PCR+PES to ~0; the spike poisons pcr.i_current (the wrap reference)
// so the 0-based reset false-detects as a rollover and TimeStampWrapAround unwraps ONLY the
// PCR to ~95443s+ while the PES stay near 0 — a permanent divergence that froze every side
// channel 11-23s in. 0023 can't help (poison is in the demux, one layer up). Fix drops the
// forward outlier before it updates pcr.i_current (streak-valved, forward-only). Marker
// "skywave-ts-pcr-spike:". Found by the deep panelfuzz campaign 2026-07-13.
// 0026 accepts a COHERENT re-based timeline after 2 consistent rejects: 0023's blind
// 10-reject valve made the side panel's encoder restarts cost ~12s of dropped video
// (~7s past the cache runway = user-visible freeze). A genuine re-base's rejected
// samples advance in lockstep with system time; two coherent rejects re-anchor the 3rd
// sample (~2.4s — inside the cache, zero visible outage). Marker "coherent new timeline".
// 0027 applies ts.c's broken-stream pcroffset PER-PID: it was computed from one ES and
// applied program-wide, so on muxes stamping audio/video bases minutes apart (fullent
// coarse-avbase: audio dts = PCR-240s, video ≈ PCR, content interleaved in real time)
// it pushed healthy video 240s into the future — frozen video, playing audio, all watch.
// Now only a pid whose own dts is below the PCR gets lifted. Marker
// "skywave-pcroffset-exempt". Both found by deep panelfuzz round 2, 2026-07-13.
// 0028 fixes the fullent HLS frozen-video class (6 channels wedged ~10s in, audio playing
// on, while raw TS played clean — found by the first HLS-transport panelfuzz round):
// (a) ts.c drops a garbage ~0x1FFFFFFFF FIRST PCR (the same 33-bit-max transcoder
// signature as the side/trex mid-stream spikes — 4th panel confirmed) that otherwise
// poisons the era and forces stock VLC's +26h pcroffset kludge; (b) FakeESOut's
// force-playlist (0015) jump test/re-anchor target now uses an all-outputs high-water
// (fp_last_any) so a PCR-STARVED mux (~1 PCR per 10s segment) can't spuriously re-anchor
// the next segment backward onto already-played time. Backward test stays vs the
// PCR-only mark (per-ES re-anchor runaway stays fixed). Markers: "skywave-ts-pcr-spike:
// dropping near-max FIRST PCR". Deterministic fixture: streamlab dailyshow-hls-wedge.
// 0029 extends 0028's first-PCR guard to drop the whole LEADING near-max ramp at open
// (some transcoders emit ~9 ceiling PCRs 95443.0->95443.7 before resetting to 0, not a
// single spike): 0028's one-shot drop let the 2nd ramp sample latch the garbage
// reference, and the broken-stream pcroffset pushed VIDEO 26h into the future — froze
// video at the initial GOP (audio playing on) on 20+ fullent loop channels over raw TS.
// Drops the whole ramp (capped 64 — the patch audit population-scanned 120 captures:
// ramps run to 18, and freeze-vs-survive on a partial drop is PES-interleaving luck).
// Fixture streamlab fullent/pcr-ceiling-ramp (the proven-freezing capture).
// URL + checksum track the release.
let vlcBinary = Target.binaryTarget(
    name: "VLCKit",
    url: "https://github.com/jdistler/skywave-vlckit/releases/download/patched-26/VLCKit.xcframework.zip",
    checksum: "51dcc720ed643669c93ddabd84084b4b09214f31b88e7dbec82dd20c8e4dd614"
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
