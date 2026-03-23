//
//  CompanySection.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Foundation

struct CompanySection: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let summary: String
    var members: [Member]

    var membersByRank: [RankGroup] {
        Rank.allCases.compactMap { rank -> RankGroup? in
            let filteredMembers = members.filter { $0.rank == rank }
            guard !filteredMembers.isEmpty else { return nil }
            return RankGroup(id: rank, rank: rank, members: filteredMembers)
        }
    }

    var rankPreview: [String] {
        membersByRank.map { "\($0.rank.shortTitle): \($0.members.count)" }
    }

    static let renfortSection = CompanySection(
        id: UUID(),
        name: "Renfort",
        summary: "Use this section for attached personnel and reinforcements.",
        members: [
            Member(name: "Adjudant Colin", rank: .chefDeSection, role: "Renfort lead", memoryTip: "Replace this sample with the real reinforcement lead."),
            Member(name: "Sergent Morel", rank: .sergent, role: "Support NCO", memoryTip: "Use Renfort for temporary or attached personnel."),
            Member(name: "Caporal Diaz", rank: .caporal, role: "Support specialist", memoryTip: "Add whoever is currently attached to the company.")
        ]
    )

    static let sampleSections: [CompanySection] = [
        CompanySection(
            id: UUID(),
            name: "1st Section",
            summary: "Use this section for your first squad roster.",
            members: [
                Member(name: "Adjudant Martin", rank: .chefDeSection, role: "Chef de section", memoryTip: "Section lead. Replace with the real chief's photo."),
                Member(name: "Sergent-chef Bernard", rank: .soa, role: "SOA", memoryTip: "Second-in-command and support reference."),
                Member(name: "Sergent Dubois", rank: .sergent, role: "Group leader", memoryTip: "Add a short note about voice, habits, or team."),
                Member(name: "Caporal-chef Leroy", rank: .caporalChef, role: "Senior specialist", memoryTip: "Use this note for key visual traits."),
                Member(name: "CC1 Petit", rank: .cc1, role: "CC1", memoryTip: "You can replace CC1 wording if your unit uses another label."),
                Member(name: "Caporal Moreau", rank: .caporal, role: "Caporal", memoryTip: "Store what makes this person easy to spot."),
                Member(name: "Soldat Simon", rank: .soldier, role: "Soldier", memoryTip: "Good place for first impression notes.")
            ]
        ),
        CompanySection(
            id: UUID(),
            name: "2nd Section",
            summary: "Tap in to review every member ordered by rank.",
            members: [
                Member(name: "Adjudant Laurent", rank: .chefDeSection, role: "Chef de section", memoryTip: "Replace sample data with your real section lead."),
                Member(name: "Sergent-chef Michel", rank: .soa, role: "SOA", memoryTip: "Use photos in Assets for faster recognition."),
                Member(name: "Sergent Garnier", rank: .sergent, role: "Group leader", memoryTip: "Add a short memory cue here."),
                Member(name: "Sergent Roche", rank: .sergent, role: "Team lead", memoryTip: "Extra sample member for stack testing in Simulator."),
                Member(name: "Sergent Vidal", rank: .sergent, role: "Driver lead", memoryTip: "Use this group to verify smooth expansion."),
                Member(name: "Sergent Maret", rank: .sergent, role: "Support lead", memoryTip: "You can remove these sample members after testing."),
                Member(name: "Caporal-chef Robin", rank: .caporalChef, role: "Senior specialist", memoryTip: "Hair, glasses, accent, or another visible cue."),
                Member(name: "Caporal-chef Denis", rank: .caporalChef, role: "Maintenance specialist", memoryTip: "Additional row for animation testing."),
                Member(name: "CC1 Henry", rank: .cc1, role: "CC1", memoryTip: "Change this member to the real person."),
                Member(name: "Caporal Noel", rank: .caporal, role: "Caporal", memoryTip: "Record a memorable detail."),
                Member(name: "Soldat Caron", rank: .soldier, role: "Soldier", memoryTip: "This note can help with revision."),
                Member(name: "Soldat Brun", rank: .soldier, role: "Soldier", memoryTip: "Extra roster depth for testing the expanded state.")
            ]
        ),
        CompanySection(
            id: UUID(),
            name: "3rd Section",
            summary: "Build this section with names, grades, and face photos.",
            members: [
                Member(name: "Adjudant Thomas", rank: .chefDeSection, role: "Chef de section", memoryTip: "Start by replacing the chiefs and sergeants first."),
                Member(name: "Sergent-chef Garcia", rank: .soa, role: "SOA", memoryTip: "This card is good for a quick reminder before duty."),
                Member(name: "Sergent Roy", rank: .sergent, role: "Group leader", memoryTip: "Add team or responsibility notes."),
                Member(name: "Caporal-chef Faure", rank: .caporalChef, role: "Senior specialist", memoryTip: "Replace sample photo name when you add an asset."),
                Member(name: "CC1 Marchand", rank: .cc1, role: "CC1", memoryTip: "Short recognition cues work best here."),
                Member(name: "Caporal Chevalier", rank: .caporal, role: "Caporal", memoryTip: "Uniform or posture can be useful cues."),
                Member(name: "Soldat Perrin", rank: .soldier, role: "Soldier", memoryTip: "You can keep this as a personal study aid.")
            ]
        ),
        renfortSection
    ]
}

struct RankGroup: Identifiable, Equatable {
    let id: Rank
    let rank: Rank
    let members: [Member]
}
