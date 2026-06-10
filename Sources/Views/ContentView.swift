import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Bindable var viewModel: MainViewModel
    @State private var isTargeted = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 文件夹选择区域
            folderSelectionBar
            
            Divider()
            
            // 主内容区
            switch viewModel.phase {
            case .empty:
                emptyStateView
            case .foldersSelected:
                foldersSelectedView
            case .scanning:
                scanningView
            case .previewReady:
                previewView
            case .processing:
                processingView
            case .completed:
                resultsView
            case .classifying:
                processingView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .alert("错误", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("确定") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
    
    // MARK: - Folder Selection Bar
    
    private var folderSelectionBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.fill")
                .foregroundColor(.accentColor)
            
            if viewModel.selectedFolders.isEmpty {
                Text("拖拽文件夹到此处，或点击选择")
                    .foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(viewModel.selectedFolders, id: \.self) { url in
                            HStack(spacing: 4) {
                                Image(systemName: "folder.fill")
                                    .font(.caption)
                                Text(url.lastPathComponent)
                                    .font(.caption)
                                Button(action: { viewModel.clearFolders() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("选择文件夹") {
                    selectFolders()
                }
                
                if !viewModel.selectedFolders.isEmpty {
                    Button("扫描") {
                        Task { await viewModel.startScan() }
                    }
                    .disabled(viewModel.phase == .scanning)
                    .keyboardShortcut(.return)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor))
        .onDrop(of: [.folder, .fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "tray.and.arrow.down.fill")
                .font(.system(size: 64))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("拖拽文件夹到这里开始整理")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("支持文档、图片、视频、归档文件等")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.7))
            
            Button("选择文件夹") {
                selectFolders()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Folders Selected
    
    private var foldersSelectedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            Text("已选择 \(viewModel.selectedFolders.count) 个文件夹")
                .font(.title3)
            Button("开始扫描") {
                Task { await viewModel.startScan() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: viewModel.progress) {
                Text(viewModel.currentStep)
                    .font(.headline)
            }
            .frame(width: 300)
            
            Text("\(Int(viewModel.progress * 100))%")
                .foregroundColor(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Preview
    
    private var previewView: some View {
        VStack(spacing: 0) {
            // 统计栏
            statsBar
            
            Divider()
            
            // 文件列表
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.suggestions) { suggestion in
                        RenamePreviewRow(
                            suggestion: suggestion,
                            files: viewModel.files,
                            onToggle: { viewModel.toggleConfirmation(for: suggestion.id) },
                            onNameChange: { newName in
                                viewModel.updateSuggestionName(suggestion.id, newName: newName)
                            }
                        )
                        Divider().padding(.leading, 44)
                    }
                }
            }
            
            Divider()
            
            // 底部操作栏
            bottomActionBar
        }
    }
    
    private var statsBar: some View {
        HStack(spacing: 16) {
            StatBadge(label: "文档", count: viewModel.documentsCount, color: .blue)
            StatBadge(label: "图片", count: viewModel.imagesCount, color: .green)
            StatBadge(label: "视频", count: viewModel.videosCount, color: .orange)
            StatBadge(label: "其他", count: viewModel.othersCount, color: .gray)
            
            Spacer()
            
            Text("总计 \(viewModel.totalFiles) 个文件")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            Button("全选") { viewModel.confirmAll() }
            Button("全拒") { viewModel.rejectAll() }
            
            Spacer()
            
            Text("已确认 \(viewModel.confirmedCount)/\(viewModel.totalFiles)")
                .foregroundColor(.secondary)
            
            Button("执行重命名") {
                Task { await viewModel.executeRename() }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.confirmedCount == 0)
            .keyboardShortcut(.return)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Processing
    
    private var processingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView(value: viewModel.progress) {
                Text(viewModel.currentStep)
                    .font(.headline)
            }
            .frame(width: 300)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.logs, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .fontDesign(.monospaced)
                    }
                }
                .padding()
            }
            .frame(maxHeight: 200)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Results
    
    private var resultsView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 20) {
                    // 成功图标
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                        .padding(.top, 32)
                    
                    Text("整理完成")
                        .font(.title)
                    
                    // 统计
                    if let result = viewModel.renameResult {
                        HStack(spacing: 32) {
                            ResultStat(value: "\(result.renamedCount)", label: "已重命名")
                            ResultStat(value: "\(result.skippedCount)", label: "已跳过")
                            ResultStat(value: "\(result.errorCount)", label: "错误")
                        }
                    }
                    
                    if let classifyResult = viewModel.classifyResult {
                        HStack(spacing: 32) {
                            ResultStat(value: "\(classifyResult.renamedCount)", label: "已分类")
                            ResultStat(value: "\(classifyResult.errorCount)", label: "分类错误")
                        }
                    }
                    
                    // 日志
                    if !viewModel.logs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("操作日志")
                                .font(.headline)
                            
                            ScrollView {
                                ForEach(viewModel.logs, id: \.self) { log in
                                    Text(log)
                                        .font(.caption)
                                        .fontDesign(.monospaced)
                                }
                            }
                            .frame(maxHeight: 150)
                            .padding(8)
                            .background(Color(nsColor: .textBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .padding(.horizontal)
                    }
                    
                    // 操作按钮
                    HStack(spacing: 12) {
                        if viewModel.classifyResult == nil {
                            Button("分类整理") {
                                Task { await viewModel.executeClassify() }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("重新扫描") {
                            viewModel.reset()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func selectFolders() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = true
        panel.message = "选择要整理的文件夹"
        panel.prompt = "选择"
        
        if panel.runModal() == .OK {
            viewModel.selectedFolders = panel.urls
            viewModel.phase = .foldersSelected
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    DispatchQueue.main.async {
                        viewModel.selectedFolders.append(url)
                        viewModel.phase = .foldersSelected
                    }
                }
            }
        }
    }
}

// MARK: - Subviews

struct StatBadge: View {
    let label: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label) \(count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct ResultStat: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct RenamePreviewRow: View {
    let suggestion: RenameSuggestion
    let files: [FileItem]
    var onToggle: () -> Void
    var onNameChange: (String) -> Void
    
    @State private var editedName: String
    
    init(suggestion: RenameSuggestion, files: [FileItem], onToggle: @escaping () -> Void, onNameChange: @escaping (String) -> Void) {
        self.suggestion = suggestion
        self.files = files
        self.onToggle = onToggle
        self.onNameChange = onNameChange
        _editedName = State(initialValue: suggestion.suggestedName)
    }
    
    private var file: FileItem? {
        files.first { $0.id == suggestion.fileID }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 状态按钮
            Button(action: onToggle) {
                Image(systemName: suggestion.isRejected
                    ? "xmark.circle.fill"
                    : suggestion.isConfirmed
                        ? "checkmark.circle.fill"
                        : "circle")
                    .foregroundColor(suggestion.isRejected
                        ? .red
                        : suggestion.isConfirmed
                            ? .green
                            : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // 文件类型图标
            Image(systemName: file?.category.iconName ?? "doc")
                .frame(width: 24)
                .foregroundColor(.secondary)
            
            // 原名 → 新名
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.originalName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .strikethrough(suggestion.isConfirmed)
                
                TextField("新文件名", text: $editedName)
                    .font(.body)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onNameChange(editedName)
                    }
            }
            
            Spacer()
            
            // 置信度
            if suggestion.confidence > 0 {
                HStack(spacing: 4) {
                    Text("AI")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text("\(Int(suggestion.confidence * 100))%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .opacity(suggestion.isRejected ? 0.4 : 1.0)
    }
}
