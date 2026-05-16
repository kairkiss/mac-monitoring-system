import Foundation
import AppKit

enum SendResult: Equatable {
    case success
    case failure(String)
}

final class TelegramService: ObservableObject {
    static let shared = TelegramService()

    @Published var lastSendStatus: SendResult?
    @Published var isSending = false

    private init() {}

    func sendPhoto(imageData: Data, caption: String = "") {
        let settings = SettingsStore.shared
        let token = settings.telegramBotToken
        let chatID = settings.telegramChatID

        guard !token.isEmpty, !chatID.isEmpty else {
            DispatchQueue.main.async { [weak self] in
                self?.lastSendStatus = .failure(Strings.telegramNotConfigured)
            }
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.isSending = true
            self?.lastSendStatus = nil
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: "https://api.telegram.org/bot\(token)/sendPhoto")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // chat_id field
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"chat_id\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(chatID)\r\n".data(using: .utf8)!)

        // caption field
        if !caption.isEmpty {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"caption\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(caption)\r\n".data(using: .utf8)!)
        }

        // photo file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"photo\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSending = false

                if let error {
                    self.lastSendStatus = .failure(error.localizedDescription)
                    return
                }

                if let httpResponse = response as? HTTPURLResponse {
                    if httpResponse.statusCode == 200 {
                        self.lastSendStatus = .success
                    } else {
                        let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "Unknown error"
                        self.lastSendStatus = .failure("HTTP \(httpResponse.statusCode): \(body)")
                    }
                } else {
                    self.lastSendStatus = .failure("No response")
                }
            }
        }.resume()
    }

    func sendTestPhoto() {
        // Create a small test image (1x1 red pixel PNG)
        let size = NSSize(width: 100, height: 100)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) else {
            lastSendStatus = .failure("Failed to create test image")
            return
        }

        sendPhoto(imageData: jpegData, caption: "CameraApp test message")
    }
}
