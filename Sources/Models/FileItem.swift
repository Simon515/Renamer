import Foundation
import UniformTypeIdentifiers

/// 文件实体，表示扫描到的单个文件
struct FileItem: Identifiable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let fileName: String
    let fileExtension: String
    let utiType: UTType?
    let fileSize: Int64
    var category: FileCategory
    var metadata: [String: String]
    let modificationDate: Date?
    let creationDate: Date?

    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String,
        fileExtension: String,
        utiType: UTType? = nil,
        fileSize: Int64,
        category: FileCategory = .other,
        metadata: [String: String] = [:],
        modificationDate: Date? = nil,
        creationDate: Date? = nil
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.utiType = utiType
        self.fileSize = fileSize
        self.category = category
        self.metadata = metadata
        self.modificationDate = modificationDate
        self.creationDate = creationDate
    }

    /// 不含扩展名的文件名
    var nameWithoutExtension: String {
        (fileName as NSString).deletingPathExtension
    }

    /// 人类可读的文件大小
    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
}
