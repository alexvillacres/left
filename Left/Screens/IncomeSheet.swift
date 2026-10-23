import SwiftUI
import SwiftData

struct IncomeChange {
    let sourceName: String
    let previousAmount: Decimal
    let amount: Decimal
    let isNew: Bool

    var delta: Decimal { amount - previousAmount }
}

struct IncomeSheet: View {
    let plan: MonthPlan
    let source: IncomeSource?
    var onSave: (IncomeChange) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Query private var plans: [MonthPlan]
    @State private var draftName: String
    @State private var amountText: String
    @State private var carriesAmountForward: Bool
    @State private var contentHeight: CGFloat = 390
    @State private var showsDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init(plan: MonthPlan, source: IncomeSource? = nil,
         onSave: @escaping (IncomeChange) -> Void = { _ in }) {
        self.plan = plan
        self.source = source
        self.onSave = onSave
        _draftName = State(initialValue: source?.name ?? "")
        _amountText = State(initialValue: source.map {
            $0.needsMonthlyAmount ? "" : $0.amount.formatted(.number.precision(.fractionLength(0)))
        } ?? "")
        _carriesAmountForward = State(initialValue: source?.carriesAmountForward ?? true)
    }

    private var originalAmount: Decimal { source?.amount ?? 0 }
    private var draftAmount: Decimal { parsedAmount ?? 0 }
    private var parsedAmount: Decimal? {
        guard !amountText.isEmpty,
              let value = try? Decimal(amountText, format: .number),
              value >= 0 else { return nil }
        var original = value
        var rounded = Decimal()
        NSDecimalRound(&rounded, &original, 0, .plain)
        guard rounded == value else { return nil }
        return value
    }
    private var trimmedName: String { draftName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && parsedAmount != nil }
    private var monthName: String { plan.monthStart.formatted(.dateTime.month(.wide)) }
    private var previousAmount: Decimal? {
        guard let source, source.needsMonthlyAmount,
              let previousMonth = Calendar.current.date(byAdding: .month, value: -1, to: plan.monthStart),
              let previousPlan = plans.first(where: { Calendar.current.isDate($0.monthStart, equalTo: previousMonth, toGranularity: .month) }) else { return nil }
        // Monthly snapshots predate shared source IDs. Only suggest an unambiguous name match.
        let matches = previousPlan.incomeSources.filter { $0.name == source.name }
        return matches.count == 1 ? matches.first?.amount : nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("\(monthName) income source")
                    .font(.dmSans(.body, weight: .medium))
                    .padding(.vertical, 14)
                VStack(spacing: 24) {
                    MoneyField(value: .constant(draftAmount), prominence: .sheet,
                               accessibilityLabel: "\(monthName) income amount", focus: $isAmountFocused,
                               text: $amountText)
                    TextField("Add name", text: $draftName)
                        .font(.dmSans(.callout))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .accessibilityLabel("Income source name")
                        .onSubmit { isNameFocused = false }
                }
                .padding(.top, 24)
                .padding(.bottom, 32)

                if let previousAmount {
                    Button("Use last month’s \(previousAmount.formatted(.currency(code: "USD").precision(.fractionLength(0))))") {
                        amountText = previousAmount.formatted(.number.grouping(.never))
                    }
                    .font(.dmSans(.footnote))
                    .frame(minHeight: 44)
                    .padding(.bottom, 8)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 3) { repeatOption(true); repeatOption(false) }
                        VStack(spacing: 3) { repeatOption(true); repeatOption(false) }
                    }
                    .padding(3)
                    .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 10))
                    Text(carriesAmountForward
                         ? "Left will use this amount next month too."
                         : "Left will confirm this amount each month.")
                        .font(.dmSans(.footnote))
                        .foregroundStyle(Color.leftTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(spacing: 12) {
                    if source != nil {
                        Button { showsDeleteConfirmation = true } label: {
                            Image(systemName: "trash")
                                .frame(width: 52, height: 52)
                                .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .accessibilityLabel("Remove income source")
                    }
                    Button(action: save) {
                        Text("Save")
                            .font(.dmSans(.body, weight: .medium))
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .foregroundStyle(canSave ? Color.leftTextOnAccent : Color.leftDisabledForeground)
                            .background(canSave ? Color.leftAccent : Color.leftDisabledFill, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(OpaqueButtonStyle())
                    .disabled(!canSave)
                }
                .padding(.top, 16)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 24)
            .background(GeometryReader { geometry in
                Color.clear.preference(key: IncomeSheetHeight.self, value: geometry.size.height)
            })
        }
        .scrollBounceBehavior(.basedOnSize)
        .onChange(of: isAmountFocused) { _, focused in
            if !focused, let parsedAmount {
                amountText = parsedAmount.formatted(.number.precision(.fractionLength(0)))
            }
        }
        .onPreferenceChange(IncomeSheetHeight.self) { contentHeight = $0 }
        .background(Color.leftSurface.ignoresSafeArea())
        .tint(.leftAccent)
        .buttonStyle(.plain)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .task {
            if source == nil || source?.needsMonthlyAmount == true {
                isAmountFocused = true
            }
        }
        .alert("Remove “\(source?.name ?? "income source")”?", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive, action: removeSource)
        } message: {
            Text("This removes this income source from \(monthName) and future plans. Earlier months stay unchanged.")
        }
    }

    private func repeatOption(_ repeats: Bool) -> some View {
        Button { carriesAmountForward = repeats } label: {
            Text(repeats ? "Same next month" : "Ask each month")
                .font(.dmSans(.subheadline, weight: carriesAmountForward == repeats ? .medium : .regular))
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(carriesAmountForward == repeats ? Color.leftSurface : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityAddTraits(carriesAmountForward == repeats ? .isSelected : [])
    }

    private func removeSource() {
        guard let source else { return }
        // The current month seeds future clones. Already-created snapshots have
        // independent IDs, so do not guess at matches in other plans.
        plan.incomeSources.removeAll { $0.persistentModelID == source.persistentModelID }
        plan.monthlyIncome = 0
        modelContext.delete(source)
        HapticFeedback.lightImpact()
        dismiss()
    }

    private func save() {
        guard canSave else { return }

        // This normally happens in AppRoot's lazy migration. Keeping the sheet
        // robust prevents an add from hiding a legacy fallback in previews or
        // other direct presentations.
        if source == nil, plan.incomeSources.isEmpty, plan.monthlyIncome > 0 {
            plan.incomeSources.append(
                IncomeSource(name: "Income",
                             amount: plan.monthlyIncome,
                             cadence: plan.incomeCadence ?? .fixed,
                             affirmedAt: plan.incomeConfirmedAt)
            )
        }

        if let source {
            source.name = trimmedName
            source.cadence = carriesAmountForward ? .fixed : .variable
            source.amount = max(0, draftAmount)
            source.affirmedAt = .now
        } else {
            plan.incomeSources.append(
                IncomeSource(name: trimmedName,
                             amount: draftAmount,
                             cadence: carriesAmountForward ? .fixed : .variable,
                             affirmedAt: .now)
            )
        }

        HapticFeedback.lightImpact()
        onSave(IncomeChange(sourceName: trimmedName,
                            previousAmount: originalAmount,
                            amount: draftAmount,
                            isNew: source == nil))
        dismiss()
    }
}

private struct IncomeSheetHeight: PreferenceKey {
    static let defaultValue: CGFloat = 390
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, IncomeSource.self, SavingsGoal.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let plan = MonthPlan(monthStart: .now, monthlyIncome: 0, savingsGoal: 0)
    let source = IncomeSource(name: "Client X", amount: 1500, cadence: .variable)
    container.mainContext.insert(plan)
    plan.incomeSources.append(source)
    plan.savingsGoals.append(SavingsGoal(name: "Roth IRA", amount: 500))
    plan.savingsGoals.append(SavingsGoal(name: "Emergency fund", amount: 0, percent: 10))
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    return Color.leftBackground
        .sheet(isPresented: .constant(true)) {
            IncomeSheet(plan: plan, source: source)
        }
        .modelContainer(container)
}
