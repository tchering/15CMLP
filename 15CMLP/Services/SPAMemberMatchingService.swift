//
//  SPAMemberMatchingService.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation

struct SPAMemberMatchingService {
    func match(_ entries: [SPAEntry], in section: CompanySection) -> [SPAEntry] {
        entries.map { entry in
            guard entry.matchStatus != .invalid else {
                return entry
            }

            let matches = section.members.filter { member in
                member.spaMatchingGrade == entry.normalizedGrade &&
                member.spaMatchingNom == entry.normalizedNom
            }

            switch matches.count {
            case 1:
                return entry.updating(
                    matchedMemberID: matches[0].id,
                    matchStatus: .matched
                )
            case 0:
                return entry.updating(
                    matchedMemberID: nil,
                    matchStatus: .unmatched
                )
            default:
                return entry.updating(
                    matchedMemberID: nil,
                    matchStatus: .ambiguous
                )
            }
        }
    }
}
