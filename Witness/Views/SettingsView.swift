import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @AppStorage("iCloudSyncEnabled") private var iCloudSyncEnabled = false
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationStack {
            List {
                // iCloud Section (placeholder for future)
                Section {
                    Toggle("iCloud Sync", isOn: $iCloudSyncEnabled)
                        .disabled(true) // Coming soon
                } header: {
                    Text("iCloud")
                } footer: {
                    Text("Coming soon: Sync your timestamps across all your devices.")
                }
                
                // About Section
                Section("About") {
                    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")
                    
                    Link(destination: URL(string: "https://opentimestamps.org")!) {
                        HStack {
                            Text("OpenTimestamps")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // Data Section
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        Text("Delete All Data")
                    }
                } footer: {
                    Text("This will permanently delete all timestamps and proofs from this device.")
                }
                
                // Privacy Section
                Section("Privacy") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Local First", systemImage: "iphone")
                        Text("Your files and content never leave your device. Only cryptographic hashes are sent to timestamp servers.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("No Account Required", systemImage: "person.slash")
                        Text("Witness works without any signup or tracking. Your privacy is preserved.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Bitcoin Anchored", systemImage: "bitcoinsign.circle")
                        Text("Timestamps are anchored in the Bitcoin blockchain, providing mathematical proof of existence.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog("Delete All Data?", isPresented: $showingResetConfirmation, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your timestamps and proofs. This cannot be undone.")
            }
        }
    }
    
    private func deleteAllData() {
        do {
            try modelContext.delete(model: WitnessItem.self)
            try modelContext.save()
        } catch {
            print("Failed to delete data: \(error)")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: WitnessItem.self, inMemory: true)
}
