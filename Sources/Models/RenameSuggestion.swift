import Foundation

/// 重命名建议
struct RenameSuggestion: Identifiable, Sendable, Hashable {
    let id: UUID
    let fileID: UUID
    let originalName: String
    var suggestedName: String
    var confidence: Double  // 0.0 - 1.0
    var reason: String
    var isConfirmed: Bool
    var isRejected: Bool

    init(
        id: UUID = UUID(),
        fileID: UUID,
        originalName: String,
        suggestedName: String,
        confidence: Double = 0.0,
        reason: String = "",
        isConfirmed: Bool = false,
        isRejected: Bool = false
    ) {
        self.id = id
        self.fileID = fileID
        self.originalName = originalName
        self.suggestedName = suggestedName
        self.confidence = confidence
        self.reason = reason
        self.isConfirmed = isConfirmed
        self.isRejected = isRejected
    }
}
