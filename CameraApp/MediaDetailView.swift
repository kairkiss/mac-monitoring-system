import SwiftUI
import AVKit
import ImageIO
import UniformTypeIdentifiers

struct MediaDetailView: View {
    let allItems: [MediaItem]
    @Binding var currentIndex: Int
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var showDeleteConfirm = false
    @State private var player: AVPlayer?
    @State private var imageLoaded = false
    @State private var zoomScale: CGFloat = 1.0
    @State private var showEXIF = false
    @State private var exifData: [String: String] = [:]
    @State private var isSlideshowActive = false
    @State private var slideshowTimer: Timer?
    @State private var dragOffset: CGFloat = 0

    private var item: MediaItem { allItems[currentIndex] }

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()

            Group {
                if item.fileType == .photo {
                    photoView
                } else {
                    videoView
                }
            }

            // Bottom navigation bar
            if allItems.count > 1 {
                VStack {
                    Spacer()
                    navigationBar
                }
            }

            // EXIF overlay
            if showEXIF && item.fileType == .photo {
                VStack {
                    Spacer()
                    exifOverlay
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(item.fileName)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                if item.fileType == .photo {
                    Button { showEXIF.toggle() } label: {
                        Label(Strings.exifInfo, systemImage: showEXIF ? "info.circle.fill" : "info.circle")
                    }

                    Button { resetZoom() } label: {
                        Label(Strings.resetZoom, systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .disabled(zoomScale == 1.0)

                    Button { toggleSlideshow() } label: {
                        Label(Strings.slideshow, systemImage: isSlideshowActive ? "pause.fill" : "play.fill")
                    }

                    Button { shareItem() } label: {
                        Label(Strings.share, systemImage: "square.and.arrow.up")
                    }
                    Button { copyToClipboard() } label: {
                        Label(Strings.copyToClipboard, systemImage: "doc.on.doc")
                    }
                }
                Button { exportToFile() } label: {
                    Label(Strings.exportToFile, systemImage: "square.and.arrow.down")
                }
                Button { mediaLibrary.revealInFinder(item) } label: {
                    Label(Strings.revealInFinder, systemImage: "folder")
                }
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label(Strings.delete, systemImage: "trash")
                }
            }
        }
        .alert(Strings.confirmDelete, isPresented: $showDeleteConfirm) {
            Button(Strings.cancel, role: .cancel) { }
            Button(Strings.delete, role: .destructive) {
                mediaLibrary.deleteItem(item)
                if allItems.count > 1 {
                    if currentIndex >= allItems.count - 1 {
                        currentIndex = max(0, currentIndex - 1)
                    }
                }
            }
        } message: {
            Text(Strings.confirmDeleteMessage)
        }
        .onChange(of: currentIndex) { _, _ in
            handleIndexChange()
        }
        .onDisappear {
            stopSlideshow()
        }
        .gesture(swipeGesture)
    }

    // MARK: - Photo View

