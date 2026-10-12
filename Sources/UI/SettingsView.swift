import SwiftUI
import AppKit

public struct SettingsView: View {
    @ObservedObject public var state: AppState

    public init(state: AppState) {
        self.state = state
    }

    public var body: some View {
        TabView(selection: $state.selectedSettingsTab) {
            generalTab
                .tabItem {
                    Label(SettingsTab.general.rawValue, systemImage: SettingsTab.general.iconName)
                }
                .tag(SettingsTab.general)

            dictationTab
                .tabItem {
                    Label(SettingsTab.dictation.rawValue, systemImage: SettingsTab.dictation.iconName)
                }
                .tag(SettingsTab.dictation)

            shortcutsTab
                .tabItem {
                    Label(SettingsTab.shortcuts.rawValue, systemImage: SettingsTab.shortcuts.iconName)
                }
                .tag(SettingsTab.shortcuts)

            historyTab
                .tabItem {
                    Label(SettingsTab.history.rawValue, systemImage: SettingsTab.history.iconName)
                }
                .tag(SettingsTab.history)

            permissionsTab
                .tabItem {
                    Label(SettingsTab.permissions.rawValue, systemImage: SettingsTab.permissions.iconName)
                }
                .tag(SettingsTab.permissions)

            aboutTab
                .tabItem {
                    Label(SettingsTab.about.rawValue, systemImage: SettingsTab.about.iconName)
                }
                .tag(SettingsTab.about)
        }
        .padding(20)
        .frame(width: 520, height: 420)
    }

