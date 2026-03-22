//
//  ContentView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var viewModel: HomeViewModel

    init(store: CompanyDirectoryStore) {
        _viewModel = State(initialValue: HomeViewModel(store: store))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HomeHeaderCard(
                        sectionCount: viewModel.sections.count,
                        totalMembers: viewModel.totalMembers,
                        onExport: viewModel.exportBackup,
                        onImport: { viewModel.isShowingImporter = true }
                    )

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Sections")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)

                        ForEach(viewModel.sections) { section in
                            NavigationLink {
                                SectionDetailView(store: viewModel.store, sectionID: section.id)
                            } label: {
                                SectionCard(section: section)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(HomeBackground().ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .fileExporter(
                isPresented: $viewModel.isShowingExporter,
                document: viewModel.backupDocument,
                contentType: .json,
                defaultFilename: viewModel.backupFileName
            ) { result in
                viewModel.handleExporterResult(result)
            }
            .fileImporter(
                isPresented: $viewModel.isShowingImporter,
                allowedContentTypes: [.json]
            ) { result in
                viewModel.handleImport(result: result)
            }
            .alert("Backup", isPresented: $viewModel.isShowingAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.alertMessage)
            }
        }
    }
}

private struct HomeHeaderCard: View {
    let sectionCount: Int
    let totalMembers: Int
    let onExport: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                RegimentLogoView()

                VStack(alignment: .leading, spacing: 6) {
                    Text("3RMAT")
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("15CMLP")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.88))

                    Text("Tap a section to review faces, names, and grades.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }
            }

            HStack(spacing: 12) {
                StatTile(title: "Sections", value: "\(sectionCount)")
                StatTile(title: "Members", value: "\(totalMembers)")
            }

            HStack(spacing: 12) {
                HeaderActionButton(title: "Export Backup", systemImage: "square.and.arrow.up", action: onExport)
                HeaderActionButton(title: "Import Backup", systemImage: "square.and.arrow.down", action: onImport)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.06, green: 0.19, blue: 0.44),
                            Color(red: 0.13, green: 0.47, blue: 0.80)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct HeaderActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title)
                    .lineLimit(1)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(.white.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RegimentLogoView: View {
    private let assetName = "3RMATLogo"

    var body: some View {
        Group {
            if let uiImage = UIImage(named: assetName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.white.opacity(0.12))

                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .overlay(alignment: .bottom) {
                    Text("Add `3RMATLogo` to Assets")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.bottom, 8)
                }
            }
        }
        .frame(width: 110, height: 130)
        .background(.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct StatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct HomeBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.15),
                    Color(red: 0.08, green: 0.14, blue: 0.24),
                    Color(red: 0.12, green: 0.20, blue: 0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 30)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.14))
                .frame(width: 300, height: 300)
                .blur(radius: 40)
                .offset(x: 150, y: -80)
        }
    }
}

private struct SectionCard: View {
    let section: CompanySection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)

                    Text("\(section.members.count) members")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()

                ZStack {
                    Circle()
                        .fill(.white.opacity(0.12))
                        .frame(width: 40, height: 40)

                    Image(systemName: "arrow.up.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
            }

            Text(section.summary)
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.78))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(section.rankPreview, id: \.self) { item in
                        Text(item)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.12))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView(store: CompanyDirectoryStore())
}
