import XCTest
import Foundation
@testable import Renamer

final class RenamerTests: XCTestCase {
    
    func testFileCategoryEnum() {
        let all = FileCategory.allCases
        XCTAssertEqual(all.count, 6)
        XCTAssertTrue(all.contains(.document))
        XCTAssertTrue(all.contains(.image))
        XCTAssertTrue(all.contains(.video))
        XCTAssertTrue(all.contains(.archive))
        XCTAssertTrue(all.contains(.application))
        XCTAssertTrue(all.contains(.other))
    }
    
    func testFileTypeDetectorByExtension() {
        let detector = FileTypeDetector()
        
        // 文档
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/test.pdf"), utType: nil), .document)
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/test.docx"), utType: nil), .document)
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/test.txt"), utType: nil), .document)
        
        // 图片
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/photo.jpg"), utType: nil), .image)
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/photo.png"), utType: nil), .image)
        
        // 视频
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/video.mp4"), utType: nil), .video)
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/video.mov"), utType: nil), .video)
        
        // 归档
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/archive.zip"), utType: nil), .archive)
        
        // 其他
        XCTAssertEqual(detector.detectCategory(for: URL(fileURLWithPath: "/tmp/unknown.xyz"), utType: nil), .other)
    }
    
    func testFileItemModel() {
        let url = URL(fileURLWithPath: "/tmp/test.pdf")
        let item = FileItem(
            url: url,
            fileName: "test.pdf",
            fileExtension: "pdf",
            fileSize: 1024,
            category: .document
        )
        
        XCTAssertEqual(item.fileName, "test.pdf")
        XCTAssertEqual(item.nameWithoutExtension, "test")
        XCTAssertEqual(item.category, .document)
        XCTAssertNotEqual(item.id, UUID())  // 应该有唯一 ID
    }
    
    func testRenameSuggestionModel() {
        let suggestion = RenameSuggestion(
            fileID: UUID(),
            originalName: "old_name.pdf",
            suggestedName: "new_name_20240101.pdf",
            confidence: 0.85,
            reason: "AI analysis result"
        )
        
        XCTAssertEqual(suggestion.originalName, "old_name.pdf")
        XCTAssertEqual(suggestion.confidence, 0.85)
        XCTAssertFalse(suggestion.isConfirmed)
        XCTAssertFalse(suggestion.isRejected)
    }
    
    func testShouldExcludeHiddenFiles() {
        let detector = FileTypeDetector()
        
        // 隐藏文件
        XCTAssertTrue(detector.shouldExclude(url: URL(fileURLWithPath: "/tmp/.DS_Store")))
        XCTAssertTrue(detector.shouldExclude(url: URL(fileURLWithPath: "/tmp/.hidden")))
        
        // 正常文件
        XCTAssertFalse(detector.shouldExclude(url: URL(fileURLWithPath: "/tmp/normal.txt")))
        
        // .git 目录内的文件
        XCTAssertTrue(detector.shouldExclude(url: URL(fileURLWithPath: "/tmp/.git/config")))
    }
    
    func testProcessingResultInitialState() {
        let result = ProcessingResult()
        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.renamedCount, 0)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(result.errorCount, 0)
        XCTAssertTrue(result.errors.isEmpty)
    }
}
