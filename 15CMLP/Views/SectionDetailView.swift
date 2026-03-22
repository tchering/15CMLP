//
//  SectionDetailView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import PhotosUI
import SwiftUI
import UIKit
import Vision

struct SectionDetailView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID

    @State private var isShowingAddMember = false
    @State private var isShowingScanImport = false
    @State private var expandedRanks: Set<Rank> = [.chefDeSection]

    var body: some View {
        Group {
            if let section = store.section(withID: sectionID) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(section.membersByRank) { rankGroup in
                            RankStackCard(
                                store: store,
                                sectionID: sectionID,
                                rankGroup: rankGroup,
                                sectionName: section.name,
                                isExpanded: expandedRanks.contains(rankGroup.rank),
                                onToggle: {
                                    toggle(rank: rankGroup.rank)
                                },
                                onDeleteMember: { member in
                                    store.deleteMember(memberID: member.id, from: sectionID)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .navigationTitle(section.name)
                .navigationBarTitleDisplayMode(.inline)
                .background(AccentBackground().ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Button {
                                isShowingAddMember = true
                            } label: {
                                Label("Add Member", systemImage: "plus")
                            }

                            Button {
                                isShowingScanImport = true
                            } label: {
                                Label("Scan Image", systemImage: "text.viewfinder")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.white)
                    }
                }
                .sheet(isPresented: $isShowingAddMember) {
                    AddMemberView(store: store, sectionID: sectionID)
                }
                .sheet(isPresented: $isShowingScanImport) {
                    OCRImportView(store: store, sectionID: sectionID)
                }
            } else {
                ContentUnavailableView("Section Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }

    private func toggle(rank: Rank) {
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
            if expandedRanks.contains(rank) {
                expandedRanks.remove(rank)
            } else {
                expandedRanks.insert(rank)
            }
        }
    }
}

private struct OCRImportView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedText = ""
    @State private var replaceExisting = true
    @State private var isRecognizing = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose a screenshot or photo of the roster. The app will extract the text, and you can review it before importing.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(selectedImage == nil ? "Choose Roster Image" : "Change Image")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            )
                    }

                    if isRecognizing {
                        ProgressView("Scanning text...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Review Text")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("The OCR result is shown in a grade/name roster layout so you can correct it before import.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.68))

                        TextEditor(text: $extractedText)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 240)
                            .background(Color.white.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(.white.opacity(0.10), lineWidth: 1)
                            )
                            .foregroundStyle(.white)
                    }

                    Toggle("Replace existing members in this section", isOn: $replaceExisting)
                        .tint(.cyan)
                        .foregroundStyle(.white)

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(AccentBackground().ignoresSafeArea())
            .navigationTitle("Scan Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        importRoster()
                    }
                    .disabled(extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRecognizing)
                    .tint(.white)
                }
            }
        }
        .task(id: selectedPhotoItem) {
            await loadAndRecognizeSelectedImage()
        }
    }

    @MainActor
    private func loadAndRecognizeSelectedImage() async {
        guard let selectedPhotoItem else {
            return
        }

        isRecognizing = true
        defer { isRecognizing = false }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Unable to load the selected image."
                return
            }

            selectedImage = image
            let recognizedText = try OCRTextRecognizer.recognizeText(in: image)
            extractedText = store.formattedRosterReviewText(from: recognizedText)
            errorMessage = extractedText.isEmpty ? "No text was recognized in this image." : ""
        } catch {
            errorMessage = "Unable to scan text from the selected image."
        }
    }

    private func importRoster() {
        do {
            _ = try store.importRosterText(
                extractedText,
                into: sectionID,
                replaceExisting: replaceExisting
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum OCRTextRecognizer {
    static func recognizeText(in image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRImportError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["fr-FR", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let recognizedLines = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedLines.joined(separator: "\n")
    }

    enum OCRImportError: Error {
        case invalidImage
    }
}

private struct RankStackCard: View {
    let store: CompanyDirectoryStore
    let sectionID: UUID
    let rankGroup: RankGroup
    let sectionName: String
    let isExpanded: Bool
    let onToggle: () -> Void
    let onDeleteMember: (Member) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(rankGroup.rank.title)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Text("\(rankGroup.members.count) \(rankGroup.members.count == 1 ? "member" : "members")")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.68))
                    }

                    Spacer()

                    Text("\(rankGroup.members.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Capsule())

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(rankGroup.members) { member in
                        NavigationLink {
                            MemberDetailView(
                                store: store,
                                sectionID: sectionID,
                                memberID: member.id
                            )
                        } label: {
                            MemberRow(member: member)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                onDeleteMember(member)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                        removal: .opacity
                    )
                )
            }
        }
        .padding(18)
        .sectionCardSurface(cornerRadius: 26)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isExpanded)
    }
}

private struct MemberRow: View {
    let member: Member

    var body: some View {
        HStack(spacing: 12) {
            MemberAvatar(member: member, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(member.name)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(member.role)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer()

            Text(member.rank.shortTitle)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .memberCardSurface(cornerRadius: 22)
    }
}

struct AccentBackground: View {
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
                .fill(Color.cyan.opacity(0.13))
                .frame(width: 260, height: 260)
                .blur(radius: 32)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 42)
                .offset(x: 150, y: -80)
        }
    }
}

private extension View {
    @ViewBuilder
    func sectionCardSurface(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(Color.white.opacity(0.01))
                .glassEffect(
                    .regular
                        .tint(Color(red: 0.20, green: 0.33, blue: 0.58).opacity(0.35))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(red: 0.10, green: 0.18, blue: 0.32).opacity(0.70))
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.12), lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    func memberCardSurface(cornerRadius: CGFloat) -> some View {
        if #available(iOS 26.0, *) {
            self
                .background(Color.white.opacity(0.01))
                .glassEffect(
                    .regular
                        .tint(Color(red: 0.24, green: 0.39, blue: 0.65).opacity(0.28))
                        .interactive(),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            self
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(red: 0.13, green: 0.23, blue: 0.40).opacity(0.86))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                )
        }
    }
}
