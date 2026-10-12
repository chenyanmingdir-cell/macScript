//
//  PDFExporter.swift
//  macScript
//
//  Created by Nois on 2026/4/3.
//

import AppKit
import SwiftUI

enum PDFExporter {
    static func makePDF(project: ScriptProject) throws -> Data {
        let pageSize = project.frameAspectRatio >= 1
            ? CGSize(width: 1440, height: 900)  // 更大的页面
            : CGSize(width: 1000, height: 1440)

        let rowsPerPage = 4
        let pages = stride(from: 0, to: max(project.shots.count, 1), by: rowsPerPage).map { start in
            Array(project.shots[start..<min(start + rowsPerPage, project.shots.count)])
        }
        let actualPages = pages.isEmpty ? [[]] : pages

        let data = NSMutableData()
        var mediaBox = CGRect(origin: .zero, size: pageSize)

        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }

        for (index, shots) in actualPages.enumerated() {
            context.beginPDFPage([kCGPDFContextMediaBox: mediaBox] as CFDictionary)
            let pageView = PDFProjectPage(
                project: project,
                shots: shots,
                pageIndex: index + 1,
                pageSize: pageSize
            )
            .frame(width: pageSize.width, height: pageSize.height)
            .background(Color.white)

            let renderer = ImageRenderer(content: pageView)
            renderer.proposedSize = ProposedViewSize(pageSize)
            renderer.render { _, renderInContext in
                renderInContext(context)
            }
            context.endPDFPage()
        }

        context.closePDF()
        return data as Data
    }
}

private struct PDFProjectPage: View {
    let project: ScriptProject
    let shots: [ShotItem]
    let pageIndex: Int
    let pageSize: CGSize

    private let pagePadding: CGFloat = 40
    private let headerHeight: CGFloat = 40
    private let footerHeight: CGFloat = 30
    private let tableHeaderHeight: CGFloat = 50
    private let firstPageTopPadding: CGFloat = 80

    var body: some View {
        let columns = project.visibleColumns
        let tableWidth = columns.reduce(CGFloat(0)) { $0 + $1.width }
        let rowHeight = project.computedRowHeight
        let tableHeight = tableHeaderHeight + rowHeight * 4
        let hasHeader = pageIndex == 1
        let totalContentHeight = (hasHeader ? headerHeight : 0) + tableHeight + footerHeight

        return ZStack {
            Color.white

            VStack(spacing: 0) {
                if hasHeader {
                    header
                        .frame(height: headerHeight)
                        .padding(.horizontal, pagePadding)
                }

                table(columns: columns, rowHeight: rowHeight)
                    .padding(.horizontal, pagePadding)

                footer
                    .frame(height: footerHeight)
                    .padding(.horizontal, pagePadding)
            }
            .padding(.top, hasHeader ? firstPageTopPadding : pagePadding)
            .padding(.bottom, pagePadding)
        }
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text(project.title)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .padding(.bottom, 0)

            Spacer()

            Text("画幅比 \(project.frameAspectRatio >= 1 ? "16:9" : "9:16")  |  总镜头数 \(project.shots.count) 个  |  总时长 \(formattedDuration)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.bottom, 0)
        }
    }

    private func table(columns: [ColumnDefinition], rowHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(columns) { column in
                    Text(column.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: column.width, height: tableHeaderHeight)
                        .background(Color.white)
                        .overlay(alignment: .trailing) {
                            Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
                        }
                }
            }
            .overlay(
                Rectangle().stroke(Color.black.opacity(0.14), lineWidth: 1)
            )

            VStack(spacing: 0) {
                ForEach(Array(shots.enumerated()), id: \.element.id) { _, shot in
                    rowView(columns: columns, shot: shot, rowHeight: rowHeight)
                }

                ForEach(0..<max(0, 4 - shots.count), id: \.self) { _ in
                    emptyRow(columns: columns, rowHeight: rowHeight)
                }
            }
            .overlay(
                Rectangle().stroke(Color.black.opacity(0.14), lineWidth: 1)
            )
        }
    }

    private func rowView(columns: [ColumnDefinition], shot: ShotItem, rowHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                cell(for: column, shot: shot, rowHeight: rowHeight)
            }
        }
        .frame(height: rowHeight)
        .background(shot.shotNumber.isMultiple(of: 2) ? Color.black.opacity(0.02) : Color.clear)
    }

    private func emptyRow(columns: [ColumnDefinition], rowHeight: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: column.width, height: rowHeight)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
                    }
            }
        }
    }

    @ViewBuilder
    private func cell(for column: ColumnDefinition, shot: ShotItem, rowHeight: CGFloat) -> some View {
        switch column.role {
        case .order:
            plainCell("", width: column.width, rowHeight: rowHeight, centered: true)
        case .shotNumber:
            plainCell("\(shot.shotNumber)", width: column.width, rowHeight: rowHeight, centered: true)
        case .frameImage:
            imageCell(shot: shot, width: column.width, rowHeight: rowHeight)
        case .shotSize:
            plainCell(shot.shotSize, width: column.width, rowHeight: rowHeight, centered: false)
        case .duration:
            plainCell(shot.duration, width: column.width, rowHeight: rowHeight, centered: true)
        case .content:
            plainCell(shot.content, width: column.width, rowHeight: rowHeight, centered: false)
        case .note:
            plainCell(shot.note, width: column.width, rowHeight: rowHeight, centered: false)
        case .customText:
            plainCell(shot.customValues[column.id] ?? "", width: column.width, rowHeight: rowHeight, centered: false)
        }
    }

    private func plainCell(_ text: String, width: CGFloat, rowHeight: CGFloat, centered: Bool) -> some View {
        ZStack(alignment: centered ? .center : .leading) {
            if centered {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.center)
            } else {
                Text(text.isEmpty ? " " : text)
                    .font(.system(size: 15, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .padding(.horizontal, 14)
            }
        }
        .frame(width: width, height: rowHeight, alignment: centered ? .center : .leading)
        .clipped()
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
        }
    }

    private func frameCellContainer<Content: View>(
        width: CGFloat,
        rowHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.82))

            content()
        }
        .frame(width: width, height: rowHeight)
        .clipped()
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 1)
        }
    }

    private func imageDrawingSize(for width: CGFloat) -> CGSize {
        if project.frameAspectRatio >= 1 {
            let imageWidth = max(width - 24, 40)
            return CGSize(width: imageWidth, height: project.frameContentHeight)
        }

        let imageWidth = max(min(width - 24, 82), 40)
        return CGSize(width: imageWidth, height: project.frameContentHeight)
    }

    private func imageCell(shot: ShotItem, width: CGFloat, rowHeight: CGFloat) -> some View {
        let imageSize = imageDrawingSize(for: width)

        return frameCellContainer(width: width, rowHeight: rowHeight) {
            if let data = shot.imageData, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageSize.width, height: imageSize.height)
                    .clipped()
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
    }

    private var footer: some View {
        HStack {
            Text(project.teamName)
            Spacer()
            Text("视频分镜 · \(project.title) · 分镜 · \(pageIndex)")
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.top, 10)
    }

    private var formattedDuration: String {
        let total = project.totalDuration
        return total.rounded(.towardZero) == total ? "\(Int(total)) 秒" : String(format: "%.1f 秒", total)
    }
}
