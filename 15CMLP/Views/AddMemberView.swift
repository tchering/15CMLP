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
    let viewModel: AddEditMemberViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            Form {
                Section("Identity") {
                    TextField("Name", text: $viewModel.name)

                    Picker("Rank", selection: $viewModel.selectedRank) {
                        ForEach(Rank.allCases) { rank in
                            Text(rank.title).tag(rank)
                        }
                    }

                    TextField("Phone Number (Optional)", text: $viewModel.phoneNumber)
                        .keyboardType(.phonePad)

                    TextField("Role", text: $viewModel.role)
                }

                Section("Memory") {
                    TextField("Memory Tip", text: $viewModel.memoryTip, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
                    Group {
                        if let preview = viewModel.selectedPhotoPreview {
                            Image(uiImage: preview)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else if case .edit = viewModel.mode {
                            MemberAvatar(member: viewModel.previewMember, size: 120)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(viewModel.modeLabelForPhotoAction, systemImage: "photo.on.rectangle")
                    }

                    if case .edit = viewModel.mode {
                        Button("Remove Custom Photo", role: .destructive) {
                            selectedPhotoItem = nil
                            viewModel.selectedPhotoData = nil
                            viewModel.selectedPhotoPreview = nil
                            viewModel.removePhoto = true
                        }
                    }

                    TextField("Bundled Asset Name (Optional)", text: $viewModel.bundledImageName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    if !viewModel.errorMessage.isEmpty {
                        Text(viewModel.errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(AccentBackground().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            if await viewModel.save() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaveDisabled)
                    .tint(.white)
                }
            }
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedPhoto()
        }
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            viewModel.loadSelectedPhotoData(nil)
            return
        }

        do {
            let data = try await selectedPhotoItem.loadTransferable(type: Data.self)
            viewModel.loadSelectedPhotoData(data)
        } catch {
            viewModel.errorMessage = "Unable to load the selected photo."
        }
    }
}

private extension AddEditMemberViewModel {
    var modeLabelForPhotoAction: String {
        switch mode {
        case .add:
            return "Import From Photo Library"
        case .edit:
            return "Change Profile Image"
        }
    }
}
