//
//  SectionDetailViewModel.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Observation
import SwiftUI
import UIKit

@Observable
final class SectionDetailViewModel {
    let store: CompanyDirectoryStore
    let sectionID: UUID

    var isShowingAddMember = false
    var isShowingScanImport = false
    var expandedRanks: Set<Rank> = [.chefDeSection]
    var scanErrorMessage = ""

    private let ocrService: OCRTextRecognitionService
    private let spaExtractionService: SPALLMExtractionService
    private let spaValidationService: SPAEntryValidationService
    private let spaMatchingService: SPAMemberMatchingService

    init(
        store: CompanyDirectoryStore,
        sectionID: UUID,
        ocrService: OCRTextRecognitionService = OCRTextRecognitionService(),
        spaExtractionService: SPALLMExtractionService = SPALLMExtractionService(),
        spaValidationService: SPAEntryValidationService = SPAEntryValidationService(),
        spaMatchingService: SPAMemberMatchingService = SPAMemberMatchingService()
    ) {
        self.store = store
        self.sectionID = sectionID
        self.ocrService = ocrService
        self.spaExtractionService = spaExtractionService
        self.spaValidationService = spaValidationService
        self.spaMatchingService = spaMatchingService
    }

    var section: CompanySection? {
        store.section(withID: sectionID)
    }

    func isExpanded(_ rank: Rank) -> Bool {
        expandedRanks.contains(rank)
    }

    func toggle(rank: Rank) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if expandedRanks.contains(rank) {
                expandedRanks.remove(rank)
            } else {
                expandedRanks.insert(rank)
            }
        }
    }

    func deleteMember(_ member: Member) {
        store.deleteMember(memberID: member.id, from: sectionID)
    }

    func recognizeRosterText(in image: UIImage) throws -> String {
        try ocrService.recognizeText(in: image)
    }

    func extractSPAEntries(from image: UIImage) async throws -> [SPAEntry] {
        let rawText = try ocrService.recognizeText(in: image)
        let entries = try await spaExtractionService.extractEntries(from: rawText)
        return matchSPAEntries(spaValidationService.validate(entries))
    }

    func extractSPAEntries(from rawText: String) async throws -> [SPAEntry] {
        let entries = try await spaExtractionService.extractEntries(from: rawText)
        return matchSPAEntries(spaValidationService.validate(entries))
    }

    func matchSPAEntries(_ entries: [SPAEntry]) -> [SPAEntry] {
        guard let section else {
            return entries
        }

        return spaMatchingService.match(entries, in: section)
    }

    func formattedRosterReviewText(from text: String) -> String {
        store.formattedRosterReviewText(from: text)
    }

    func rosterCandidates(from text: String) throws -> [RosterImportService.Candidate] {
        try store.rosterCandidates(from: text)
    }

    func importRosterText(_ text: String, replaceExisting: Bool) throws {
        _ = try store.importRosterText(text, into: sectionID, replaceExisting: replaceExisting)
    }

    func importMembers(_ members: [Member], replaceExisting: Bool) throws {
        _ = try store.importMembers(members, into: sectionID, replaceExisting: replaceExisting)
    }
}
