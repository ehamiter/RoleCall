//
//  MainView.swift
//  They Were Also In This
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct MainView: View {
    @ObservedObject var plexService: PlexService

    var body: some View {
        NavigationView {
            List {
                Section("Server Information") {
                    NavigationLink(destination: ServerCapabilitiesView(plexService: plexService)) {
                        Label("Server Capabilities", systemImage: "server.rack")
                    }

                    NavigationLink(destination: ActivitiesView(plexService: plexService)) {
                        Label("Server Activities", systemImage: "gearshape.2")
                    }

                    NavigationLink(destination: SessionsView(plexService: plexService)) {
                        Label("Active Sessions", systemImage: "play.circle")
                    }
                }

                Section("Features") {
                    // Placeholder for future features
                    Label("Movies & Cast", systemImage: "film")
                        .foregroundColor(.secondary)
                    Label("Search", systemImage: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Label("Favorites", systemImage: "heart")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("They Were Also In This")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    MainView(plexService: PlexService())
}