    // MARK: - 1. General Tab
    private var generalTab: some View {
        Form {
            Section {
                Toggle("Show Floating HUD Overlay", isOn: $state.showFloatingHUD)
                Text("Displays a sleek dynamic pill with live audio waveform at the bottom of the screen.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Push-to-Talk (Hold-to-Record)", isOn: $state.pushToTalk)
                Text("Hold shortcut while speaking and release to automatically paste. Quick tap toggles recording.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Section {
                Toggle("Launch Sagaa at Login", isOn: $state.launchAtLogin)
                Text("Start Sagaa automatically in the background when your Mac boots.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Section {
                Toggle("Auto-Paste into Active Application", isOn: $state.autoPaste)
                Text("Automatically insert transcribed text at your current text cursor.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if state.autoPaste {
                    Picker("Paste Delay", selection: $state.pasteDelayMs) {
                        Text("40 ms (Fastest)").tag(40)
                        Text("60 ms (Recommended)").tag(60)
                        Text("80 ms (Safe)").tag(80)
                        Text("100 ms (For Slow Apps)").tag(100)
                        Text("150 ms (Terminal / Remote)").tag(150)
                    }
                    .pickerStyle(MenuPickerStyle())
                    Text("Time allowed for modifier keys to release and target window to settle.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Section {
                Toggle("Sound Effects", isOn: $state.soundFeedback)
                Text("Play subtle system audio cues when starting and stopping dictation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 2. Dictation Tab
    private var dictationTab: some View {
        Form {
            Section {
                Toggle("Natural Word Flow (သဘာဝ စာလုံးပေါင်း)", isOn: $state.useNaturalFlow)
                Text("Intelligently merges raw Burmese syllables into natural words based on Myanmar grammatical rules.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Divider()

            Section {
                LabeledContent("ASR Architecture", value: "Conformer CTC (23.8M)")
                LabeledContent("Inference Precision", value: "Float16 (Apple Neural Engine)")
                LabeledContent("Audio DSP", value: "Hardware VoiceProcessingIO")
                LabeledContent("Noise Cancellation", value: "Active (Acoustic Echo & Background Cut)")
                LabeledContent("Sample Rate", value: "16,000 Hz (Mono PCM)")
                LabeledContent("Latency", value: "~24 ms warm inference")
            }
        }
    }

    // MARK: - 3. Shortcuts Tab
    private var shortcutsTab: some View {
        Form {
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Global Dictation Shortcut")
                            .font(.headline)
                        Text("Press anywhere across macOS to toggle recording.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("⌃")
                        Text("⌥")
                        Text("S")
                    }
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(6)
                }
            }

            Divider()

            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Interaction Modes:")
                        .font(.subheadline.bold())
                    Text("• Push-to-Talk: Hold ⌃⌥S while speaking, then release to instantly paste.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Tap-to-Talk: Tap ⌃⌥S once to record, and tap again when finished.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("• Zero Permissions Required: Carbon EventHotKey works system-wide without needing Accessibility keystroke monitoring.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 4. History Tab
    private var historyTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent Transcriptions (\(state.history.count))")
                    .font(.headline)
                Spacer()
                if !state.history.isEmpty {
                    Button("Clear History") {
                        state.clearHistory()
                    }
                    .buttonStyle(.borderless)
                    .foregroundColor(.red)
                }
            }

            if state.history.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("No dictation history yet.")
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(state.history) { record in
                            historyRow(record)
                        }
                    }
                }
            }
        }
    }

    private func historyRow(_ record: DictationRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(record.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(String(format: "%.0f", record.latencyMs)) ms")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(record.text, forType: .string)
                    state.copiedHistoryRecordId = record.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        if state.copiedHistoryRecordId == record.id {
                            state.copiedHistoryRecordId = nil
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: state.copiedHistoryRecordId == record.id ? "checkmark" : "doc.on.doc")
                        Text(state.copiedHistoryRecordId == record.id ? "Copied" : "Copy")
                    }
                    .font(.caption2)
                    .foregroundColor(state.copiedHistoryRecordId == record.id ? .green : .accentColor)
                }
                .buttonStyle(.plain)
            }

            Text(record.text)
                .font(.system(size: 13))
                .lineLimit(3)
        }
        .padding(10)
        .background(Color.primary.opacity(0.04))
        .cornerRadius(8)
    }

    // MARK: - 5. Permissions Tab
    private var permissionsTab: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Accessibility Permission")
                                .font(.headline)
                            Text("Required for automatic text injection (Cmd+V paste) into frontmost applications.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if state.isAccessibilityGranted {
                            Label("Granted", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        } else {
                            Label("Not Granted", systemImage: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Request Prompt") {
                            requestAccessibility()
                        }
                        Button("Open System Settings") {
                            openAccessibilitySettings()
                        }
                        Button("Reset Permission") {
                            resetAccessibilityPermission()
                        }
                    }
                    .buttonStyle(.bordered)

                    Text("Tip: If macOS displays Sagaa as enabled in System Settings but auto-paste doesn't inject text, click 'Reset Permission' to clear stale signatures from previous builds.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Microphone Access")
                            .font(.headline)
                        Text("Required for audio capture and 16kHz speech recognition.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if state.isMicrophoneGranted {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Open Settings") {
                            openMicrophoneSettings()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 6. About Tab
    private var aboutTab: some View {
        VStack(spacing: 12) {
            Image(systemName: "waveform.circle.fill")
                .resizable()
                .frame(width: 60, height: 60)
                .foregroundColor(SagaaTheme.primaryAccent)

            Text("Sagaa")
                .font(.title2.bold())
            Text("Version 1.0.0 (Apple Silicon Native)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Ultra-fast, private, and lightweight offline Burmese speech-to-text dictation app powered by End-to-End CoreML.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 20)

            Divider().padding(.vertical, 4)

            HStack(spacing: 16) {
                Button("GitHub Repository") {
                    if let url = URL(string: "https://github.com/tklwin/sagaa") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Model License (Apache 2.0)") {
                    if let url = URL(string: "https://huggingface.co/freococo/myanmar_asr") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.state.refreshPermissions()
        }
    }

    private func resetAccessibilityPermission() {
        let bundleID = Bundle.main.bundleIdentifier ?? "com.tklwin.sagaa"
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.launchPath = "/usr/bin/tccutil"
            task.arguments = ["reset", "Accessibility", bundleID]
            try? task.run()
            task.waitUntilExit()

            DispatchQueue.main.async {
                self.state.refreshPermissions()
                self.requestAccessibility()
            }
        }
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

