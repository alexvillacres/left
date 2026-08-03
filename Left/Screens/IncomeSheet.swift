import SwiftUI
import SwiftData
import UIKit

// Reached from the confirm row on Today, and from the Plan tab. Shows what the
// month inherited, what it works out to per day, and lets you correct it.
//
// Deliberately a text field rather than AddSpendingSheet's numpad: that numpad is
// cents-first (650 → $6.50), which is right for a coffee and wrong for a
// paycheck. Two identical-looking keypads meaning different things is a trap.
struct IncomeSheet: View {
    let plan: MonthPlan

    /// Reports whether the amount actually moved, so Today can explain a
    /// mid-month recalculation instead of letting the hero lurch unannounced.
    var onConfirm: (Bool) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: Decimal
    @FocusState private var isAmountFocused: Bool

    init(plan: MonthPlan, onConfirm: @escaping (Bool) -> Void) {
        self.plan = plan
        self.onConfirm = onConfirm
        _draft = State(initialValue: plan.monthlyIncome)
    }

    private var isChanged: Bool { draft != plan.monthlyIncome }

    private var money: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(0))
    }

    private var monthName: String {
        plan.monthStart.formatted(.dateTime.month(.wide))
    }

    private var inheritedFrom: String? {
        guard plan.incomeIsUnconfirmed,
              let previous = Calendar.current.date(byAdding: .month, value: -1, to: plan.monthStart)
        else { return nil }
        return previous.formatted(.dateTime.month(.wide))
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    header
                    amountField
                    DerivationLine(plan: plan, income: draft)
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
        .presentationDetents([.height(440), .large])
        .presentationDragIndicator(.visible)
        .toolbar {
            if isAmountFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { isAmountFocused = false }
                        .font(.dmSans(.subheadline, weight: .medium))
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            Text("Money available in \(monthName)")
                .font(.dmSans(size: 28, weight: .bold, relativeTo: .title))
                .foregroundStyle(.primary)

            if let inheritedFrom {
                Text("Using \(inheritedFrom)'s amount until you confirm")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
            }

            Text("Include invoices you expect to be paid in \(monthName), even if you completed the work earlier.")
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)
                .padding(.top, AppSpacing.xs)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var amountField: some View {
        MoneyField(value: $draft,
                   unit: .currency,
                   prominence: .prominent,
                   alignment: .leading,
                   accessibilityLabel: "Money available in \(monthName)",
                   focus: $isAmountFocused)
    }

    private var actions: some View {
        VStack(spacing: AppSpacing.xs) {
            Button(action: confirm) {
                Text(isChanged ? "Set \(draft.formatted(money))" : "Keep \(draft.formatted(money))")
                    .font(.dmSans(.body, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(draft <= 0)
            .opacity(draft <= 0 ? 0.35 : 1)
            .accessibilityLabel(isChanged
                                ? "Set money available in \(monthName) to \(draft.formatted(money))"
                                : "Keep money available in \(monthName) at \(draft.formatted(money))")

            Button("Decide later") { dismiss() }
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
    }

    private func confirm() {
        guard draft > 0 else { return }
        let changed = plan.confirmIncome(draft)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onConfirm(changed)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let plan = MonthPlan(monthStart: .now,
                         monthlyIncome: 6200,
                         savingsGoal: 1000,
                         incomeCadence: .variable)
    container.mainContext.insert(plan)
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    return Color(uiColor: .systemBackground)
        .sheet(isPresented: .constant(true)) {
            IncomeSheet(plan: plan) { _ in }
        }
        .modelContainer(container)
}
