import SwiftUI
import SwiftData

enum SavingsMode: String, CaseIterable, Identifiable {
    case amount, percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amount: "Amount"
        case .percent: "% of income"
        }
    }
}

struct SavingsGoalSheet: View {
    let plan: MonthPlan
    let goal: SavingsGoal?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var draftName: String
    @State private var draftAmount: Decimal
    @State private var draftPercent: Decimal
    @State private var mode: SavingsMode
    @FocusState private var isNameFocused: Bool
    @FocusState private var isValueFocused: Bool

    init(plan: MonthPlan, goal: SavingsGoal? = nil) {
        self.plan = plan
        self.goal = goal
        _draftName = State(initialValue: goal?.name ?? "")
        _draftAmount = State(initialValue: goal?.amount ?? 0)
        _draftPercent = State(initialValue: goal?.percent ?? 20)
        _mode = State(initialValue: goal?.usesPercent == true ? .percent : .amount)
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resolvedAmount: Decimal {
        switch mode {
        case .amount:
            max(0, draftAmount)
        case .percent:
            (plan.incomeTotal * cappedPercent / 100).roundedToCents()
        }
    }

    private var cappedPercent: Decimal {
        min(max(0, draftPercent), SavingsGoal.maxPercent)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && (mode == .amount ? draftAmount > 0 : cappedPercent > 0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        header
                        fields
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
                if isNameFocused || isValueFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isNameFocused = false
                            isValueFocused = false
                        }
                        .font(.dmSans(.subheadline, weight: .medium))
                    }
                }
            }
        }
        .presentationDetents([.height(500), .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        PlanSheetHeader(
            title: goal == nil ? "Add savings goal" : "Edit savings goal",
            subtitle: "A label for money you plan to set aside this month"
        )
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            TextField("Goal name", text: $draftName)
                .font(.dmSans(.body, weight: .medium))
                .textInputAutocapitalization(.words)
                .focused($isNameFocused)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 52)
                .background(Color.leftSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Savings goal name")

            SegmentedControl(
                options: SavingsMode.allCases,
                selection: modeBinding,
                label: \.label
            )

            MoneyField(value: valueBinding,
                       unit: mode == .percent ? .percent : .currency,
                       prominence: .prominent,
                       alignment: .leading,
                       accessibilityLabel: mode == .percent
                           ? "Percent of income for this savings goal"
                           : "Monthly savings goal amount",
                       focus: $isValueFocused)

            resolution
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: mode)
    }

    @ViewBuilder
    private var resolution: some View {
        if mode == .percent {
            Text("\(resolvedAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))) this month, and it moves with what you receive")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if plan.incomeTotal > 0, draftAmount > 0 {
            Text("About \(equivalentPercent(for: draftAmount).formatted(.number))% of this month's income")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: save) {
                Text(goal == nil ? "Add goal" : "Save")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color.leftBackground)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.35)

            Button("Cancel") { dismiss() }
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
    }

    private var modeBinding: Binding<SavingsMode> {
        Binding {
            mode
        } set: { newMode in
            guard newMode != mode else { return }
            if newMode == .amount {
                draftAmount = resolvedAmount
            } else {
                draftPercent = equivalentPercent(for: draftAmount)
            }
            mode = newMode
        }
    }

    private var valueBinding: Binding<Decimal> {
        Binding {
            mode == .percent ? draftPercent : draftAmount
        } set: { value in
            if mode == .percent {
                draftPercent = min(max(0, value), SavingsGoal.maxPercent)
            } else {
                draftAmount = max(0, value)
            }
        }
    }

    private func equivalentPercent(for amount: Decimal, fallback: Decimal = 20) -> Decimal {
        guard plan.incomeTotal > 0, amount > 0 else { return fallback }
        let percent = (amount / plan.incomeTotal * 100).rounded(scale: 0)
        return min(max(percent, 0), SavingsGoal.maxPercent)
    }

    private func save() {
        guard canSave else { return }

        let target: SavingsTarget = mode == .percent
            ? .percentOfIncome(cappedPercent)
            : .amount(draftAmount)

        if let goal {
            goal.name = trimmedName
            goal.target = target
        } else {
            let newGoal = SavingsGoal(name: trimmedName,
                                      amount: draftAmount,
                                      percent: mode == .percent ? cappedPercent : nil)
            plan.savingsGoals.append(newGoal)
        }

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
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 6200, affirmedAt: .now))
    let goal = SavingsGoal(name: "Roth IRA", amount: 500)
    plan.savingsGoals.append(goal)
    return Color.leftBackground
        .sheet(isPresented: .constant(true)) {
            SavingsGoalSheet(plan: plan, goal: goal)
        }
        .modelContainer(container)
}
