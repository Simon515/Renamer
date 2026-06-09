import Foundation
import UniformTypeIdentifiers

/// 文件扫描器 — 递归遍历目录生成 FileItem 列表
struct FileScanner: Sendable {

    private let typeDetector = FileTypeDetector()

    /// 并发扫描多个文件夹，返回所有文件列表
    func scanFolders(_ folderURLs: [URL]) async throws -> [FileItem] {
        var allFiles: [FileItem] = []

        // 使用 TaskGroup 并发扫描多个文件夹
        try await withThrowingTaskGroup(of: [FileItem].self) { group in
            for url in folderURLs {
                let detector = typeDetector
                group.addTask {
                    try Self.scanSingleFolder(url, typeDetector: detector)
                }
            }

            for try await files in group {
                allFiles.append(contentsOf: files)
            }
        }

        return allFiles.sorted { $0.fileName.localizedStandardCompare($1.fileName) == .orderedAscending }
    }

    /// 同步扫描单个文件夹（在 Task 内调用，FileManager 在方法内局部创建）
    nonisolated
    static func scanSingleFolder(
        _ folderURL: URL,
        typeDetector: FileTypeDetector
    ) throws -> [FileItem] {
        let fileManager = FileManager.default
        var files: [FileItem] = []

        let resourceKeys: Set<URLResourceKey> = [
            .isRegularFileKey, .isDirectoryKey,
            .fileSizeKey, .contentModificationDateKey,
            .creationDateKey, .typeIdentifierKey
        ]

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants, .skipsHiddenFiles],
            errorHandler: { url, error in
                print("[FileScanner] Warning: \(url.lastPathComponent): \(error.localizedDescription)")
                return true
            }
        ) else {
            throw FileScannerError.cannotEnumerate(folderURL)
        }

        for case let fileURL as URL in enumerator {
            // 检查是否应排除
            guard !typeDetector.shouldExclude(url: fileURL) else {
                continue
            }

            // 获取资源属性
            guard let resourceValues = try? fileURL.resourceValues(forKeys: resourceKeys),
                  resourceValues.isRegularFile == true else {
                continue
            }

            let fileName = fileURL.lastPathComponent
            let fileExtension = fileURL.pathExtension
            let fileSize = Int64(resourceValues.fileSize ?? 0)
            let modDate = resourceValues.contentModificationDate
            let createDate = resourceValues.creationDate

            // UTI 类型
            let utiType: UTType?
            if let typeIdentifier = resourceValues.typeIdentifier {
                utiType = UTType(typeIdentifier)
            } else {
                utiType = UTType(filenameExtension: fileExtension)
            }

            let category = typeDetector.detectCategory(for: fileURL, utType: utiType)

            let fileItem = FileItem(
                url: fileURL,
                fileName: fileName,
                fileExtension: fileExtension,
                utiType: utiType,
                fileSize: fileSize,
                category: category,
                modificationDate: modDate,
                creationDate: createDate
            )

            files.append(fileItem)
        }

        return files
    }
}

// MARK: - Errors

enum FileScannerError: LocalizedError {
    case cannotEnumerate(URL)

    var errorDescription: String? {
        switch self {
        case .cannotEnumerate(let url):
            "无法扫描目录: \(url.lastPathComponent)"
        }
    }
}
