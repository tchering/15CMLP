//
//  Member.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Foundation

struct Member: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let rank: Rank
    let role: String
    let memoryTip: String
    let bundledImageName: String?
    let storedPhotoFileName: String?

    init(
        id: UUID = UUID(),
        name: String,
        rank: Rank,
        role: String,
        memoryTip: String,
        bundledImageName: String? = nil,
        storedPhotoFileName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.rank = rank
        self.role = role
        self.memoryTip = memoryTip
        self.bundledImageName = bundledImageName
        self.storedPhotoFileName = storedPhotoFileName
    }

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

enum Rank: Int, CaseIterable, Codable, Identifiable {
    case chefDeSection
    case soa
    case sergent
    case caporalChef
    case cc1
    case caporal
    case soldier

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .chefDeSection:
            return "Chef de section"
        case .soa:
            return "SOA"
        case .sergent:
            return "Sergent"
        case .caporalChef:
            return "Caporal-chef"
        case .cc1:
            return "CC1"
        case .caporal:
            return "Caporal"
        case .soldier:
            return "Soldier"
        }
    }

    var shortTitle: String {
        switch self {
        case .chefDeSection:
            return "CDS"
        case .soa:
            return "SOA"
        case .sergent:
            return "SGT"
        case .caporalChef:
            return "CCH"
        case .cc1:
            return "CC1"
        case .caporal:
            return "CPL"
        case .soldier:
            return "SOL"
        }
    }
}
