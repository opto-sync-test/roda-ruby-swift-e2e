import Foundation
import XCTest
import OptoSyncClient
@testable import RubySwiftContract

final class MergeGatewayTests: XCTestCase {
    func testOfficialSwiftClientCrossesRodaAndReachesTheCCore() async throws {
        let endpoint = ProcessInfo.processInfo.environment["OPTO_SYNC_ENDPOINT"]
            ?? "http://127.0.0.1:9292"
        let client = OptoSyncClient.Client(
            baseURL: try XCTUnwrap(URL(string: endpoint)),
            bearerToken: "e2e-token"
        )
        let gateway = MergeGateway(client: client)

        let (data, response) = try await gateway.merge(
            base: [
                "id": "doc-1",
                "profile": ["server": "kept"],
                "items": [["id": "a", "server": true]]
            ],
            incoming: [
                "profile": ["client": "kept"],
                "items": [["id": "a", "client": true]]
            ]
        )
        XCTAssertEqual(response.statusCode, 200, String(decoding: data, as: UTF8.self))

        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let coreVersion = try XCTUnwrap(body["core_version"] as? String)
        XCTAssertNotNil(coreVersion.range(of: #"^\d+\.\d+\.\d+$"#, options: .regularExpression))

        let merged = try XCTUnwrap(body["merged"] as? [String: Any])
        let profile = try XCTUnwrap(merged["profile"] as? [String: Any])
        XCTAssertEqual(profile["server"] as? String, "kept")
        XCTAssertEqual(profile["client"] as? String, "kept")
        let items = try XCTUnwrap(merged["items"] as? [[String: Any]])
        XCTAssertEqual(items.first?["server"] as? Bool, true)
        XCTAssertEqual(items.first?["client"] as? Bool, true)
    }

    func testBackgroundWorkerMultiplexesMobileAndDesktopLanes() async throws {
        let endpoint = ProcessInfo.processInfo.environment["OPTO_SYNC_ENDPOINT"]
            ?? "http://127.0.0.1:9292"
        let gateway = MergeGateway(
            client: OptoSyncClient.Client(
                baseURL: try XCTUnwrap(URL(string: endpoint)),
                bearerToken: "e2e-token"
            )
        )
        let worker = BackgroundSyncWorker(gateway: gateway)
        let responses = try await worker.drain([
            try SyncLane(
                name: "ios-bg-task",
                base: ["id": "doc-1", "profile": ["server": "kept"]],
                incoming: ["profile": ["mobile": "background"]]
            ),
            try SyncLane(
                name: "macos-desktop-task",
                base: ["id": "doc-2", "profile": ["server": "kept"]],
                incoming: ["profile": ["desktop": "background"]]
            ),
        ])

        XCTAssertEqual(responses.map(\.name), ["ios-bg-task", "macos-desktop-task"])
        let bodies = try Dictionary(uniqueKeysWithValues: responses.map { response in
            (
                response.name,
                try XCTUnwrap(
                    JSONSerialization.jsonObject(with: response.body) as? [String: Any]
                )
            )
        })
        let mobile = try XCTUnwrap(bodies["ios-bg-task"]?["merged"] as? [String: Any])
        let mobileProfile = try XCTUnwrap(mobile["profile"] as? [String: Any])
        XCTAssertEqual(mobileProfile["mobile"] as? String, "background")
        let desktop = try XCTUnwrap(bodies["macos-desktop-task"]?["merged"] as? [String: Any])
        let desktopProfile = try XCTUnwrap(desktop["profile"] as? [String: Any])
        XCTAssertEqual(desktopProfile["desktop"] as? String, "background")
    }
}
