import Foundation

/// Remi via the backend (`POST /explorer/stylist`). The server validates input and output;
/// the app validates again (unknown values are dropped by `AvatarPatch` decoding) and falls
/// back to the on-device rules if the backend can't be reached.
final class RemoteStylistService: StylistServicing {
    private let client: BackendClient
    private let fallback = MockStylistService()

    init(client: BackendClient) { self.client = client }

    func reply(to message: String, current: AvatarLook, history: [StylistTurn]) async -> StylistReply {
        let text = StylistGuard.cleanInput(message)
        if StylistGuard.containsPersonalInfo(text) {
            return StylistReply(text: StylistGuard.privacyReply, patch: AvatarPatch(), suggestsConfirm: false)
        }
        struct Body: Encodable { let message: String; let look: AvatarLook; let history: [StylistTurn] }
        struct Wire: Decodable { let reply: String; let patch: AvatarPatch; let confirm: Bool? }
        do {
            let wire: Wire = try await client.send("POST", "explorer/stylist", body: Body(message: text, look: current, history: Array(history.suffix(6))))
            return StylistReply(text: StylistGuard.cleanReply(wire.reply), patch: wire.patch, suggestsConfirm: wire.confirm ?? false)
        } catch {
            return await fallback.reply(to: text, current: current, history: history)
        }
    }
}

/// The shared Community Park on the backend (`/explorer/park`, Upstash Redis).
/// Players are identified by a hash of their account on the server; no names are shared.
final class RemoteCommunityParkService: CommunityParkServicing {
    private let client: BackendClient
    private let auth: AuthServicing
    private let fallback = MockCommunityParkService()

    init(client: BackendClient, auth: AuthServicing) {
        self.client = client
        self.auth = auth
    }

    private var headers: [String: String] {
        auth.currentUser.map { ["X-User-Id": $0.email] } ?? [:]
    }

    func status() async -> ParkStatus {
        if let status: ParkStatus = try? await client.send("GET", "explorer/park", headers: headers) { return status }
        return await fallback.status()
    }

    func contribute(points: Int) async throws -> ParkStatus {
        do {
            return try await client.send("POST", "explorer/park/contribute", body: ["points": points], headers: headers)
        } catch let error as BackendError {
            throw ServiceError.network(error.message)
        }
    }
}
