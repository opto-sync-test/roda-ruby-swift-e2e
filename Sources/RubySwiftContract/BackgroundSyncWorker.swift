import Foundation
#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

public struct SyncLane: Sendable {
    public let name: String
    public let baseJSON: Data
    public let incomingJSON: Data

    public init(name: String, base: [String: Any], incoming: [String: Any]) throws {
        self.name = name
        self.baseJSON = try JSONSerialization.data(withJSONObject: base)
        self.incomingJSON = try JSONSerialization.data(withJSONObject: incoming)
    }

    fileprivate func dictionaries() throws -> ([String: Any], [String: Any]) {
        guard
            let base = try JSONSerialization.jsonObject(with: baseJSON) as? [String: Any],
            let incoming = try JSONSerialization.jsonObject(with: incomingJSON) as? [String: Any]
        else {
            throw URLError(.cannotParseResponse)
        }
        return (base, incoming)
    }
}

public struct SyncLaneResponse: Sendable {
    public let name: String
    public let body: Data
}

/// Bounded worker core shared by BGTaskScheduler, a macOS task, or a desktop
/// process. A wake multiplexes independent lanes and replays the immutable
/// batch when any response is lost.
public struct BackgroundSyncWorker: Sendable {
    public let gateway: MergeGateway
    public let maxAttempts: Int
    public let retryDelayNanoseconds: UInt64

    public init(
        gateway: MergeGateway,
        maxAttempts: Int = 8,
        retryDelayNanoseconds: UInt64 = 100_000_000
    ) {
        precondition(maxAttempts > 0)
        self.gateway = gateway
        self.maxAttempts = maxAttempts
        self.retryDelayNanoseconds = retryDelayNanoseconds
    }

    public func drain(_ lanes: [SyncLane]) async throws -> [SyncLaneResponse] {
        guard !lanes.isEmpty else { return [] }
        precondition(Set(lanes.map(\.name)).count == lanes.count)

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await withThrowingTaskGroup(of: SyncLaneResponse.self) { group in
                    for lane in lanes {
                        group.addTask {
                            let (base, incoming) = try lane.dictionaries()
                            let (body, response) = try await gateway.merge(
                                base: base,
                                incoming: incoming
                            )
                            guard response.statusCode == 200 else {
                                throw URLError(.badServerResponse)
                            }
                            return SyncLaneResponse(name: lane.name, body: body)
                        }
                    }
                    var responses: [SyncLaneResponse] = []
                    for try await response in group {
                        responses.append(response)
                    }
                    return responses.sorted { $0.name < $1.name }
                }
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: retryDelayNanoseconds)
                }
            }
        }
        throw lastError ?? URLError(.unknown)
    }
}

#if canImport(BackgroundTasks)
@available(iOS 13.0, macOS 10.15, *)
public enum AppleBackgroundSyncRegistration {
    public static func register(
        identifier: String,
        operation: @escaping @Sendable () async -> Bool
    ) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            Task {
                task.setTaskCompleted(success: await operation())
            }
        }
    }
}
#endif
