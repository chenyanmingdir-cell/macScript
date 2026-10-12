//
//  ContentView.swift
//  macScript
//
//  Created by Nois on 2026/4/3.
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var store: ProjectStore

    var body: some View {
        VStack(spacing: 0) {
            TabStripView(store: store)
            if let session = store.selectedSession {
                ProjectEditorView(store: store, session: session)
            } else {
                ProjectLibraryView(store: store)
            }
        }
        .background(AppPalette.canvas.ignoresSafeArea())
    }
}

private struct TabStripView: View {
    @ObservedObject var store: ProjectStore
    
    var body: some View {
        HStack(spacing: 10) {
            projectMenu
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.sessions) { session in
                        SessionTabItemView(
                            title: session.project.title,
                            isSelected: session.id == store.selectedSessionID,
                            onSelect: {
                                store.selectedSessionID = session.id
                            },
                            onClose: {
                                store.closeSession(session)
                            }
                        )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var projectMenu: some View {
        Menu {
            Button("新建脚本") {
                store.createProjectAndOpen()
            }
            Button("打开脚本...") {
                store.openProjectWithPanel()
            }
            Divider()
            ForEach(store.projectFiles) { file in
                Button(file.title) {
                    store.openProject(at: file.url)
                }
            }
            Divider()
            Button("打开项目文件夹") {
                store.revealWorkspace()
            }
        } label: {
            Label("项目", systemImage: "folder")
                .font(.system(size: 13, weight: .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(AppPalette.card)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppPalette.border, lineWidth: 1)
                )
        }
        .menuStyle(.borderlessButton)
    }
}

private struct SessionTabItemView: View {
    let title: String
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                Text(title)
                    .lineLimit(1)
                    .font(.system(size: 13, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(
                        Circle()
                            .fill(
                                isSelected
                                    ? Color.white.opacity(0.8)
                                    : Color(nsColor: .separatorColor).opacity(0.5)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(isSelected ? AppPalette.lightCyan : AppPalette.card)
        .clipShape(Capsule())
        .overlay(
            Capsule().stroke(
                isSelected ? AppPalette.lightCyanDark.opacity(0.7) : AppPalette.border,
                lineWidth: isSelected ? 1.5 : 1
            )
        )
    }
}

private struct ProjectLibraryView: View {
    @ObservedObject var store: ProjectStore

    var body: some View {
        VStack(spacing: 24) {
            Text("MacScript")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(AppPalette.coffeeDark)

            HStack(spacing: 16) {
                Button {
                    store.createProjectAndOpen()
                } label: {
                    landingActionButton(
                        title: "新建脚本",
                        subtitle: "快速开始分镜",
                        systemImage: "plus",
                        isPrimary: true
                    )
                }
                .buttonStyle(CodexRectButtonStyle())

                Button {
                    store.openProjectWithPanel()
                } label: {
                    landingActionButton(
                        title: "打开脚本",
                        subtitle: "继续当前项目",
                        systemImage: "folder.badge.person.crop",
                        isPrimary: false
                    )
                }
                .buttonStyle(CodexRectButtonStyle())

                Button {
                    store.revealWorkspace()
                } label: {
                    landingActionButton(
                        title: "打开项目文件夹",
                        subtitle: "管理所有脚本",
                        systemImage: "folder",
                        isPrimary: false
                    )
                }
                .buttonStyle(CodexRectButtonStyle())
            }
            .frame(maxWidth: 860)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 20)
    }

    private func landingActionButton(title: String, subtitle: String, systemImage: String, isPrimary: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 19, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .opacity(0.82)
        }
        .foregroundStyle(isPrimary ? Color.white : AppPalette.coffeeDark)
        .frame(width: 210, height: 98, alignment: .leading)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isPrimary ? AppPalette.accent : AppPalette.card)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(isPrimary ? AppPalette.accentBorder : AppPalette.border, lineWidth: 1)
        }
        .shadow(color: AppPalette.shadow, radius: 8, y: 3)
    }
}

private struct ProjectEditorView: View {
    @ObservedObject var store: ProjectStore
    @ObservedObject var session: ProjectSession

    @State private var selectedImageCell: UUID?
    @State private var draggingShotID: UUID?
    @State private var pdfError: String?
    @State private var pdfSuccessURL: URL?
    @State private var showingColumnSheet = false
    @State private var cutImageData: Data?
    @State private var isImageCut = false
    @State private var keyboardMonitor: Any?
    @State private var undoHistory: [ScriptProject] = []
    @State private var redoHistory: [ScriptProject] = []
    @State private var isRestoringHistory = false
    @State private var saveFeedbackVisible = false

    var body: some View {
        VStack(spacing: 10) {
            topBar
            tableCard
            statusBar
        }
        .onAppear {
            setupKeyboardMonitor()
        }
        .onDisappear {
            if let monitor = keyboardMonitor {
                NSEvent.removeMonitor(monitor)
                keyboardMonitor = nil
            }
        }
        .sheet(isPresented: $showingColumnSheet) {
            ColumnSettingsView(session: session)
                .frame(minWidth: 520, minHeight: 420)
        }
        .alert("导出失败", isPresented: Binding(
            get: { pdfError != nil },
            set: { if !$0 { pdfError = nil } }
        )) {
            Button("好的", role: .cancel) { pdfError = nil }
        } message: {
            Text(pdfError ?? "")
        }
        .alert("导出成功", isPresented: Binding(
            get: { pdfSuccessURL != nil },
            set: { if !$0 { pdfSuccessURL = nil } }
        )) {
            Button("打开所在文件夹") {
                if let url = pdfSuccessURL {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
                pdfSuccessURL = nil
            }
            Button("关闭", role: .cancel) { pdfSuccessURL = nil }
        } message: {
            Text("PDF 文件已成功导出")
        }
        .onAppear {
            if undoHistory.isEmpty {
                undoHistory = [session.project]
            }
        }
        .onChange(of: session.project) { oldValue, newValue in
            guard !isRestoringHistory else { return }
            guard oldValue != newValue else { return }
            undoHistory.append(newValue)
            if undoHistory.count > 80 {
                undoHistory.removeFirst(undoHistory.count - 80)
            }
            redoHistory.removeAll()
        }
    }

    private var topBar: some View {
        HStack(spacing: 14) {
            headerInfoCard
            toolbarCard
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(AppPalette.canvas)
    }

    private var headerInfoCard: some View {
        HStack(spacing: 12) {
            editorField(
                title: "脚本名称",
                prompt: "脚本名称",
                text: $session.project.title
            )

            editorField(
                title: "制作团队",
                prompt: "制作团队",
                text: $session.project.teamName
            )
            .frame(width: 220)
        }
        .frame(maxWidth: .infinity * 0.4, minHeight: 80, maxHeight: 80)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(topCardBackground)
    }

    private var toolbarCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Menu {
                    Button("保存项目") {
                        store.saveSession(session)
                        flashSaveFeedback()
                    }
                    Button("另存为...") {
                        store.saveSessionAs(session)
                        flashSaveFeedback()
                    }
                    Button("在访达中显示") {
                        store.revealSession(session)
                    }
                } label: {
                    toolbarChip(
                        title: saveFeedbackVisible ? "已保存" : "保存",
                        systemImage: saveFeedbackVisible ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                }
                .menuStyle(.borderlessButton)

                Menu {
                    Button("16:9 横屏") {
                        session.project.setAspectRatio(16.0 / 9.0)
                    }
                    Button("9:16 竖屏") {
                        session.project.setAspectRatio(9.0 / 16.0)
                    }
                } label: {
                    toolbarChip(title: session.project.aspectLabel, systemImage: "rectangle.ratio.16.to.9")
                }
                .menuStyle(.borderlessButton)

                Spacer()
            }

            HStack(spacing: 10) {
                Button {
                    addShot(after: session.project.shots.last?.id)
                } label: {
                    toolbarChip(title: "新增镜头", systemImage: "plus")
                }
                .buttonStyle(CodexRectButtonStyle())

                Button {
                    showingColumnSheet = true
                } label: {
                    toolbarChip(title: "列设置", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(CodexRectButtonStyle())

                Button {
                    exportPDF()
                } label: {
                    toolbarChip(title: "导出 PDF", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(CodexRectButtonStyle())

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 80, maxHeight: 80)
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(topCardBackground)
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                VStack(spacing: 0) {
                    headerRow
                    Divider()
                    LazyVStack(spacing: 0) {
                        ForEach(session.project.shots) { shot in
                            if let shotBinding = bindingForShot(shot.id) {
                                ShotRowView(
                                    shot: shotBinding,
                                    columns: visibleColumns,
                                    rowHeight: session.project.computedRowHeight,
                                    frameAspectRatio: session.project.frameAspectRatio,
                                    frameContentHeight: session.project.frameContentHeight,
                                    selectedImageCell: $selectedImageCell,
                                    draggingShotID: $draggingShotID,
                                    cutImageData: $cutImageData,
                                    isImageCut: $isImageCut,
                                    onInsertBelow: { addShot(after: shot.id) },
                                    onDelete: { deleteShot(shot.id) },
                                    onMoveBefore: { moveShot(with: $0, before: shot.id) },
                                    onUpdateImage: { data in
                                        updateImage(data, for: shot.id)
                                    },
                                    columnWidth: columnWidth
                                )
                                .id(shot.id)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                }
            }
        }
        .background(AppPalette.sheet)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppPalette.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
        .frame(minWidth: 1240)
        .shadow(color: AppPalette.shadow, radius: 14, y: 6)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(visibleColumns) { column in
                HeaderCell(
                    title: column.title,
                    width: Binding(
                        get: { columnWidth(column.id) },
                        set: { newWidth in
                            updateColumnWidth(column.id, width: newWidth)
                        }
                    )
                )
            }
        }
        .frame(height: 56)
        .background(AppPalette.header)
    }

    private var statusBar: some View {
        HStack {
            Text("镜头总数 \(session.project.shots.count)")
            Spacer()
            Text("画幅比 \(session.project.aspectLabel)")
            Spacer()
            Text("总时长 \(formattedTotalDuration)")
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(AppPalette.coffee)
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .frame(minWidth: 1240)
    }

    private var visibleColumns: [ColumnDefinition] {
        session.project.visibleColumns
    }

    private var formattedTotalDuration: String {
        let total = session.project.totalDuration
        return total.rounded(.towardZero) == total ? "\(Int(total)) 秒" : String(format: "%.1f 秒", total)
    }

    private func addShot(after id: UUID?) {
        let shot = ShotItem(shotNumber: 0)
        if let id, let index = session.project.shots.firstIndex(where: { $0.id == id }) {
            session.project.shots.insert(shot, at: index + 1)
        } else {
            session.project.shots.append(shot)
        }
        session.project.normalize()
        selectedImageCell = shot.id
    }

    private func bindingForShot(_ id: UUID) -> Binding<ShotItem>? {
        guard session.project.shots.contains(where: { $0.id == id }) else {
            return nil
        }
        return Binding(
            get: {
                guard let idx = session.project.shots.firstIndex(where: { $0.id == id }) else {
                    return ShotItem(shotNumber: 0)
                }
                return session.project.shots[idx]
            },
            set: { newValue in
                guard let idx = session.project.shots.firstIndex(where: { $0.id == id }) else { return }
                session.project.shots[idx] = newValue
            }
        )
    }

    private func deleteShot(_ id: UUID) {
        guard session.project.shots.count > 1 else {
            let replacement = ShotItem(shotNumber: 1)
            session.project.shots = [replacement]
            selectedImageCell = replacement.id
            return
        }
        session.project.shots.removeAll { $0.id == id }
        if selectedImageCell == id {
            selectedImageCell = session.project.shots.first?.id
        }
        session.project.normalize()
    }

    private func moveShot(with draggedID: UUID, before targetID: UUID) {
        guard draggedID != targetID else { return }
        guard let sourceIndex = session.project.shots.firstIndex(where: { $0.id == draggedID }) else { return }
        guard let targetIndex = session.project.shots.firstIndex(where: { $0.id == targetID }) else { return }

        let shot = session.project.shots.remove(at: sourceIndex)
        let destination = min(max(targetIndex, 0), session.project.shots.count)
        session.project.shots.insert(shot, at: destination)
        session.project.normalize()
    }

    private func updateColumnWidth(_ columnID: String, width: CGFloat) {
        guard let index = session.project.columns.firstIndex(where: { $0.id == columnID }) else { return }
        session.project.columns[index].width = min(max(width, 72), 520)
    }

    private func handleCutImage() {
        guard let selectedID = selectedImageCell else { return }
        guard let index = session.project.shots.firstIndex(where: { $0.id == selectedID }) else { return }
        guard let imageData = session.project.shots[index].imageData else { return }
        
        cutImageData = imageData
        isImageCut = true
        session.project.shots[index].imageData = nil
    }

    private func handlePasteImage() {
        guard let selectedID = selectedImageCell else { return }
        guard let index = session.project.shots.firstIndex(where: { $0.id == selectedID }) else { return }
        
        if let cutData = cutImageData, isImageCut {
            session.project.shots[index].imageData = cutData
            cutImageData = nil
            isImageCut = false
            return
        }

        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let data = image.pngData {
            session.project.shots[index].imageData = data
            return
        }

        if let url = NSPasteboard.general.readObjects(forClasses: [NSURL.self])?.first as? URL,
           let data = try? Data(contentsOf: url),
           NSImage(data: data) != nil {
            session.project.shots[index].imageData = data
        }
    }

    private func setupKeyboardMonitor() {
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) {
                switch event.charactersIgnoringModifiers?.lowercased() {
                case "z":
                    if event.modifierFlags.contains(.shift) {
                        redoLastChange()
                    } else {
                        undoLastChange()
                    }
                    return nil
                case "x":
                    guard !isTextInputFocused(), selectedImageCell != nil else { return event }
                    handleCutImage()
                    return nil
                case "c":
                    guard !isTextInputFocused(), selectedImageCell != nil else { return event }
                    handleCopyImage()
                    return nil
                case "v":
                    guard !isTextInputFocused(), selectedImageCell != nil else { return event }
                    handlePasteImage()
                    return nil
                case "s":
                    saveWithShortcut()
                    return nil
                default:
                    break
                }
            }
            return event
        }
    }

    private func saveWithShortcut() {
        if FileManager.default.fileExists(atPath: session.fileURL.path) {
            store.saveSession(session)
        } else {
            store.saveSessionAs(session)
        }
        flashSaveFeedback()
    }

    private func flashSaveFeedback() {
        saveFeedbackVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            saveFeedbackVisible = false
        }
    }

    private func isTextInputFocused() -> Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    private func handleCopyImage() {
        guard let selectedID = selectedImageCell else { return }
        guard let index = session.project.shots.firstIndex(where: { $0.id == selectedID }) else { return }
        guard let imageData = session.project.shots[index].imageData else { return }
        guard let image = NSImage(data: imageData), let png = image.pngData else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(png, forType: .png)
        cutImageData = nil
        isImageCut = false
    }

    private func undoLastChange() {
        guard undoHistory.count > 1 else { return }
        isRestoringHistory = true
        let current = undoHistory.removeLast()
        redoHistory.append(current)
        session.project = undoHistory.last ?? session.project
        isRestoringHistory = false
    }

    private func redoLastChange() {
        guard let target = redoHistory.popLast() else { return }
        isRestoringHistory = true
        session.project = target
        undoHistory.append(target)
        isRestoringHistory = false
    }

    private func columnWidth(_ columnID: String) -> CGFloat {
        session.project.columns.first(where: { $0.id == columnID })?.width ?? 120
    }

    private func updateImage(_ data: Data?, for shotID: UUID) {
        guard let index = session.project.shots.firstIndex(where: { $0.id == shotID }) else { return }
        let hadImagesBefore = session.project.shots.contains { $0.imageData != nil }
        session.project.shots[index].imageData = data

        if !hadImagesBefore, let data, let image = NSImage(data: data) {
            session.project.frameAspectRatio = image.aspectRatioValue
        }
    }

    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = "\(session.project.title.isEmpty ? "分镜脚本" : session.project.title).pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try PDFExporter.makePDF(project: session.project)
            try data.write(to: url, options: .atomic)
            pdfSuccessURL = url
        } catch {
            pdfError = error.localizedDescription
        }
    }

    private func infoPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppPalette.sheet)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(AppPalette.border, lineWidth: 1)
            )
    }

