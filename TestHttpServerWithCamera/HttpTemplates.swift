import Foundation

struct HttpTemplates {
    static func homePage(isServerRunning: Bool, port: UInt16) -> String {
        """
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
    }

    static func statusPage(isServerRunning: Bool, port: UInt16) -> String {
        """
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
    }

    static let notFoundPage = """
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
}
