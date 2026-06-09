import Foundation
import ImageIO
import AVFoundation
import UniformTypeIdentifiers

/// 元数据结构
struct FileMetadata: Sendable {
    var creationDate: Date?
    var modificationDate: Date?
    var cameraModel: String?
    var gpsLatitude: Double?
    var gpsLongitude: Double?
    var duration: TimeInterval?
    var imageWidth: Int?
    var imageHeight: Int?
    var author: String?
    var title: String?
    var keywords: [String]
    
    init() {
        keywords = []
    }
}

/// 统一元数据提取服务
struct MetadataService: Sendable {

    /// 根据文件分类提取元数据
    func extractMetadata(for item: FileItem) async -> FileMetadata {
        var metadata = FileMetadata()
        metadata.creationDate = item.creationDate
        metadata.modificationDate = item.modificationDate

        switch item.category {
        case .image:
            await extractImageMetadata(from: item.url, into: &metadata)
        case .video:
            await extractVideoMetadata(from: item.url, into: &metadata)
        default:
            extractSpotlightMetadata(from: item.url, into: &metadata)
        }

        return metadata
    }

    /// 批量提取元数据
    func extractBatch(for items: [FileItem]) async -> [UUID: FileMetadata] {
        var results: [UUID: FileMetadata] = [:]
        await withTaskGroup(of: (UUID, FileMetadata).self) { group in
            for item in items {
                group.addTask { [self] in
                    let meta = await extractMetadata(for: item)
                    return (item.id, meta)
                }
            }
            for await (id, meta) in group {
                results[id] = meta
            }
        }
        return results
    }

    // MARK: - Private

    private func extractImageMetadata(from url: URL, into metadata: inout FileMetadata) async {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return }

        // EXIF
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let dateString = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata.creationDate = parseEXIFDate(dateString)
            }
            metadata.cameraModel = exif[kCGImagePropertyExifLensModel as String] as? String
                ?? exif[kCGImagePropertyExifBodySerialNumber as String] as? String
        }

        // TIFF (contains camera make/model sometimes)
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if metadata.cameraModel == nil {
                let make = tiff[kCGImagePropertyTIFFMake as String] as? String ?? ""
                let model = tiff[kCGImagePropertyTIFFModel as String] as? String ?? ""
                if !make.isEmpty || !model.isEmpty {
                    metadata.cameraModel = "\(make) \(model)".trimmingCharacters(in: .whitespaces)
                }
            }
        }

        // GPS
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            metadata.gpsLatitude = gps[kCGImagePropertyGPSLatitude as String] as? Double
            metadata.gpsLongitude = gps[kCGImagePropertyGPSLongitude as String] as? Double
        }

        // Dimensions
        metadata.imageWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        metadata.imageHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
    }

    private func extractVideoMetadata(from url: URL, into metadata: inout FileMetadata) async {
        let asset = AVAsset(url: url)

        // 创建日期
        if let item = try? await asset.load(.creationDate) {
            metadata.creationDate = try? await item.load(.dateValue)
        }

        // 时长
        if let duration = try? await asset.load(.duration) {
            metadata.duration = CMTimeGetSeconds(duration)
        }

        // 通用元数据项
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    guard let key = item.commonKey else { continue }
                    switch key {
                    case .commonKeyArtist, .commonKeyAuthor:
                        metadata.author = try? await item.load(.stringValue)
                    case .commonKeyTitle:
                        metadata.title = try? await item.load(.stringValue)
                    case .commonKeyModel:
                        metadata.cameraModel = try? await item.load(.stringValue)
                    default:
                        break
                    }
                }
            }
        } catch {
            // 静默失败，已从其他途径获取
        }
    }

    /// Spotlight 元数据回退（通过 mdls）
    private func extractSpotlightMetadata(from url: URL, into metadata: inout FileMetadata) {
        // 尝试通过 mdls 获取 kMDItemAuthors, kMDItemTitle 等
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
        process.arguments = ["-name", "kMDItemAuthors", "-name", "kMDItemTitle",
                             "-name", "kMDItemContentCreationDate", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return }

            for line in output.split(separator: "\n") {
                if line.contains("kMDItemAuthors") {
                    let value = extractMDLSValue(from: String(line))
                    if !value.isEmpty { metadata.author = value }
                } else if line.contains("kMDItemTitle") {
                    let value = extractMDLSValue(from: String(line))
                    if !value.isEmpty { metadata.title = value }
                } else if line.contains("kMDItemContentCreationDate") {
                    let value = extractMDLSValue(from: String(line))
                    if let date = parseMDLSDate(value) {
                        metadata.creationDate = date
                    }
                }
            }
        } catch {
            // mdls 不可用时静默忽略
        }
    }

    // MARK: - Helpers

    private func parseEXIFDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: dateString)
    }

    private func extractMDLSValue(from line: String) -> String {
        // mdls 格式: "kMDItemTitle    = \"value\""
        guard let equalsIndex = line.firstIndex(of: "=") else { return "" }
        let valuePart = line[line.index(after: equalsIndex)...]
            .trimmingCharacters(in: .whitespaces)
        // 去掉引号
        let cleaned = valuePart.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        // 去掉数组括号
        let noBrackets = cleaned
            .replacingOccurrences(of: "(\n", with: "")
            .replacingOccurrences(of: "\n)", with: "")
            .trimmingCharacters(in: .whitespaces)
        return noBrackets.components(separatedBy: ",")
            .first?.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\""))) ?? ""
    }

    private func parseMDLSDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        if let date = formatter.date(from: dateString) {
            return date
        }
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: dateString)
    }
}