    private func editorField(title: String, prompt: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.coffee)

            TextField(prompt, text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppPalette.field)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppPalette.border, lineWidth: 1)
                }
        }
    }

    private func toolbarChip(title: String, systemImage: String, accent: Color? = nil) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(accent == nil ? AppPalette.coffeeDark : Color.white)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent ?? AppPalette.sheet)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(accent == nil ? AppPalette.border : AppPalette.accentBorder, lineWidth: 1)
            }
    }

    private var topCardBackground: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(AppPalette.card)
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(AppPalette.border, lineWidth: 1)
            }
            .shadow(color: AppPalette.shadow, radius: 10, y: 3)
    }
}

private struct ShotRowView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var shot: ShotItem
    let columns: [ColumnDefinition]
    let rowHeight: CGFloat
    let frameAspectRatio: Double
    let frameContentHeight: CGFloat
    @Binding var selectedImageCell: UUID?
    @Binding var draggingShotID: UUID?
    @Binding var cutImageData: Data?
    @Binding var isImageCut: Bool

    let onInsertBelow: () -> Void
    let onDelete: () -> Void
    let onMoveBefore: (UUID) -> Void
    let onUpdateImage: (Data?) -> Void
    let columnWidth: (String) -> CGFloat

    @State private var isDropTargeted = false
    @State private var cachedCompressedImage: NSImage?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                rowCell(for: column)
            }
        }
        .frame(height: rowHeight)
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : rowBackground)
        .contentShape(Rectangle())
        .overlay(alignment: .top) {
            Divider()
        }
        .dropDestination(for: String.self) { items, _ in
            guard let raw = items.first, let id = UUID(uuidString: raw) else { return false }
            onMoveBefore(id)
            return true
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .contextMenu {
            Button("在下方插入镜头", action: onInsertBelow)
            Button("删除镜头", role: .destructive, action: onDelete)
        }
        .onAppear(perform: refreshCompressedImage)
        .onChange(of: shot.imageData) { _ in
            refreshCompressedImage()
        }
    }

    @ViewBuilder
    private func rowCell(for column: ColumnDefinition) -> some View {
        let cellWidth = columnWidth(column.id)
        switch column.role {
        case .order:
            orderCell(width: cellWidth)
        case .shotNumber:
            readOnlyCell("\(shot.shotNumber)", width: cellWidth)
        case .frameImage:
            imageCell(width: cellWidth)
        case .shotSize:
            editableCell("景别", text: shot.shotSize, width: cellWidth) { newValue in
                shot.shotSize = newValue
            }
        case .duration:
            editableCell("秒数", text: shot.duration, width: cellWidth) { newValue in
                shot.duration = newValue
            }
        case .content:
            multilineCell("输入内容", text: shot.content, width: cellWidth) { newValue in
                shot.content = newValue
            }
        case .note:
            multilineCell("备注", text: shot.note, width: cellWidth) { newValue in
                shot.note = newValue
            }
        case .customText:
            multilineCell(
                column.title,
                text: shot.customValues[column.id] ?? "",
                width: cellWidth
            ) { newValue in
                shot.customValues[column.id] = newValue
            }
        }
    }

    private func orderCell(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.coffeeDark)
                .frame(width: 24, height: 24)
                .background(AppPalette.sheet)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(AppPalette.border, lineWidth: 1)
                )
                .onDrag {
                    draggingShotID = shot.id
                    return NSItemProvider(object: shot.id.uuidString as NSString)
                }

            Button(action: onInsertBelow) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(AppPalette.sheet)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppPalette.border, lineWidth: 1)
            )

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .bold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .background(AppPalette.sheet)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(AppPalette.border, lineWidth: 1)
            )
        }
        .frame(width: width, height: rowHeight)
    }

    private func readOnlyCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .medium))
            .frame(width: width, height: rowHeight)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func editableCell(_ title: String, text: String, width: CGFloat, onChange: @escaping (String) -> Void) -> some View {
        TextField(title, text: Binding(
            get: { text },
            set: { onChange($0) }
        ))
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .medium))
            .padding(.horizontal, 14)
            .frame(width: width, height: rowHeight, alignment: .leading)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func multilineCell(_ title: String, text: String, width: CGFloat, onChange: @escaping (String) -> Void) -> some View {
        TextField(title, text: Binding(
            get: { text },
            set: { onChange($0) }
        ), axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 18, weight: .medium))
            .lineLimit(6)
            .padding(.horizontal, 14)
            .frame(width: width, height: rowHeight, alignment: .leading)
            .overlay(alignment: .trailing) {
                Divider()
            }
    }

    private func imageCell(width: CGFloat) -> some View {
        let imageHeight = frameContentHeight
        let actualWidth = frameAspectRatio >= 1 ? width - 24 : min(width - 24, 82)

        return ZStack {
            Rectangle()
                .fill(selectedImageCell == shot.id ? AppPalette.selection : AppPalette.field)

            if let image = compressedImage {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: actualWidth, height: imageHeight)
                    .clipped()
                    .opacity(isImageCut && shot.id == selectedImageCell ? 0.3 : 1.0)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 24))
                    Text("点击后 Cmd+V 粘贴图片")
                        .font(.system(size: 12, weight: .medium))
                    Text("首次导入会同步整列比例")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: width, height: rowHeight)
        .overlay(alignment: .trailing) {
            Divider()
        }
        .onTapGesture {
            selectedImageCell = shot.id
            NSApp.keyWindow?.makeFirstResponder(nil)
        }
        .onDrop(of: [.fileURL, .png, .jpeg, .tiff], isTargeted: nil) { providers in
            importImage(from: providers)
        }
        .contextMenu {
            Button("粘贴图片") {
                pasteImageFromPasteboard()
            }
            if shot.imageData != nil {
                Button("剪切图片") {
                    cutImage()
                }
                Button("清除图片", role: .destructive) {
                    onUpdateImage(nil)
                }
            }
        }
    }

    private var rowBackground: Color {
        if colorScheme == .dark {
            return AppPalette.sheet
        }
        return shot.shotNumber.isMultiple(of: 2) ? AppPalette.band : AppPalette.sheet.opacity(0.001)
    }

    private var shotImage: NSImage? {
        guard let data = shot.imageData else { return nil }
        return NSImage(data: data)
    }

    private var compressedImage: NSImage? {
        cachedCompressedImage
    }

    private func refreshCompressedImage() {
        guard let originalImage = shotImage else {
            cachedCompressedImage = nil
            return
        }

        let maxDimension: CGFloat = 200
        let originalSize = originalImage.size

        guard originalSize.width > maxDimension || originalSize.height > maxDimension else {
            cachedCompressedImage = originalImage
            return
        }

        let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
        let newSize = NSSize(width: originalSize.width * ratio, height: originalSize.height * ratio)

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        originalImage.draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: originalSize),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()

        cachedCompressedImage = newImage
    }

    private func pasteImageFromPasteboard() {
        if let cutData = cutImageData, isImageCut {
            selectedImageCell = shot.id
            onUpdateImage(cutData)
            cutImageData = nil
            isImageCut = false
            return
        }

        if let image = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage,
           let data = image.pngData {
            selectedImageCell = shot.id
            onUpdateImage(data)
            return
        }

        if let url = NSPasteboard.general.readObjects(forClasses: [NSURL.self])?.first as? URL,
           let data = try? Data(contentsOf: url),
           NSImage(data: data) != nil {
            selectedImageCell = shot.id
            onUpdateImage(data)
        }
    }

    private func cutImage() {
        guard let imageData = shot.imageData else { return }
        cutImageData = imageData
        isImageCut = true
        selectedImageCell = shot.id
        onUpdateImage(nil)
    }

    private func importImage(from providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data else { return }
                    guard let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    guard let fileData = try? Data(contentsOf: url), NSImage(data: fileData) != nil else { return }
                    DispatchQueue.main.async {
                        onUpdateImage(fileData)
                    }
                }
                return true
            }

            for type in [UTType.png.identifier, UTType.jpeg.identifier, UTType.tiff.identifier] {
                if provider.hasItemConformingToTypeIdentifier(type) {
                    provider.loadDataRepresentation(forTypeIdentifier: type) { data, _ in
                        guard let data, NSImage(data: data) != nil else { return }
                        DispatchQueue.main.async {
                            onUpdateImage(data)
                        }
                    }
                    return true
                }
            }
        }

        return false
    }
}

