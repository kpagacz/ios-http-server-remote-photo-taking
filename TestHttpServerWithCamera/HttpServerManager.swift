import Foundation
import Network
import SwiftUI
import AVFoundation

class HttpServerManager: ObservableObject {
    private var listener: NWListener?
    let port: UInt16 = 8010
    @Published var isServerRunning = false
    @Published var serverStatus = "Stopped"

    // Add Camera reference
    private let camera: Camera

    init(camera: Camera) {
        self.camera = camera
    }

    func startServer() {
        guard !isServerRunning else { return }

        // Create the listener
        let parameters = NWParameters.tcp
        listener = try? NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

        listener?.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.isServerRunning = true
                    self?.serverStatus = "Running on localhost:\(self?.port ?? 8000)"
                    print("HTTP Server is running on localhost:\(self?.port ?? 8000)")
                case .failed(let error):
                    self?.isServerRunning = false
                    self?.serverStatus = "Failed: \(error.localizedDescription)"
                    print("HTTP Server failed: \(error)")
                case .cancelled:
                    self?.isServerRunning = false
                    self?.serverStatus = "Stopped"
                    print("HTTP Server stopped")
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleNewConnection(connection)
        }

        listener?.start(queue: .main)
    }

    func stopServer() {
        listener?.cancel()
        isServerRunning = false
        serverStatus = "Stopped"
    }

    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                self.receiveData(from: connection)
            case .failed, .cancelled:
                break
            default:
                break
            }
        }
        connection.start(queue: .main)
    }

    private func receiveData(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, let requestString = String(data: data, encoding: .utf8) {
                // Handle the request asynchronously
                Task {
                    let response = await self?.generateResponse(for: requestString) ?? "HTTP/1.1 500 Internal Server Error\r\n\r\n"
                    self?.sendResponse(response, to: connection)
                }
            }

            if isComplete || error != nil {
                connection.cancel()
            } else {
                self?.receiveData(from: connection)
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

    private func generateResponse(for request: String) async -> String {
        let lines = request.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else {
            return "HTTP/1.1 400 Bad Request\r\n\r\n"
        }

        let components = firstLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            return "HTTP/1.1 400 Bad Request\r\n\r\n"
        }

        let method = components[0]
        let path = components[1]

        switch (method, path) {
        case ("GET", "/"):
            return generateHomePage()
        case ("GET", "/status"):
            return generateStatusPage()
        case ("GET", "/api/status"):
            return generateJSONStatus()
        case ("GET", "/api/photo"):
            return await generateJSONPhoto()
        default:
            return generate404Page()
        }
    }

    private func generateJSONPhoto() async -> String {
        print("📸 generateJSONPhoto: Starting photo capture process")

        // Start camera if not running
        if !camera.isRunning {
            print("📸 generateJSONPhoto: Camera not running, starting it now")
            await camera.start()
        } else {
            print("📸 generateJSONPhoto: Camera is already running")
        }

        do {
            print("📸 generateJSONPhoto: Setting up photo capture")
            let photo = try await withThrowingTaskGroup(of: AVCapturePhoto.self) { group in
                group.addTask {
                    try await withCheckedThrowingContinuation { continuation in
                        print("📸 generateJSONPhoto: Setting up photo stream handler")
                        var photoStreamTask: Task<Void, Never>?
                        photoStreamTask = Task {
                            print("📸 generateJSONPhoto: Starting to listen to photo stream")
                            for await photo in self.camera.photoStream {
                                print("📸 generateJSONPhoto: Received photo from stream!")
                                photoStreamTask?.cancel()
                                continuation.resume(returning: photo)
                                break
                            }
                        }

                        // Set up timeout
                        Task {
                            print("📸 generateJSONPhoto: Setting up timeout task")
                            try await Task.sleep(for: .seconds(20))
                            if !photoStreamTask!.isCancelled {
                                print("📸 generateJSONPhoto: ⚠️ Timeout occurred while waiting for photo")
                                photoStreamTask?.cancel()
                                continuation.resume(throwing: NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Photo capture timeout"]))
                            }
                        }

                        // Take the photo after we're listening
                        print("📸 generateJSONPhoto: Taking photo...")
                        self.camera.takePhoto()
                    }
                }

                // Wait for the first result or timeout
                guard let photo = try await group.next() else {
                    throw NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "No photo captured"])
                }

                group.cancelAll()
                return photo
            }

            // Process the captured photo
            print("📸 generateJSONPhoto: Processing captured photo")
            guard let imageData = photo.fileDataRepresentation() else {
                throw NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to get photo data"])
            }

            print("📸 generateJSONPhoto: Successfully got photo data, size: \(imageData.count) bytes")

            // Convert to JPEG
            guard let uiImage = UIImage(data: imageData),
                  let jpegData = uiImage.jpegData(compressionQuality: 0.8) else {
                throw NSError(domain: "PhotoCapture", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to process photo data"])
            }

            let base64String = jpegData.base64EncodedString()

            let successResponse = [
                "status": "success",
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "image": base64String,
                "format": "jpeg",
                "size": jpegData.count
            ] as [String : Any]

            let jsonData = try JSONSerialization.data(withJSONObject: successResponse)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"

            return """
            HTTP/1.1 200 OK
            Content-Type: application/json
            Content-Length: \(jsonString.utf8.count)

            \(jsonString)
            """

        } catch {
            print("📸 generateJSONPhoto: ❌ Error during photo capture: \(error.localizedDescription)")
            let errorResponse = [
                "status": "error",
                "message": error.localizedDescription,
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ] as [String : Any]

            let jsonData = try? JSONSerialization.data(withJSONObject: errorResponse)
            let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) ?? "{}"

            return """
            HTTP/1.1 500 Internal Server Error
            Content-Type: application/json
            Content-Length: \(jsonString.utf8.count)

            \(jsonString)
            """
        }
    }

    private func generateHomePage() -> String {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Camera App Server</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .container { max-width: 800px; margin: 0 auto; }
                .status { padding: 10px; background: #f0f0f0; border-radius: 5px; margin: 20px 0; }
                .endpoint { background: #e8f4f8; padding: 10px; margin: 10px 0; border-left: 4px solid #2196F3; }
                .photo-endpoint { background: #e8f5e8; padding: 10px; margin: 10px 0; border-left: 4px solid #4CAF50; }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📷 Camera App HTTP Server</h1>
                <div class="status">
                    <strong>Status:</strong> \(isServerRunning ? "Running" : "Stopped")
                </div>
                <h2>Available Endpoints:</h2>
                <div class="endpoint">
                    <strong>GET /</strong> - This page
                </div>
                <div class="endpoint">
                    <strong>GET /status</strong> - Server status page
                </div>
                <div class="endpoint">
                    <strong>GET /api/status</strong> - JSON status response
                </div>
                <div class="photo-endpoint">
                    <strong>GET /api/photo</strong> - Capture and return photo as JSON (base64 encoded)
                </div>
                <p><em>Server running on localhost:\(port)</em></p>
            </div>
        </body>
        </html>
        """

        return """
        HTTP/1.1 200 OK
        Content-Type: text/html; charset=utf-8
        Content-Length: \(html.utf8.count)

        \(html)
        """
    }

    private func generateStatusPage() -> String {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Server Status</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; }
                .status { padding: 15px; background: #e8f5e8; border-radius: 5px; }
            </style>
        </head>
        <body>
            <h1>Server Status</h1>
            <div class="status">
                <p><strong>Status:</strong> \(isServerRunning ? "🟢 Running" : "🔴 Stopped")</p>
                <p><strong>Port:</strong> \(port)</p>
                <p><strong>Timestamp:</strong> \(Date())</p>
            </div>
            <p><a href="/">← Back to Home</a></p>
        </body>
        </html>
        """

        return """
        HTTP/1.1 200 OK
        Content-Type: text/html; charset=utf-8
        Content-Length: \(html.utf8.count)

        \(html)
        """
    }

    private func generateJSONStatus() -> String {
        let status = [
            "status": isServerRunning ? "running" : "stopped",
            "port": port,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "platform": "iOS/macOS"
        ] as [String : Any]

        let jsonData = try? JSONSerialization.data(withJSONObject: status)
        let jsonString = String(data: jsonData ?? Data(), encoding: .utf8) ?? "{}"

        return """
        HTTP/1.1 200 OK
        Content-Type: application/json
        Content-Length: \(jsonString.utf8.count)

        \(jsonString)
        """
    }

    private func generate404Page() -> String {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>404 - Not Found</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 40px; text-align: center; }
            </style>
        </head>
        <body>
            <h1>404 - Page Not Found</h1>
            <p>The requested resource was not found on this server.</p>
            <p><a href="/">← Back to Home</a></p>
        </body>
        </html>
        """

        return """
        HTTP/1.1 404 Not Found
        Content-Type: text/html; charset=utf-8
        Content-Length: \(html.utf8.count)

        \(html)
        """
    }
}
