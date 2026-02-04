import SwiftUI
import SwiftData

/// View for managing folders
struct FolderListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Query(sort: \Folder.sortOrder) private var folders: [Folder]
    
    @State private var showingAddFolder = false
    @State private var editingFolder: Folder?
    @State private var newFolderName = ""
    @State private var newFolderIcon = "folder.fill"
    @State private var newFolderColor = "F7931A"
    
    let onSelect: ((Folder?) -> Void)?
    let selectedFolder: Folder?
    
    init(selectedFolder: Folder? = nil, onSelect: ((Folder?) -> Void)? = nil) {
        self.selectedFolder = selectedFolder
        self.onSelect = onSelect
    }
    
    var body: some View {
        NavigationStack {
            List {
                // All Items option
                Button {
                    onSelect?(nil)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "tray.full.fill")
                            .foregroundStyle(.orange)
                            .frame(width: 30)
                        Text("All Timestamps")
                        Spacer()
                        if selectedFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                .foregroundStyle(.primary)
                
                // Folders section
                if !folders.isEmpty {
                    Section("Folders") {
                        ForEach(folders) { folder in
                            FolderRow(
                                folder: folder,
                                isSelected: selectedFolder?.id == folder.id,
                                onTap: {
                                    onSelect?(folder)
                                    dismiss()
                                },
                                onEdit: {
                                    editingFolder = folder
                                    newFolderName = folder.name
                                    newFolderIcon = folder.icon
                                    newFolderColor = folder.colorHex
                                    showingAddFolder = true
                                }
                            )
                        }
                        .onDelete(perform: deleteFolders)
                        .onMove(perform: moveFolders)
                    }
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingFolder = nil
                        newFolderName = ""
                        newFolderIcon = "folder.fill"
                        newFolderColor = "F7931A"
                        showingAddFolder = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddFolder) {
                FolderEditorSheet(
                    name: $newFolderName,
                    icon: $newFolderIcon,
                    colorHex: $newFolderColor,
                    isEditing: editingFolder != nil,
                    onSave: saveFolder,
                    onCancel: {
                        showingAddFolder = false
                    }
                )
            }
        }
    }
    
    private func saveFolder() {
        if let folder = editingFolder {
            folder.name = newFolderName
            folder.icon = newFolderIcon
            folder.colorHex = newFolderColor
        } else {
            let folder = Folder(
                name: newFolderName,
                icon: newFolderIcon,
                colorHex: newFolderColor,
                sortOrder: folders.count
            )
            modelContext.insert(folder)
        }
        showingAddFolder = false
    }
    
    private func deleteFolders(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(folders[index])
        }
    }
    
    private func moveFolders(from source: IndexSet, to destination: Int) {
        var reorderedFolders = folders
        reorderedFolders.move(fromOffsets: source, toOffset: destination)
        for (index, folder) in reorderedFolders.enumerated() {
            folder.sortOrder = index
        }
    }
}

// MARK: - Folder Row

struct FolderRow: View {
    let folder: Folder
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: folder.icon)
                    .foregroundStyle(folder.color)
                    .frame(width: 30)
                
                Text(folder.name)
                
                Spacer()
                
                Text("\(folder.itemCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.fill.tertiary, in: Capsule())
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.orange)
                }
            }
        }
        .foregroundStyle(.primary)
        .swipeActions(edge: .trailing) {
            Button("Edit", systemImage: "pencil") {
                onEdit()
            }
            .tint(.blue)
        }
    }
}

// MARK: - Folder Editor Sheet

struct FolderEditorSheet: View {
    @Binding var name: String
    @Binding var icon: String
    @Binding var colorHex: String
    
    let isEditing: Bool
    let onSave: () -> Void
    let onCancel: () -> Void
    
    let availableIcons = [
        "folder.fill", "folder.badge.person.crop", "folder.badge.gear",
        "archivebox.fill", "tray.full.fill", "doc.fill",
        "star.fill", "heart.fill", "bookmark.fill",
        "tag.fill", "flag.fill", "pin.fill",
        "briefcase.fill", "house.fill", "building.fill",
        "camera.fill", "photo.fill", "paintbrush.fill"
    ]
    
    let availableColors = [
        "F7931A", "FF6B6B", "4ECDC4", "45B7D1",
        "96CEB4", "FFEAA7", "DDA0DD", "98D8C8",
        "F38181", "AA96DA", "FCBAD3", "A8D8EA"
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Folder name", text: $name)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableIcons, id: \.self) { iconName in
                            Button {
                                icon = iconName
                            } label: {
                                Image(systemName: iconName)
                                    .font(.title2)
                                    .frame(width: 44, height: 44)
                                    .background(icon == iconName ? Color.orange.opacity(0.2) : Color.clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .foregroundStyle(icon == iconName ? .orange : .primary)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(availableColors, id: \.self) { hex in
                            Button {
                                colorHex = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex) ?? .orange)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Preview") {
                    HStack {
                        Image(systemName: icon)
                            .foregroundStyle(Color(hex: colorHex) ?? .orange)
                            .frame(width: 30)
                        Text(name.isEmpty ? "Folder Name" : name)
                            .foregroundStyle(name.isEmpty ? .secondary : .primary)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Folder" : "New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: onSave)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    FolderListView()
        .modelContainer(for: [Folder.self, DataStampItem.self], inMemory: true)
}
