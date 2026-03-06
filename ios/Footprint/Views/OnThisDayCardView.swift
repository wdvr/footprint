//
//  OnThisDayCardView.swift
//  Footprint
//
//  A banner card surfacing "On This Day" travel memories.
//

import SwiftUI

/// Banner card shown at the top of the map view when there are travel memories for today
struct OnThisDayCardView: View {
    let memories: [OnThisDayMemory]
    let onDismiss: () -> Void

    @State private var currentIndex = 0

    private var memory: OnThisDayMemory {
        memories[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // Flag or calendar icon
                if !memory.flagEmoji.isEmpty {
                    Text(memory.flagEmoji)
                        .font(.system(size: 36))
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("On This Day")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .textCase(.uppercase)

                    Text(memory.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(2)

                    if let notes = memory.place.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Dismiss memory")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Pagination dots if multiple memories
            if memories.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<memories.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.orange : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if memories.count > 1 {
                        if value.translation.width < -30 {
                            withAnimation {
                                currentIndex = min(currentIndex + 1, memories.count - 1)
                            }
                        } else if value.translation.width > 30 {
                            withAnimation {
                                currentIndex = max(currentIndex - 1, 0)
                            }
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(memory.description)
        .accessibilityHint(memories.count > 1 ? "Swipe to see more memories. Double tap to dismiss." : "Double tap to dismiss.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction {
            onDismiss()
        }
    }
}
