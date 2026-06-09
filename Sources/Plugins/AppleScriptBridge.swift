import Foundation

/// AppleScript 桥接器 — 为 DEVONthink、Photos 等应用预留
struct AppleScriptBridge: Sendable {
    
    /// 执行一段 AppleScript 并返回结果
    @discardableResult
    static func execute(_ script: String) throws -> String? {
        var error: NSDictionary?
        guard let appleScript = NSAppleScript(source: script) else {
            throw AppleScriptError.invalidScript
        }
        
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "AppleScript 执行失败"
            throw AppleScriptError.executionFailed(message)
        }
        
        return result.stringValue
    }
    
    /// 检查应用是否已安装
    static func isAppInstalled(_ bundleIdentifier: String) -> Bool {
        let script = """
        tell application "Finder"
            set appPath to (POSIX path of (path to application id "\(bundleIdentifier)"))
            return appPath
        end tell
        """
        
        do {
            _ = try execute(script)
            return true
        } catch {
            return false
        }
    }
    
    /// DEVONthink 导入（预留）
    static func devonThinkImport(files: [URL], databaseName: String) throws {
        let filePaths = files.map { $0.path }.joined(separator: "\", \"")
        let script = """
        tell application "DEVONthink 3"
            set theDB to database "\(databaseName)"
            tell theDB
                import {"\(filePaths)"}
            end tell
        end tell
        """
        try execute(script)
    }
    
    /// Photos.app 导入（预留）
    static func photosImport(fileURLs: [URL]) throws {
        let filePaths = fileURLs.map { "POSIX file \"\($0.path)\"" }.joined(separator: ", ")
        let script = """
        tell application "Photos"
            import {\(filePaths)}
        end tell
        """
        try execute(script)
    }
}

// MARK: - Errors

enum AppleScriptError: LocalizedError, Sendable {
    case invalidScript
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidScript:
            "AppleScript 脚本无效"
        case .executionFailed(let message):
            message
        }
    }
}
