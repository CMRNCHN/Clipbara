import AppKit

/// Reads the active tab URL from supported browsers via Apple Events, so `SensitiveRule`
/// domain rules can match a copy made on a specific site (e.g. a bank) regardless of
/// whether the browser itself is otherwise trusted.
enum BrowserURLProvider {

    private static let scriptByBundleID: [String: String] = [
        "com.apple.Safari": "tell application \"Safari\" to return URL of current tab of front window",
        "com.google.Chrome": "tell application \"Google Chrome\" to return URL of active tab of front window",
        "com.microsoft.edgemac": "tell application \"Microsoft Edge\" to return URL of active tab of front window",
        "com.brave.Browser": "tell application \"Brave Browser\" to return URL of active tab of front window",
        "com.vivaldi.Vivaldi": "tell application \"Vivaldi\" to return URL of active tab of front window",
        "company.thebrowser.Browser": "tell application \"Arc\" to return URL of active tab of front window",
    ]

    static func isSupportedBrowser(_ bundleID: String) -> Bool {
        scriptByBundleID[bundleID] != nil
    }

    /// Runs synchronously via Apple Events; only call this when a domain rule is
    /// actually configured, since the first call per browser blocks on a one-time
    /// Automation permission prompt.
    static func currentURL(forBundleID bundleID: String) -> URL? {
        guard let source = scriptByBundleID[bundleID],
              let script = NSAppleScript(source: source) else { return nil }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        guard error == nil, let urlString = result.stringValue else { return nil }
        return URL(string: urlString)
    }
}
