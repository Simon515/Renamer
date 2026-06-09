import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Text("命名模板设置")
                .tabItem { Label("命名", systemImage: "textformat") }
            
            Text("导出设置")
                .tabItem { Label("导出", systemImage: "square.and.arrow.up") }
            
            Text("AI 选项")
                .tabItem { Label("AI", systemImage: "brain") }
        }
        .frame(width: 450, height: 300)
    }
}
