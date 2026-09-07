import Foundation

public struct BridgeRequest: Codable, Sendable {
    public let id: UUID
    public let command: String
    public let url: String?
    public let outputDirectory: String?

    public init(
        id: UUID = UUID(),
        command: String,
        url: String? = nil,
        outputDirectory: String? = nil
    ) {
        self.id = id
        self.command = command
        self.url = url
        self.outputDirectory = outputDirectory
    }
}

public struct BridgeResponse: Codable, Sendable {
    public let id: UUID?
    public let ok: Bool
    public let platform: DownloadPlatform?
    public let message: String
    public let details: [String: String]?
}
