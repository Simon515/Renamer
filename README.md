# Renamer - macOS 文件智能整理工具

纯原生 macOS 应用，对文件夹内容进行智能分析、重命名和分类整理。

## 功能

- 📂 **文件夹导入**：支持拖拽或选择多个文件夹
- 🔍 **智能扫描**：递归扫描文件，自动识别文件类型
- 📝 **文档 AI 重命名**：基于设备端 NaturalLanguage 框架，提取文档主题关键词生成文件名
- 📷 **图片视频元数据重命名**：基于 EXIF / AVFoundation 提取拍摄时间、相机型号等
- 📦 **安装包/应用识别**：基于应用类型和版本信息重命名
- 📊 **预览确认**：所有重命名操作先预览再执行，支持手动编辑
- 📁 **分类整理**：按文档/图片/视频/归档/应用/其他自动创建子目录
- 🔄 **撤销支持**：批量重命名后可一键回滚

## 技术栈

- **语言**: Swift 6.3
- **UI**: SwiftUI (macOS 14+)
- **构建**: Swift Package Manager
- **AI**: 设备端 NaturalLanguage 框架（无需联网）
- **元数据**: ImageIO / AVFoundation / Spotlight

## 构建与运行

```bash
# 构建
swift build

# 运行
swift run

# 测试
swift test
```

> 也可用 Xcode 打开 `Package.swift` 直接运行。

## 项目结构

```
Sources/
├── App/          # 应用入口
├── Models/       # 数据模型
├── Services/     # 核心服务
├── Plugins/      # 导出插件
├── ViewModels/   # 视图模型
└── Views/        # SwiftUI 视图
```

## 许可证

MIT License
