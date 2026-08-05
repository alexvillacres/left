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
    @State private var draftCadence: IncomeCadence
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
        _draftCadence = State(initialValue: source?.effectiveCadence ?? .fixed)
    }

    private var originalAmount: Decimal { source?.amount ?? 0 }
    private var previewIncome: Decimal {
        plan.incomeTotal - originalAmount + max(0, draftAmount)
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && draftAmount > 0
    }

    private var monthName: String {
        plan.monthStart.formatted(.dateTime.month(.wide))
    }

    private var inheritedFrom: String? {
        guard source?.isUnconfirmed == true,
              let previous = Calendar.current.date(byAdding: .month, value: -1, to: plan.monthStart)
        else { return nil }
        return previous.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        header
                        fields
                        DerivationLine(plan: plan, income: previewIncome)
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                }
                .scrollDismissesKeyboard(.interactively)

                actions
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                    .background(Color(uiColor: .systemBackground))
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
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
        .presentationDetents([.height(570), .large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text(source == nil ? "Add income" : "Edit income")
                .font(.dmSans(size: 28, weight: .bold, relativeTo: .title))
                .foregroundStyle(.primary)

            if let inheritedFrom, let source {
                Text("Using \(inheritedFrom)'s \(source.name) amount until you confirm")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            } else {
                Text("Money expected in \(monthName)")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            TextField("Source name", text: $draftName)
                .font(.dmSans(.body, weight: .medium))
                .textInputAutocapitalization(.words)
                .focused($isNameFocused)
                .padding(.horizontal, AppSpacing.md)
                .frame(minHeight: 52)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel("Income source name")

            MoneyField(value: $draftAmount,
                       unit: .currency,
                       prominence: .prominent,
                       alignment: .leading,
                       accessibilityLabel: "Amount expected from \(trimmedName.isEmpty ? "this source" : trimmedName)",
                       focus: $isAmountFocused)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Does this amount change?")
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)

                Picker("Income cadence", selection: $draftCadence) {
                    ForEach(IncomeCadence.allCases) { cadence in
                        Text(cadence.label).tag(cadence)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: save) {
                Text(source == nil ? "Add income" : "Save")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .systemBackground))
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
            source.cadence = draftCadence
            source.affirm(amount: draftAmount)
        } else {
            plan.incomeSources.append(
                IncomeSource(name: trimmedName,
                             amount: draftAmount,
                             cadence: draftCadence,
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
    return Color(uiColor: .systemBackground)
        .sheet(isPresented: .constant(true)) {
            IncomeSheet(plan: plan, source: source)
        }
        .modelContainer(container)
}
