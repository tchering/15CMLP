//
//  SPAEntryValidationService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct SPAEntryValidationService {
    private static let supportedGrades: Set<String> = [
        "LTN", "SCH", "SGT", "CC1", "CCH", "CPL", "1CL", "SDT"
    ]

    private static let knownPositions: Set<String> = [
        "STGEXT", "DIV", "SAUT", "ENC", "FS", "MCD", "DRT", "REC", "PER"
    ]

    private let calendar: Calendar
    private let dateFormatter: DateFormatter

    init(calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy"
        self.dateFormatter = formatter
    }

    func validate(_ entries: [SPAEntry]) -> [SPAEntry] {
        let duplicateKeys = duplicateEntryKeys(in: entries)

        return entries.map { entry in
            var issues: [String] = []

            if !Self.supportedGrades.contains(entry.normalizedGrade) {
                issues.append("Unsupported GRADE.")
            }

            if entry.normalizedNom.isEmpty {
                issues.append("Missing NOM.")
            }

            if !entry.normalizedPosition.isEmpty && !Self.knownPositions.contains(entry.normalizedPosition) {
                issues.append("Unknown Position code.")
            }

            if !entry.debut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parseDate(entry.debut) == nil {
                issues.append("Invalid Début date.")
            }

            if !entry.fin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && parseDate(entry.fin) == nil {
                issues.append("Invalid Fin date.")
            }

            if let startDate = parseDate(entry.debut),
               let endDate = parseDate(entry.fin),
               calendar.startOfDay(for: startDate) > calendar.startOfDay(for: endDate) {
                issues.append("Début is after Fin.")
            }

            if duplicateKeys.contains(duplicateKey(for: entry)) {
                issues.append("Possible duplicate SPA row.")
            }

            return entry.updating(
                matchStatus: issues.isEmpty ? entry.matchStatus : .invalid,
                validationIssues: issues
            )
        }
    }

    private func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        return dateFormatter.date(from: trimmed)
    }

    private func duplicateEntryKeys(in entries: [SPAEntry]) -> Set<String> {
        var counts: [String: Int] = [:]

        for entry in entries {
            counts[duplicateKey(for: entry), default: 0] += 1
        }

        return Set(counts.compactMap { key, count in
            count > 1 ? key : nil
        })
    }

    private func duplicateKey(for entry: SPAEntry) -> String {
        [
            entry.normalizedGrade,
            entry.normalizedNom,
            entry.normalizedPosition,
            normalizedValue(entry.debut),
            normalizedValue(entry.fin)
        ].joined(separator: "|")
    }

    private func normalizedValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
