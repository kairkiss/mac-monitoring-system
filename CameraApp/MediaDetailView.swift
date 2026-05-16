import SwiftUI
import AVKit
import ImageIO
import UniformTypeIdentifiers

struct MediaDetailView: View {
    let item: MediaItem
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var showDeleteConfirm = false
    @State private var player: AVPlayer?
    @State private var imageLoaded = false

    var body: some View {
        ZStack {
            // Background blur
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Group {
                if item.fileType == .photo {
                    photoView
                } else {
                    videoView
                }
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(30)
                    .opacity(imageLoaded ? 1 : 0)
                    .scaleEffect(imageLoaded ? 1 : 0.95)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                            imageLoaded = true
                        }
                    }
            } else {
                ContentUnavailableView {
                    Label(Strings.photo, systemImage: "photo")
                } description: {
                    Text(item.fileName)
                }
            }
        }
    }

    private func loadDownsampledImage() -> NSImage? {
        let url = mediaLibrary.fileURL(for: item)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
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
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.2), radius: 16, y: 8)
                    .padding(30)
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
