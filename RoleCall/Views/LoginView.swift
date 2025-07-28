//
//  LoginView.swift
//  RoleCall
//
//  Created by Eric on 7/28/25.
//

import SwiftUI

struct LoginView: View {
    @ObservedObject var plexService: PlexService
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showingPassword = false

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "tv.and.hifispeaker.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)

                    Text("Login to Plex")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Enter your Plex credentials to connect to your media server")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)

                // Login Form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email or Username")
                            .font(.headline)
                        TextField("Enter your email or username", text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        HStack {
                            Group {
                                if showingPassword {
                                    TextField("Enter your password", text: $password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                            Button(action: {
                                showingPassword.toggle()
                            }) {
                                Image(systemName: showingPassword ? "eye.slash" : "eye")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)

                // Login Button
                Button(action: {
                    Task {
                        await plexService.login(username: username, password: password)
                    }
                }) {
                    HStack {
                        if plexService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        Text(plexService.isLoading ? "Logging in..." : "Login")
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

                // Error Message
                if let errorMessage = plexService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal, 24)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                // Server Settings Note
                VStack(spacing: 8) {
                    Text("Make sure to configure your Plex server settings first")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    if plexService.settings.serverIP.isEmpty {
                        Text("⚠️ No server IP configured")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Server: \(plexService.settings.serverIP)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }

    private var canLogin: Bool {
        !username.isEmpty && !password.isEmpty && !plexService.settings.serverIP.isEmpty
    }
}

#Preview {
    LoginView(plexService: PlexService())
}
