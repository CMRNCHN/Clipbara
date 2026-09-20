import Foundation
import AppKit

actor ScreenshotManager {
    private let fileManager = FileManager.default
    private var lastProcessedScreenshots: Set<String> = []

    // Monitor typical screenshot locations for new files
    private let screenshotDirectories: [String] = [
        "~/Desktop".expandingTildeInPath,
        "~/Pictures".expandingTildeInPath,
        "~/Downloads".expandingTildeInPath,
    ]

    func captureScreenshot() async -> NSImage? {
        // Take a screenshot using macOS screenshot functionality
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")

        // Use -c to copy to clipboard, -i for interactive
        task.arguments = ["-c", "-i"]

        do {
            try task.run()
            task.waitUntilExit()

            // Wait a moment for pasteboard to update
            try? await Task.sleep(for: .milliseconds(500))

            // Check if an image is on the pasteboard
            return self.getScreenshotFromPasteboard()
        } catch {
            return nil
        }
    }

    func getScreenshotFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        guard let imageData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) else {
            return nil
        }
        return NSImage(data: imageData)
    }

    func checkForNewScreenshots() async -> [ScreenshotFile] {
        var newScreenshots: [ScreenshotFile] = []

        for directory in screenshotDirectories {
            guard fileManager.fileExists(atPath: directory) else { continue }

            do {
                let files = try fileManager.contentsOfDirectory(
                    at: URL(fileURLWithPath: directory),
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                for file in files {
                    guard isScreenshot(file) else { continue }

                    let fileName = file.lastPathComponent
                    guard !lastProcessedScreenshots.contains(fileName) else { continue }

                    if let modDate = try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                       Date().timeIntervalSince(modDate) < 30 {
                        // Recent screenshot (within last 30 seconds)
                        lastProcessedScreenshots.insert(fileName)
                        newScreenshots.append(ScreenshotFile(url: file, date: modDate))
                    }
                }
            } catch {
                continue
            }
        }

        return newScreenshots
    }

    private func isScreenshot(_ file: URL) -> Bool {
        let name = file.lastPathComponent.lowercased()
        let imageExtensions = ["png", "jpg", "jpeg"]

        // Check if it's an image
        guard imageExtensions.contains(where: { name.hasSuffix($0) }) else {
            return false
        }

        // Check if filename matches macOS screenshot pattern
        return name.hasPrefix("screenshot") ||
               name.hasPrefix("screen shot") ||
               name.contains("screenshot")
    }
}

struct ScreenshotFile: Hashable {
    let url: URL
    let date: Date

    var data: Data? {
        try? Data(contentsOf: url)
    }

    var image: NSImage? {
        guard let data else { return nil }
        return NSImage(data: data)
    }
}

extension String {
    var expandingTildeInPath: String {
        NSString(string: self).expandingTildeInPath
    }
}
