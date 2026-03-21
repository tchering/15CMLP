//
//  CompanyDirectoryStore.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Foundation
import Observation
import UIKit

@Observable
final class CompanyDirectoryStore {
    var sections: [CompanySection]

    private let persistence = CompanyDirectoryPersistence()

    init() {
        sections = persistence.loadSections()
    }

    func section(withID sectionID: UUID) -> CompanySection? {
        sections.first { $0.id == sectionID }
    }

    func addMember(
        to sectionID: UUID,
        name: String,
        rank: Rank,
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

private struct CompanyDirectoryPersistence {
    private let sectionsFileName = "company-sections.json"

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
