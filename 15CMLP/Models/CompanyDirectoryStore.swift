//
//  CompanyDirectoryStore.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

@Observable
final class CompanyDirectoryStore {
    var sections: [CompanySection]

    private let persistence = CompanyDirectoryPersistence()

    init() {
        sections = persistence.loadSections()
    }

    func makeBackupDocument() throws -> CompanyBackupDocument {
        CompanyBackupDocument(data: try persistence.exportBackup(sections: sections))
    }

    func importBackup(from data: Data) throws {
        sections = try persistence.importBackup(from: data)
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

        let storedPhotoFileName: String?
        if let importedPhotoData {
            storedPhotoFileName = try persistence.savePhoto(data: importedPhotoData)
        } else {
            storedPhotoFileName = nil
        }

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

    func deleteMembers(offsets: IndexSet, from sectionID: UUID, rankGroup: RankGroup) {
        let memberIDs = offsets.map { rankGroup.members[$0].id }
        deleteMembers(withIDs: memberIDs, from: sectionID)
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
            if existingMember.storedPhotoFileName != nil {
                persistence.deletePhoto(for: existingMember)
            }
            storedPhotoFileName = try persistence.savePhoto(data: importedPhotoData)
        } else if removePhoto {
            if existingMember.storedPhotoFileName != nil {
                persistence.deletePhoto(for: existingMember)
            }
            storedPhotoFileName = nil
        }

        let updatedMember = Member(
            id: existingMember.id,
            name: name,
            rank: rank,
            phoneNumber: phoneNumber,
            role: role,
            memoryTip: memoryTip,
            bundledImageName: bundledImageName,
            storedPhotoFileName: storedPhotoFileName
        )

        sections[sectionIndex].members[memberIndex] = updatedMember
        try persistence.saveSections(sections)
    }

    private func deleteMembers(withIDs memberIDs: [UUID], from sectionID: UUID) {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else {
            return
        }

        let membersToDelete = sections[sectionIndex].members.filter { memberIDs.contains($0.id) }
        sections[sectionIndex].members.removeAll { memberIDs.contains($0.id) }

        for member in membersToDelete {
            persistence.deletePhoto(for: member)
        }

        do {
            try persistence.saveSections(sections)
        } catch {
            assertionFailure("Failed to save sections after deleting members.")
        }
    }
}

struct MemberPhotoStorage {
    static func loadImage(for member: Member) -> UIImage? {
        if let storedPhotoFileName = member.storedPhotoFileName,
           let uiImage = UIImage(contentsOfFile: fileURL(for: storedPhotoFileName).path) {
            return uiImage
        }

        if let bundledImageName = member.bundledImageName,
           let uiImage = UIImage(named: bundledImageName) {
            return uiImage
        }

        return nil
    }

    fileprivate static func photosDirectoryURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosURL = documentsURL.appendingPathComponent("MemberPhotos", isDirectory: true)

        if !FileManager.default.fileExists(atPath: photosURL.path) {
            try? FileManager.default.createDirectory(at: photosURL, withIntermediateDirectories: true)
        }

        return photosURL
    }

    fileprivate static func fileURL(for fileName: String) -> URL {
        photosDirectoryURL().appendingPathComponent(fileName)
    }
}

struct CompanyDirectoryBackup: Codable {
    let version: Int
    let exportedAt: Date
    let sections: [CompanySection]
    let photos: [String: Data]
}

struct CompanyBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

private struct CompanyDirectoryPersistence {
    private let sectionsFileName = "company-sections.json"
    private let backupVersion = 1

    func loadSections() -> [CompanySection] {
        let url = sectionsFileURL()

        guard let data = try? Data(contentsOf: url) else {
            return CompanySection.sampleSections
        }

        do {
            return try JSONDecoder().decode([CompanySection].self, from: data)
        } catch {
            return CompanySection.sampleSections
        }
    }

    func saveSections(_ sections: [CompanySection]) throws {
        let data = try JSONEncoder.prettyEncoder.encode(sections)
        try data.write(to: sectionsFileURL(), options: [.atomic])
    }

    func exportBackup(sections: [CompanySection]) throws -> Data {
        let photoFileNames = Set(
            sections
                .flatMap(\.members)
                .compactMap(\.storedPhotoFileName)
        )

        var photos: [String: Data] = [:]
        for fileName in photoFileNames {
            let fileURL = MemberPhotoStorage.fileURL(for: fileName)
            if let data = try? Data(contentsOf: fileURL) {
                photos[fileName] = data
            }
        }

        let backup = CompanyDirectoryBackup(
            version: backupVersion,
            exportedAt: Date(),
            sections: sections,
            photos: photos
        )

        return try JSONEncoder.prettyEncoder.encode(backup)
    }

    func importBackup(from data: Data) throws -> [CompanySection] {
        let decoder = JSONDecoder()

        if let backup = try? decoder.decode(CompanyDirectoryBackup.self, from: data) {
            replacePhotos(with: backup.photos)
            try saveSections(backup.sections)
            return backup.sections
        }

        let sections = try decoder.decode([CompanySection].self, from: data)
        try saveSections(sections)
        return sections
    }

    func savePhoto(data: Data) throws -> String {
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = MemberPhotoStorage.fileURL(for: fileName)
        let storedData = normalizedPhotoData(from: data)
        try storedData.write(to: fileURL, options: [.atomic])
        return fileName
    }

    func deletePhoto(for member: Member) {
        guard let storedPhotoFileName = member.storedPhotoFileName else {
            return
        }

        try? FileManager.default.removeItem(at: MemberPhotoStorage.fileURL(for: storedPhotoFileName))
    }

    private func replacePhotos(with photos: [String: Data]) {
        let photosURL = MemberPhotoStorage.photosDirectoryURL()

        if let existingFiles = try? FileManager.default.contentsOfDirectory(
            at: photosURL,
            includingPropertiesForKeys: nil
        ) {
            for fileURL in existingFiles {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }

        for (fileName, data) in photos {
            try? data.write(to: MemberPhotoStorage.fileURL(for: fileName), options: [.atomic])
        }
    }

    private func normalizedPhotoData(from data: Data) -> Data {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            return data
        }

        return jpegData
    }

    private func sectionsFileURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(sectionsFileName)
    }
}

private extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
