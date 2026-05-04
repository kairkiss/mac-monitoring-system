import SwiftUI
import AVKit

struct MediaDetailView: View {
    let item: MediaItem
    @EnvironmentObject var mediaLibrary: MediaLibraryManager
    @State private var showDeleteConfirm = false
    @State private var player: AVPlayer?

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
            if let image = NSImage(contentsOf: mediaLibrary.fileURL(for: item)) {
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
