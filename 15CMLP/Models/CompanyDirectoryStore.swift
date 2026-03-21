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

    func formattedRosterReviewText(from text: String) -> String {
        RosterTextImporter.formattedReview(from: text)
    }

    @discardableResult
    func importRosterText(
        _ text: String,
        into sectionID: UUID,
        replaceExisting: Bool
    ) throws -> Int {
        guard let sectionIndex = sections.firstIndex(where: { $0.id == sectionID }) else {
            return 0
        }

        let importedMembers = try RosterTextImporter.members(from: text)

        if replaceExisting {
            for member in sections[sectionIndex].members {
                persistence.deletePhoto(for: member)
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

private enum RosterTextImporter {
    static func members(from text: String) throws -> [Member] {
        if let tableMembers = try membersFromTableLayout(text: text) {
            return tableMembers
        }

        let lines = cleanedLines(from: text)

        if let nomIndex = lines.firstIndex(where: { $0.uppercased() == "NOM" }) {
            return try membersFromColumnLayout(lines: lines, nomIndex: nomIndex)
        }

        return try membersFromAlternatingLayout(lines: lines)
    }

    static func formattedReview(from text: String) -> String {
        let lines = cleanedLines(from: text)

        guard let nomIndex = lines.firstIndex(where: { $0.uppercased() == "NOM" }) else {
            return lines.joined(separator: "\n")
        }

        let rawGrades = lines[..<nomIndex].filter { !isIgnored($0) }
        let rawNames = lines[(nomIndex + 1)...].filter { !isIgnored($0) }
        let rowCount = max(rawGrades.count, rawNames.count)

        var output = ["Grade\tNom"]
        for index in 0..<rowCount {
            let grade = index < rawGrades.count ? rawGrades[index] : "?"
            let name = index < rawNames.count ? rawNames[index] : "?"
            output.append("\(grade)\t\(name)")
        }

        return output.joined(separator: "\n")
    }

    private static func membersFromAlternatingLayout(lines: [String]) throws -> [Member] {
        let filteredLines = lines.filter { !isIgnored($0) }

        guard filteredLines.count.isMultiple(of: 2) else {
            throw ImportError.invalidFormat
        }

        var members: [Member] = []
        var index = 0

        while index < filteredLines.count {
            let rawGrade = filteredLines[index]
            let name = filteredLines[index + 1]
            let normalizedGrade = rawGrade.uppercased().replacingOccurrences(of: " ", with: "")
            let rank = try mapRank(from: normalizedGrade)

            members.append(
                Member(
                    name: name,
                    rank: rank,
                    phoneNumber: "",
                    role: rawGrade,
                    memoryTip: ""
                )
            )

            index += 2
        }

        return members
    }

    private static func membersFromTableLayout(text: String) throws -> [Member]? {
        let rows = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstRow = rows.first, firstRow.contains("\t") else {
            return nil
        }

        var members: [Member] = []

        for row in rows.dropFirst() {
            let columns = row
                .components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard columns.count >= 2 else {
                continue
            }

            let rawGrade = columns[0]
            let name = columns[1]

            guard !rawGrade.isEmpty, !name.isEmpty else {
                continue
            }

            let normalizedGrade = rawGrade.uppercased().replacingOccurrences(of: " ", with: "")
            let rank = try mapRank(from: normalizedGrade)

            members.append(
                Member(
                    name: name,
                    rank: rank,
                    phoneNumber: "",
                    role: rawGrade,
                    memoryTip: ""
                )
            )
        }

        return members.isEmpty ? nil : members
    }

    private static func membersFromColumnLayout(lines: [String], nomIndex: Int) throws -> [Member] {
        let rawGrades = lines[..<nomIndex]
            .filter { !isIgnored($0) }

        let rawNames = lines[(nomIndex + 1)...]
            .filter { !isIgnored($0) }

        guard rawGrades.count == rawNames.count else {
            throw ImportError.invalidColumnFormat(grades: rawGrades.count, names: rawNames.count)
        }

        return try zip(rawGrades, rawNames).map { rawGrade, name in
            let normalizedGrade = rawGrade.uppercased().replacingOccurrences(of: " ", with: "")
            let rank = try mapRank(from: normalizedGrade)

            return Member(
                name: name,
                rank: rank,
                phoneNumber: "",
                role: rawGrade,
                memoryTip: ""
            )
        }
    }

    private static func mapRank(from rawGrade: String) throws -> Rank {
        switch rawGrade {
        case "LTN":
            return .chefDeSection
        case "SCH_B", "SCHB":
            return .soa
        case "SCH", "SGT":
            return .sergent
        case "CC1":
            return .cc1
        case "CCH":
            return .caporalChef
        case "CPL":
            return .caporal
        case "1CL", "SDT":
            return .soldier
        default:
            throw ImportError.unsupportedGrade(rawGrade)
        }
    }

    private static func cleanedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func isIgnored(_ token: String) -> Bool {
        let uppercased = token.uppercased()
        return uppercased == "GRADE" || uppercased == "NOM"
    }

    enum ImportError: LocalizedError {
        case invalidFormat
        case invalidColumnFormat(grades: Int, names: Int)
        case unsupportedGrade(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "The scanned roster format is invalid. It should alternate between grade and name."
            case .invalidColumnFormat(let grades, let names):
                return "The scanned roster columns do not match. Grades: \(grades), names: \(names)."
            case .unsupportedGrade(let grade):
                return "Unsupported grade in scanned text: \(grade)"
            }
        }
    }
}
