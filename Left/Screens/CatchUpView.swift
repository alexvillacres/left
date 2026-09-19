import SwiftUI
import SwiftData

struct CatchUpView: View {
    let plan: MonthPlan
    let period: ClosedRange<Date>
    let transaction: Transaction?
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var digits = ""
    @ScaledMetric private var amountSize: CGFloat = 64

    init(plan: MonthPlan,
         period: ClosedRange<Date>,
         transaction: Transaction? = nil,
         onSave: @escaping () -> Void = {}) {
        self.plan = plan; self.period = period; self.transaction = transaction
        self.onSave = onSave
        if let transaction { _digits = State(initialValue: Self.digits(for: transaction.amount)) }
    }

    private var amount: Decimal { Decimal(UInt64(digits) ?? 0) / 100 }
    private var periodLabel: String {
        let start = period.lowerBound.formatted(.dateTime.month(.abbreviated).day())
        let end = period.upperBound.formatted(.dateTime.month(.abbreviated).day())
        return start == end ? start : "\(start)–\(end)"
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel") { dismiss() }
                Spacer(); Text("Catch up").font(.dmSans(.headline, weight: .semibold)); Spacer()
                Color.clear.frame(width: 52)
            }
            .padding(.horizontal, AppSpacing.xl).frame(minHeight: 52)
            VStack(spacing: AppSpacing.sm) {
                HeroMoneyText(amount: amount, size: amountSize)
                    .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                    .contentTransition(.numericText())
                Text("Additional spending not already logged")
                    .font(.dmSans(.subheadline)).foregroundStyle(.secondary)
                Text(periodLabel).font(.dmSans(.subheadline, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.top, AppSpacing.xxl).padding(.bottom, AppSpacing.xl)
            Spacer()
            NumpadView(onDigit: appendDigit, onBackspace: backspace).padding(.horizontal, AppSpacing.xl)
            Button(action: save) {
                Text(transaction == nil ? "Add total" : "Save")
                    .font(.dmSans(.headline, weight: .medium))
                    .foregroundStyle(amount > 0 ? Color(uiColor: .systemBackground) : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(amount > 0 ? Color.primary : Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain).disabled(amount == 0)
            .padding(.horizontal, AppSpacing.xl).padding(.top, AppSpacing.lg).padding(.bottom, AppSpacing.lg)
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
    }

    private func appendDigit(_ digit: Int) {
        guard !(digits.isEmpty && digit == 0), digits.count < 7 else { return }
        digits.append(String(digit))
    }
    private func backspace() { if !digits.isEmpty { digits.removeLast() } }

    private func save() {
        let start = Calendar.current.startOfDay(for: period.lowerBound)
        let end = Calendar.current.startOfDay(for: period.upperBound)
        if let transaction {
            transaction.amount = amount; transaction.date = end.addingTimeInterval(12 * 60 * 60)
            transaction.isCatchUp = true; transaction.catchUpStartDate = start; transaction.catchUpEndDate = end
        } else {
            let entry = Transaction(amount: amount, date: end.addingTimeInterval(12 * 60 * 60), category: .other,
                                    isCatchUp: true, catchUpStartDate: start, catchUpEndDate: end)
            modelContext.insert(entry); entry.plan = plan
        }
        plan.catchUpAcknowledgedThrough = max(plan.catchUpAcknowledgedThrough ?? .distantPast, end)
        try? modelContext.save()
        onSave()
        HapticFeedback.lightImpact(); dismiss()
    }

    private static func digits(for amount: Decimal) -> String {
        let cents = NSDecimalNumber(decimal: amount * 100).uint64Value
        return cents == 0 ? "" : String(cents)
    }
}
