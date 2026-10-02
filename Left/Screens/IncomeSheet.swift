import SwiftUI
import SwiftData

struct IncomeChange {
    let sourceName: String
    let previousAmount: Decimal
    let amount: Decimal
    let isNew: Bool

    var delta: Decimal { amount - previousAmount }
}

// Deliberately a text field rather than AddSpendingView's numpad: that numpad
// is cents-first (650 → $6.50), which is right for a coffee and wrong for a
// paycheck. Two identical-looking keypads meaning different things is a trap.
struct IncomeSheet: View {
    let plan: MonthPlan
    let source: IncomeSource?
    var onSave: (IncomeChange) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var draftAmount: Decimal
    @State private var carriesAmountForward: Bool
    @State private var draftStartsOn: Date?
    @State private var draftEndsAfter: Date?
    @State private var isDurationExpanded = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool

    init(plan: MonthPlan,
         source: IncomeSource? = nil,
         onSave: @escaping (IncomeChange) -> Void = { _ in }) {
        self.plan = plan
        self.source = source
        self.onSave = onSave
        _draftName = State(initialValue: source?.name ?? "")
        _draftAmount = State(initialValue: source?.amount ?? 0)
        _carriesAmountForward = State(initialValue: source?.carriesAmountForward ?? true)
        _draftStartsOn = State(initialValue: source?.startsOn)
        _draftEndsAfter = State(initialValue: source?.endsAfter)
    }

    private var originalAmount: Decimal { source?.amount ?? 0 }
    private var previewIncome: Decimal {
        let originalContribution = source?.covers(month: plan.monthStart) == true ? originalAmount : 0
        let draftContribution = draftCoversPlanMonth ? max(0, draftAmount) : 0
        return plan.incomeTotal - originalContribution + draftContribution
    }

    private var draftCoversPlanMonth: Bool {
        (draftStartsOn.map { $0 <= plan.monthStart } ?? true)
            && (draftEndsAfter.map { plan.monthStart <= $0 } ?? true)
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && draftAmount >= 0
    }

    private var monthName: String {
        plan.monthStart.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        header
                        fields
                        if !plan.activeIncomeSources.contains(where: {
                            $0.persistentModelID != source?.persistentModelID && $0.needsMonthlyAmount
                        }) {
                            DerivationBar(plan: plan, income: previewIncome, showsDetails: false)
                        }
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)

                actions
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                    .background(Color.leftBackground)
            }
            .background(Color.leftBackground.ignoresSafeArea())
            .toolbar {
                if isNameFocused || isAmountFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isNameFocused = false
                            isAmountFocused = false
                        }
                            .font(.dmSans(.subheadline, weight: .medium))
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        PlanSheetHeader(
            title: "\(monthName) income",
            subtitle: "Take-home income you’re budgeting with in \(plan.monthStart.formatted(.dateTime.month(.wide).year())). Earlier months stay unchanged."
        )
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            PlanSheetRow("Name") {
                TextField("Source name", text: $draftName)
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    .accessibilityLabel("Income source name")
            }

            PlanSheetRow("Amount") {
                MoneyField(value: $draftAmount,
                           unit: .currency,
                           prominence: .inline,
                           alignment: .leading,
                           accessibilityLabel: "\(monthName) income from \(trimmedName.isEmpty ? "this source" : trimmedName)",
                           focus: $isAmountFocused)
            }

            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Toggle("Use this amount next month too", isOn: $carriesAmountForward)
                    .font(.dmSans(.body, weight: .medium))
                    .tint(.leftAccent)
                    .frame(minHeight: 44)

                Text(carriesAmountForward
                     ? "Repeats while this source is in your plan. You can update it anytime."
                     : "Enter a new amount each month. This source stays in your plan.")
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if source?.needsMonthlyAmount == true {
                    Text("Enter zero if you’re not budgeting any income from this source in \(monthName).")
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, AppSpacing.lg)

            MonthDurationPicker(startsOn: $draftStartsOn,
                                endsAfter: $draftEndsAfter,
                                isExpanded: $isDurationExpanded)
        }
    }

    private var actions: some View {
        PlanSheetActions(primaryTitle: "Update \(monthName)",
                         isEnabled: canSave,
                         save: save,
                         cancel: { dismiss() })
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
            source.startsOn = draftStartsOn
            source.endsAfter = draftEndsAfter
            source.cadence = carriesAmountForward ? .fixed : .variable
            source.amount = max(0, draftAmount)
            source.affirmedAt = .now
        } else {
            plan.incomeSources.append(
                IncomeSource(name: trimmedName,
                             amount: draftAmount,
                             cadence: carriesAmountForward ? .fixed : .variable,
                             affirmedAt: .now,
                             startsOn: draftStartsOn,
                             endsAfter: draftEndsAfter)
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
