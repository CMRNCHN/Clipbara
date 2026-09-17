import SwiftUI

/// Placeholder shown instead of the normal card body for `item.isSensitive` items —
/// never touches `item.rawData`/`item.textContent` (which hold ciphertext) or the
/// decrypted accessors, so nothing sensitive ever reaches the view tree here.
struct SensitiveCardContent: View {
    let item: ClipboardItem
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "lock.fill")
                .font(.system(size: 20, weight: .medium))
            Text("Sensitive")
                .font(.system(size: 12, weight: .semibold))
            if let expiresAt = item.expiresAt {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(countdown(until: expiresAt, now: context.date))
                        .font(.system(size: 10))
                        .monospacedDigit()
                }
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func countdown(until expiresAt: Date, now: Date) -> String {
        let remaining = max(0, Int(expiresAt.timeIntervalSince(now)))
        return remaining > 0 ? "erases in \(remaining)s" : "erasing…"
    }
}
