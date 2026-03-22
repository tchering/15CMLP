//
//  RosterImportService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct RosterImportService {
    func members(from text: String) throws -> [Member] {
        if let tableMembers = try membersFromTableLayout(text: text) {
            return tableMembers
        }

        let lines = cleanedLines(from: text)

        if let nomIndex = lines.firstIndex(where: { $0.uppercased() == "NOM" }) {
            return try membersFromColumnLayout(lines: lines, nomIndex: nomIndex)
        }

        return try membersFromAlternatingLayout(lines: lines)
    }

    func formattedReview(from text: String) -> String {
        let lines = cleanedLines(from: text)

        guard let nomIndex = lines.firstIndex(where: { $0.uppercased() == "NOM" }) else {
            return lines.joined(separator: "\n")
        }

        let rawGrades = Array(lines[..<nomIndex].filter { !isIgnored($0) })
        let rawNames = Array(lines[(nomIndex + 1)...].filter { !isIgnored($0) })
        let rowCount = max(rawGrades.count, rawNames.count)

        var output = ["Grade\tNom"]
        for index in 0..<rowCount {
            let grade = index < rawGrades.count ? rawGrades[index] : "?"
            let name = index < rawNames.count ? rawNames[index] : "?"
            output.append("\(grade)\t\(name)")
        }

        return output.joined(separator: "\n")
    }

    private func membersFromAlternatingLayout(lines: [String]) throws -> [Member] {
        let filteredLines = lines.filter { !isIgnored($0) }

        guard filteredLines.count.isMultiple(of: 2) else {
            throw ImportError.invalidFormat
        }

        var members: [Member] = []
        var index = 0

        while index < filteredLines.count {
            let rawGrade = filteredLines[index]
            let name = filteredLines[index + 1]
            let rank = try mapRank(from: normalizeGrade(rawGrade))

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

    private func membersFromTableLayout(text: String) throws -> [Member]? {
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

            let rank = try mapRank(from: normalizeGrade(rawGrade))
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

    private func membersFromColumnLayout(lines: [String], nomIndex: Int) throws -> [Member] {
        let rawGrades = Array(lines[..<nomIndex].filter { !isIgnored($0) })
        let rawNames = Array(lines[(nomIndex + 1)...].filter { !isIgnored($0) })

        guard rawGrades.count == rawNames.count else {
            throw ImportError.invalidColumnFormat(grades: rawGrades.count, names: rawNames.count)
        }

        return try zip(rawGrades, rawNames).map { rawGrade, name in
            let rank = try mapRank(from: normalizeGrade(rawGrade))
            return Member(
                name: name,
                rank: rank,
                phoneNumber: "",
                role: rawGrade,
                memoryTip: ""
            )
        }
    }

    private func cleanedLines(from text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizeGrade(_ rawGrade: String) -> String {
        rawGrade.uppercased().replacingOccurrences(of: " ", with: "")
    }

    private func isIgnored(_ token: String) -> Bool {
        let uppercased = token.uppercased()
        return uppercased == "GRADE" || uppercased == "NOM"
    }

    private func mapRank(from rawGrade: String) throws -> Rank {
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
