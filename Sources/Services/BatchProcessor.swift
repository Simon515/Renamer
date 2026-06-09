import Foundation

/// 批量处理编排器 — 协调 Scanner → Analyzer → RenameEngine → Classification 流水线
@MainActor
final class BatchProcessor: ObservableObject {
    
    private let scanner = FileScanner()
    private let metadataService = MetadataService()
    private let aiService = AIRenameService()
    private let renameEngine = RenameEngine()
    private let classificationService = ClassificationService()
    
    // MARK: - Progress
    
    enum Step: String, Sendable {
        case scanning = "扫描文件..."
        case analyzing = "分析内容..."
        case generatingSuggestions = "生成重命名建议..."
        case done = "完成"
    }
    
    /// 处理全流程：扫描 → 分析 → 生成建议
    func process(folders: [URL], onProgress: @escaping @Sendable (Double, String) -> Void) async throws -> BatchResult {
        let totalSteps = 3.0
        var step = 0.0
        
        // Step 1: 扫描
        onProgress(step / totalSteps, Step.scanning.rawValue)
        let files = try await scanner.scanFolders(folders)
        step += 1
        
        // Step 2: 提取元数据和分析
        onProgress(step / totalSteps, Step.analyzing.rawValue)
        
        // 按分类分组
        let docs = files.filter { $0.category == .document }
        let images = files.filter { $0.category == .image }
        let videos = files.filter { $0.category == .video }
        let others = files.filter { !["document", "image", "video"].contains($0.category.rawValue.lowercased()) || $0.category == .archive || $0.category == .application || $0.category == .other }
        
        // Step 3: 生成建议（并发）
        onProgress(step / totalSteps, Step.generatingSuggestions.rawValue)
        
        var allSuggestions: [RenameSuggestion] = []
        
        // 文档：AI 分析
        let docSuggestions = await aiService.generateSuggestions(for: docs)
        allSuggestions.append(contentsOf: docSuggestions)
        
        // 图片：元数据
        for file in images {
            let metadata = await metadataService.extractMetadata(for: file)
            let suggestion = metadataService.generateRenameSuggestion(for: file, metadata: metadata)
            allSuggestions.append(suggestion)
        }
        
        // 视频：元数据
        for file in videos {
            let metadata = await metadataService.extractMetadata(for: file)
            let suggestion = metadataService.generateRenameSuggestion(for: file, metadata: metadata)
            allSuggestions.append(suggestion)
        }
        
        // 其他：基于类型
        for file in others {
            let metadata = await metadataService.extractMetadata(for: file)
            let suggestion = metadataService.generateRenameSuggestion(for: file, metadata: metadata)
            allSuggestions.append(suggestion)
        }
        
        step += 1
        onProgress(1.0, Step.done.rawValue)
        
        return BatchResult(files: files, suggestions: allSuggestions)
    }
    
    /// 验证重命名建议
    func validate(suggestions: [RenameSuggestion], in directory: URL) async -> [RenameSuggestion] {
        await renameEngine.validateSuggestions(suggestions, in: directory)
    }
    
    /// 执行重命名
    func executeRenames(suggestions: [RenameSuggestion], in directory: URL) async throws -> ProcessingResult {
        try await renameEngine.executeRenames(suggestions, in: directory)
    }
    
    /// 执行分类整理
    func classify(files: [FileItem], in directory: URL) async throws -> ProcessingResult {
        try await classificationService.classifyFiles(files, rootDirectory: directory)
    }
    
    /// 回滚重命名
    func rollback() async -> ProcessingResult {
        await renameEngine.rollback()
    }
}

/// 批量处理中间结果
struct BatchResult: Sendable {
    let files: [FileItem]
    let suggestions: [RenameSuggestion]
}
