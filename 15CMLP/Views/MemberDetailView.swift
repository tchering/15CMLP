//
//  MemberDetailView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import PhotosUI
import SwiftUI
import UIKit

struct MemberDetailView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID
    let memberID: UUID

    @Environment(\.openURL) private var openURL

    @State private var isShowingEditSheet = false
    @State private var alertMessage = ""
    @State private var isShowingAlert = false

    var body: some View {
        Group {
            if let section = store.section(withID: sectionID),
               let member = store.member(withID: memberID, in: sectionID) {
                ScrollView {
                    VStack(spacing: 20) {
                        MemberAvatar(member: member, size: 150)
                            .overlay {
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            }

                        VStack(spacing: 8) {
                            Text(member.name)
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Text(member.rank.title)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.72))

                            if !member.role.isEmpty {
                                Text(member.role)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Section", value: section.name)
                            DetailRow(title: "Grade", value: member.rank.title)
                            PhoneDetailRow(
                                phoneNumber: member.phoneNumber,
                                onCall: { call(phoneNumber: member.phoneNumber) },
                                onCopy: { copy(phoneNumber: member.phoneNumber) }
                            )
                            DetailRow(title: "Role", value: member.role)
                            DetailRow(title: "Memory Tip", value: member.memoryTip)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        }
                    }
                    .padding(20)
                }
                .background(AccentBackground().ignoresSafeArea())
                .navigationTitle(member.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            isShowingEditSheet = true
                        }
                        .tint(.white)
                    }
                }
                .sheet(isPresented: $isShowingEditSheet) {
                    EditMemberView(
                        store: store,
                        sectionID: sectionID,
                        member: member
                    )
                }
                .alert("Phone Action", isPresented: $isShowingAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(alertMessage)
                }
            } else {
                ContentUnavailableView("Member Missing", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
    }

    private func call(phoneNumber: String) {
        let digits = phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty, let url = URL(string: "tel://\(digits)") else {
            showAlert(message: "This phone number is not valid for calling.")
            return
        }

        openURL(url)
    }

    private func copy(phoneNumber: String) {
        guard !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            showAlert(message: "There is no phone number to copy.")
            return
        }

        UIPasteboard.general.string = phoneNumber
        showAlert(message: "Phone number copied.")
    }

    private func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}

private struct EditMemberView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID
    let member: Member

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var selectedRank: Rank
    @State private var phoneNumber: String
    @State private var role: String
    @State private var memoryTip: String
    @State private var bundledImageName: String
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedPhotoPreview: Image?
    @State private var removePhoto = false
    @State private var isSaving = false
    @State private var errorMessage = ""

    init(store: CompanyDirectoryStore, sectionID: UUID, member: Member) {
        self.store = store
        self.sectionID = sectionID
        self.member = member
        _name = State(initialValue: member.name)
        _selectedRank = State(initialValue: member.rank)
        _phoneNumber = State(initialValue: member.phoneNumber)
        _role = State(initialValue: member.role)
        _memoryTip = State(initialValue: member.memoryTip)
        _bundledImageName = State(initialValue: member.bundledImageName ?? "")
    }

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

                    TextField("Phone Number (Optional)", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    TextField("Role", text: $role)
                }

                Section("Memory") {
                    TextField("Memory Tip", text: $memoryTip, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
                    Group {
                        if let selectedPhotoPreview {
                            selectedPhotoPreview
                                .resizable()
                                .scaledToFill()
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        } else {
                            MemberAvatar(member: previewMember, size: 120)
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
                        Label("Change Profile Image", systemImage: "photo.on.rectangle")
                    }

                    Button("Remove Custom Photo", role: .destructive) {
                        selectedPhotoItem = nil
                        selectedPhotoData = nil
                        selectedPhotoPreview = nil
                        removePhoto = true
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
            .navigationTitle("Edit Member")
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
                            await saveChanges()
                        }
                    }
                    .disabled(isSaveDisabled)
                    .tint(.white)
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

    private var previewMember: Member {
        Member(
            id: member.id,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? member.name : name,
            rank: selectedRank,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role,
            memoryTip: memoryTip,
            bundledImageName: normalizedBundledImageName ?? member.bundledImageName,
            storedPhotoFileName: removePhoto ? nil : member.storedPhotoFileName
        )
    }

    @MainActor
    private func loadSelectedPhoto() async {
        guard let selectedPhotoItem else {
            return
        }

        do {
            if let data = try await selectedPhotoItem.loadTransferable(type: Data.self) {
                selectedPhotoData = data
                if let uiImage = UIImage(data: data) {
                    selectedPhotoPreview = Image(uiImage: uiImage)
                } else {
                    selectedPhotoPreview = nil
                }
                removePhoto = false
                errorMessage = ""
            } else {
                errorMessage = "Unable to load the selected photo."
            }
        } catch {
            errorMessage = "Unable to load the selected photo."
        }
    }

    @MainActor
    private func saveChanges() async {
        isSaving = true
        defer { isSaving = false }

        do {
            try store.updateMember(
                in: sectionID,
                memberID: member.id,
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                rank: selectedRank,
                phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                role: role.trimmingCharacters(in: .whitespacesAndNewlines),
                memoryTip: memoryTip.trimmingCharacters(in: .whitespacesAndNewlines),
                bundledImageName: normalizedBundledImageName,
                importedPhotoData: selectedPhotoData,
                removePhoto: removePhoto
            )
            dismiss()
        } catch {
            errorMessage = "Unable to save changes."
        }
    }

    private var normalizedBundledImageName: String? {
        let trimmed = bundledImageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            Text(value.isEmpty ? "None" : value)
                .font(.body)
                .foregroundStyle(.white)
        }
    }
}

private struct PhoneDetailRow: View {
    let phoneNumber: String
    let onCall: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phone")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            if phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("None")
                    .font(.body)
                    .foregroundStyle(.white)
            } else {
                Button(action: onCall) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(phoneNumber)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.white)

                            Text("Tap to call")
                                .font(.caption)
                                .foregroundStyle(.cyan)
                        }

                        Spacer()

                        Image(systemName: "phone.fill")
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button {
                        onCall()
                    } label: {
                        Label("Call", systemImage: "phone.fill")
                    }

                    Button {
                        onCopy()
                    } label: {
                        Label("Copy Number", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

struct MemberAvatar: View {
    let member: Member
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = MemberPhotoStorage.loadImage(for: member) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Text(member.initials)
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
    }
}
