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
}
