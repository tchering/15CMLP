//
//  CompanyBackupService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

struct CompanyBackupService {
    private let backupVersion = 1
    private let photoStorage: MemberPhotoStorageService
    private let persistence: CompanyDirectoryPersistenceService

    init(
        photoStorage: MemberPhotoStorageService = .shared,
        persistence: CompanyDirectoryPersistenceService = CompanyDirectoryPersistenceService()
    ) {
        self.photoStorage = photoStorage
        self.persistence = persistence
    }

    func exportBackup(sections: [CompanySection]) throws -> Data {
        let photoFileNames = Set(sections.flatMap(\.members).compactMap(\.storedPhotoFileName))
        var photos: [String: Data] = [:]

        for fileName in photoFileNames {
            if let data = photoStorage.photoData(for: fileName) {
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
            photoStorage.replacePhotos(with: backup.photos)
            try persistence.saveSections(backup.sections)
            return backup.sections
        }

        let sections = try decoder.decode([CompanySection].self, from: data)
        try persistence.saveSections(sections)
        return sections
    }
}

private extension JSONEncoder {
    static var prettyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}