// MARK: - Rename Suggestion Generation

extension MetadataService {
    
    /// 基于元数据生成重命名建议
    func generateRenameSuggestion(for file: FileItem, metadata: FileMetadata) -> RenameSuggestion {
        let originalName = file.fileName
        let ext = file.fileExtension
        
        let date = metadata.creationDate ?? metadata.modificationDate ?? file.modificationDate
        let dateStr = formatDate(date)
        
        var components: [String] = []
        
        switch file.category {
        case .image, .video:
            components.append(dateStr)
            if let camera = metadata.cameraModel, !camera.isEmpty {
                let sanitizedCamera = camera
                    .replacingOccurrences(of: " ", with: "_")
                    .replacingOccurrences(of: "/", with: "-")
                components.append(sanitizedCamera)
            }
            if let duration = metadata.duration, duration > 0, file.category == .video {
                components.append(formatDuration(duration))
            }
            
        case .document:
            let base = file.nameWithoutExtension
            components.append(base)
            components.append(dateStr)
            
        case .archive, .other:
            let base = file.nameWithoutExtension
            components.append(base)
            components.append(dateStr)
            
        case .application:
            let base = file.nameWithoutExtension
            let version = extractVersion(from: file)
            components.append(base)
            if let version {
                components.append("v\(version)")
            }
            components.append(dateStr)
        }
        
        let suggestedName = components.joined(separator: "_") + "." + ext
        let reason = metadata.cameraModel ?? metadata.title ?? dateStr
        
        return RenameSuggestion(
            fileID: file.id,
            originalName: originalName,
            suggestedName: suggestedName,
            confidence: 0.8,
            reason: reason
        )
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "nodate" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%dm%ds", mins, secs)
    }
    
    private func extractVersion(from file: FileItem) -> String? {
        guard file.fileExtension == "app" else { return nil }
        let plistURL = file.url.appendingPathComponent("Contents/Info.plist")
        guard let plist = NSDictionary(contentsOf: plistURL),
              let version = plist["CFBundleShortVersionString"] as? String
                ?? plist["CFBundleVersion"] as? String else {
            return nil
        }
        return version
    }
}
