//
//  Cats_DogsApp.swift
//  Cats&Dogs
//
//  Created by Colin Tucker on 6/4/26.
//

import SwiftUI

private let splashDuration: Duration = .seconds(1.5)

@main
struct Cats_DogsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSplash = true

    var body: some Scene {
        WindowGroup {
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .task {
                        try? await Task.sleep(for: splashDuration)
                        withAnimation(.easeOut(duration: 0.3)) {
                            showSplash = false
                        }
                    }
            } else {
                RootView()
                    .transition(.opacity)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                WeatherBackgroundRefresher.shared.scheduleNextRefresh()
            }
        }
        .backgroundTask(.appRefresh(WeatherBackgroundRefresher.taskIdentifier)) {
            await WeatherBackgroundRefresher.shared.handleAppRefresh()
        }
    }
}
