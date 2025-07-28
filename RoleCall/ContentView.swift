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

    var body: some View {
        NavigationView {
            Group {
                if plexService.isLoggedIn {
                    // Main app content when logged in - Now Playing focused
                    MainView(plexService: plexService)
                } else {
                    // Login view when not authenticated
                    LoginView(plexService: plexService)
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(plexService: plexService)
        }
    }
}

#Preview {
    ContentView()
}
