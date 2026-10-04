import XCTest
@testable import Cats_Dogs

@MainActor
final class RadarTests: XCTestCase {
    func testParsesHostAndMergesPastThenNowcastInChronologicalOrder() throws {
        let body = """
        {
          "host": "https://tilecache.rainviewer.com",
          "radar": {
            "past": [
              { "time": 100, "path": "/v2/radar/100" },
              { "time": 200, "path": "/v2/radar/200" }
            ],
            "nowcast": [ { "time": 300, "path": "/v2/radar/nowcast_300" } ]
          }
        }
        """

        let timeline = try RadarRepository.parseTimeline(Data(body.utf8))

        XCTAssertEqual(timeline.host, "https://tilecache.rainviewer.com")
        XCTAssertEqual(timeline.frames.map(\.timeEpochSeconds), [100, 200, 300])
        // Past frames are observed; the nowcast frame is a forecast.
        XCTAssertEqual(timeline.frames.map(\.isForecast), [false, false, true])
    }

    /// RainViewer currently returns no nowcast frames at all; past frames alone must still work.
    func testAcceptsAPayloadWithNoNowcast() throws {
        let body = """
        { "host": "https://tilecache.rainviewer.com", "radar": { "past": [ { "time": 100, "path": "/a" } ] } }
        """

        XCTAssertEqual(try RadarRepository.parseTimeline(Data(body.utf8)).frames.count, 1)
    }

    func testBuildsARainViewerTileURLFromHostPathAndTileCoordinates() throws {
        let body = """
        { "host": "https://tilecache.rainviewer.com", "radar": { "past": [ { "time": 100, "path": "/v2/radar/100" } ], "nowcast": [] } }
        """
        let timeline = try RadarRepository.parseTimeline(Data(body.utf8))
        let zoom = RadarTimeline.maxZoom

        let url = timeline.tileURL(for: timeline.frames[0], z: zoom, x: 34, y: 50)

        XCTAssertEqual(url, "https://tilecache.rainviewer.com/v2/radar/100/256/\(zoom)/34/50/4/1_1.png")
    }

    func testThrowsWhenThereAreNoFrames() {
        let body = """
        { "host": "https://tilecache.rainviewer.com", "radar": { "past": [], "nowcast": [] } }
        """

        XCTAssertThrowsError(try RadarRepository.parseTimeline(Data(body.utf8))) { error in
            XCTAssertEqual(error as? RadarError, .empty)
        }
    }

    func testThrowsOnAMalformedPayload() {
        XCTAssertThrowsError(try RadarRepository.parseTimeline(Data("not json".utf8)))
    }

    // MARK: - RadarViewModel

    private let sampleTimeline = RadarTimeline(
        host: "https://example.com",
        frames: [RadarFrame(timeEpochSeconds: 1, path: "/a", isForecast: false)]
    )

    func testLoadsTheTimelineOnceAndIgnoresLaterLoads() async {
        let calls = Counter()
        let timeline = sampleTimeline
        let viewModel = RadarViewModel(fetchTimeline: {
            await calls.increment()
            return timeline
        })

        viewModel.load()
        viewModel.load()
        await waitUntil { viewModel.timeline.successValue != nil }
        viewModel.load()
        await settle()

        XCTAssertEqual(viewModel.timeline, .success(sampleTimeline))
        let count = await calls.value
        XCTAssertEqual(count, 1)
    }

    func testAFailedLoadShowsARetryableErrorAndRetryRecovers() async {
        let shouldFail = Flag(true)
        let timeline = sampleTimeline
        let viewModel = RadarViewModel(fetchTimeline: {
            if await shouldFail.value { throw RadarError.network }
            return timeline
        })

        viewModel.load()
        await waitUntil { viewModel.timeline != .loading }
        XCTAssertEqual(viewModel.timeline, .error(errorKey: "radar_unavailable", canRetry: true))

        await shouldFail.set(false)
        viewModel.retry()
        await waitUntil { viewModel.timeline.successValue != nil }
    }
}

private actor Counter {
    private(set) var value = 0
    func increment() { value += 1 }
}

private actor Flag {
    private(set) var value: Bool
    init(_ value: Bool) { self.value = value }
    func set(_ newValue: Bool) { value = newValue }
}
