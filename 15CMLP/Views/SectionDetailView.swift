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
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isShowingAddMember = true
                        } label: {
                            Label("Add Member", systemImage: "plus")
                        }
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

                Text(member.role)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(member.rank.shortTitle)
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.12))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
