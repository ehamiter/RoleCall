//
//  ContentView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var plexService = PlexService()
    @State private var showingSettings = false
    @State private var isInitialSetup = false
    @State private var showingSessionSwap = false

    var body: some View {
        NavigationView {
            Group {
                if plexService.isLoggedIn {
                    // Main app content when logged in - Now Playing focused
                    MainView(plexService: plexService)
                } else {
                    // Login view when not authenticated
                    LoginView(plexService: plexService) {
                        isInitialSetup = true
                        showingSettings = true
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Quick session swap, only relevant when multiple streams are active
                    if plexService.isLoggedIn && plexService.activeVideoSessions.count > 1 {
                        Button(action: {
                            showingSessionSwap = true
                        }) {
                            Image(systemName: "arrow.left.arrow.right")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isInitialSetup = false
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingSessionSwap) {
            SessionSwapView(plexService: plexService, selectedSessionIndex: $plexService.selectedSessionIndex)
        }
        .sheet(isPresented: $showingSettings) {
            if isInitialSetup {
                SettingsView(plexService: plexService) {
                    isInitialSetup = false
                }
            } else {
                SettingsView(plexService: plexService)
            }
        }
    }
}

#Preview {
    ContentView()
}
