//
//  AddMemberView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import PhotosUI
import SwiftUI

struct AddMemberView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedRank: Rank = .soldier
    @State private var role = ""
    @State private var memoryTip = ""
    @State private var bundledImageName = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: Image?
    @State private var isSaving = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $name)

                    Picker("Rank", selection: $selectedRank) {
                        ForEach(Rank.allCases) { rank in
                            Text(rank.title).tag(rank)
                        }
                    }

                    TextField("Role", text: $role)
                }

                Section("Memory") {
                    TextField("Memory Tip", text: $memoryTip, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Import From Photo Library", systemImage: "photo.on.rectangle")
                    }

                    if let selectedPhotoPreview {
                        selectedPhotoPreview
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    TextField("Bundled Asset Name (Optional)", text: $bundledImageName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await saveMember()
                        }
                    }
                    .disabled(isSaveDisabled)
                }
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
    }

    private var isSaveDisabled: Bool {
        isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            selectedPhotoData = nil
            selectedPhotoPreview = nil
            return
        }

        do {
            if let data = try await selectedPhotoItem.loadTransferable(type: Data.self) {
                selectedPhotoData = data
                selectedPhotoPreview = Image(uiImage: UIImage(data: data) ?? UIImage())
                errorMessage = ""
            } else {
                errorMessage = "Unable to load the selected photo."
            }
        } catch {
            errorMessage = "Unable to load the selected photo."
        }
    }

    @MainActor
    private func saveMember() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try store.addMember(
                to: sectionID,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                rank: selectedRank,
                role: role.trimmingCharacters(in: .whitespacesAndNewlines),
                memoryTip: memoryTip.trimmingCharacters(in: .whitespacesAndNewlines),
                bundledImageName: normalizedBundledImageName,
                importedPhotoData: selectedPhotoData
            )
            dismiss()
        } catch {
            errorMessage = "Unable to save this member."
        }
    }

    private var normalizedBundledImageName: String? {
        let trimmed = bundledImageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
