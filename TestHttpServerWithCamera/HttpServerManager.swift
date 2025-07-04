import Foundation
import Network
import SwiftUI
import AVFoundation

// MARK: - HTTP Types
enum HttpMethod: String {
    case get = "GET"
    case post = "POST"
}

enum HttpPath: String {
    case root = "/"
    case status = "/status"
    case apiStatus = "/api/status"
    case apiPhoto = "/api/photo"
}

// MARK: - HttpServerManager
class HttpServerManager: ObservableObject {
    // MARK: - Properties
    private var listener: NWListener?
    let port: UInt16 = 8010
    @Published var isServerRunning = false
    @Published var serverStatus = "Stopped"
    private let camera: Camera
    private let photoTimeout: TimeInterval = 20
    private let httpQueue = DispatchQueue.init(label: "HttpServerQueue", qos: .default)

    // MARK: - Initialization
    init(camera: Camera) {
        self.camera = camera
    }

    // MARK: - Server Control
    func startServer() {
        guard !isServerRunning else { return }

        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)
            setupListenerHandlers()
            listener?.start(queue: httpQueue)
        } catch {
            handleServerError(error)
        }
    }

    func stopServer() {
        listener?.cancel()
        isServerRunning = false
        serverStatus = "Stopped"
    }

    // MARK: - Private Methods
    private func setupListenerHandlers() {
        listener?.stateUpdateHandler = { [weak self] state in
            self?.handleListenerState(state)
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.isServerRunning = true
                self.serverStatus = "Running on localhost:\(self.port)"
                print("HTTP Server is running on localhost:\(self.port)")
            case .failed(let error):
                self.handleServerError(error)
            case .cancelled:
                self.isServerRunning = false
                self.serverStatus = "Stopped"
                print("HTTP Server stopped")
            default:
                break
            }
        }
    }

    private func handleServerError(_ error: Error) {
        isServerRunning = false
        serverStatus = "Failed: \(error.localizedDescription)"
        print("HTTP Server error: \(error)")
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.receiveData(from: connection)
            case .failed, .cancelled:
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                Task(executorPreference: httpQueue) {
                        let response = await self.generateResponse(for: requestString)
                        self.sendResponse(response, to: connection)
                    }
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                self.receiveData(from: connection)
            }
        }
    }

    private func sendResponse(_ response: String, to connection: NWConnection) {
        guard let responseData = response.data(using: .utf8) else { return }

        connection.send(content: responseData, completion: .contentProcessed { error in
            if let error = error {
                print("Failed to send response: \(error)")
            }
        })
    }

    // MARK: - Response Generation
    private func generateResponse(for request: String) async -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first,
              let (method, path) = parseRequest(firstLine) else {
            return createResponse(status: .badRequest)
        }

        switch (method, path) {
        case (.get, .root):
            return createResponse(content: HttpTemplates.homePage(isServerRunning: isServerRunning, port: port))
        case (.get, .status):
            return createResponse(content: HttpTemplates.statusPage(isServerRunning: isServerRunning, port: port))
        case (.get, .apiStatus):
            return await generateJSONStatus()
        case (.get, .apiPhoto):
            return await generateJSONPhoto()
        default:
            return createResponse(status: .notFound, content: HttpTemplates.notFoundPage)
        }
    }

    private func parseRequest(_ requestLine: String) -> (HttpMethod, HttpPath)? {
        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2,
              let method = HttpMethod(rawValue: components[0]),
              let path = HttpPath(rawValue: components[1]) else {
            return nil
        }
        return (method, path)
    }

    // MARK: - Photo Capture
    private func generateJSONPhoto() async -> String {
        print("📸 Starting photo capture process")

        if !camera.isRunning {
            print("📸 Starting camera")
            await camera.start()
        }

        do {
            let photo = try await capturePhoto()
            let response = try await processPhoto(photo)
            return createResponse(content: response, contentType: "application/json")
        } catch {
            return createErrorResponse(error)
        }
    }

    private func capturePhoto() async throws -> AVCapturePhoto {
        try await withThrowingTaskGroup(of: AVCapturePhoto.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { continuation in
                    var photoStreamTask: Task<Void, Never>?
                    photoStreamTask = Task {
                        for await photo in self.camera.photoStream {
                            photoStreamTask?.cancel()
                            continuation.resume(returning: photo)
                            break
                        }
                    }

                    // Set up timeout
                    Task {
                        try await Task.sleep(for: .seconds(self.photoTimeout))
                        if !photoStreamTask!.isCancelled {
                            photoStreamTask?.cancel()
                            continuation.resume(throwing: PhotoCaptureError.timeout)
                        }
                    }

                    self.camera.takePhoto()
                }
            }

            guard let photo = try await group.next() else {
                throw PhotoCaptureError.noPhotoReceived
            }

            group.cancelAll()
            return photo
        }
    }

    private func processPhoto(_ photo: AVCapturePhoto) async throws -> String {
        guard let imageData = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: imageData),
              let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
            throw PhotoCaptureError.processingFailed
        }

        let response = [
            "status": "success",
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "image": jpegData.base64EncodedString(),
            "format": "jpeg",
            "size": jpegData.count
        ] as [String: Any]

        return try JSONSerialization.data(withJSONObject: response).toString()
    }

    private func generateJSONStatus() async -> String {
        let status: [String: Any] = [
            "status": isServerRunning ? "running" : "stopped",
            "port": port,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS/macOS"
        ]

        do {
            let jsonString = try JSONSerialization.data(withJSONObject: status).toString()
            return createResponse(content: jsonString, contentType: "application/json")
        } catch {
            return createErrorResponse(error)
        }
    }
}

// MARK: - Extensions
private extension Data {
    func toString() -> String {
        String(data: self, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Types
private enum HttpStatus {
    case ok
    case badRequest
    case notFound
    case internalError

    var code: Int {
        switch self {
        case .ok: return 200
        case .badRequest: return 400
        case .notFound: return 404
        case .internalError: return 500
        }
    }

    var description: String {
        switch self {
        case .ok: return "OK"
        case .badRequest: return "Bad Request"
        case .notFound: return "Not Found"
        case .internalError: return "Internal Server Error"
        }
    }
}

private enum PhotoCaptureError: LocalizedError {
    case timeout
    case noPhotoReceived
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .timeout: return "Photo capture timed out"
        case .noPhotoReceived: return "No photo was received"
        case .processingFailed: return "Failed to process photo data"
        }
    }
}

// MARK: - Response Helpers
private extension HttpServerManager {
    func createResponse(status: HttpStatus = .ok, content: String = "", contentType: String = "text/html; charset=utf-8") -> String {
        """
        HTTP/1.1 \(status.code) \(status.description)
        Content-Type: \(contentType)
        Content-Length: \(content.utf8.count)

        \(content)
        """
    }

    func createErrorResponse(_ error: Error) -> String {
        let errorResponse: [String: String] = [
            "status": "error",
            "message": error.localizedDescription,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]

        let jsonString = (try? JSONSerialization.data(withJSONObject: errorResponse))?.toString() ?? "{}"
        return createResponse(status: .internalError, content: jsonString, contentType: "application/json")
    }
}
