//
//  SPAEntry.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct SPAEntry: Identifiable, Codable, Equatable {
    let id: UUID
    let grade: String
    let nom: String
    let position: String
    let observation: String
    let debut: String
    let fin: String
    let matchedMemberID: UUID?
    let matchStatus: MatchStatus
    let rawSourceText: String
    let validationIssues: [String]

    init(
        id: UUID = UUID(),
        grade: String,
        nom: String,
        position: String = "",
        observation: String = "",
        debut: String = "",
        fin: String = "",
        matchedMemberID: UUID? = nil,
        matchStatus: MatchStatus = .unmatched,
        rawSourceText: String = "",
        validationIssues: [String] = []
    ) {
        self.id = id
        self.grade = grade
        self.nom = nom
        self.position = position
        self.observation = observation
        self.debut = debut
        self.fin = fin
        self.matchedMemberID = matchedMemberID
        self.matchStatus = matchStatus
        self.rawSourceText = rawSourceText
        self.validationIssues = validationIssues
    }

    var normalizedGrade: String {
        grade.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var normalizedNom: String {
        nom
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .uppercased()
    }

    var normalizedPosition: String {
        position.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var hasDateRange: Bool {
        !debut.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !fin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isValid: Bool {
        validationIssues.isEmpty && matchStatus != .invalid
    }

    func updating(
        matchedMemberID: UUID? = nil,
        matchStatus: MatchStatus? = nil,
        validationIssues: [String]? = nil
    ) -> SPAEntry {
        SPAEntry(
            id: id,
            grade: grade,
            nom: nom,
            position: position,
            observation: observation,
            debut: debut,
            fin: fin,
            matchedMemberID: matchedMemberID ?? self.matchedMemberID,
            matchStatus: matchStatus ?? self.matchStatus,
            rawSourceText: rawSourceText,
            validationIssues: validationIssues ?? self.validationIssues
        )
    }
}

extension SPAEntry {
    enum MatchStatus: String, Codable, Equatable {
        case unmatched
        case matched
        case ambiguous
        case invalid

        var title: String {
            switch self {
            case .unmatched:
                return "Unmatched"
            case .matched:
                return "Matched"
            case .ambiguous:
                return "Ambiguous"
            case .invalid:
                return "Invalid"
            }
        }
    }
}
