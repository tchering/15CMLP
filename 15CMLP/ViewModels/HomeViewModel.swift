//
//  HomeViewModel.swift
//  15CMLP
//
//  Created by OpenAI Codex.
//

import Foundation
import Observation

@Observable
final class HomeViewModel {
    let store: CompanyDirectoryStore

    var isShowingExporter = false
    var isShowingImporter = false
    var backupDocument: CompanyBackupDocument?
    var alertMessage = ""
    var isShowingAlert = false

    init(store: CompanyDirectoryStore) {
        self.store = store
    }

    var sections: [CompanySection] {
        store.sections
    }

    var totalMembers: Int {
        store.sections.reduce(0) { $0 + $1.members.count }
    }

    var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "15CMLP-Backup-\(formatter.string(from: Date()))"
    }

    func exportBackup() {
        do {
            backupDocument = try store.makeBackupDocument()
            isShowingExporter = true
        } catch {
            showAlert(message: "Unable to prepare backup.")
        }
    }

    func handleExporterResult(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            showAlert(message: "Backup exported successfully.")
        case .failure:
            showAlert(message: "Unable to export backup.")
        }
    }

    func handleImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer {
                if hasAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            do {
                let data = try Data(contentsOf: url)
                try store.importBackup(from: data)
                showAlert(message: "Backup imported successfully.")
            } catch {
                showAlert(message: "Unable to import backup.")
            }
        case .failure:
            showAlert(message: "Backup import was cancelled or failed.")
        }
    }

    func showAlert(message: String) {
        alertMessage = message
        isShowingAlert = true
    }
}
