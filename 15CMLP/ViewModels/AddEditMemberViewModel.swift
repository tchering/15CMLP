//
//  AddEditMemberViewModel.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Observation
import UIKit

@Observable
final class AddEditMemberViewModel {
    enum Mode {
        case add(sectionID: UUID)
        case edit(sectionID: UUID, member: Member)

        var sectionID: UUID {
            switch self {
            case .add(let sectionID), .edit(let sectionID, _):
                return sectionID
            }
        }

        var existingMember: Member? {
            switch self {
            case .add:
                return nil
            case .edit(_, let member):
                return member
            }
        }
    }

    let store: CompanyDirectoryStore
    let mode: Mode

    var name: String
    var selectedRank: Rank
    var phoneNumber: String
    var role: String
    var memoryTip: String
    var bundledImageName: String
    var selectedPhotoData: Data?
    var selectedPhotoPreview: UIImage?
    var removePhoto = false
    var isSaving = false
    var errorMessage = ""

    init(store: CompanyDirectoryStore, mode: Mode) {
        self.store = store
        self.mode = mode

        if let member = mode.existingMember {
            self.name = member.name
            self.selectedRank = member.rank
            self.phoneNumber = member.phoneNumber
            self.role = member.role
            self.memoryTip = member.memoryTip
            self.bundledImageName = member.bundledImageName ?? ""
        } else {
            self.name = ""
            self.selectedRank = .soldier
            self.phoneNumber = ""
            self.role = ""
            self.memoryTip = ""
            self.bundledImageName = ""
        }
    }

    var navigationTitle: String {
        switch mode {
        case .add:
            return "Add Member"
        case .edit:
            return "Edit Member"
        }
    }

    var isSaveDisabled: Bool {
        isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var previewMember: Member {
        let existingStoredFileName = mode.existingMember?.storedPhotoFileName

        return Member(
            id: mode.existingMember?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (mode.existingMember?.name ?? "") : name,
            rank: selectedRank,
            phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            role: role,
            memoryTip: memoryTip,
            bundledImageName: normalizedBundledImageName ?? mode.existingMember?.bundledImageName,
            storedPhotoFileName: removePhoto ? nil : existingStoredFileName
        )
    }

    var normalizedBundledImageName: String? {
        let trimmed = bundledImageName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    func loadSelectedPhotoData(_ data: Data?) {
        guard let data else {
            if case .add = mode {
                selectedPhotoData = nil
                selectedPhotoPreview = nil
            }
            return
        }

        selectedPhotoData = data
        selectedPhotoPreview = UIImage(data: data)
        removePhoto = false
        errorMessage = selectedPhotoPreview == nil ? "Unable to load the selected photo." : ""
    }

    @MainActor
    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }

        do {
            switch mode {
            case .add(let sectionID):
                try store.addMember(
                    to: sectionID,
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    rank: selectedRank,
                    phoneNumber: phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    role: role.trimmingCharacters(in: .whitespacesAndNewlines),
                    memoryTip: memoryTip.trimmingCharacters(in: .whitespacesAndNewlines),
                    bundledImageName: normalizedBundledImageName,
                    importedPhotoData: selectedPhotoData
                )
            case .edit(let sectionID, let member):
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
            }

            return true
        } catch {
            switch mode {
            case .add:
                errorMessage = "Unable to save this member."
            case .edit:
                errorMessage = "Unable to save changes."
            }
            return false
        }
    }
}
