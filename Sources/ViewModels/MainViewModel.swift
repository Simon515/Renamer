import Foundation
import Observation
import SwiftUI

/// 主视图模型 — 管理全部应用状态
@MainActor
@Observable
final class MainViewModel {
    
    // MARK: - State
    
    enum AppPhase: Sendable {
        case empty
        case foldersSelected
        case scanning
        case previewReady
        case processing
        case completed
        case classifying
    }
    
    var phase: AppPhase = .empty
    
    // 选择的文件夹
    var selectedFolders: [URL] = [] {
        didSet {
            if selectedFolders.isEmpty { phase = .empty }
            else { phase = .foldersSelected }
        }
    }
    
    // 扫描结果
    var files: [FileItem] = []
    
    // 重命名建议
    var suggestions: [RenameSuggestion] = []
    
    // 处理进度
    var progress: Double = 0.0
    var currentStep: String = ""
    var logs: [String] = []
    
    // 结果
    var renameResult: ProcessingResult?
    var classifyResult: ProcessingResult?
    
    // 统计
    var totalFiles: Int { files.count }
    var documentsCount: Int { files.filter { $0.category == .document }.count }
    var imagesCount: Int { files.filter { $0.category == .image }.count }
    var videosCount: Int { files.filter { $0.category == .video }.count }
    var othersCount: Int { totalFiles - documentsCount - imagesCount - videosCount }
    
    var confirmedCount: Int { suggestions.filter { $0.isConfirmed && !$0.isRejected }.count }
    var rejectedCount: Int { suggestions.filter { $0.isRejected }.count }
    var pendingCount: Int { suggestions.filter { !$0.isConfirmed && !$0.isRejected }.count }
    
    // 错误
    var errorMessage: String?
    
    // MARK: - Services
    
    private let processor = BatchProcessor()
    
    // MARK: - Actions
    
    /// 开始扫描所选文件夹
    func startScan() async {
        guard !selectedFolders.isEmpty else { return }
        
        phase = .scanning
        progress = 0
        logs.removeAll()
        suggestions.removeAll()
        renameResult = nil
        classifyResult = nil
        errorMessage = nil
        
        do {
            let result = try await processor.process(folders: selectedFolders) { [weak self] progress, step in
                Task { @MainActor in
                    self?.progress = progress
                    self?.currentStep = step
                }
            }
            
            files = result.files
            suggestions = result.suggestions
            
            // 默认全部确认
            for i in suggestions.indices {
                suggestions[i].isConfirmed = true
            }
            
            phase = .previewReady
            progress = 1.0
            currentStep = "扫描完成 — 共 \(files.count) 个文件"
            
        } catch {
            errorMessage = error.localizedDescription
            phase = .empty
        }
    }
    
    /// 确认/拒绝单条建议
    func toggleConfirmation(for suggestionID: UUID) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        if suggestions[index].isRejected {
            suggestions[index].isRejected = false
            suggestions[index].isConfirmed = true
        } else if suggestions[index].isConfirmed {
            suggestions[index].isConfirmed = false
            suggestions[index].isRejected = true
        } else {
            suggestions[index].isConfirmed = true
        }
    }
    
    /// 确认全部
    func confirmAll() {
        for i in suggestions.indices where !suggestions[i].isRejected {
            suggestions[i].isConfirmed = true
        }
    }
    
    /// 拒绝全部
    func rejectAll() {
        for i in suggestions.indices {
            suggestions[i].isConfirmed = false
            suggestions[i].isRejected = true
        }
    }
    
    /// 编辑单条建议名
    func updateSuggestionName(_ suggestionID: UUID, newName: String) {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestionID }) else { return }
        suggestions[index].suggestedName = newName
    }
    
    /// 执行重命名
    func executeRename() async {
        guard phase == .previewReady, confirmedCount > 0 else { return }
        
        phase = .processing
        progress = 0
        logs.removeAll()
        
        do {
            // 验证
            let dir = selectedFolders.first!
            let validated = await processor.validate(suggestions: suggestions, in: dir)
            suggestions = validated
            
            // 执行
            let result = try await processor.executeRenames(suggestions: suggestions, in: dir)
            renameResult = result
            logs = result.logs
            phase = .completed
            progress = 1.0
            currentStep = "重命名完成 — 成功 \(result.renamedCount) / \(result.totalFiles)"
            
        } catch {
            errorMessage = error.localizedDescription
            phase = .previewReady
        }
    }
    
    /// 执行分类整理
    func executeClassify() async {
        guard !files.isEmpty else { return }
        
        phase = .classifying
        progress = 0
        logs.removeAll()
        
        do {
            let dir = selectedFolders.first!
            let result = try await processor.classify(files: files, in: dir)
            classifyResult = result
            logs.append(contentsOf: result.logs)
            phase = .completed
            progress = 1.0
            currentStep = "分类完成 — \(result.renamedCount) 个文件已整理"
            
        } catch {
            errorMessage = error.localizedDescription
            phase = .completed
        }
    }
    
    /// 回滚重命名
    func rollback() async {
        let result = await processor.rollback()
        renameResult = result
        logs = result.logs
    }
    
    /// 重置
    func reset() {
        phase = selectedFolders.isEmpty ? .empty : .foldersSelected
        files.removeAll()
        suggestions.removeAll()
        progress = 0
        currentStep = ""
        logs.removeAll()
        renameResult = nil
        classifyResult = nil
        errorMessage = nil
    }
    
    /// 清空文件夹选择
    func clearFolders() {
        selectedFolders.removeAll()
        reset()
    }
}
