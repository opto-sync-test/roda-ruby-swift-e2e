import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import OptoSyncClient

public struct MergeGateway: Sendable {
    public let client: OptoSyncClient.Client

    public init(client: OptoSyncClient.Client) {
        self.client = client
    }

    public func merge(
        base: [String: Any],
        incoming: [String: Any]
    ) async throws -> (Data, HTTPURLResponse) {
        var request = URLRequest(url: client.baseURL.appendingPathComponent("merge"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        if let bearerToken = client.bearerToken {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "authorization")
        }
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["base": base, "incoming": incoming]
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, httpResponse)
    }
}
