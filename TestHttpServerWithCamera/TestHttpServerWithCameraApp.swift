//
//  TestHttpServerWithCameraApp.swift
//  TestHttpServerWithCamera
//
//  Created by Konrad Pagacz on 27/06/2025.
//

import SwiftUI
import SwiftData

@main
struct TestHttpServerWithCameraApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // Create a shared DataModel instance
    @StateObject private var sharedDataModel = DataModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sharedDataModel)
        }
        .modelContainer(sharedModelContainer)
    }
}