private enum AppPalette {
    static let canvas = dynamic(
        NSColor(calibratedRed: 0.964, green: 0.968, blue: 0.976, alpha: 1),
        NSColor(calibratedRed: 0.086, green: 0.098, blue: 0.114, alpha: 1)
    )
    static let sheet = dynamic(
        NSColor(calibratedRed: 0.952, green: 0.957, blue: 0.966, alpha: 1),
        NSColor(calibratedRed: 0.121, green: 0.137, blue: 0.16, alpha: 1)
    )
    static let card = dynamic(
        NSColor(calibratedRed: 0.982, green: 0.986, blue: 0.994, alpha: 0.93),
        NSColor(calibratedRed: 0.149, green: 0.168, blue: 0.196, alpha: 0.98)
    )
    static let field = dynamic(
        NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.95),
        NSColor(calibratedRed: 0.103, green: 0.117, blue: 0.141, alpha: 1)
    )
    static let header = dynamic(
        NSColor(calibratedRed: 0.933, green: 0.941, blue: 0.954, alpha: 1),
        NSColor(calibratedRed: 0.113, green: 0.125, blue: 0.145, alpha: 1)
    )
    static let band = dynamic(
        NSColor(calibratedRed: 0.938, green: 0.952, blue: 0.978, alpha: 0.43),
        NSColor(calibratedRed: 0.208, green: 0.247, blue: 0.31, alpha: 0.35)
    )
    static let border = dynamic(
        NSColor(calibratedWhite: 0.2, alpha: 0.14),
        NSColor(calibratedWhite: 1.0, alpha: 0.16)
    )
    static let coffee = dynamic(
        NSColor(calibratedWhite: 0.28, alpha: 0.92),
        NSColor(calibratedWhite: 0.87, alpha: 0.9)
    )
    static let coffeeDark = dynamic(
        NSColor(calibratedWhite: 0.13, alpha: 0.95),
        NSColor(calibratedWhite: 0.95, alpha: 0.96)
    )
    static let accent = Color(nsColor: NSColor(calibratedRed: 0.2, green: 0.47, blue: 0.93, alpha: 1))
    static let accentBorder = Color(nsColor: NSColor(calibratedRed: 0.13, green: 0.37, blue: 0.78, alpha: 0.75))
    static let lightCyan = sheet
    static let lightCyanDark = border
    static let selection = dynamic(
        NSColor(calibratedRed: 0.87, green: 0.92, blue: 1, alpha: 0.72),
        NSColor(calibratedRed: 0.17, green: 0.28, blue: 0.45, alpha: 0.65)
    )
    static let shadow = dynamic(
        NSColor(calibratedWhite: 0, alpha: 0.08),
        NSColor(calibratedWhite: 0, alpha: 0.22)
    )

    private static func dynamic(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(
            nsColor: NSColor(name: nil) { appearance in
                return appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
            }
        )
    }
}

