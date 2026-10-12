//
//  ScriptDocument.swift
//  macScript
//
//  Created by Nois on 2026/4/3.
//

import AppKit
import Combine
import Foundation
import UniformTypeIdentifiers

enum ColumnRole: String, Codable, CaseIterable {
    case order
    case shotNumber
    case frameImage
    case shotSize
    case duration
    case content
    case note
    case customText

    var title: String {
        switch self {
        case .order: "排序"
        case .shotNumber: "镜号"
        case .frameImage: "画面"
        case .shotSize: "景别"
        case .duration: "时长(秒)"
        case .content: "内容"
        case .note: "备注"
        case .customText: "新列"
        }
    }

    var defaultWidth: CGFloat {
        switch self {
        case .order: 78
        case .shotNumber: 92
        case .frameImage: 300
        case .shotSize: 118
        case .duration: 110
        case .content: 360
        case .note: 250
        case .customText: 180
        }
    }
}

struct ColumnDefinition: Identifiable, Codable, Equatable {
    var id: String
    var title: String
    var width: CGFloat
    var isVisible: Bool
    var role: ColumnRole

    static func builtIn(_ role: ColumnRole) -> ColumnDefinition {
        ColumnDefinition(
            id: role.rawValue,
            title: role.title,
            width: role.defaultWidth,
            isVisible: true,
            role: role
        )
    }

    static func custom(title: String, index: Int) -> ColumnDefinition {
        ColumnDefinition(
            id: "custom-\(UUID().uuidString.lowercased())-\(index)",
            title: title,
            width: ColumnRole.customText.defaultWidth,
            isVisible: true,
            role: .customText
        )
    }
}

struct ShotItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var shotNumber: Int
    var imageData: Data?
    var shotSize: String
    var duration: String
    var content: String
    var note: String
    var customValues: [String: String]

    init(
        id: UUID = UUID(),
        shotNumber: Int,
        imageData: Data? = nil,
        shotSize: String = "",
        duration: String = "",
        content: String = "",
        note: String = "",
        customValues: [String: String] = [:]
    ) {
        self.id = id
        self.shotNumber = shotNumber
        self.imageData = imageData
        self.shotSize = shotSize
        self.duration = duration
        self.content = content
        self.note = note
        self.customValues = customValues
    }
}

struct ScriptProject: Codable, Equatable {
    var title: String
    var teamName: String
    var shots: [ShotItem]
    var columns: [ColumnDefinition]
    var frameAspectRatio: Double
    var minimumRowHeight: CGFloat

    init(
        title: String = "未命名脚本",
        teamName: String = "制作团队",
        shots: [ShotItem] = [ShotItem(shotNumber: 1)],
        columns: [ColumnDefinition] = ScriptProject.defaultColumns,
        frameAspectRatio: Double = 16.0 / 9.0,
        minimumRowHeight: CGFloat = 116
    ) {
        self.title = title
        self.teamName = teamName
        self.shots = shots
        self.columns = columns
        self.frameAspectRatio = frameAspectRatio
        self.minimumRowHeight = minimumRowHeight
        normalize()
    }

    static let defaultColumns: [ColumnDefinition] = [
        .builtIn(.order),
        .builtIn(.shotNumber),
        .builtIn(.frameImage),
        .builtIn(.shotSize),
        .builtIn(.duration),
        .builtIn(.content),
        .builtIn(.note)
    ]
    static let maxCustomColumnCount = 3

    static var starter: ScriptProject {
        ScriptProject(
            title: "新脚本",
            teamName: "制作团队",
            shots: [
                ShotItem(shotNumber: 1, shotSize: "远景", duration: "3", content: "输入镜头内容"),
                ShotItem(shotNumber: 2),
                ShotItem(shotNumber: 3),
                ShotItem(shotNumber: 4),
                ShotItem(shotNumber: 5)
            ]
        )
    }

