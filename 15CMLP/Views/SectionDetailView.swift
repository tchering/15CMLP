//
//  SectionDetailView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import Observation
import SwiftUI

struct SectionDetailView: View {
    @Bindable var store: CompanyDirectoryStore
    let sectionID: UUID

    @State private var isShowingAddMember = false

    var body: some View {
        Group {
            if let section = store.section(withID: sectionID) {
                List {
                    ForEach(section.membersByRank) { rankGroup in
                        Section(rankGroup.rank.title) {
                            ForEach(rankGroup.members) { member in
                                NavigationLink {
                                    MemberDetailView(member: member, sectionName: section.name)
                                } label: {
                                    MemberRow(member: member)
                                }
                            }
                            .onDelete { offsets in
                                store.deleteMembers(
                                    offsets: offsets,
                                    from: sectionID,
                                    rankGroup: rankGroup
                                )
                            }
                        }
                    }
                }
                .navigationTitle(section.name)
                .navigationBarTitleDisplayMode(.inline)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(AccentBackground().ignoresSafeArea())
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingAddMember = true
                        } label: {
                            Label("Add Member", systemImage: "plus")
                        }
                        .tint(.white)
                    }
                }
                .sheet(isPresented: $isShowingAddMember) {
                    AddMemberView(store: store, sectionID: sectionID)
                }
            } else {
                ContentUnavailableView("Section Missing", systemImage: "exclamationmark.triangle")
            }
        }
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
                    .foregroundStyle(Color.primary)

                Text(member.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(member.rank.shortTitle)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(Color(red: 0.14, green: 0.28, blue: 0.48))
                .background(Color.blue.opacity(0.10))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.blue.opacity(0.10), lineWidth: 1)
        )
        .listRowBackground(Color.clear)
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
