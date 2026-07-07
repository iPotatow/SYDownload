import Foundation

public struct BridgeRequest: Codable, Sendable {
    public let id: UUID
    public let command: String
    public let url: String?
    public let outputDirectory: String?
    public let engine: String?
    public let settingsJSON: String?
    public let timeoutSeconds: Double?

    public init(
        id: UUID = UUID(),
        command: String,
        url: String? = nil,
        outputDirectory: String? = nil,
        engine: String? = nil,
        settingsJSON: String? = nil,
        timeoutSeconds: Double? = nil
    ) {
        self.id = id
        self.command = command
        self.url = url
        self.outputDirectory = outputDirectory
        self.engine = engine
        self.settingsJSON = settingsJSON
        self.timeoutSeconds = timeoutSeconds
    }
}

public struct BridgeProgressEvent: Codable, Sendable {
    public let id: UUID?
    public let event: String
    public let message: String
    public let progress: Double?
    public let bytesWritten: Int64?
    public let fileCount: Int?

    public init(
        id: UUID? = nil,
        event: String = "progress",
        message: String,
        progress: Double? = nil,
        bytesWritten: Int64? = nil,
        fileCount: Int? = nil
    ) {
        self.id = id
        self.event = event
        self.message = message
        self.progress = progress
        self.bytesWritten = bytesWritten
        self.fileCount = fileCount
    }
}

public struct BridgeResponse: Codable, Sendable {
    public let id: UUID?
    public let ok: Bool
    public let platform: DownloadPlatform?
    public let message: String
    public let details: [String: String]?

    public init(
        id: UUID? = nil,
        ok: Bool,
        platform: DownloadPlatform? = nil,
        message: String,
        details: [String: String]? = nil
    ) {
        self.id = id
        self.ok = ok
        self.platform = platform
        self.message = message
        self.details = details
    }
}
