//
//  yarrApp.swift
//  Yarr
//
//  Created by Eric on 5/31/25.
//

import SwiftUI
import AppKit

@main
struct YarrApp: App {
    @State private var isKeyboardModeActive = false
    // Refined state variables for Command key double-press detection
    @State private var firstCommandReleaseTimestamp: Date? = nil
    @State private var isWaitingForSecondCommandRelease = false
    @State private var commandKeyDownPurely = false // Tracks if current key down is purely command
    @State private var globalEventMonitor: Any? = nil
    @State private var localEventMonitor: Any? = nil
    @State private var timeoutWorkItem: DispatchWorkItem? = nil

    var body: some Scene {
        WindowGroup {
            ContentView(isKeyboardModeActive: $isKeyboardModeActive)
                .onAppear {
                    setupEventMonitors()
                }
                .onDisappear {
                    removeEventMonitors()
                }
                .onChange(of: isKeyboardModeActive) { oldValue, newValue in
                    let baseTitle = "Yarr"
                    if newValue {
                        NSApplication.shared.mainWindow?.title = "\(baseTitle) - keyboard mode"
                    } else {
                        NSApplication.shared.mainWindow?.title = baseTitle
                    }
                }
        }
    }
    
    private func setupEventMonitors() {
        // Global event monitor (for events outside the app)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { event in
            handleCommandKeyEvent(event)
        }
        
        // Local event monitor (for events inside the app)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handleCommandKeyEvent(event)
            return event
        }
    }
    
    private func removeEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
        
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }
    
    private func handleCommandKeyEvent(_ event: NSEvent) {
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isCommandKeyDownNow = relevantFlags.contains(.command)

        if isCommandKeyDownNow {
            // Command key is currently down
            if relevantFlags == .command {
                // Command key is down *purely* (no other significant modifiers)
                // Mark that the current key down phase is pure.
                if !commandKeyDownPurely {
                    commandKeyDownPurely = true
                }
            } else {
                // Command key is down, but *with other modifiers*.
                // This invalidates any ongoing double-press sequence attempt and the purity of the current press.
                commandKeyDownPurely = false
                resetDoubleClickState()
            }
        } else {
            // Command key is currently up (i.e., was just released)
            if commandKeyDownPurely {
                // This means the command key was pressed purely and then released. This constitutes one "click".
                let now = Date()
                if isWaitingForSecondCommandRelease {
                    // We were waiting for the second click of a double-click sequence.
                    if let firstReleaseTime = firstCommandReleaseTimestamp, 
                       now.timeIntervalSince(firstReleaseTime) < 0.4 { // 400ms threshold
                        // This is a successful double-click.
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isKeyboardModeActive.toggle()
                        }
                        print("🎯 Double command key detected - keyboard mode: \(isKeyboardModeActive)")
                    }
                    // Whether the double-click was successful or timed out, reset the sequence.
                    resetDoubleClickState()
                } else {
                    // This is the first pure command key release in a potential double-click sequence.
                    firstCommandReleaseTimestamp = now
                    isWaitingForSecondCommandRelease = true
                    
                    // Set up timeout to reset the state if second click doesn't come
                    timeoutWorkItem?.cancel()
                    timeoutWorkItem = DispatchWorkItem { 
                        DispatchQueue.main.async {
                            self.resetDoubleClickState()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: timeoutWorkItem!)
                }
            } else {
                // Command key was released, but the preceding key-down phase was not pure.
                // Reset any ongoing double-press sequence.
                resetDoubleClickState()
            }
            // When command key goes up, the purity of the (now finished) down-phase is no longer relevant for the *next* press.
            commandKeyDownPurely = false
        }
    }
    
    private func resetDoubleClickState() {
        isWaitingForSecondCommandRelease = false
        firstCommandReleaseTimestamp = nil
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
    }
}