    private var photoView: some View {
        Group {
            if let image = loadDownsampledImage() {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(zoomScale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
                    .padding(30)
                    .opacity(imageLoaded ? 1 : 0)
                    .scaleEffect(imageLoaded ? 1 : 0.95, anchor: .center)
                    .onAppear {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.05)) {
                            imageLoaded = true
                        }
                        loadEXIFData()
                    }
                    .gesture(magnificationGesture)
            } else {
                ContentUnavailableView {
                    Label(Strings.photo, systemImage: "photo")
                } description: {
                    Text(item.fileName)
                }
            }
        }
    }

    // MARK: - Video View

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
            loadVideoPlayer()
        }
    }

    // MARK: - Navigation Bar

    private var navigationBar: some View {
        HStack(spacing: 20) {
            Button { navigateToPrevious() } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(currentIndex <= 0)
            .keyboardShortcut(.leftArrow, modifiers: [])

            Text("\(currentIndex + 1) / \(allItems.count)")
                .font(.callout.monospaced().bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())

            Button { navigateToNext() } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(currentIndex >= allItems.count - 1)
            .keyboardShortcut(.rightArrow, modifiers: [])
        }
        .padding(.bottom, 20)
    }

    // MARK: - EXIF Overlay

    private var exifOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Strings.exifInfo)
                    .font(.caption.bold())
                Spacer()
                Button { withAnimation { showEXIF = false } } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            if exifData.isEmpty {
                Text(Strings.noExifData)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(exifData.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text(key)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                        Text(value)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                        Spacer()
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 300)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
        .padding(.bottom, 80)
        .padding(.trailing, 20)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    // MARK: - Gestures

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onChanged { value in
                dragOffset = value.translation.width
            }
            .onEnded { value in
                if value.translation.width < -100 && currentIndex < allItems.count - 1 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentIndex += 1
                    }
                } else if value.translation.width > 100 && currentIndex > 0 {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        currentIndex -= 1
                    }
                }
                dragOffset = 0
            }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                zoomScale = max(0.5, min(value, 5.0))
            }
            .onEnded { _ in
                if zoomScale < 1.0 {
                    withAnimation(.spring(response: 0.3)) {
                        zoomScale = 1.0
                    }
                }
            }
    }

    // MARK: - Navigation

    private func navigateToNext() {
        guard currentIndex < allItems.count - 1 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentIndex += 1
        }
    }

    private func navigateToPrevious() {
        guard currentIndex > 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentIndex -= 1
        }
    }

    private func handleIndexChange() {
        zoomScale = 1.0
        showEXIF = false
        exifData = [:]
        imageLoaded = false
        if item.fileType == .photo {
            loadEXIFData()
        } else {
            loadVideoPlayer()
        }
    }

    // MARK: - Zoom

    private func resetZoom() {
        withAnimation(.spring(response: 0.3)) {
            zoomScale = 1.0
        }
    }

    // MARK: - Slideshow

    private func toggleSlideshow() {
        if isSlideshowActive {
            stopSlideshow()
        } else {
            startSlideshow()
        }
    }

    private func startSlideshow() {
        isSlideshowActive = true
        let interval = TimeInterval(SettingsStore.shared.slideshowIntervalSeconds)
        slideshowTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            DispatchQueue.main.async {
                if currentIndex < allItems.count - 1 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentIndex += 1
                    }
                } else {
                    stopSlideshow()
                }
            }
        }
    }

    private func stopSlideshow() {
        isSlideshowActive = false
        slideshowTimer?.invalidate()
        slideshowTimer = nil
    }

    // MARK: - EXIF

    private func loadEXIFData() {
        let url = mediaLibrary.fileURL(for: item)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else { return }

        var data: [String: String] = [:]

        if let width = properties[kCGImagePropertyPixelWidth as String] as? Int {
            data[Strings.imageWidth] = "\(width) px"
        }
        if let height = properties[kCGImagePropertyPixelHeight as String] as? Int {
            data[Strings.imageHeight] = "\(height) px"
        }

        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            if let make = exif[kCGImagePropertyExifLensMake as String] as? String {
                data[Strings.cameraMake] = make
            }
            if let model = exif[kCGImagePropertyExifLensModel as String] as? String {
                data[Strings.cameraModel] = model
            }
            if let aperture = exif[kCGImagePropertyExifFNumber as String] as? Double {
                data[Strings.aperture] = "f/\(String(format: "%.1f", aperture))"
            }
            if let iso = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Int], let first = iso.first {
                data[Strings.iso] = "\(first)"
            }
            if let shutter = exif[kCGImagePropertyExifExposureTime as String] as? Double {
                if shutter < 1 {
                    data[Strings.shutterSpeed] = "1/\(Int(1.0 / shutter))s"
                } else {
                    data[Strings.shutterSpeed] = "\(String(format: "%.1f", shutter))s"
                }
            }
            if let focal = exif[kCGImagePropertyExifFocalLength as String] as? Double {
                data[Strings.focalLength] = "\(Int(focal))mm"
            }
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String, data[Strings.cameraMake] == nil {
                data[Strings.cameraMake] = make
            }
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String, data[Strings.cameraModel] == nil {
                data[Strings.cameraModel] = model
            }
        }

        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
           let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
           let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double {
            let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
            let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
            data[Strings.gpsLocation] = String(format: "%.4f%@ %.4f%@", lat, latRef, lon, lonRef)
        }

        let fileAttrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = fileAttrs?[.size] as? Int64 {
            data[Strings.fileSizeLabel] = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
        }

        exifData = data
    }

    // MARK: - Helpers

    private func loadVideoPlayer() {
        player?.pause()
        let url = mediaLibrary.fileURL(for: item)
        player = AVPlayer(url: url)
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
}
