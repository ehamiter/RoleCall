//
//  LoginView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var plexService: PlexService
    @State private var showDemoButton = false
    var onServerSettingsTap: (() -> Void)?

    var body: some View {
        VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "tv.and.hifispeaker.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Login to Plex")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("You'll be redirected to Plex.tv to securely log in with your account")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Main Login Button
                Button(action: {
                    Task {
                        await plexService.startOAuthLogin()
                    }
                }) {
                    HStack {
                        if plexService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Image(systemName: "arrow.up.forward.app")
                        Text(plexService.isLoading ? "Authenticating..." : "Login with Plex")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canLogin ? Color.orange : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!canLogin || plexService.isLoading)
                .padding(.horizontal, 24)
                .padding(.top, 8)
                
                // Demo Account Section
                if showDemoButton {
                    VStack(spacing: 12) {
                        Divider()
                            .padding(.horizontal, 24)
                        
                        Text("Demo Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            Task {
                                await plexService.loginDemo(email: DemoService.demoEmail)
                            }
                        }) {
                            HStack {
                                if plexService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text("Login as Demo")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(plexService.isLoading)
                        .padding(.horizontal, 24)
                    }
                } else {
                    Button(action: {
                        showDemoButton = true
                    }) {
                        Text("App Review? Use Demo Account")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }

                // Error Message
                if let errorMessage = plexService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                if plexService.settings.serverIP.isEmpty {
                    Button(action: {
                        onServerSettingsTap?()
                    }) {
                        HStack {
                            Image(systemName: "server.rack")
                            Text("Enter Plex Media Server IP")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                } else {
                    VStack(spacing: 4) {
                        Text("Server: \(plexService.settings.serverIP)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if plexService.settings.serverIP.hasPrefix("10.") || plexService.settings.serverIP.hasPrefix("192.168.") || plexService.settings.serverIP.hasPrefix("172.") {
                            Text("🏠 Internal network connection")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else {
                            Text("🌐 External network connection")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)
                }
        }
    }

    private var canLogin: Bool {
        !plexService.settings.serverIP.isEmpty
    }
}

#Preview {
    LoginView(plexService: PlexService())
}
