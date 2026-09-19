import SwiftUI
import SwiftData

struct ClipboardTimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: [SortDescriptor(\ClipboardItem.copiedAt, order: .reverse)])
    private var allItems: [ClipboardItem]

    @State private var searchText = ""
    @State private var selectedItem: UUID?
    @State private var filteredType: ContentType? = nil

    private var filteredItems: [ClipboardItem] {
        allItems.filter { item in
            !item.isDeleted &&
            (searchText.isEmpty || item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false) &&
            (filteredType == nil || item.contentType == filteredType)
        }
    }

    private var groupedByDate: [String: [ClipboardItem]] {
        Dictionary(grouping: filteredItems) { item in
            Calendar.current.isDateInToday(item.copiedAt) ? "Today" :
            Calendar.current.isDateInYesterday(item.copiedAt) ? "Yesterday" :
            item.copiedAt.formatted(date: .abbreviated, time: .omitted)
        }
    }

    private let dateOrder = ["Today", "Yesterday"]

    var body: some View {
        VStack(spacing: 0) {
            // Search & Filter Bar
            VStack(spacing: 8) {
                SearchBar(text: $searchText, placeholder: "Search clipboard history...")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ContentType.allCases, id: \.self) { type in
                            FilterChip(
                                label: type.displayName,
                                isSelected: filteredType == type,
                                action: {
                                    filteredType = filteredType == type ? nil : type
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 4)
            }
            .padding(12)
            .background(DesignTokens.Card.backgroundColor(for: colorScheme))
            .border(width: 0.5, edges: [.bottom], color: DesignTokens.Card.borderColor(for: colorScheme))

            // Timeline
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No clipboard history")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Start copying to fill your timeline" : "No items match your search")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(DesignTokens.Card.backgroundColor(for: colorScheme))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        ForEach(dateOrder.filter { groupedByDate[$0] != nil }, id: \.self) { dateKey in
                            TimelineSection(
                                title: dateKey,
                                items: groupedByDate[dateKey] ?? [],
                                selectedItem: $selectedItem,
                                appState: appState,
                                colorScheme: colorScheme
                            )
                        }

                        // Other dates in reverse chronological order
                        ForEach(
                            groupedByDate.keys
                                .filter { !dateOrder.contains($0) }
                                .sorted(by: { a, b in
                                    (groupedByDate[a]?.first?.copiedAt ?? .distantPast) >
                                    (groupedByDate[b]?.first?.copiedAt ?? .distantPast)
                                }),
                            id: \.self
                        ) { dateKey in
                            TimelineSection(
                                title: dateKey,
                                items: groupedByDate[dateKey] ?? [],
                                selectedItem: $selectedItem,
                                appState: appState,
                                colorScheme: colorScheme
                            )
                        }
                    }
                    .padding(16)
                }
                .background(DesignTokens.Card.backgroundColor(for: colorScheme))
            }
        }
        .background(DesignTokens.Card.backgroundColor(for: colorScheme))
    }
}

// MARK: - Timeline Section

struct TimelineSection: View {
    let title: String
    let items: [ClipboardItem]
    @Binding var selectedItem: UUID?
    let appState: AppState
    let colorScheme: ColorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.callout)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 10) {
                ForEach(items) { item in
                    TimelineItemRow(
                        item: item,
                        isSelected: selectedItem == item.id,
                        onSelect: { selectedItem = item.id },
                        onPaste: { appState.paste(item, asPlainText: false) },
                        colorScheme: colorScheme
                    )
                }
            }
        }
    }
}

// MARK: - Timeline Item Row

struct TimelineItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onPaste: () -> Void
    let colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail/Icon
            Group {
                if item.isSensitive {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 48, height: 48)
                        .background(Color.secondary.opacity(0.1))
                } else if item.contentType == .image, let rawData = try? item.decryptedRawData(), let nsImage = NSImage(data: rawData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 48, height: 48)
                } else {
                    Image(systemName: item.contentType.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DesignTokens.typeTint(for: item.contentType, itemColor: item.textContent))
                        .frame(width: 48, height: 48)
                        .background(
                            DesignTokens.typeTint(for: item.contentType, itemColor: item.textContent)
                                .opacity(0.1)
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        DesignTokens.Card.borderColor(for: colorScheme),
                        lineWidth: 0.5
                    )
            )

            // Content
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.userTitle ?? item.contentType.displayName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    if item.isSensitive {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(RelativeTimeFormatter.string(for: item.copiedAt))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !item.isSensitive, let preview = item.textContent?.prefix(80) {
                    Text(String(preview))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Spacer()

            // Copy Button
            Button(action: onPaste) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Copy to clipboard")
        }
        .padding(12)
        .background(
            isSelected
                ? DesignTokens.Selection.borderColor.opacity(0.1)
                : DesignTokens.Card.backgroundColor(for: colorScheme)
        )
        .border(
            width: isSelected ? 1 : 0.5,
            edges: [.top, .bottom, .leading, .trailing],
            color: isSelected
                ? DesignTokens.Selection.borderColor
                : DesignTokens.Card.borderColor(for: colorScheme)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onSelect)
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(Color(.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(isSelected ? Color.blue : Color(.controlBackgroundColor))
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ClipboardTimelineView()
        .environment(AppState())
}
