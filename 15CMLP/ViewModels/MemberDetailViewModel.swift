//
//  MemberDetailViewModel.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import Observation

@Observable
final class MemberDetailViewModel {
    let store: CompanyDirectoryStore
    let sectionID: UUID
    let memberID: UUID

    var isShowingEditSheet = false
    var alertMessage = ""
    var isShowingAlert = false

    init(store: CompanyDirectoryStore, sectionID: UUID, memberID: UUID) {
        self.store = store
        self.sectionID = sectionID
        self.memberID = memberID
    }

    var section: CompanySection? {
        store.section(withID: sectionID)
    }

    var member: Member? {
        store.member(withID: memberID, in: sectionID)
    }

    func callURL() -> URL? {
        guard let member else {
            return nil
        }

        let digits = member.phoneNumber.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else {
            return nil
        }

        return URL(string: "tel://\(digits)")
    }

    func copyMessage() -> String? {
        guard let member else {
            return nil
        }

        let number = member.phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        return number.isEmpty ? nil : number
    }

    func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}