    mutating func normalize() {
        if shots.isEmpty {
            shots = [ShotItem(shotNumber: 1)]
        }

        for index in shots.indices {
            shots[index].shotNumber = index + 1
        }

        if columns.isEmpty {
            columns = Self.defaultColumns
        }

        for builtIn in Self.defaultColumns {
            if !columns.contains(where: { $0.id == builtIn.id }) {
                columns.append(builtIn)
            }
        }

        columns = columns.sorted { lhs, rhs in
            let leftIndex = builtInOrderIndex(lhs.role) ?? 999
            let rightIndex = builtInOrderIndex(rhs.role) ?? 999
            if leftIndex == rightIndex {
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
            return leftIndex < rightIndex
        }

        for index in columns.indices {
            if columns[index].title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                columns[index].title = columns[index].role.title
            }
            columns[index].width = min(max(columns[index].width, 72), 520)
        }
        rebalanceColumnWidthsForCustomColumns()

        if frameAspectRatio <= 0 {
            frameAspectRatio = 16.0 / 9.0
        }

        if teamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            teamName = "制作团队"
        }

        minimumRowHeight = min(max(minimumRowHeight, 96), 180)
    }

    private func builtInOrderIndex(_ role: ColumnRole) -> Int? {
        switch role {
        case .order: 0
        case .shotNumber: 1
        case .frameImage: 2
        case .shotSize: 3
        case .duration: 4
        case .content: 5
        case .note: 6
        case .customText: nil
        }
    }

    var visibleColumns: [ColumnDefinition] {
        columns.filter(\.isVisible)
    }

    var totalDuration: Double {
        shots.reduce(0) { partial, shot in
            partial + (Double(shot.duration.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0)
        }
    }

    var frameColumn: ColumnDefinition {
        columns.first(where: { $0.role == .frameImage }) ?? .builtIn(.frameImage)
    }

    var frameContentHeight: CGFloat {
        let baseWidth = frameColumn.width - 24
        if frameAspectRatio >= 1 {
            return max(84, baseWidth / frameAspectRatio)
        }

        let portraitWidth = max(72, min(baseWidth * 0.28, 82))
        return max(132, portraitWidth / frameAspectRatio)
    }

    var computedRowHeight: CGFloat {
        max(minimumRowHeight, frameContentHeight + 24)
    }

    var aspectLabel: String {
        frameAspectRatio >= 1 ? "16:9 横屏" : "9:16 竖屏"
    }

    mutating func setAspectRatio(_ value: Double) {
        frameAspectRatio = value
    }

    mutating func addCustomColumn() {
        guard columns.filter({ $0.role == .customText }).count < Self.maxCustomColumnCount else { return }
        let nextIndex = columns.filter { $0.role == .customText }.count + 1
        columns.append(.custom(title: "自定义\(nextIndex)", index: nextIndex))
        normalize()
    }

    mutating func removeCustomColumn(_ columnID: String) {
        guard let column = columns.first(where: { $0.id == columnID }), column.role == .customText else { return }
        columns.removeAll { $0.id == columnID }
        for index in shots.indices {
            shots[index].customValues.removeValue(forKey: columnID)
        }
        normalize()
    }

    private mutating func rebalanceColumnWidthsForCustomColumns() {
        let customIDs = columns.filter { $0.role == .customText }.map(\.id)
        guard !customIDs.isEmpty else { return }

        let adjustableRoles: Set<ColumnRole> = [.shotSize, .duration, .content, .note]
        let minWidthForRole: [ColumnRole: CGFloat] = [
            .shotSize: 90,
            .duration: 86,
            .content: 220,
            .note: 150
        ]

        let targetWidth: CGFloat = 130
        let requiredTotal = CGFloat(customIDs.count) * targetWidth
        var released: CGFloat = 0

        for index in columns.indices where adjustableRoles.contains(columns[index].role) {
            let minimum = minWidthForRole[columns[index].role] ?? 90
            let available = max(0, columns[index].width - minimum)
            guard available > 0 else { continue }
            let need = requiredTotal - released
            guard need > 0 else { break }

            let delta = min(available, need)
            columns[index].width -= delta
            released += delta
        }

        let actualCustomWidth = max(96, min(targetWidth, released / CGFloat(customIDs.count)))
        for id in customIDs {
            if let idx = columns.firstIndex(where: { $0.id == id }) {
                columns[idx].width = actualCustomWidth
            }
        }
    }

    func value(for column: ColumnDefinition, shot: ShotItem) -> String {
        switch column.role {
        case .order: ""
        case .shotNumber: "\(shot.shotNumber)"
        case .frameImage: ""
        case .shotSize: shot.shotSize
        case .duration: shot.duration
        case .content: shot.content
        case .note: shot.note
        case .customText: shot.customValues[column.id] ?? ""
        }
    }

    mutating func setValue(_ value: String, for column: ColumnDefinition, shotIndex: Int) {
        guard shots.indices.contains(shotIndex) else { return }
        switch column.role {
        case .order, .shotNumber, .frameImage:
            break
        case .shotSize:
            shots[shotIndex].shotSize = value
        case .duration:
            shots[shotIndex].duration = value
        case .content:
            shots[shotIndex].content = value
        case .note:
            shots[shotIndex].note = value
        case .customText:
            shots[shotIndex].customValues[column.id] = value
        }
    }
}

