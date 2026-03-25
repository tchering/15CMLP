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

struct SectionDetailView: View {
    @State private var viewModel: SectionDetailViewModel

    init(store: CompanyDirectoryStore, sectionID: UUID) {
        _viewModel = State(initialValue: SectionDetailViewModel(store: store, sectionID: sectionID))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if let section = viewModel.section {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(section.membersByRank) { rankGroup in
                            RankStackCard(
                                store: viewModel.store,
                                sectionID: viewModel.sectionID,
                                rankGroup: rankGroup,
                                isExpanded: viewModel.isExpanded(rankGroup.rank),
                                onToggle: {
                                    viewModel.toggle(rank: rankGroup.rank)
                                },
                                onDeleteMember: { member in
                                    viewModel.deleteMember(member)
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
                                viewModel.isShowingAddMember = true
                            } label: {
                                Label("Add Member", systemImage: "plus")
                            }

                            Button {
                                viewModel.isShowingScanImport = true
                            } label: {
                                Label("Import Roster", systemImage: "text.viewfinder")
                            }

                            Button {
                                viewModel.isShowingSPAScanReview = true
                            } label: {
                                Label("Scan SPA", systemImage: "doc.text.viewfinder")
                            }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.white)
                    }
                }
                .sheet(isPresented: $viewModel.isShowingAddMember) {
                    AddMemberView(
                        viewModel: AddEditMemberViewModel(
                            store: viewModel.store,
                            mode: .add(sectionID: viewModel.sectionID)
                        )
                    )
                }
                .sheet(isPresented: $viewModel.isShowingScanImport) {
                    OCRImportView(viewModel: viewModel)
                }
                .sheet(isPresented: $viewModel.isShowingSPAScanReview) {
                    SPAScanReviewView(viewModel: viewModel)
                }
            } else {
                ContentUnavailableView("Section Missing", systemImage: "exclamationmark.triangle")
            }
        }
    }
}

private struct SPAScanReviewView: View {
    let viewModel: SectionDetailViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var entries: [SPAEntry] = []
    @State private var selectedEntryIDs = Set<UUID>()
    @State private var isProcessing = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Choose a SPA image. The app will run OCR, send the raw text to the LLM, validate the rows, and show match results before any update is applied.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.74))

                    PhotosPicker(
                        selection: $selectedPhotoItem,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 10) {
                            Image(systemName: "doc.text.viewfinder")
                            Text(selectedImage == nil ? "Choose SPA Image" : "Change SPA Image")
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

                    if isProcessing {
                        ProgressView("Extracting SPA rows...")
                            .tint(.white)
                            .foregroundStyle(.white)
                    }

                    SPAReviewSummary(entries: entries, selectedEntryIDs: selectedEntryIDs)

                    if entries.isEmpty {
                        Text("No SPA rows yet. Select an image to extract and review the daily status table.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.68))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Extracted SPA Rows")
                                .font(.headline)
                                .foregroundStyle(.white)

                            ForEach(entries) { entry in
                                SPAEntryReviewRow(
                                    entry: entry,
                                    matchedMemberName: viewModel.memberName(for: entry.matchedMemberID),
                                    isSelected: selectedEntryIDs.contains(entry.id)
                                ) {
                                    toggleSelection(for: entry.id)
                                }
                            }
                        }
                    }

                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(20)
            }
            .background(AccentBackground().ignoresSafeArea())
            .navigationTitle("Scan SPA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                    .tint(.white)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Review Complete") {
                        dismiss()
                    }
                    .disabled(entries.isEmpty || isProcessing)
                    .tint(.white)
                }
            }
        }
        .task(id: selectedPhotoItem) {
            await loadAndExtractSPA()
        }
    }

    @MainActor
    private func loadAndExtractSPA() async {
        guard let selectedPhotoItem else {
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            guard let data = try await selectedPhotoItem.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "Unable to load the selected SPA image."
                return
            }

            selectedImage = image
            let extractedEntries = try await viewModel.extractSPAEntries(from: image)
            entries = extractedEntries
            selectedEntryIDs = Set(extractedEntries.filter(\.isValid).map(\.id))
            errorMessage = extractedEntries.isEmpty ? "No SPA rows were extracted from this image." : ""
        } catch {
            entries = []
            selectedEntryIDs = []
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSelection(for id: UUID) {
        guard let entry = entries.first(where: { $0.id == id }), entry.isValid else {
            return
        }

        if selectedEntryIDs.contains(id) {
            selectedEntryIDs.remove(id)
        } else {
            selectedEntryIDs.insert(id)
        }
    }
}

private struct SPAReviewSummary: View {
    let entries: [SPAEntry]
    let selectedEntryIDs: Set<UUID>

    var body: some View {
        HStack(spacing: 12) {
            StatChip(title: "Rows", value: "\(entries.count)")
            StatChip(title: "Selected", value: "\(selectedEntryIDs.count)")
            StatChip(title: "Matched", value: "\(entries.filter { $0.matchStatus == .matched }.count)")
            StatChip(title: "Issues", value: "\(entries.filter { !$0.validationIssues.isEmpty }.count)")
        }
    }
}

