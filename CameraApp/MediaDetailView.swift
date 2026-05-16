import SwiftUI
import AVKit
import ImageIO
import UniformTypeIdentifiers

struct MediaDetailView: View {
    let item: MediaItem
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var showDeleteConfirm = false
    @State private var player: AVPlayer?
    @State private var exportResult: URL?

    var body: some View {
        Group {
            if item.fileType == .photo {
                photoView
            } else {
                videoView
            }
        }
        .navigationTitle(item.fileName)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if item.fileType == .photo {
                    Button {
                        shareItem()
                    } label: {
                        Label(Strings.share, systemImage: "square.and.arrow.up")
                    }
                    Button {
                        copyToClipboard()
                    } label: {
                        Label(Strings.copyToClipboard, systemImage: "doc.on.doc")
                    }
                }
                Button {
                    exportToFile()
                } label: {
                    Label(Strings.exportToFile, systemImage: "square.and.arrow.down")
                }
                Button {
                    mediaLibrary.revealInFinder(item)
                } label: {
                    Label(Strings.revealInFinder, systemImage: "folder")
                }
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(Strings.delete, systemImage: "trash")
                }
            }
        }
        .alert(Strings.confirmDelete, isPresented: $showDeleteConfirm) {
            Button(Strings.cancel, role: .cancel) { }
            Button(Strings.delete, role: .destructive) {
                mediaLibrary.deleteItem(item)
            }
        } message: {
            Text(Strings.confirmDeleteMessage)
        }
    }

    private var photoView: some View {
        Group {
            if let image = loadDownsampledImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label(Strings.photo, systemImage: "photo")
                } description: {
                    Text(item.fileName)
                }
            }
        }
        .background(Color.black)
    }

    private func loadDownsampledImage() -> NSImage? {
        let url = mediaLibrary.fileURL(for: item)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let maxDimension: CGFloat = 2048
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    private func shareItem() {
        let url = mediaLibrary.fileURL(for: item)
        guard let image = NSImage(contentsOf: url) else { return }
        let picker = NSSharingServicePicker(items: [image])
        if let view = NSApp.keyWindow?.contentView {
            picker.show(relativeTo: .zero, of: view, preferredEdge: .minY)
        }
    }

    private func copyToClipboard() {
        let url = mediaLibrary.fileURL(for: item)
        guard let image = NSImage(contentsOf: url) else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([image])
    }

    private func exportToFile() {
        let url = mediaLibrary.fileURL(for: item)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.fileName
        panel.allowedContentTypes = item.fileType == .photo ? [.jpeg] : [.quickTimeMovie]
        panel.begin { response in
            guard response == .OK, let destURL = panel.url else { return }
            try? FileManager.default.copyItem(at: url, to: destURL)
        }
    }

    private var videoView: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            } else {
                ContentUnavailableView {
                    Label(Strings.video, systemImage: "film")
                } description: {
                    Text(item.fileName)
                }
            }
        }
        .onAppear {
            let url = mediaLibrary.fileURL(for: item)
            player = AVPlayer(url: url)
        }
    }
}
