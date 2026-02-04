import SwiftUI
import SwiftData

/// Simple picker to assign a folder to an item
struct FolderPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var item: DataStampItem
    let folders: [Folder]
    
    var body: some View {
        NavigationStack {
            List {
                // No folder option
                Button {
                    item.folder = nil
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray.full")
                            .foregroundStyle(.secondary)
                            .frame(width: 30)
                        Text("No Folder")
                        Spacer()
                        if item.folder == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .foregroundStyle(.primary)
                
                // Folders
                if !folders.isEmpty {
                    Section("Folders") {
                        ForEach(folders) { folder in
                            Button {
                                item.folder = folder
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: folder.icon)
                                        .foregroundStyle(folder.color)
                                        .frame(width: 30)
                                    Text(folder.name)
                                    Spacer()
                                    if item.folder?.id == folder.id {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
            }
            .navigationTitle("Select Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let item = DataStampItem(contentType: .text, contentHash: Data(), title: "Test")
    return FolderPickerView(item: item, folders: [])
        .modelContainer(for: [DataStampItem.self, Folder.self], inMemory: true)
}
