import SwiftUI
import SwiftData

struct CatchUpPeriod {
    let range: ClosedRange<Date>
    let transaction: Transaction?
    let coveredThrough: Date?
    let hasThreeQuietDays: Bool

    static func current(for plan: MonthPlan, now: Date = .now) -> CatchUpPeriod? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return nil
        }
        let planStart = max(calendar.startOfDay(for: plan.effectiveCreatedAt), plan.monthStart)
        guard planStart <= yesterday else { return nil }

        let latestLoggedDay = plan.transactions.compactMap { transaction -> Date? in
            if transaction.isCatchUp, let end = transaction.catchUpEndDate {
                return min(calendar.startOfDay(for: end), yesterday)
            }
            return min(calendar.startOfDay(for: transaction.date), today)
        }.max()
        let acknowledged = plan.catchUpAcknowledgedThrough.map { calendar.startOfDay(for: $0) }
        let coveredThrough = [latestLoggedDay, acknowledged].compactMap { $0 }.max()
        let firstUncovered = coveredThrough.flatMap {
            calendar.date(byAdding: .day, value: 1, to: $0)
        } ?? planStart

        // The header action remains available for an extra amount even when
        // all previous days are covered; the card requires three full days.
        let rangeStart = min(max(firstUncovered, planStart), yesterday)
        let range = rangeStart...yesterday
        let catchUp = plan.transactions.first {
            $0.isCatchUp && $0.catchUpStartDate.map(calendar.startOfDay) == range.lowerBound &&
                $0.catchUpEndDate.map(calendar.startOfDay) == range.upperBound
        }
        let thirdPreviousDay = calendar.date(byAdding: .day, value: -3, to: today)!
        return CatchUpPeriod(range: range,
                             transaction: catchUp,
                             coveredThrough: coveredThrough,
                             hasThreeQuietDays: firstUncovered <= thirdPreviousDay)
    }
}

struct CatchUpCard: View {
    let plan: MonthPlan
    let visitID: UUID
    let onOpen: (CatchUpPeriod) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var promptShownVisitID: UUID?
    @State private var promptShownOn: Date?

    var body: some View {
        if let period = CatchUpPeriod.current(for: plan), shouldShow(period) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(alignment: .top, spacing: AppSpacing.md) {
                    Image(systemName: "arrow.uturn.backward.circle")
                        .font(.dmSans(.title3))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text("Anything to catch up on?")
                            .font(.dmSans(.subheadline, weight: .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text("No spending logged since \(period.range.lowerBound.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).")
                            .font(.dmSans(.footnote))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    Button { acknowledge(period.range) } label: {
                        Image(systemName: "xmark")
                            .font(.dmSans(.caption, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Dismiss catch-up prompt")
                }

                (dynamicTypeSize.isAccessibilitySize
                 ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.xs))
                 : AnyLayout(HStackLayout(spacing: AppSpacing.lg))) {
                    Button { onOpen(period) } label: {
                        Text(period.transaction == nil ? "Add a total" : "Edit total")
                            .font(.dmSans(.subheadline, weight: .semibold))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.primary)

                    Button { acknowledge(period.range) } label: {
                        Text("Nothing spent")
                            .font(.dmSans(.subheadline, weight: .medium))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Marks the period as having no spending")
                }
            }
            .padding(AppSpacing.lg)
            .background(Color.leftNeutralFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.md)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear { markShown() }
        }
    }

    private func shouldShow(_ period: CatchUpPeriod) -> Bool {
        guard period.hasThreeQuietDays else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if promptShownVisitID == visitID && promptShownOn == today { return true }
        guard let lastShown = plan.catchUpPromptShownAt.map(calendar.startOfDay) else { return true }
        if let coveredThrough = period.coveredThrough, coveredThrough > lastShown { return true }
        return (calendar.dateComponents([.day], from: lastShown, to: today).day ?? 0) >= 3
    }

    private func markShown() {
        let today = Calendar.current.startOfDay(for: .now)
        guard promptShownVisitID != visitID || promptShownOn != today else { return }
        promptShownVisitID = visitID
        promptShownOn = today
        plan.catchUpPromptShownAt = today
        try? modelContext.save()
    }

    private func acknowledge(_ period: ClosedRange<Date>) {
        withAnimation(reduceMotion ? nil : .spring(duration: 0.3)) {
            plan.catchUpAcknowledgedThrough = max(plan.catchUpAcknowledgedThrough ?? .distantPast,
                                                  period.upperBound)
        }
        try? modelContext.save()
        HapticFeedback.lightImpact()
    }
}
