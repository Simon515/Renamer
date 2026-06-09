import Foundation

/// 分类整理服务 — 根据 FileCategory 将文件整理到子目录
actor ClassificationService {
    
    private let fileManager = FileManager.default
    
    // MARK: - Public
    
    /// 在目标目录中按分类创建子目录并移动文件
    func classifyFiles(
        _ files: [FileItem],
        rootDirectory: URL,
        mode: ClassificationMode = .move
    ) async throws -> ProcessingResult {
        var result = ProcessingResult(totalFiles: files.count)
        
        // 创建分类子目录
        let categories = Set(files.map { $0.category })
        let folderMap = try createCategoryFolders(categories, in: rootDirectory)
        
        for file in files {
            guard let targetFolder = folderMap[file.category] else {
                result.errorCount += 1
                result.errors.append("无法确定目标目录: \(file.fileName)")
                continue
            }
            
            let sourceURL = file.url
            let targetURL = targetFolder.appendingPathComponent(file.fileName)
            
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                result.errorCount += 1
                result.errors.append("源文件不存在: \(file.fileName)")
                continue
            }
            
            // 处理目标文件已存在的情况
            var finalTarget = targetURL
            var counter = 1
            while fileManager.fileExists(atPath: finalTarget.path) {
                let base = (file.fileName as NSString).deletingPathExtension
                let ext = file.fileExtension
                let seq = String(format: "%02d", counter)
                let newName = ext.isEmpty ? "\(base)_\(seq)" : "\(base)_\(seq).\(ext)"
                finalTarget = targetFolder.appendingPathComponent(newName)
                counter += 1
            }
            
            do {
                switch mode {
                case .move:
                    try fileManager.moveItem(at: sourceURL, to: finalTarget)
                case .copy:
                    try fileManager.copyItem(at: sourceURL, to: finalTarget)
                }
                result.renamedCount += 1
                result.logs.append("→ \(file.fileName) → \(file.category.folderName)/")
            } catch {
                result.errorCount += 1
                result.errors.append("分类失败 [\(file.fileName)]: \(error.localizedDescription)")
            }
        }
        
        return result
    }
    
    // MARK: - Private
    
    private func createCategoryFolders(
        _ categories: Set<FileCategory>,
        in root: URL
    ) throws -> [FileCategory: URL] {
        var map: [FileCategory: URL] = [:]
        
        for category in categories {
            let folderURL = root.appendingPathComponent(category.folderName)
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
            map[category] = folderURL
        }
        
        return map
    }
}

// MARK: - Classification Mode

enum ClassificationMode: String, Sendable, CaseIterable {
    case move
    case copy
}
