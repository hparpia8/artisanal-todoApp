import SwiftUI

struct TodoRowView: View {
    let item: TodoItem
    let onToggle: () -> Void
    var onDelete: (() -> Void)? = nil  // nil for completed rows (no delete)

    @State private var isHovered = false

    private var isCompleted: Bool { item.isCompleted }

    var body: some View {
        HStack(spacing: 0) {
            // Main row — entire area toggles the item
            Button(action: onToggle) {
                HStack(alignment: .center, spacing: 12) {
                    checkbox

                    Text(item.title)
                        .font(AppTheme.bodyFont)
                        .foregroundStyle(isCompleted ? AppTheme.completedText : AppTheme.primaryText)
                        .strikethrough(isCompleted, color: AppTheme.completedText)
                        .lineLimit(nil)
                        .multilineTextAlignment(.leading)
                        .animation(.easeInOut(duration: 0.2), value: isCompleted)

                    Spacer()

                    // Timestamp fades in on hover — completedAt for done items, createdAt for pending
                    if isCompleted, let completedAt = item.completedAt {
                        Text(completedAt, format: .dateTime.hour().minute())
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.completedText.opacity(0.55))
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                    } else if !isCompleted {
                        Text(item.createdAt, format: .dateTime.hour().minute())
                            .font(AppTheme.captionFont)
                            .foregroundStyle(AppTheme.mutedText.opacity(0.7))
                            .opacity(isHovered ? 1 : 0)
                            .animation(.easeInOut(duration: 0.15), value: isHovered)
                    }
                }
                .padding(.leading, AppTheme.rowPaddingH)
                .padding(.trailing, onDelete != nil ? 8 : AppTheme.rowPaddingH)
                .padding(.vertical, AppTheme.rowPaddingV)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Trash button — fades in on hover, only for pending rows
            if let onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.mutedText.opacity(0.55))
                }
                .buttonStyle(.plain)
                .frame(width: 36)
                .padding(.trailing, 8)
                .opacity(isHovered ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
        }
        .background(
            Rectangle()
                .fill(isHovered ? AppTheme.paperLine.opacity(0.28) : Color.clear)
                .animation(.easeInOut(duration: 0.12), value: isHovered)
        )
        .overlay(
            Rectangle()
                .fill(AppTheme.paperLine.opacity(0.7))
                .frame(height: 0.5)
                .padding(.horizontal, AppTheme.rowPaddingH),
            alignment: .bottom
        )
        .onHover { isHovered = $0 }
    }

    // Pure visual checkbox — toggling handled by the parent Button
    var checkbox: some View {
        ZStack {
            Circle()
                .stroke(
                    isCompleted
                        ? AppTheme.accent
                        : (isHovered ? AppTheme.accent : AppTheme.checkboxBorder),
                    lineWidth: 1.5
                )
                .frame(width: 18, height: 18)

            if isCompleted {
                Circle()
                    .fill(AppTheme.accent.opacity(0.18))
                    .frame(width: 18, height: 18)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isCompleted)
    }
}
