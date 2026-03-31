import SwiftUI

private let completedDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "EEEE, MMMM d"
    return f
}()

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var newItemText = ""
    @State private var scrollTrigger = 0
    @FocusState private var inputFocused: Bool
    @AppStorage("colorScheme") private var colorSchemePreference: String = "auto"

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            thinDivider
            scrollContent
            thinDivider
            inputBar
        }
        .background(AppTheme.background)
        .frame(minWidth: 380, idealWidth: 460, minHeight: 500, idealHeight: 650)
        .onReceive(NotificationCenter.default.publisher(for: .focusInput)) { _ in
            inputFocused = true
        }
    }

    // MARK: - Header

    var headerBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ToDo")
                    .font(AppTheme.headlineFont)
                    .foregroundStyle(AppTheme.primaryText)
                Text(Date(), format: .dateTime.weekday(.wide).month(.wide).day())
                    .font(AppTheme.captionFont)
                    .foregroundStyle(AppTheme.mutedText)
            }

            Spacer()

            HStack(spacing: 14) {
                if store.pending.count > 0 {
                    Text("\(store.pending.count) remaining")
                        .font(AppTheme.captionFont.monospacedDigit())
                        .foregroundStyle(AppTheme.mutedText)
                }
                colorSchemePicker
            }
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.top, 32) // clear traffic-light buttons
        .padding(.bottom, 12)
        .background(AppTheme.background)
    }

    var colorSchemePicker: some View {
        HStack(spacing: 1) {
            ForEach(AppColorScheme.allCases, id: \.rawValue) { mode in
                Button {
                    colorSchemePreference = mode.rawValue
                } label: {
                    Image(systemName: mode.systemIcon)
                        .font(.system(size: 11))
                        .frame(width: 26, height: 22)
                        .foregroundStyle(
                            colorSchemePreference == mode.rawValue
                                ? AppTheme.accent
                                : AppTheme.mutedText
                        )
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(
                                    colorSchemePreference == mode.rawValue
                                        ? AppTheme.accent.opacity(0.12)
                                        : Color.clear
                                )
                        )
                }
                .buttonStyle(.plain)
                .help(mode.label)
            }
        }
    }

    // MARK: - Scroll content

    var scrollContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {

                    // Completed history grouped by day (oldest → newest, scrolled above)
                    if !store.completed.isEmpty {
                        completedHeader
                        ForEach(completedByDay, id: \.date) { group in
                            dayHeader(group.date)
                            ForEach(group.items) { item in
                                TodoRowView(item: item) {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                        store.toggle(item)
                                    }
                                }
                                // slides up into completed, slides down out when restored
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .move(edge: .bottom)),
                                    removal: .opacity.combined(with: .move(edge: .top))
                                ))
                            }
                        }
                        nowDivider
                    }

                    // Anchor — scroll here on appear so completed section is hidden above
                    Color.clear.frame(height: 0).id("pending-top")

                    // Active / pending items
                    if store.pending.isEmpty {
                        emptyState
                    } else {
                        ForEach(store.pending) { item in
                            TodoRowView(
                                item: item,
                                onToggle: {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                        store.toggle(item)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                        store.delete(item)
                                    }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity.combined(with: .move(edge: .top))
                            ))
                        }
                    }

                    // Bottom anchor — app opens scrolled here
                    Spacer(minLength: 32)
                    Color.clear.frame(height: 1).id("bottom")
                }
            }
            .onAppear {
                DispatchQueue.main.async {
                    proxy.scrollTo("pending-top", anchor: .top)
                }
            }
            .onChange(of: scrollTrigger) { _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    proxy.scrollTo("pending-top", anchor: .top)
                }
            }
        }
    }

    var completedByDay: [(date: Date, items: [TodoItem])] {
        let calendar = Calendar.current
        var byDay: [Date: [TodoItem]] = [:]
        for item in store.completed {
            let day = calendar.startOfDay(for: item.completedAt ?? item.createdAt)
            byDay[day, default: []].append(item)
        }
        return byDay.keys.sorted().map { date in
            (date: date, items: byDay[date]!)
        }
    }

    var completedHeader: some View {
        ruledLabel("Completed", color: AppTheme.mutedText, top: 24, bottom: 8)
    }

    func dayHeader(_ date: Date) -> some View {
        ruledLabel(completedDayFormatter.string(from: date), color: AppTheme.mutedText, top: 16, bottom: 4)
    }

    var nowDivider: some View {
        ruledLabel("Today", color: AppTheme.accent, top: 18, bottom: 18)
    }

    private func ruledLabel(_ text: String, color: Color, top: CGFloat, bottom: CGFloat) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(AppTheme.paperLine).frame(height: 0.5)
            Text(text)
                .font(AppTheme.monoFont)
                .tracking(1.5)
                .foregroundStyle(color)
                .fixedSize()
            Rectangle().fill(AppTheme.paperLine).frame(height: 0.5)
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.top, top)
        .padding(.bottom, bottom)
    }

    var emptyState: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 60)
            Text("nothing pending")
                .font(.system(size: 14, weight: .light, design: .serif))
                .foregroundStyle(AppTheme.completedText)
            Text("type below to add a task")
                .font(AppTheme.captionFont)
                .foregroundStyle(AppTheme.completedText.opacity(0.6))
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input bar

    var inputBar: some View {
        HStack(spacing: 12) {
            Circle()
                .stroke(AppTheme.checkboxBorder.opacity(0.35), lineWidth: 1)
                .frame(width: 18, height: 18)

            TextField("add a task...", text: $newItemText)
                .textFieldStyle(.plain)
                .font(AppTheme.bodyFont)
                .foregroundStyle(AppTheme.primaryText)
                .focused($inputFocused)
                .onSubmit { addItem() }

            if !newItemText.isEmpty {
                Button(action: addItem) {
                    Image(systemName: "return")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, AppTheme.rowPaddingH)
        .padding(.vertical, 14)
        .background(AppTheme.background)
        .animation(.easeInOut(duration: 0.15), value: newItemText.isEmpty)
    }

    var thinDivider: some View {
        Rectangle()
            .fill(AppTheme.paperLine)
            .frame(height: 0.5)
    }

    // MARK: - Actions

    func addItem() {
        guard !newItemText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            store.add(newItemText)
        }
        newItemText = ""
        scrollTrigger += 1
    }
}
