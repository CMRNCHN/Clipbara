import SwiftUI
import SwiftData

struct RecentItemsPanel: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\ClipboardItem.copiedAt, order: .reverse)])
    private var allItems: [ClipboardItem]

    @State private var isHovered: UUID?

    private var recentItems: [ClipboardItem] {
        Array(allItems.filter { !$0.isDeleted }.prefix(8))
    }

    var body: some View {
        VStack(spacing: 8) {
            Text("Recent")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(recentItems) { item in
                        RecentItemCard(
                            item: item,
                            isHovered: isHovered == item.id,
                            onHover: { isHovered = item.id },
                            onUnhover: { isHovered = nil },
                            onPaste: { appState.paste(item, asPlainText: false) },
                            colorScheme: colorScheme
                        )
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
        .background(DesignTokens.Card.backgroundColor(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}

// MARK: - Recent Item Card

struct RecentItemCard: View {
    let item: ClipboardItem
    let isHovered: Bool
    let onHover: () -> Void
    let onUnhover: () -> Void
    let onPaste: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack(alignment: .topTrailing) {
                Group {
                    if item.isSensitive {
                        VStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.secondary.opacity(0.1))
                    } else if item.contentType == .image, let rawData = try? item.decryptedRawData(), let nsImage = NSImage(data: rawData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        VStack {
                            Image(systemName: item.contentType.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(DesignTokens.typeTint(for: item.contentType, itemColor: item.textContent))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(
                            DesignTokens.typeTint(for: item.contentType, itemColor: item.textContent)
                                .opacity(0.1)
                        )
                    }
                }
                .frame(height: 80)
                .clipped()

                // Copy button overlay
                if isHovered {
                    Button(action: onPaste) {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }

            // Title
            VStack(alignment: .leading, spacing: 4) {
                Text(item.userTitle ?? item.contentType.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)

                Text(RelativeTimeFormatter.string(for: item.copiedAt))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(6)
        }
        .frame(width: 90)
        .background(DesignTokens.Card.backgroundColor(for: colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isHovered
                        ? DesignTokens.Selection.borderColor
                        : DesignTokens.Card.borderColor(for: colorScheme),
                    lineWidth: isHovered ? 1 : 0.5
                )
        )
        .shadow(
            color: .black.opacity(isHovered ? 0.15 : 0.08),
            radius: isHovered ? 6 : 3,
            y: isHovered ? 3 : 1
        )
        .scaleEffect(isHovered ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            if hovering {
                onHover()
            } else {
                onUnhover()
            }
        }
    }
}

#Preview {
    RecentItemsPanel()
        .environment(AppState())
        .padding(16)
        .background(Color(.windowBackgroundColor))
}
