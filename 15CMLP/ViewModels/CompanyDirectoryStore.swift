//
//  CompanyDirectoryStore.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import Observation

@Observable
final class CompanyDirectoryStore {
    var sections: [CompanySection]

    private let persistence: CompanyDirectoryPersistenceService
    private let photoStorage: MemberPhotoStorageService
    private let backupService: CompanyBackupService
    private let rosterImportService: RosterImportService

    init(
        persistence: CompanyDirectoryPersistenceService = CompanyDirectoryPersistenceService(),
        photoStorage: MemberPhotoStorageService = .shared,
        backupService: CompanyBackupService? = nil,
        rosterImportService: RosterImportService = RosterImportService()
    ) {
        self.persistence = persistence
        self.photoStorage = photoStorage
        self.backupService = backupService ?? CompanyBackupService(
            photoStorage: photoStorage,
            persistence: persistence
        )
        self.rosterImportService = rosterImportService
        self.sections = Self.ensureDefaultSections(in: persistence.loadSections())

        do {
            try persistence.saveSections(sections)
        } catch {
            assertionFailure("Failed to persist default sections.")
        }
    }

    func makeBackupDocument() throws -> CompanyBackupDocument {
        CompanyBackupDocument(data: try backupService.exportBackup(sections: sections))
    }

    func importBackup(from data: Data) throws {
        sections = try backupService.importBackup(from: data)
    }

    func formattedRosterReviewText(from text: String) -> String {
        rosterImportService.formattedReview(from: text)
    }

    @discardableResult
    func importRosterText(_ text: String, into sectionID: UUID, replaceExisting: Bool) throws -> Int {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else {
            return 0
        }

        let importedMembers = try rosterImportService.members(from: text)

        if replaceExisting {
            for member in sections[sectionIndex].members {
                photoStorage.deletePhoto(fileName: member.storedPhotoFileName)
            }
            sections[sectionIndex].members = importedMembers
        } else {
            sections[sectionIndex].members.append(contentsOf: importedMembers)
        }

        try persistence.saveSections(sections)
        return importedMembers.count
    }

    func section(withID sectionID: UUID) -> CompanySection? {
        sections.first { $0.id == sectionID }
    }

    func member(withID memberID: UUID, in sectionID: UUID) -> Member? {
        section(withID: sectionID)?.members.first { $0.id == memberID }
    }

    func addMember(
        to sectionID: UUID,
        name: String,
        rank: Rank,
        phoneNumber: String,
        role: String,
        memoryTip: String,
        bundledImageName: String?,
        importedPhotoData: Data?
    ) throws {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else {
            return
        }

        let storedPhotoFileName = try importedPhotoData.map { try photoStorage.savePhoto(data: $0) }
        let member = Member(
            name: name,
            rank: rank,
            phoneNumber: phoneNumber,
            role: role,
            memoryTip: memoryTip,
            bundledImageName: bundledImageName,
            storedPhotoFileName: storedPhotoFileName
        )

        sections[sectionIndex].members.append(member)
        try persistence.saveSections(sections)
    }

    func deleteMember(memberID: UUID, from sectionID: UUID) {
        deleteMembers(withIDs: [memberID], from: sectionID)
    }

    func updateMember(
        in sectionID: UUID,
        memberID: UUID,
        name: String,
        rank: Rank,
        phoneNumber: String,
        role: String,
        memoryTip: String,
        bundledImageName: String?,
        importedPhotoData: Data?,
        removePhoto: Bool
    ) throws {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }),
              let memberIndex = sections[sectionIndex].members.firstIndex(where: { $0.id == memberID }) else {
            return
        }

        let existingMember = sections[sectionIndex].members[memberIndex]
        var storedPhotoFileName = existingMember.storedPhotoFileName

        if let importedPhotoData {
            photoStorage.deletePhoto(fileName: existingMember.storedPhotoFileName)
            storedPhotoFileName = try photoStorage.savePhoto(data: importedPhotoData)
        } else if removePhoto {
            photoStorage.deletePhoto(fileName: existingMember.storedPhotoFileName)
            storedPhotoFileName = nil
        }

        sections[sectionIndex].members[memberIndex] = Member(
            id: existingMember.id,
            name: name,
            rank: rank,
            phoneNumber: phoneNumber,
            role: role,
            memoryTip: memoryTip,
            bundledImageName: bundledImageName,
            storedPhotoFileName: storedPhotoFileName
        )

        try persistence.saveSections(sections)
    }

    private func deleteMembers(withIDs memberIDs: [UUID], from sectionID: UUID) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else {
            return
        }

        let membersToDelete = sections[sectionIndex].members.filter { memberIDs.contains($0.id) }
        sections[sectionIndex].members.removeAll { memberIDs.contains($0.id) }

        for member in membersToDelete {
            photoStorage.deletePhoto(fileName: member.storedPhotoFileName)
        }

        do {
            try persistence.saveSections(sections)
        } catch {
            assertionFailure("Failed to save sections after deleting members.")
        }
    }

    private static func ensureDefaultSections(in sections: [CompanySection]) -> [CompanySection] {
        var updatedSections = sections

        if !updatedSections.contains(where: { $0.name.localizedCaseInsensitiveCompare("Renfort") == .orderedSame }) {
            updatedSections.append(CompanySection.renfortSection)
        }

        return updatedSections
    }
}
