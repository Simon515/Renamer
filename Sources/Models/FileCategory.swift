import Foundation
import UniformTypeIdentifiers

/// 文件分类枚举
enum FileCategory: String, CaseIterable, Codable, Sendable {
    case document = "Documents"
    case image = "Images"
    case video = "Videos"
    case archive = "Archives"
    case application = "Applications"
    case other = "Others"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .document: "doc.text"
        case .image: "photo"
        case .video: "video"
        case .archive: "archivebox"
        case .application: "app.dashed"
        case .other: "questionmark.folder"
        }
    }
    
    /// 返回分类对应的子目录名
    var folderName: String { rawValue }
}
