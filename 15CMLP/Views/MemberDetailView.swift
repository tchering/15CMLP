//
//  MemberDetailView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import SwiftUI
import UIKit

struct MemberDetailView: View {
    @State private var viewModel: MemberDetailViewModel

    @Environment(\.openURL) private var openURL

    init(store: CompanyDirectoryStore, sectionID: UUID, memberID: UUID) {
        _viewModel = State(initialValue: MemberDetailViewModel(store: store, sectionID: sectionID, memberID: memberID))
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Group {
            if let section = viewModel.section,
               let member = viewModel.member {
                ScrollView {
                    VStack(spacing: 20) {
                        MemberAvatar(member: member, size: 150)
                            .overlay {
                                RoundedRectangle(cornerRadius: 36, style: .continuous)
                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                            }

                        VStack(spacing: 8) {
                            Text(member.name)
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Text(member.rank.title)
                                .font(.headline)
                                .foregroundStyle(.white.opacity(0.72))

                            if !member.role.isEmpty {
                                Text(member.role)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.cyan)
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            DetailRow(title: "Section", value: section.name)
                            DetailRow(title: "Grade", value: member.rank.title)
                            PhoneDetailRow(
                                phoneNumber: member.phoneNumber,
                                onCall: { call(using: viewModel) },
                                onMessage: { message(using: viewModel) },
                                onWhatsApp: { whatsapp(using: viewModel) },
                                onCopy: { copy(using: viewModel) }
                            )
                            DetailRow(title: "Role", value: member.role)
                            DetailRow(title: "Memory Tip", value: member.memoryTip)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(.white.opacity(0.10), lineWidth: 1)
                        }
                    }
                    .padding(20)
                }
                .background(AccentBackground().ignoresSafeArea())
                .navigationTitle(member.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Edit") {
                            viewModel.isShowingEditSheet = true
                        }
                        .tint(.white)
                    }
                }
                .sheet(isPresented: $viewModel.isShowingEditSheet) {
                    AddMemberView(
                        viewModel: AddEditMemberViewModel(
                            store: viewModel.store,
                            mode: .edit(sectionID: viewModel.sectionID, member: member)
                        )
                    )
                }
                .alert("Phone Action", isPresented: $viewModel.isShowingAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text(viewModel.alertMessage)
                }
            } else {
                ContentUnavailableView("Member Missing", systemImage: "person.crop.circle.badge.exclamationmark")
            }
        }
    }

    private func call(using viewModel: MemberDetailViewModel) {
        guard let url = viewModel.callURL() else {
            viewModel.showAlert(message: "This phone number is not valid for calling.")
            return
        }

        openURL(url)
    }

    private func copy(using viewModel: MemberDetailViewModel) {
        guard let number = viewModel.copyMessage() else {
            viewModel.showAlert(message: "There is no phone number to copy.")
            return
        }

        UIPasteboard.general.string = number
        viewModel.showAlert(message: "Phone number copied.")
    }

    private func message(using viewModel: MemberDetailViewModel) {
        guard let url = viewModel.messageURL() else {
            viewModel.showAlert(message: "This phone number is not valid for messaging.")
            return
        }

        openURL(url)
    }

    private func whatsapp(using viewModel: MemberDetailViewModel) {
        guard let url = viewModel.whatsappURL() else {
            viewModel.showAlert(message: "This phone number is not valid for WhatsApp.")
            return
        }

        guard viewModel.canOpenWhatsApp() else {
            viewModel.showAlert(message: "WhatsApp is not available on this device.")
            return
        }

        openURL(url)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            Text(value.isEmpty ? "None" : value)
                .font(.body)
                .foregroundStyle(.white)
        }
    }
}

private struct PhoneDetailRow: View {
    let phoneNumber: String
    let onCall: () -> Void
    let onMessage: () -> Void
    let onWhatsApp: () -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Phone")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))

            if phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("None")
                    .font(.body)
                    .foregroundStyle(.white)
            } else {
                VStack(spacing: 10) {
                    Button(action: onCall) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(phoneNumber)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.white)

                                Text("Tap to call")
                                    .font(.caption)
                                    .foregroundStyle(.cyan)
                            }

                            Spacer()

                            Image(systemName: "phone.fill")
                                .foregroundStyle(.white)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 10) {
                        PhoneShortcutButton(
                            title: "SMS",
                            systemImage: "message.fill",
                            action: onMessage
                        )

                        PhoneShortcutButton(
                            title: "WhatsApp",
                            systemImage: "bubble.left.and.bubble.right.fill",
                            action: onWhatsApp
                        )

                        PhoneShortcutButton(
                            title: "Copy",
                            systemImage: "doc.on.doc",
                            action: onCopy
                        )
                    }
                }
                .contextMenu {
                    Button(action: onCall) {
                        Label("Call", systemImage: "phone.fill")
                    }

                    Button(action: onMessage) {
                        Label("Message", systemImage: "message.fill")
                    }

                    Button(action: onWhatsApp) {
                        Label("WhatsApp", systemImage: "bubble.left.and.bubble.right.fill")
                    }

                    Button(action: onCopy) {
                        Label("Copy Number", systemImage: "doc.on.doc")
                    }
                }
            }
        }
    }
}

private struct PhoneShortcutButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.headline)

                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct MemberAvatar: View {
    let member: Member
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = MemberPhotoStorageService.shared.loadImage(for: member) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [.blue, .indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Text(member.initials)
                        .font(.system(size: size * 0.34, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
    }
}
