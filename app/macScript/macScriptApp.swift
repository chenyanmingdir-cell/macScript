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
