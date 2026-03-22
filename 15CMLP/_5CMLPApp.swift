//
//  _5CMLPApp.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import SwiftUI

@main
struct _5CMLPApp: App {
    @State private var store = CompanyDirectoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
    }
}
