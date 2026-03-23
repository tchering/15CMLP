//
//  MemberDetailViewModel.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import Observation
import UIKit

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
        url(forScheme: "tel://")
    }

    func messageURL() -> URL? {
        url(forScheme: "sms:")
    }

    func whatsappURL() -> URL? {
        guard let digits = normalizedPhoneNumber() else {
            return nil
        }

        return URL(string: "whatsapp://send?phone=\(digits)")
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

    func canOpenWhatsApp() -> Bool {
        guard let url = whatsappURL() else {
            return false
        }

        return UIApplication.shared.canOpenURL(url)
    }

    private func url(forScheme scheme: String) -> URL? {
        guard let digits = normalizedPhoneNumber() else {
            return nil
        }

        return URL(string: "\(scheme)\(digits)")
    }

    private func normalizedPhoneNumber() -> String? {
        guard let member else {
            return nil
        }

        let digits = member.phoneNumber.filter { $0.isNumber || $0 == "+" }
        return digits.isEmpty ? nil : digits
    }
}
