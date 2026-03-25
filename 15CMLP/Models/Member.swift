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
    let spaPosition: String
    let spaObservation: String
    let spaStartDate: Date?
    let spaEndDate: Date?
    let spaLastUpdatedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        rank: Rank,
        phoneNumber: String = "",
        role: String,
        memoryTip: String,
        bundledImageName: String? = nil,
        storedPhotoFileName: String? = nil,
        spaPosition: String = "",
        spaObservation: String = "",
        spaStartDate: Date? = nil,
        spaEndDate: Date? = nil,
        spaLastUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.rank = rank
        self.phoneNumber = phoneNumber
        self.role = role
        self.memoryTip = memoryTip
        self.bundledImageName = bundledImageName
        self.storedPhotoFileName = storedPhotoFileName
        self.spaPosition = spaPosition
        self.spaObservation = spaObservation
        self.spaStartDate = spaStartDate
        self.spaEndDate = spaEndDate
        self.spaLastUpdatedAt = spaLastUpdatedAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    var spaMatchingGrade: String {
        rank.spaCode
    }

    var spaMatchingNom: String {
        let separators = CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)
        let components = name
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }

        let surname = components.last ?? name

        return surname
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "fr_FR"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .uppercased()
    }

    var presenceStatus: PresenceStatus {
        presenceStatus(on: Date())
    }

    var formattedSPAStartDate: String {
        Self.formattedSPADate(spaStartDate)
    }

    var formattedSPAEndDate: String {
        Self.formattedSPADate(spaEndDate)
    }

    func hasActiveSPAAssignment(on date: Date, calendar: Calendar = .current) -> Bool {
        guard let spaStartDate, let spaEndDate else {
            return false
        }

        let startOfDay = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: spaStartDate)
        let end = calendar.startOfDay(for: spaEndDate)
        return startOfDay >= start && startOfDay <= end
    }

    func presenceStatus(on date: Date, calendar: Calendar = .current) -> PresenceStatus {
        hasActiveSPAAssignment(on: date, calendar: calendar) ? .absent : .present
    }

    private static let spaDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter
    }()

    private static func formattedSPADate(_ date: Date?) -> String {
        guard let date else {
            return ""
        }

        return spaDateFormatter.string(from: date)
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
        case spaPosition
        case spaObservation
        case spaStartDate
        case spaEndDate
        case spaLastUpdatedAt
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
        spaPosition = try container.decodeIfPresent(String.self, forKey: .spaPosition) ?? ""
        spaObservation = try container.decodeIfPresent(String.self, forKey: .spaObservation) ?? ""
        spaStartDate = try container.decodeIfPresent(Date.self, forKey: .spaStartDate)
        spaEndDate = try container.decodeIfPresent(Date.self, forKey: .spaEndDate)
        spaLastUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .spaLastUpdatedAt)
    }
}

extension Member {
    enum PresenceStatus: String, Codable {
        case present
        case absent

        var title: String {
            switch self {
            case .present:
                return "Present"
            case .absent:
                return "Absent"
            }
        }
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

    var spaCode: String {
        switch self {
        case .chefDeSection:
            return "LTN"
        case .soa:
            return "SCH"
        case .sergent:
            return "SGT"
        case .cc1:
            return "CC1"
        case .caporalChef:
            return "CCH"
        case .caporal:
            return "CPL"
        case .soldier:
            return "1CL"
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
