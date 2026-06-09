import Foundation

/// 导出插件协议 — 为 DEVONthink / Photos 等应用的集成预留
protocol ExportPluginProtocol: AnyObject, Sendable {
    var pluginName: String { get }
    var pluginIdentifier: String { get }
    var supportedCategories: Set<FileCategory> { get }
    
    /// 验证目标应用是否可用
    func isAvailable() -> Bool
    
    /// 导出文件到目标应用
    func export(_ files: [FileItem], progress: @escaping @Sendable (Double) -> Void) async throws
}

/// 内建：按分类整理到文件夹（导入到子目录）
final class FolderSortPlugin: ExportPluginProtocol, @unchecked Sendable {
    let pluginName = "文件夹分类整理"
    let pluginIdentifier = "com.renamer.foldersort"
    let supportedCategories: Set<FileCategory> = Set(FileCategory.allCases)
    
    func isAvailable() -> Bool { true }
    
    func export(_ files: [FileItem], progress: @escaping @Sendable (Double) -> Void) async throws {
        let service = ClassificationService()
        guard let root = files.first?.url.deletingLastPathComponent() else { return }
        let result = try await service.classifyFiles(files, rootDirectory: root)
        progress(1.0)
    }
}
