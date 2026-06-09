import Foundation
import NaturalLanguage
import PDFKit

/// AI 重命名服务 — 使用设备端 NaturalLanguage 框架进行文档主题分析
struct AIRenameService: Sendable {

    // MARK: - Public

    /// 为文档类文件生成重命名建议
    func generateSuggestion(for file: FileItem) async -> RenameSuggestion {
        let originalName = file.fileName
        let ext = file.fileExtension

        // 提取文档文本
        let text = await extractText(from: file)

        // NL 分析
        let (topic, entities) = analyzeText(text, fileName: file.nameWithoutExtension)

        // 日期
        let dateStr = formatDate(file.modificationDate ?? file.creationDate)

        // 生成新名称：主题_日期.扩展名
        let newName: String
        if let topic, !topic.isEmpty {
            let sanitized = sanitizeFilename(topic)
            newName = "\(sanitized)_\(dateStr).\(ext)"
        } else if !entities.isEmpty {
            let sanitized = sanitizeFilename(entities.joined(separator: "-"))
            newName = "\(sanitized)_\(dateStr).\(ext)"
        } else {
            // 回退：原名 + 日期
            let base = file.nameWithoutExtension
            newName = "\(base)_\(dateStr).\(ext)"
        }

        let confidence = topic != nil ? 0.7 : 0.3
        let reason = topic ?? entities.joined(separator: ", ")

        return RenameSuggestion(
            fileID: file.id,
            originalName: originalName,
            suggestedName: newName,
            confidence: confidence,
            reason: reason
        )
    }

    /// 批量为文档文件生成重命名建议
    func generateSuggestions(for files: [FileItem]) async -> [RenameSuggestion] {
        await withTaskGroup(of: RenameSuggestion?.self) { group in
            for file in files where file.category == .document {
                group.addTask {
                    await self.generateSuggestion(for: file)
                }
            }

            var results: [RenameSuggestion] = []
            for await suggestion in group {
                if let suggestion {
                    results.append(suggestion)
                }
            }
            return results
        }
    }

    // MARK: - Private

    private func extractText(from file: FileItem) async -> String {
        let url = file.url
        let ext = file.fileExtension.lowercased()

        // PDF 文件
        if ext == "pdf" {
            return extractPDFText(from: url)
        }

        // 纯文本文件
        if ["txt", "md", "rtf", "csv", "json", "xml", "yaml", "yml", "html", "htm"].contains(ext) {
            return extractPlainText(from: url)
        }

        // 其他文档使用 mdls 提取元信息
        return extractSpotlightText(from: url)
    }

    private func extractPDFText(from url: URL) -> String {
        guard let pdf = PDFDocument(url: url) else { return "" }
        let maxPages = min(pdf.pageCount, 5)
        var text = ""
        for i in 0..<maxPages {
            if let page = pdf.page(at: i), let pageText = page.string {
                text += pageText + "\n"
            }
        }
        return text
    }

    private func extractPlainText(from url: URL) -> String {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii) else {
            return ""
        }
        // 取前 5000 字符
        return String(text.prefix(5000))
    }

    private func extractSpotlightText(from url: URL) -> String {
        // 利用 mdls 获取 kMDItemTextContent
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/mdls")
        process.arguments = ["-name", "kMDItemTextContent", url.path]

        let pipe = Pipe()
        process.standardOutput = pipe

        guard let _ = try? process.run() else { return "" }
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func analyzeText(_ text: String, fileName: String) -> (topic: String?, entities: [String]) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, [])
        }

        // 语言识别
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        let language = recognizer.dominantLanguage

        // 命名实体识别
        var entities: [String] = []
        let tagger = NLTagger(tagSchemes: [.nameType, .nameTypeOrLexicalClass])
        tagger.string = String(text.prefix(3000))

        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, range in
            if let tag {
                let word = String(text[range])
                switch tag {
                case .personalName:
                    entities.append(word)
                case .organizationName:
                    entities.append(word)
                case .placeName:
                    entities.append(word)
                default:
                    break
                }
            }
            return true
        }

        // 关键词提取
        var keywords: [String] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        // 词频统计
        var wordFreq: [String: Int] = [:]
        let stopWords: Set<String> = [
            "the", "a", "an", "is", "are", "was", "were", "be", "been",
            "in", "on", "at", "to", "for", "of", "with", "by", "from",
            "and", "or", "but", "not", "this", "that", "it", "as", "we",
            "he", "she", "they", "you", "i", "my", "me", "his", "her",
            "的", "是", "在", "和", "了", "有", "我", "他", "她", "它",
            "我们", "你们", "他们", "这", "那", "不", "就", "也", "都",
            "个", "人", "上", "下", "中", "大", "小", "多", "少", "很",
            "可以", "会", "能", "要", "用", "把", "被", "让", "给", "从"
        ]

        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let word = String(text[range]).lowercased()
            if word.count >= 2 && !stopWords.contains(word) {
                wordFreq[word, default: 0] += 1
            }
            return true
        }

        // 取词频最高的 3 个词
        let sorted = wordFreq.sorted { $0.value > $1.value }
        keywords = sorted.prefix(3).map { $0.key }

        let topic = keywords.isEmpty ? entities.first : keywords.joined(separator: "-")
        return (topic, entities)
    }

    private func formatDate(_ date: Date?) -> String {
        guard let date else { return "nodate" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    private func sanitizeFilename(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\?%*:|\"<>")
        var sanitized = name
            .components(separatedBy: invalidChars)
            .joined(separator: "_")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")

        // 限制长度
        if sanitized.count > 80 {
            sanitized = String(sanitized.prefix(80))
        }

        return sanitized.isEmpty ? "document" : sanitized
    }
}
