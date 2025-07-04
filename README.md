# Test HTTP Server with Camera

This iOS/macOS application includes both camera functionality and a local HTTP server running on localhost:8000.

## Features

### Camera
- Access to device camera
- Photo capture and management
- Photo library integration

### HTTP Server
- Local HTTP server running on `localhost:8000`
- Web interface accessible from any browser
- REST API endpoints
- Real-time server status monitoring

## HTTP Server Endpoints

### Web Pages
- `GET /` - Home page with server information
- `GET /status` - Server status page

### API Endpoints
- `GET /api/status` - JSON response with server status

## How to Use

1. **Start the App**: Launch the application on your iOS device or Mac
2. **Navigate to HTTP Server**: Tap on "HTTP Server" in the main menu
3. **Start the Server**: Tap the "Start Server" button
4. **Access the Server**:
   - Tap "Open in Browser" to open directly in Safari
   - Or manually navigate to `http://localhost:8000` in any browser

## Accessing from macOS

When running on iOS Simulator or Mac:
- The server will be accessible at `http://localhost:8000`
- You can access it from Safari, Chrome, or any other browser
- The server provides both HTML pages and JSON API responses

## Network Permissions

The app includes the necessary network permissions:
- `NSLocalNetworkUsageDescription` - Required for local network access
- `NSBonjourServices` - For HTTP service discovery

## Server Features

- **Real-time Status**: Live updates of server status
- **Multiple Endpoints**: Both web pages and API responses
- **Error Handling**: Proper HTTP status codes and error pages
- **Responsive Design**: Web interface works on desktop and mobile browsers

## Development

The HTTP server is implemented using Apple's Network framework (`NWListener`) and provides:
- TCP socket listening on port 8000
- HTTP request parsing and response generation
- Asynchronous connection handling
- SwiftUI integration for status monitoring

## Troubleshooting

If the server doesn't start:
1. Check that port 8000 is not already in use
2. Ensure the app has network permissions
3. Try restarting the app
4. Check the console for error messages

## Security Notes

- The server only listens on localhost (127.0.0.1)
- No external network access is provided
- Suitable for development and testing purposes only