private struct SPAEntryReviewRow: View {
    let entry: SPAEntry
    let matchedMemberName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selectionIconName)
                        .font(.title3)
                        .foregroundStyle(selectionColor)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(entry.grade)
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.12))
                                .clipShape(Capsule())

                            Text(entry.nom)
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            SPAMatchBadge(status: entry.matchStatus)
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 90), alignment: .leading),
                                GridItem(.flexible(minimum: 90), alignment: .leading)
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            SPAField(label: "Position", value: entry.position)
                            SPAField(label: "Matched", value: matchedMemberName.isEmpty ? "None" : matchedMemberName)
                            SPAField(label: "Début", value: entry.debut)
                            SPAField(label: "Fin", value: entry.fin)
                        }

                        SPAField(label: "Observation", value: entry.observation)

                        if !entry.validationIssues.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Validation Issues")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.orange)

                                ForEach(entry.validationIssues, id: \.self) { issue in
                                    Text(issue)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.74))
                                }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var selectionIconName: String {
        if !entry.isValid {
            return "exclamationmark.triangle.fill"
        }

        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private var selectionColor: Color {
        if !entry.isValid {
            return .orange
        }

        return isSelected ? .cyan : .white.opacity(0.55)
    }
}

private struct SPAField: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "None" : value)
                .font(.subheadline)
                .foregroundStyle(.white)
        }
    }
}

private struct SPAMatchBadge: View {
    let status: SPAEntry.MatchStatus

    var body: some View {
        Text(status.title)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .foregroundStyle(.white)
            .background(backgroundColor)
            .clipShape(Capsule())
    }

    private var backgroundColor: Color {
        switch status {
        case .matched:
            return .green.opacity(0.55)
        case .unmatched:
            return .gray.opacity(0.40)
        case .ambiguous:
            return .orange.opacity(0.65)
        case .invalid:
            return .red.opacity(0.70)
        }
    }
}

private struct StatChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct OCRImportView: View {
    let viewModel: SectionDetailViewModel

    @Environment(\.dismiss) private var dismiss

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var extractedText = ""
    @State private var replaceExisting = true
    @State private var isRecognizing = false
    @State private var errorMessage = ""
    @State private var candidates: [RosterImportService.Candidate] = []
    @State private var selectedCandidateIDs = Set<UUID>()

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

                        Text("The OCR result is shown in a grade/name/phone layout when possible so you can correct it before import.")
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

                    HStack {
                        Text("Detected People")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button("Refresh List") {
                            refreshCandidates()
                        }
                        .font(.footnote.weight(.semibold))
                        .tint(.white)
                    }

                    if candidates.isEmpty {
                        Text("No valid people have been extracted yet. Review the text above, then tap Refresh List.")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.68))
                    } else {
                        VStack(spacing: 10) {
                            ForEach(candidates) { candidate in
                                CandidateRow(
                                    candidate: candidate,
                                    isSelected: selectedCandidateIDs.contains(candidate.id)
                                ) {
                                    toggleSelection(for: candidate.id)
                                }
                            }
                        }
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
                    .disabled(selectedCandidateIDs.isEmpty || isRecognizing)
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
            let recognizedText = try viewModel.recognizeRosterText(in: image)
            extractedText = viewModel.formattedRosterReviewText(from: recognizedText)
            refreshCandidates()
            errorMessage = extractedText.isEmpty ? "No text was recognized in this image." : ""
        } catch {
            errorMessage = "Unable to scan text from the selected image."
        }
    }

    private func importRoster() {
        do {
            let selectedMembers = candidates
                .filter { selectedCandidateIDs.contains($0.id) }
                .map(\.member)
            try viewModel.importMembers(selectedMembers, replaceExisting: replaceExisting)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshCandidates() {
        do {
            candidates = try viewModel.rosterCandidates(from: extractedText)
            selectedCandidateIDs = Set(candidates.map(\.id))
            errorMessage = candidates.isEmpty ? "No valid members were detected in the reviewed text." : ""
        } catch {
            candidates = []
            selectedCandidateIDs = []
            errorMessage = error.localizedDescription
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedCandidateIDs.contains(id) {
            selectedCandidateIDs.remove(id)
        } else {
            selectedCandidateIDs.insert(id)
        }
    }
}

private struct CandidateRow: View {
    let candidate: RosterImportService.Candidate
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .cyan : .white.opacity(0.55))

                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.member.name)
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 8) {
                        Text(candidate.member.rank.title)
                        if !candidate.member.phoneNumber.isEmpty {
                            Text(candidate.member.phoneNumber)
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                }

                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RankStackCard: View {
    let store: CompanyDirectoryStore
    let sectionID: UUID
    let rankGroup: RankGroup
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
