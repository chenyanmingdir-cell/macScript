//
//  macscript-pdf
//  Headless PDF export for macScript storyboard projects.
//
//  usage: macscript-pdf <project.macscript> [out.pdf]
//

import AppKit
import Foundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("error: \(message)\n".utf8))
    exit(1)
}

@MainActor
func run() {
    let arguments = CommandLine.arguments

    guard arguments.count >= 2 else {
        FileHandle.standardError.write(Data("usage: macscript-pdf <project.macscript> [out.pdf]\n".utf8))
        exit(2)
    }

    // ImageRenderer needs AppKit up before offscreen rendering, otherwise text
    // can render with fallback metrics.
    let application = NSApplication.shared
    application.setActivationPolicy(.prohibited)

    let inputURL = URL(fileURLWithPath: (arguments[1] as NSString).expandingTildeInPath)
    let outputURL: URL = arguments.count >= 3
        ? URL(fileURLWithPath: (arguments[2] as NSString).expandingTildeInPath)
        : inputURL.deletingPathExtension().appendingPathExtension("pdf")

    do {
        let data = try Data(contentsOf: inputURL)
        var project = try JSONDecoder().decode(ScriptProject.self, from: data)
        project.normalize()
        let pdf = try PDFExporter.makePDF(project: project)
        try pdf.write(to: outputURL, options: .atomic)
        print(outputURL.path)
    } catch {
        fail("\(error)")
    }
}

MainActor.assumeIsolated {
    run()
}
