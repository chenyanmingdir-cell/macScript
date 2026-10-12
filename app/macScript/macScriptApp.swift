//
//  macScriptApp.swift
//  macScript
//
//  Created by Nois on 2026/4/3.
//

import SwiftUI

@main
struct macScriptApp: App {
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1400, minHeight: 800)
                // 双击 .macscript、拖到 Dock 图标、或从访达「打开方式」进来时
                // 由系统把文件地址交给这里打开
                .onOpenURL { url in
                    store.openProject(at: url)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建脚本") {
                    store.createProjectAndOpen()
                }
                .keyboardShortcut("n")

                Button("打开脚本...") {
                    store.openProjectWithPanel()
                }
                .keyboardShortcut("o")

                Button("显示项目文件夹") {
                    store.revealWorkspace()
                }
            }
        }
    }
}
