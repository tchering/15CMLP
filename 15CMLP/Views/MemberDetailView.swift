//
//  MemberDetailView.swift
//  15CMLP
//
//  Created by sonam sherpa on 21/03/2026.
//

import SwiftUI
import UIKit

struct MemberDetailView: View {
    let member: Member
    let sectionName: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                MemberAvatar(member: member, size: 150)

                VStack(spacing: 8) {
                    Text(member.name)
                        .font(.title.bold())

                    Text(member.rank.title)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if !member.role.isEmpty {
                        Text(member.role)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.blue)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    DetailRow(title: "Section", value: sectionName)
                    DetailRow(title: "Grade", value: member.rank.title)
                    DetailRow(title: "Role", value: member.role)
                    DetailRow(title: "Memory Tip", value: member.memoryTip)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value.isEmpty ? "None" : value)
                .font(.body)
        }
    }
}

struct MemberAvatar: View {
    let member: Member
    let size: CGFloat

    var body: some View {
        Group {
            if let uiImage = MemberPhotoStorage.loadImage(for: member) {
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
