import SwiftUI

struct ServerControlView: View {
    @ObservedObject var dataModel: DataModel
    @StateObject private var serverManager: HttpServerManager

    init(dataModel: DataModel) {
        self.dataModel = dataModel
        self._serverManager = StateObject(wrappedValue: HttpServerManager(camera: dataModel.camera))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("HTTP Server Control")
                .font(.largeTitle)
                .fontWeight(.bold)

            // Server Status
            VStack(alignment: .leading, spacing: 10) {
                Text("Server Status")
                    .font(.headline)

                HStack {
                    Circle()
                        .fill(serverManager.isServerRunning ? Color.green : Color.red)
                        .frame(width: 12, height: 12)

                    Text(serverManager.serverStatus)
                        .font(.body)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            // Control Buttons
            VStack(spacing: 15) {
                Button(action: {
                    if serverManager.isServerRunning {
                        serverManager.stopServer()
                    } else {
                        serverManager.startServer()
                    }
                }) {
                    HStack {
                        Image(systemName: serverManager.isServerRunning ? "stop.circle.fill" : "play.circle.fill")
                        Text(serverManager.isServerRunning ? "Stop Server" : "Start Server")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(serverManager.isServerRunning ? Color.red : Color.green)
                    .cornerRadius(10)
                }

                if serverManager.isServerRunning {
                    Button(action: {
                        if let url = URL(string: "http://localhost:\(serverManager.port)") {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open in Browser")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                }
            }

            // Server Information
            VStack(alignment: .leading, spacing: 10) {
                Text("Server Information")
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    InfoRow(label: "Port", value: "\(serverManager.port)")
                    InfoRow(label: "URL", value: "http://localhost:\(serverManager.port)")
                    InfoRow(label: "Status Endpoint", value: "/api/status")
                    InfoRow(label: "Status Page", value: "/status")
                    InfoRow(label: "Photo Endpoint", value: "/api/photo")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("HTTP Server")
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .monospaced))
        }
    }
}

#Preview {
    NavigationView {
        ServerControlView(dataModel: DataModel())
    }
}
