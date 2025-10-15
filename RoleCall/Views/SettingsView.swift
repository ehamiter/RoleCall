//
//  SettingsView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var plexService: PlexService
    @State private var serverIP: String = ""
    @State private var showingAlert = false
    @Environment(\.dismiss) private var dismiss
    var onSettingsSaved: (() -> Void)?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Plex Server Configuration")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Server IP Address")
                            .font(.headline)
                        TextField("Enter server IP address", text: $serverIP)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .autocorrectionDisabled()
                        Text("Enter the IP address of your Plex Media Server (port 32400 will be added automatically)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if !serverIP.isEmpty && !isValidIPAddress(serverIP) {
                            Text("⚠️ Please enter a valid IP address (e.g., 192.168.1.100)")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(header: Text("Actions")) {
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .disabled(serverIP.isEmpty || !isValidIPAddress(serverIP))

                    if plexService.isLoggedIn {
                        Button("Logout", role: .destructive) {
                            plexService.logout()
                        }
                    }
                }

                if plexService.isLoggedIn {
                    Section(header: Text("Connection Status")) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Connected to Plex Server")
                        }

                        Text("Server: \(plexService.settings.serverIP)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Section(header: Text("Server Information")) {
                        NavigationLink(destination: ServerCapabilitiesView(plexService: plexService)) {
                            Label("Server Capabilities", systemImage: "server.rack")
                        }

                        NavigationLink(destination: ActivitiesView(plexService: plexService)) {
                            Label("Server Activities", systemImage: "gearshape.2")
                        }

                        NavigationLink(destination: SessionsView(plexService: plexService, selectedSessionIndex: $plexService.selectedSessionIndex)) {
                            Label("Active Sessions", systemImage: "play.circle")
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Settings Saved", isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text("Your Plex server settings have been saved.")
            }
        }
        .onAppear {
            serverIP = plexService.settings.serverIP
        }
    }

    private func saveSettings() {
        plexService.updateServerIP(serverIP)
        if let onSettingsSaved = onSettingsSaved {
            onSettingsSaved()
            dismiss()
        } else {
            showingAlert = true
        }
    }

    private func isValidIPAddress(_ ip: String) -> Bool {
        let parts = ip.components(separatedBy: ".")
        guard parts.count == 4 else { return false }

        for part in parts {
            guard let num = Int(part), num >= 0 && num <= 255 else {
                return false
            }
        }
        return true
    }
}

#Preview {
    SettingsView(plexService: PlexService())
}
