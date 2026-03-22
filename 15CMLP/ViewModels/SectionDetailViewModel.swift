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

    init(
        store: CompanyDirectoryStore,
        sectionID: UUID,
        ocrService: OCRTextRecognitionService = OCRTextRecognitionService()
    ) {
        self.store = store
        self.sectionID = sectionID
        self.ocrService = ocrService
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

    func formattedRosterReviewText(from text: String) -> String {
        store.formattedRosterReviewText(from: text)
    }

    func importRosterText(_ text: String, replaceExisting: Bool) throws {
        _ = try store.importRosterText(text, into: sectionID, replaceExisting: replaceExisting)
    }
}
