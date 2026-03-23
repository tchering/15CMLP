//
//  RosterImportService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct RosterImportService {
    struct Candidate: Identifiable, Equatable {
        let id: UUID
        let member: Member
        let sourceGrade: String

        init(member: Member, sourceGrade: String) {
            self.id = member.id
            self.member = member
            self.sourceGrade = sourceGrade
        }
    }

    func candidates(from text: String) throws -> [Candidate] {
        if let tableCandidates = try candidatesFromTableLayout(text: text) {
            return tableCandidates
        }

        let lines = cleanedLines(from: text)

        if let nomIndex = indexOfNameHeader(in: lines) {
            return try candidatesFromColumnLayout(lines: lines, nomIndex: nomIndex)
        }

        return try candidatesFromAlternatingLayout(lines: lines)
    }

    func members(from text: String) throws -> [Member] {
        try candidates(from: text).map(\.member)
    }

    func formattedReview(from text: String) -> String {
        let lines = cleanedLines(from: text)

        guard let nomIndex = indexOfNameHeader(in: lines) else {
            return lines.joined(separator: "\n")
        }

        let rawGrades = Array(lines[..<nomIndex].filter { !isIgnored($0) })
        let remainingLines = Array(lines[(nomIndex + 1)...])
        let phoneHeaderIndex = indexOfPhoneHeader(in: remainingLines)
        let rawNames: [String]
        let rawPhones: [String]

        if let phoneHeaderIndex {
            rawNames = Array(remainingLines[..<phoneHeaderIndex]).filter { !isIgnored($0) }
            rawPhones = Array(remainingLines[(phoneHeaderIndex + 1)...]).filter { !isIgnored($0) }
        } else {
            rawNames = remainingLines.filter { !isIgnored($0) }
            rawPhones = []
        }

        let rowCount = max(rawGrades.count, rawNames.count, rawPhones.count)
        let hasPhones = !rawPhones.isEmpty

        var output = [hasPhones ? "Grade\tNom\tPhone" : "Grade\tNom"]
        for index in 0..<rowCount {
            let grade = index < rawGrades.count ? rawGrades[index] : "?"
            let name = index < rawNames.count ? rawNames[index] : "?"
            if hasPhones {
                let phone = index < rawPhones.count ? rawPhones[index] : ""
                output.append("\(grade)\t\(name)\t\(phone)")
            } else {
                output.append("\(grade)\t\(name)")
            }
        }

        return output.joined(separator: "\n")
    }

    private func candidatesFromAlternatingLayout(lines: [String]) throws -> [Candidate] {
        let filteredLines = lines.filter { !isIgnored($0) }

        guard filteredLines.count.isMultiple(of: 2) else {
            throw ImportError.invalidFormat
        }

        var candidates: [Candidate] = []
        var index = 0

        while index < filteredLines.count {
            let rawGrade = filteredLines[index]
            let name = filteredLines[index + 1]
            let rank = try mapRank(from: normalizeGrade(rawGrade))

            candidates.append(
                Candidate(
                    member: Member(
                        name: name,
                        rank: rank,
                        phoneNumber: "",
                        role: rawGrade,
                        memoryTip: ""
                    ),
                    sourceGrade: rawGrade
                )
            )

            index += 2
        }

        return candidates
    }

    private func candidatesFromTableLayout(text: String) throws -> [Candidate]? {
        let rows = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard let firstRow = rows.first, firstRow.contains("\t") else {
            return nil
        }

        let headerColumns = rows[0]
            .components(separatedBy: "\t")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }

        guard let gradeIndex = headerColumns.firstIndex(where: isGradeHeader),
              let nameIndex = headerColumns.firstIndex(where: isNameHeader) else {
            return nil
        }

        let phoneIndex = headerColumns.firstIndex(where: isPhoneHeader)
        var candidates: [Candidate] = []

        for row in rows.dropFirst() {
            let columns = row
                .components(separatedBy: "\t")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

            guard columns.indices.contains(gradeIndex), columns.indices.contains(nameIndex) else {
                continue
            }

            let rawGrade = columns[gradeIndex]
            let name = columns[nameIndex]
            let phoneNumber = phoneIndex.flatMap { columns.indices.contains($0) ? columns[$0] : nil } ?? ""

            guard !rawGrade.isEmpty, !name.isEmpty else {
                continue
            }

            let rank = try mapRank(from: normalizeGrade(rawGrade))
            candidates.append(
                Candidate(
                    member: Member(
                        name: name,
                        rank: rank,
                        phoneNumber: normalizedPhoneNumber(phoneNumber),
                        role: rawGrade,
                        memoryTip: ""
                    ),
                    sourceGrade: rawGrade
                )
            )
        }

        return candidates.isEmpty ? nil : candidates
    }

    private func candidatesFromColumnLayout(lines: [String], nomIndex: Int) throws -> [Candidate] {
        let rawGrades = Array(lines[..<nomIndex].filter { !isIgnored($0) })
        let remainingLines = Array(lines[(nomIndex + 1)...])
        let phoneHeaderIndex = indexOfPhoneHeader(in: remainingLines)
        let rawNames: [String]
        let rawPhones: [String]

        if let phoneHeaderIndex {
            rawNames = Array(remainingLines[..<phoneHeaderIndex]).filter { !isIgnored($0) }
            rawPhones = Array(remainingLines[(phoneHeaderIndex + 1)...]).filter { !isIgnored($0) }
        } else {
            rawNames = remainingLines.filter { !isIgnored($0) }
            rawPhones = []
        }

        guard rawGrades.count == rawNames.count else {
            throw ImportError.invalidColumnFormat(grades: rawGrades.count, names: rawNames.count)
        }

        if !rawPhones.isEmpty && rawPhones.count != rawNames.count {
            throw ImportError.invalidPhoneColumnFormat(names: rawNames.count, phones: rawPhones.count)
        }

        return try rawGrades.enumerated().map { index, rawGrade in
            let name = rawNames[index]
            let phoneNumber = rawPhones.isEmpty ? "" : rawPhones[index]
            let rank = try mapRank(from: normalizeGrade(rawGrade))

            return Candidate(
                member: Member(
                    name: name,
                    rank: rank,
                    phoneNumber: normalizedPhoneNumber(phoneNumber),
                    role: rawGrade,
                    memoryTip: ""
                ),
                sourceGrade: rawGrade
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

    private func normalizedPhoneNumber(_ phoneNumber: String) -> String {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func indexOfNameHeader(in lines: [String]) -> Int? {
        lines.firstIndex(where: { isNameHeader($0.uppercased()) })
    }

    private func indexOfPhoneHeader(in lines: [String]) -> Int? {
        lines.firstIndex(where: { isPhoneHeader($0.uppercased()) })
    }

    private func isIgnored(_ token: String) -> Bool {
        let uppercased = token.uppercased()
        return isGradeHeader(uppercased) || isNameHeader(uppercased) || isPhoneHeader(uppercased)
    }

    private func isGradeHeader(_ token: String) -> Bool {
        token == "GRADE" || token == "GRADES"
    }

    private func isNameHeader(_ token: String) -> Bool {
        token == "NOM" || token == "NAME" || token == "NOMS"
    }

    private func isPhoneHeader(_ token: String) -> Bool {
        token == "PHONE" || token == "TEL" || token == "TELEPHONE" || token == "PORTABLE" || token == "NUMERO" || token == "NUMERO DE TELEPHONE"
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
        case invalidPhoneColumnFormat(names: Int, phones: Int)
        case unsupportedGrade(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat:
                return "The scanned roster format is invalid. It should alternate between grade and name."
            case .invalidColumnFormat(let grades, let names):
                return "The scanned roster columns do not match. Grades: \(grades), names: \(names)."
            case .invalidPhoneColumnFormat(let names, let phones):
                return "The scanned phone column does not match the extracted names. Names: \(names), phones: \(phones)."
            case .unsupportedGrade(let grade):
                return "Unsupported grade in scanned text: \(grade)"
            }
        }
    }
}
