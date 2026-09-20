import Foundation
import AppKit
import os.log

actor ScreenshotManager {
    private let logger = Logger(subsystem: "com.minsang.Clipbara", category: "ScreenshotManager")

    func captureScreenshot() async -> Data? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-c", "-i"]

        let exitCode = try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int32, Error>) in
            task.terminationHandler = { _ in
                continuation.resume(returning: task.terminationStatus)
            }

            do {
                try task.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }

        // Exit code 1 = user cancelled (Esc), or task.run() threw
        guard let code = exitCode, code == 0 else {
            logger.debug("Screenshot capture failed or was cancelled")
            return nil
        }

        // Wait a moment for pasteboard to update
        try? await Task.sleep(for: .milliseconds(500))

        return getScreenshotDataFromPasteboard()
    }

    private func getScreenshotDataFromPasteboard() -> Data? {
        let pasteboard = NSPasteboard.general
        return pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png)
    }
}
