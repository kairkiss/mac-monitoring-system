import SwiftUI
import UniformTypeIdentifiers

struct MediaLibraryView: View {
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @EnvironmentObject var lang: LanguageManager
    @State private var selectedSegment = 0
    @State private var selection = Set<UUID>()
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var showBatchDeleteConfirm = false
    @State private var itemToDelete: MediaItem?
    @State private var detailItem: MediaItem?
    @State private var hoveredPhotoID: UUID?
    @State private var hoveredVideoID: UUID?

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header bar
                HStack {
                    Picker("", selection: $selectedSegment) {
                        Label(Strings.photos, systemImage: "photo").tag(0)
                        Label(Strings.videos, systemImage: "film").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 300)

                    Spacer()

                    if isEditing {
                        Button {
                            if !selection.isEmpty { showBatchDeleteConfirm = true }
                        } label: {
                            Label("\(Strings.delete) (\(selection.count))", systemImage: "trash")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.small)
                        .disabled(selection.isEmpty)
                        .transition(.scale.combined(with: .opacity))
                    }

                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            isEditing.toggle()
                            if !isEditing { selection.removeAll() }
                        }
                    } label: {
                        Text(isEditing ? Strings.done : Strings.select)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)

                Divider()

                if selectedSegment == 0 {
                    photoGrid
                        .transition(.opacity.combined(with: .move(edge: .leading)))
                } else {
                    videoList
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .navigationTitle(Strings.libraryTitle)
            .navigationDestination(item: $detailItem) { item in
                MediaDetailView(item: item)
            }
            .onAppear { mediaLibrary.scanLibrary() }
            .animation(.easeInOut(duration: 0.2), value: selectedSegment)
            .alert(Strings.confirmDelete, isPresented: $showDeleteConfirm) {
                Button(Strings.cancel, role: .cancel) { }
                Button(Strings.delete, role: .destructive) {
                    if let item = itemToDelete {
                        withAnimation(.spring(response: 0.3)) { mediaLibrary.deleteItem(item) }
                    }
                }
            } message: {
                Text(Strings.confirmDeleteMessage)
            }
            .alert(Strings.confirmDelete, isPresented: $showBatchDeleteConfirm) {
                Button(Strings.cancel, role: .cancel) { }
                Button("\(Strings.delete) (\(selection.count))", role: .destructive) {
                    withAnimation(.spring(response: 0.3)) {
                        let allItems = selectedSegment == 0 ? mediaLibrary.photos : mediaLibrary.videos
                        for item in allItems where selection.contains(item.id) {
                            mediaLibrary.deleteItem(item)
                        }
                        selection.removeAll()
                        isEditing = false
                    }
                }
            } message: {
                Text("\(selection.count) \(Strings.confirmDeleteMessage)")
            }
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        Group {
            if mediaLibrary.photos.isEmpty {
                animatedEmptyState(icon: "photo.on.rectangle", text: Strings.noPhotosYet)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(mediaLibrary.photos) { item in
                            photoCard(item)
                                .onTapGesture {
                                    if isEditing {
                                        toggleSelection(item.id)
                                    } else {
                                        detailItem = item
                                    }
                                }
                                .onDrag {
                                    let url = mediaLibrary.fileURL(for: item)
                                    return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                                }
                                .contextMenu {
                                    Button {
                                        shareMediaItem(item)
                                    } label: {
                                        Label(Strings.share, systemImage: "square.and.arrow.up")
                                    }
                                    Button {
                                        copyMediaToClipboard(item)
                                    } label: {
                                        Label(Strings.copyToClipboard, systemImage: "doc.on.doc")
                                    }
                                    Button {
                                        exportMediaToFile(item)
                                    } label: {
                                        Label(Strings.exportToFile, systemImage: "square.and.arrow.down")
                                    }
                                    Divider()
                                    Button { mediaLibrary.revealInFinder(item) } label: {
                                        Label(Strings.revealInFinder, systemImage: "folder")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showDeleteConfirm = true
                                    } label: {
                                        Label(Strings.delete, systemImage: "trash")
                                    }
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func photoCard(_ item: MediaItem) -> some View {
        let isHovered = hoveredPhotoID == item.id
        return VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                Group {
                    if let thumb = mediaLibrary.thumbnail(for: item, maxSize: CGSize(width: 240, height: 180)) {
                        Image(nsImage: thumb)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo")
                                    .font(.title)
                                    .foregroundStyle(.tertiary)
                            }
                    }
                }
                .frame(height: 140)
                .frame(maxWidth: .infinity)
                .clipped()

                if isEditing {
                    Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle.fill")
                        .font(.title2)
                        .foregroundStyle(selection.contains(item.id) ? .blue : .white.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .padding(8)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.createdAt, style: .date)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                Text(item.createdAt, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.12 : 0.06), radius: isHovered ? 10 : 4, y: isHovered ? 5 : 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            hoveredPhotoID = hovering ? item.id : nil
        }
    }

    // MARK: - Video List

    private var videoList: some View {
        Group {
            if mediaLibrary.videos.isEmpty {
                animatedEmptyState(icon: "film.stack", text: Strings.noVideosYet)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(mediaLibrary.videos) { item in
                            videoCard(item)
                                .onTapGesture {
                                    if isEditing {
                                        toggleSelection(item.id)
                                    } else {
                                        detailItem = item
                                    }
                                }
                                .onDrag {
                                    let url = mediaLibrary.fileURL(for: item)
                                    return NSItemProvider(contentsOf: url) ?? NSItemProvider()
                                }
                                .contextMenu {
                                    Button {
                                        exportMediaToFile(item)
                                    } label: {
                                        Label(Strings.exportToFile, systemImage: "square.and.arrow.down")
                                    }
                                    Divider()
                                    Button { mediaLibrary.revealInFinder(item) } label: {
                                        Label(Strings.revealInFinder, systemImage: "folder")
                                    }
                                    Divider()
                                    Button(role: .destructive) {
                                        itemToDelete = item
                                        showDeleteConfirm = true
                                    } label: {
                                        Label(Strings.delete, systemImage: "trash")
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(20)
                }
            }
        }
    }

    private func videoCard(_ item: MediaItem) -> some View {
        let isHovered = hoveredVideoID == item.id
        return HStack(spacing: 14) {
            if isEditing {
                Image(systemName: selection.contains(item.id) ? "checkmark.circle.fill" : "circle.fill")
                    .font(.title3)
                    .foregroundStyle(selection.contains(item.id) ? .blue : .secondary)
                    .transition(.scale)
            }

            Group {
                if let thumb = mediaLibrary.thumbnail(for: item, maxSize: CGSize(width: 100, height: 70)) {
                    Image(nsImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "film")
                                .foregroundStyle(.tertiary)
                        }
                }
            }
            .frame(width: 90, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.fileName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                HStack(spacing: 10) {
                    Text(item.createdAt, style: .date)
                    Text(item.createdAt, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(ByteCountFormatter.string(fromByteCount: item.fileSize, countStyle: .file))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if !isEditing {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.windowBackgroundColor))
                .shadow(color: .black.opacity(isHovered ? 0.08 : 0.04), radius: isHovered ? 8 : 3, y: isHovered ? 4 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isHovered)
        .onHover { hovering in
            hoveredVideoID = hovering ? item.id : nil
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ id: UUID) {
        withAnimation(.spring(response: 0.2)) {
            if selection.contains(id) {
                selection.remove(id)
            } else {
                selection.insert(id)
            }
        }
    }

    private func shareMediaItem(_ item: MediaItem) {
        let url = mediaLibrary.fileURL(for: item)
        guard let image = NSImage(contentsOf: url) else { return }
        let picker = NSSharingServicePicker(items: [image])
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func copyMediaToClipboard(_ item: MediaItem) {
        let url = mediaLibrary.fileURL(for: item)
        guard let image = NSImage(contentsOf: url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    private func exportMediaToFile(_ item: MediaItem) {
        let url = mediaLibrary.fileURL(for: item)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.fileName
        panel.allowedContentTypes = item.fileType == .photo ? [.jpeg] : [.quickTimeMovie]
        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }
            try? FileManager.default.copyItem(at: url, to: destURL)
        }
    }

    // MARK: - Animated Empty State

    private func animatedEmptyState(icon: String, text: String) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(.quaternary)
                    .frame(width: 90, height: 90)
                    .shadow(color: .black.opacity(0.04), radius: 8, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 38))
                    .foregroundStyle(.tertiary)
            }
            .transition(.scale.combined(with: .opacity))

            VStack(spacing: 6) {
                Text(text)
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("拖拽或右键导出文件")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
