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
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var showingDates = false
    // HeroMoneyText already scales relative to .largeTitle.
    private let amountSize: CGFloat = 64

    init(plan: MonthPlan,
         period: ClosedRange<Date>,
         transaction: Transaction? = nil,
         onSave: @escaping () -> Void = {}) {
        self.plan = plan; self.period = period; self.transaction = transaction
        self.onSave = onSave
        _startDate = State(initialValue: Calendar.current.startOfDay(for: period.lowerBound))
        _endDate = State(initialValue: Calendar.current.startOfDay(for: period.upperBound))
        if let transaction { _digits = State(initialValue: Self.digits(for: transaction.amount)) }
    }

    private var amount: Decimal { Decimal(UInt64(digits) ?? 0) / 100 }
    private var latestDate: Date {
        let calendar = Calendar.current
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: plan.monthStart)!
        let monthEnd = calendar.date(byAdding: .day, value: -1, to: nextMonth)!
        return max(plan.monthStart, min(calendar.startOfDay(for: .now), monthEnd))
    }
    private var periodLabel: String {
        let start = startDate.formatted(.dateTime.month(.abbreviated).day())
        let end = endDate.formatted(.dateTime.month(.abbreviated).day())
        return start == end ? start : "\(start)–\(end)"
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: AppSpacing.xl)
                        amountGroup
                        Spacer(minLength: AppSpacing.xl)
                        entryControls
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: max(0, geometry.size.height - 52), alignment: .bottom)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(Color.leftBackground.ignoresSafeArea())
        .sheet(isPresented: $showingDates) { datesSheet }
    }

    private var topBar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .frame(minHeight: 44)
            Spacer()
            Text("Catch up").font(.dmSans(.headline, weight: .semibold))
            Spacer()
            Color.clear.frame(width: 52)
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(height: 52)
    }

    private var amountGroup: some View {
        VStack(spacing: AppSpacing.md) {
            HeroMoneyText(amount: amount, size: amountSize)
                .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                .contentTransition(.numericText())
                .padding(.horizontal, AppSpacing.xl)
            Text("Additional spending not already logged")
                .font(.dmSans(.subheadline)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Button { showingDates = true } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "calendar")
                    Text(periodLabel).monospacedDigit()
                    Image(systemName: "chevron.down")
                        .font(.dmSans(.caption, weight: .semibold))
                }
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(.primary)
                .frame(minHeight: 44)
                .padding(.horizontal, AppSpacing.md)
                .background(Color(uiColor: .secondarySystemFill), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Catch-up dates, \(periodLabel)")
            .accessibilityHint("Choose the first and last day covered by this total")
        }
        .frame(maxWidth: .infinity)
    }

    private var entryControls: some View {
        VStack(spacing: AppSpacing.md) {
            NumpadView(onDigit: appendDigit, onBackspace: backspace)
            Button(action: save) {
                Text(transaction == nil ? "Add total" : "Save")
                    .font(.dmSans(.headline, weight: .medium))
                    .foregroundStyle(amount > 0 ? Color.leftBackground : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(amount > 0 ? Color.primary : Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain).disabled(amount == 0)
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.sm)
    }

    private var datesSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text("Catch-up dates")
                    .font(.dmSans(.headline, weight: .semibold))
                Spacer()
                Button("Done") { showingDates = false }
                    .font(.dmSans(.body, weight: .semibold))
                    .frame(minHeight: 44)
            }

            Text("Choose the days this additional spending covers.")
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)

            DatePicker("From", selection: $startDate, in: plan.monthStart...latestDate,
                       displayedComponents: .date)
                .onChange(of: startDate) { _, newDate in
                    if endDate < newDate { endDate = newDate }
                }
            DatePicker("Through", selection: $endDate, in: startDate...latestDate,
                       displayedComponents: .date)
            Spacer(minLength: 0)
        }
        .font(.dmSans(.body))
        .padding(AppSpacing.xl)
        .background(Color.leftBackground.ignoresSafeArea())
        .presentationDetents([.medium])
    }

    private func appendDigit(_ digit: Int) {
        guard !(digits.isEmpty && digit == 0), digits.count < 7 else { return }
        digits.append(String(digit))
    }
    private func backspace() { if !digits.isEmpty { digits.removeLast() } }

    private func save() {
        let start = Calendar.current.startOfDay(for: startDate)
        let end = Calendar.current.startOfDay(for: endDate)
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
