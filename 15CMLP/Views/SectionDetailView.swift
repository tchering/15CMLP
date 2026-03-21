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
    @State private var expandedRanks: Set<Rank> = [.chefDeSection]

    var body: some View {
        Group {
            if let section = store.section(withID: sectionID) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
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

    private func toggle(rank: Rank) {
        if expandedRanks.contains(rank) {
            expandedRanks.remove(rank)
        } else {
            expandedRanks.insert(rank)
        }
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .sectionCardSurface(cornerRadius: 26)
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
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
