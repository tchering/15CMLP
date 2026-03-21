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
    let phoneNumber: String
    let role: String
    let memoryTip: String
    let bundledImageName: String?
    let storedPhotoFileName: String?

    init(
        id: UUID = UUID(),
        name: String,
        rank: Rank,
        phoneNumber: String = "",
        role: String,
        memoryTip: String,
        bundledImageName: String? = nil,
        storedPhotoFileName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.rank = rank
        self.phoneNumber = phoneNumber
        self.role = role
        self.memoryTip = memoryTip
        self.bundledImageName = bundledImageName
        self.storedPhotoFileName = storedPhotoFileName
    }

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case rank
        case phoneNumber
        case role
        case memoryTip
        case bundledImageName
        case storedPhotoFileName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rank = try container.decode(Rank.self, forKey: .rank)
        phoneNumber = try container.decodeIfPresent(String.self, forKey: .phoneNumber) ?? ""
        role = try container.decode(String.self, forKey: .role)
        memoryTip = try container.decode(String.self, forKey: .memoryTip)
        bundledImageName = try container.decodeIfPresent(String.self, forKey: .bundledImageName)
        storedPhotoFileName = try container.decodeIfPresent(String.self, forKey: .storedPhotoFileName)
    }
}

enum Rank: Int, CaseIterable, Codable, Identifiable {
    case chefDeSection
    case soa
    case sergent
    case cc1
    case caporalChef
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
        case .cc1:
            return "CC1"
        case .caporalChef:
            return "Caporal-chef"
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
        case .cc1:
            return "CC1"
        case .caporalChef:
            return "CCH"
        case .caporal:
            return "CPL"
        case .soldier:
            return "SOL"
        }
    }

    private enum CodingError: Error {
        case unsupportedValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            switch value {
            case "chefDeSection":
                self = .chefDeSection
            case "soa":
                self = .soa
            case "sergent":
                self = .sergent
            case "cc1":
                self = .cc1
            case "caporalChef":
                self = .caporalChef
            case "caporal":
                self = .caporal
            case "soldier":
                self = .soldier
            default:
                throw CodingError.unsupportedValue
            }
            return
        }

        let legacyValue = try container.decode(Int.self)
        switch legacyValue {
        case 0:
            self = .chefDeSection
        case 1:
            self = .soa
        case 2:
            self = .sergent
        case 3:
            self = .caporalChef
        case 4:
            self = .cc1
        case 5:
            self = .caporal
        case 6:
            self = .soldier
        default:
            throw CodingError.unsupportedValue
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let stableValue: String

        switch self {
        case .chefDeSection:
            stableValue = "chefDeSection"
        case .soa:
            stableValue = "soa"
        case .sergent:
            stableValue = "sergent"
        case .cc1:
            stableValue = "cc1"
        case .caporalChef:
            stableValue = "caporalChef"
        case .caporal:
            stableValue = "caporal"
        case .soldier:
            stableValue = "soldier"
        }

        try container.encode(stableValue)
    }
}
