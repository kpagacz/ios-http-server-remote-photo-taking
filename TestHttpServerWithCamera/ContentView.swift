//
//  ContentView.swift
//  TestHttpServerWithCamera
//
//  Created by Konrad Pagacz on 27/06/2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var dataModel: DataModel
    @Query private var items: [Item]

    var body: some View {
        NavigationView {
            List {
                NavigationLink(destination: CameraView(model: dataModel)) {
                    HStack {
                        Image(systemName: "camera")
                            .foregroundColor(.blue)
                        Text("Camera")
                    }
                }

                NavigationLink(destination: ServerControlView(dataModel: dataModel)) {
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundColor(.green)
                        Text("HTTP Server")
                    }
                }
            }
            .navigationTitle("Test App")
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
        .environmentObject(DataModel())
}
