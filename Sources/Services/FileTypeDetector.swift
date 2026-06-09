import Foundation
import UniformTypeIdentifiers

/// 文件类型检测器 — 基于 UTType 层次关系判定文件分类
struct FileTypeDetector: Sendable {

    /// 需要跳过的目录名
    private static let excludedDirNames: Set<String> = [
        ".git", ".svn", ".hg",
        ".DS_Store", "__MACOSX",
        "node_modules", ".Trash",
        ".fseventsd", ".Spotlight-V100",
        ".TemporaryItems"
    ]

    /// 需要跳过的文件扩展名
    private static let excludedExtensions: Set<String> = [
        "ds_store", "localized", "tmp", "temp"
    ]

    /// 判定文件的 FileCategory
    func detectCategory(for url: URL, utType: UTType?) -> FileCategory {
        guard let utType else {
            return inferFromExtension(url.pathExtension)
        }

        // 遵循 UTType 层次结构判定
        if utType.conforms(to: .image) || utType.conforms(to: .rawImage) {
            return .image
        }
        if utType.conforms(to: .movie) || utType.conforms(to: .video) {
            return .video
        }
        if utType.conforms(to: .archive) || utType.conforms(to: .diskImage) {
            return .archive
        }
        if utType.conforms(to: .application) || utType.conforms(to: .executable) {
            return .application
        }
        if utType.conforms(to: .text) || utType.conforms(to: .pdf)
            || utType.conforms(to: .presentation) || utType.conforms(to: .spreadsheet) {
            return .document
        }

        // 常见文档类型的补充判定
        if isDocumentType(utType) {
            return .document
        }

        return .other
    }

    /// 是否应排除此 URL（隐藏文件、系统文件等）
    func shouldExclude(url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix(".") else { return true }

        let ext = url.pathExtension.lowercased()
        guard !Self.excludedExtensions.contains(ext) else { return true }

        // 检查路径中是否包含排除目录
        let pathComponents = url.pathComponents
        for component in pathComponents {
            if Self.excludedDirNames.contains(component) {
                return true
            }
        }

        return false
    }

    // MARK: - Private

    private func isDocumentType(_ utType: UTType) -> Bool {
        // Office 文档扩展名
        let officeExtensions = ["doc", "docx", "xls", "xlsx", "ppt", "pptx"]
        for ext in officeExtensions {
            if let officeType = UTType(filenameExtension: ext),
               utType.conforms(to: officeType) {
                return true
            }
        }

        // RTF, HTML
        if let rtfType = UTType(filenameExtension: "rtf"), utType.conforms(to: rtfType) {
            return true
        }
        if let htmlType = UTType(filenameExtension: "html"), utType.conforms(to: htmlType) {
            return true
        }

        return false
    }

    private func inferFromExtension(_ ext: String) -> FileCategory {
        let lower = ext.lowercased()

        // 文档类
        let docExtensions: Set<String> = [
            "pdf", "txt", "md", "rtf", "rtfd", "html", "htm",
            "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "pages", "numbers", "key",
            "csv", "json", "xml", "yaml", "yml",
            "tex", "latex", "odt", "ods", "odp"
        ]

        // 图片类
        let imgExtensions: Set<String> = [
            "jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif",
            "heic", "heif", "webp", "raw", "cr2", "nef", "arw",
            "dng", "ico", "icns", "svg", "psd", "ai", "eps"
        ]

        // 视频类
        let vidExtensions: Set<String> = [
            "mp4", "mov", "avi", "mkv", "wmv", "flv",
            "m4v", "mpg", "mpeg", "3gp", "webm", "ogv"
        ]

        // 归档类
        let archExtensions: Set<String> = [
            "zip", "rar", "7z", "tar", "gz", "bz2", "xz",
            "dmg", "iso", "pkg", "tgz", "tbz"
        ]

        // 应用类
        let appExtensions: Set<String> = [
            "app", "dmg", "pkg", "framework", "bundle", "saver", "prefPane"
        ]

        if docExtensions.contains(lower) { return .document }
        if imgExtensions.contains(lower) { return .image }
        if vidExtensions.contains(lower) { return .video }
        if archExtensions.contains(lower) { return .archive }
        if appExtensions.contains(lower) { return .application }

        return .other
    }
}