private struct CodexRectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 10
    var rowSpacing: CGFloat = 10

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentRowWidth: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacingBefore = currentRowWidth > 0 ? spacing : 0

            if currentRowWidth + spacingBefore + size.width > maxWidth {
                totalWidth = max(totalWidth, currentRowWidth)
                totalHeight += currentRowHeight
                if totalHeight > 0 {
                    totalHeight += rowSpacing
                }
                currentRowWidth = size.width
                currentRowHeight = size.height
            } else {
                currentRowWidth += spacingBefore + size.width
                currentRowHeight = max(currentRowHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, currentRowWidth)
        totalHeight += currentRowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let spacingBefore = x > bounds.minX ? spacing : 0

            if x + spacingBefore + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + rowSpacing
                rowHeight = 0
            } else {
                x += spacingBefore
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )

            x += size.width
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct ColumnSettingsView: View {
    @ObservedObject var session: ProjectSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("列设置")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Spacer()
                Button("完成") {
                    dismiss()
                }
            }

            HStack(spacing: 12) {
                Button("新增自定义列") {
                    session.project.addCustomColumn()
                }
                .buttonStyle(.borderedProminent)
                .disabled(session.project.columns.filter { $0.role == .customText }.count >= ScriptProject.maxCustomColumnCount)

                Text("基础列可改名可隐藏；自定义列最多 3 个。")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(session.project.columns) { column in
                        HStack(spacing: 12) {
                            Toggle("", isOn: Binding(
                                get: {
                                    session.project.columns.first(where: { $0.id == column.id })?.isVisible ?? true
                                },
                                set: { newValue in
                                    guard let index = session.project.columns.firstIndex(where: { $0.id == column.id }) else { return }
                                    session.project.columns[index].isVisible = newValue
                                }
                            ))
                            .toggleStyle(.checkbox)

                            TextField("列名", text: Binding(
                                get: {
                                    session.project.columns.first(where: { $0.id == column.id })?.title ?? column.title
                                },
                                set: { newValue in
                                    guard let index = session.project.columns.firstIndex(where: { $0.id == column.id }) else { return }
                                    session.project.columns[index].title = newValue
                                }
                            ))
                            .textFieldStyle(.roundedBorder)

                            Text(column.role == .customText ? "自定义列" : "基础列")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if column.role == .customText {
                                Button("删除") {
                                    session.project.removeCustomColumn(column.id)
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                        }
                        .padding(14)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            Spacer()
        }
        .padding(22)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct HeaderCell: View {
    let title: String
    @Binding var width: CGFloat
    @State private var initialWidth: CGFloat = 0

    var body: some View {
        HStack(spacing: 0) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1)
                .overlay(alignment: .trailing) {
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 12)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 2)
                                .onChanged { value in
                                    if initialWidth == 0 {
                                        initialWidth = width
                                    }
                                    width = initialWidth + value.translation.width
                                }
                                .onEnded { _ in
                                    initialWidth = 0
                                }
                        )
                }
        }
        .frame(width: width)
    }
}