final class ProjectSession: ObservableObject, Identifiable {
    let id = UUID()
    @Published var project: ScriptProject
    @Published var fileURL: URL

    init(project: ScriptProject, fileURL: URL) {
        self.project = project
        self.fileURL = fileURL
    }
}

struct ProjectFileInfo: Identifiable {
    let url: URL
    let title: String
    let modifiedAt: Date

    var id: String { url.path }
}

final class ProjectStore: ObservableObject {
    @Published var projectFiles: [ProjectFileInfo] = []
    @Published var sessions: [ProjectSession] = []
    @Published var selectedSessionID: UUID?

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var autosaveCancellables: [UUID: AnyCancellable] = [:]
    private let saveQueue = DispatchQueue(label: "macscript.project-save", qos: .utility)

    init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        refreshProjectFiles()
    }

    var selectedSession: ProjectSession? {
        sessions.first(where: { $0.id == selectedSessionID })
    }

    func createProjectAndOpen() {
        ensureWorkspaceExists()
        let url = nextDefaultURL()
        var project = ScriptProject.starter
        project.title = url.deletingPathExtension().lastPathComponent
        write(project, to: url)
        openProject(at: url)
    }

    func openProject(at url: URL) {
        if let existing = sessions.first(where: { $0.fileURL.standardizedFileURL == url.standardizedFileURL }) {
            selectedSessionID = existing.id
            return
        }

        guard let data = try? Data(contentsOf: url),
              var project = try? decoder.decode(ScriptProject.self, from: data) else { return }
        project.normalize()

        let session = ProjectSession(project: project, fileURL: url)
        sessions.append(session)
        selectedSessionID = session.id
        attachAutosave(to: session)
        refreshProjectFiles()
    }

    func closeSession(_ session: ProjectSession) {
        autosaveCancellables[session.id]?.cancel()
        autosaveCancellables.removeValue(forKey: session.id)
        sessions.removeAll { $0.id == session.id }
        if selectedSessionID == session.id {
            selectedSessionID = sessions.last?.id
        }
    }

    func refreshProjectFiles() {
        ensureWorkspaceExists()
        let directory = workspaceURL()
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )) ?? []

        projectFiles = urls
            .filter { $0.pathExtension == "macscript" }
            .compactMap { url in
                let modifiedAt = (try? url.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast
                let title = readProjectTitle(from: url) ?? url.deletingPathExtension().lastPathComponent
                return ProjectFileInfo(url: url, title: title, modifiedAt: modifiedAt)
            }
            .sorted { lhs, rhs in
                if lhs.modifiedAt == rhs.modifiedAt {
                    return lhs.title.localizedCompare(rhs.title) == .orderedAscending
                }
                return lhs.modifiedAt > rhs.modifiedAt
            }
    }

    func revealWorkspace() {
        ensureWorkspaceExists()
        NSWorkspace.shared.activateFileViewerSelecting([workspaceURL()])
    }

    func openProjectWithPanel() {
        ensureWorkspaceExists()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "macscript")!]
        panel.directoryURL = workspaceURL()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openProject(at: url)
    }

    func revealSession(_ session: ProjectSession) {
        saveSession(session)
        NSWorkspace.shared.activateFileViewerSelecting([session.fileURL])
    }

    func saveSessionAs(_ session: ProjectSession) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "macscript")!]
        panel.directoryURL = session.fileURL.deletingLastPathComponent()
        panel.nameFieldStringValue = session.fileURL.lastPathComponent

        guard panel.runModal() == .OK, let targetURL = panel.url else { return }
        var destination = targetURL
        if destination.pathExtension.lowercased() != "macscript" {
            destination = destination.appendingPathExtension("macscript")
        }

        session.fileURL = destination
        saveSession(session)
    }

    func saveSession(_ session: ProjectSession) {
        var project = session.project
        project.normalize()

        let trimmedTitle = project.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeTitle = sanitizedFileName(from: trimmedTitle.isEmpty ? session.fileURL.deletingPathExtension().lastPathComponent : trimmedTitle)
        let desiredURL = session.fileURL.deletingLastPathComponent().appendingPathComponent(safeTitle).appendingPathExtension("macscript")

        if desiredURL.standardizedFileURL != session.fileURL.standardizedFileURL {
            let uniqueURL = availableURL(for: desiredURL, keeping: session.fileURL)
            do {
                try FileManager.default.moveItem(at: session.fileURL, to: uniqueURL)
                session.fileURL = uniqueURL
            } catch {
                session.fileURL = availableURL(for: desiredURL, keeping: nil)
            }
        }

        write(project, to: session.fileURL)
        refreshProjectFiles()
    }

    private func attachAutosave(to session: ProjectSession) {
        autosaveCancellables[session.id] = session.$project
            .dropFirst()
            .debounce(for: .milliseconds(800), scheduler: DispatchQueue.main)
            .sink { [weak self, weak session] _ in
                guard let self, let session else { return }
                self.autosaveSession(session)
            }
    }

    private func autosaveSession(_ session: ProjectSession) {
        var project = session.project
        project.normalize()
        let url = session.fileURL

        saveQueue.async { [weak self] in
            self?.write(project, to: url)
        }
    }

    private func readProjectTitle(from url: URL) -> String? {
        guard let data = try? Data(contentsOf: url),
              let project = try? decoder.decode(ScriptProject.self, from: data) else { return nil }
        return project.title
    }

    private func write(_ project: ScriptProject, to url: URL) {
        ensureWorkspaceExists()
        guard let data = try? encoder.encode(project) else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func nextDefaultURL() -> URL {
        let folder = workspaceURL()
        let existingNames = Set(
            ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
                .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
        )

        var index = 1
        while true {
            let name = String(format: "%02d", index)
            if !existingNames.contains(name) {
                return folder.appendingPathComponent(name).appendingPathExtension("macscript")
            }
            index += 1
        }
    }

    private func availableURL(for url: URL, keeping currentURL: URL?) -> URL {
        if currentURL?.standardizedFileURL == url.standardizedFileURL || !FileManager.default.fileExists(atPath: url.path) {
            return url
        }

        let base = url.deletingPathExtension().lastPathComponent
        let folder = url.deletingLastPathComponent()
        let ext = url.pathExtension
        var index = 2
        while true {
            let candidate = folder.appendingPathComponent("\(base)-\(index)").appendingPathExtension(ext)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }

    private func sanitizedFileName(from raw: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let name = raw.components(separatedBy: invalid).joined(separator: "-")
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "未命名脚本" : trimmed
    }

    private func ensureWorkspaceExists() {
        try? FileManager.default.createDirectory(at: workspaceURL(), withIntermediateDirectories: true)
    }

    private func workspaceURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documents.appendingPathComponent("MacScript", isDirectory: true)
    }
}

extension NSImage {
    var pngData: Data? {
        guard let tiffRepresentation else { return nil }
        guard let bitmap = NSBitmapImageRep(data: tiffRepresentation) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    var aspectRatioValue: Double {
        guard size.height > 0 else { return 16.0 / 9.0 }
        return Double(size.width / size.height)
    }
}
