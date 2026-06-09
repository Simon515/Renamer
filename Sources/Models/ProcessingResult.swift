import Foundation

/// 批量处理结果汇总
struct ProcessingResult: Sendable {
    let totalFiles: Int
    var renamedCount: Int
    var skippedCount: Int
    var errorCount: Int
    var errors: [String]
    var logs: [String]
    var rollbackMap: [UUID: URL]  // fileID → originalURL for rollback

    init(
        totalFiles: Int = 0,
        renamedCount: Int = 0,
        skippedCount: Int = 0,
        errorCount: Int = 0,
        errors: [String] = [],
        logs: [String] = [],
        rollbackMap: [UUID: URL] = [:]
    ) {
        self.totalFiles = totalFiles
        self.renamedCount = renamedCount
        self.skippedCount = skippedCount
        self.errorCount = errorCount
        self.errors = errors
        self.logs = logs
        self.rollbackMap = rollbackMap
    }
}

/// 导出目标描述
struct ExportTarget: Identifiable, Sendable, Hashable {
    let id: UUID
    let name: String
    let pluginID: String
    let isAvailable: Bool

    init(
        id: UUID = UUID(),
        name: String,
        pluginID: String,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.name = name
        self.pluginID = pluginID
        self.isAvailable = isAvailable
    }
}
