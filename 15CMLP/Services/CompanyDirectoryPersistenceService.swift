//
//  CompanyDirectoryPersistenceService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct CompanyDirectoryPersistenceService {
    private let sectionsFileName = "company-sections.json"

    func loadSections() -> [CompanySection] {
        guard let data = try? Data(contentsOf: sectionsFileURL()) else {
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
