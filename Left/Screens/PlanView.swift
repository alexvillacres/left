import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: MonthPlan
    var isOnboarding: Bool = false

    @State private var isAddingExpense = false
    @State private var newExpenseName = ""
    @State private var newExpenseAmount: Decimal = 0
    @State private var newExpenseCadence: ExpenseCadence = .monthly
    @State private var expenseBasis: ExpenseBasis = .daily
    @FocusState private var isMoneyFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.xl) {
                screenTitle(isOnboarding ? "Get started" : "My Plan")

                planSection("Monthly income") {
                    moneyField(value: $plan.monthlyIncome)
                }

                planSection("Fixed expenses") {
                    fixedExpensesCard
                }

                planSection("Savings goal") {
                    moneyField(value: $plan.savingsGoal)
                }

                derivationLine
                    .font(.figtree(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .background(Color.budgetBackground.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            if isOnboarding {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.figtree(.subheadline, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .overlay {
                                Capsule()
                                    .stroke(Color.budgetDivider, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            if isMoneyFieldFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isMoneyFieldFocused = false
                    }
                    .font(.figtree(.subheadline, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $isAddingExpense) {
            addExpenseSheet
        }
    }

    private var fixedExpensesCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Picker("Expense basis", selection: $expenseBasis) {
                ForEach(ExpenseBasis.allCases) { basis in
                    Text(basis.label).tag(basis)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280, alignment: .leading)

            VStack(spacing: 0) {
                ForEach(Array(plan.fixedExpenses.enumerated()), id: \.element.id) { index, expense in
                    @Bindable var expense = expense
                    expenseRow(
                        expense: expense,
                        name: $expense.name,
                        amount: $expense.amount
                    )

                    if index < plan.fixedExpenses.count - 1 {
                        Divider()
                            .padding(.leading, AppSpacing.md)
                    }
                }

                if !plan.fixedExpenses.isEmpty {
                    Divider()
                        .padding(.leading, AppSpacing.md)
                }

                Button {
                    newExpenseName = ""
                    newExpenseAmount = 0
                    newExpenseCadence = .monthly
                    isAddingExpense = true
                } label: {
                    Label("Add expense", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.figtree(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(AppSpacing.md)
                }
                .buttonStyle(.plain)
            }
            .background(Color.budgetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.budgetDivider, lineWidth: 1)
            }
        }
    }

    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newExpenseName)
                        .multilineTextAlignment(.leading)
                        .neutralControl()
                        .listRowInsets(planInsets)
                        .listRowBackground(Color.clear)
                }
                Section {
                    moneyField(value: $newExpenseAmount)
                    Picker("Cadence", selection: $newExpenseCadence) {
                        ForEach(ExpenseCadence.allCases) { cadence in
                            Text(cadence.label).tag(cadence)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(planInsets)
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.budgetBackground.ignoresSafeArea())
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isAddingExpense = false
                    } label: {
                        Text("Cancel")
                            .font(.figtree(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .overlay {
                                Capsule()
                                    .stroke(Color.budgetDivider, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addExpense()
                    } label: {
                        Text("Add")
                            .font(.figtree(.subheadline, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .overlay {
                                Capsule()
                                    .stroke(Color.budgetDivider, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(newExpenseName.isEmpty || newExpenseAmount <= 0)
                    .opacity(newExpenseName.isEmpty || newExpenseAmount <= 0 ? 0.35 : 1)
                }
                if isMoneyFieldFocused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isMoneyFieldFocused = false
                        }
                        .font(.figtree(.subheadline, weight: .medium))
                    }
                }
            }
        }
        .presentationDetents([.height(320)])
    }

    private var planInsets: EdgeInsets {
        EdgeInsets(top: AppSpacing.xs, leading: AppSpacing.xl, bottom: AppSpacing.xs, trailing: AppSpacing.xl)
    }

    private func screenTitle(_ title: String) -> some View {
        Text(title)
            .font(.figtree(size: 44, weight: .semibold, relativeTo: .largeTitle))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, AppSpacing.xxl)
    }

    private func planSection<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            sectionHeader(title)
            content()
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.figtree(.caption2, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textCase(nil)
    }

    private func moneyField(value: Binding<Decimal>) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text("$")
                .foregroundStyle(.secondary)
            TextField("0", value: value, format: Decimal.FormatStyle())
                .keyboardType(.decimalPad)
                .focused($isMoneyFieldFocused)
                .multilineTextAlignment(.leading)
                .monospacedDigit()
                .frame(maxWidth: 180)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .neutralControl()
    }

    private func expenseRow(
        expense: FixedExpense,
        name: Binding<String>,
        amount: Binding<Decimal>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            TextField("Name", text: name)
                .font(.figtree(.body, weight: .medium))
                .multilineTextAlignment(.leading)

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text(expenseAmount(expense, for: expenseBasis), format: .currency(code: "USD"))
                    .font(.figtree(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                Text(expenseBasis.suffix)
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: AppSpacing.xs) {
                Text("Bill")
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)

                HStack(spacing: AppSpacing.xxs) {
                    Text("$")
                        .font(.figtree(.caption))
                        .foregroundStyle(.secondary)
                    TextField("0", value: amount, format: Decimal.FormatStyle())
                        .font(.figtree(.caption))
                        .foregroundStyle(.secondary)
                        .keyboardType(.decimalPad)
                        .focused($isMoneyFieldFocused)
                        .multilineTextAlignment(.leading)
                        .monospacedDigit()
                        .frame(width: 64)
                }

                Text(expense.effectiveCadence.label.lowercased())
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func expenseAmount(_ expense: FixedExpense, for basis: ExpenseBasis) -> Decimal {
        switch basis {
        case .daily:
            expense.monthlyAmount / Decimal(plan.daysInMonth())
        case .monthly:
            expense.monthlyAmount
        case .annually:
            expense.monthlyAmount * 12
        }
    }

    // Renders as: $6,200 − $2,840 − $1,000 = $1,360 ÷ 31 days = $43/day
    // with the daily rate bolded
    private var derivationLine: Text {
        let fmt = Decimal.FormatStyle.Currency(code: "USD")
        return Text("""
        \(Text(plan.monthlyIncome, format: fmt).foregroundColor(.secondary))\
         \(Text("−").foregroundColor(.secondary)) \
        \(Text(plan.fixedTotal, format: fmt).foregroundColor(.secondary))\
         \(Text("−").foregroundColor(.secondary)) \
        \(Text(plan.savingsGoal, format: fmt).foregroundColor(.secondary))\
         \(Text("=").foregroundColor(.secondary)) \
        \(Text(plan.monthlySpendable, format: fmt).foregroundColor(.secondary))\
         \(Text("÷ \(plan.daysInMonth()) days =").foregroundColor(.secondary)) \
        \(Text(plan.dailyRate, format: fmt).font(.figtree(.subheadline, weight: .semibold)))\(Text("/day").font(.figtree(.subheadline, weight: .semibold)))
        """)
    }

    private func addExpense() {
        guard !newExpenseName.isEmpty, newExpenseAmount > 0 else { return }
        plan.fixedExpenses.append(FixedExpense(name: newExpenseName, amount: newExpenseAmount, cadence: newExpenseCadence))
        isAddingExpense = false
    }
}

private enum ExpenseBasis: String, CaseIterable, Identifiable {
    case daily, monthly, annually

    var id: String { rawValue }

    var label: String {
        switch self {
        case .daily: "Daily"
        case .monthly: "Monthly"
        case .annually: "Annual"
        }
    }

    var suffix: String {
        switch self {
        case .daily: "/ day"
        case .monthly: "/ month"
        case .annually: "/ year"
        }
    }
}

private struct NeutralControlModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(Color.budgetSurface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.budgetDivider, lineWidth: 1)
            }
    }
}

private extension View {
    func neutralControl() -> some View {
        modifier(NeutralControlModifier())
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(from: cal.dateComponents([.year, .month], from: .now))!)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 6200, savingsGoal: 1000)
    container.mainContext.insert(plan)
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.fixedExpenses.append(FixedExpense(name: "Utilities", amount: 200))
    plan.fixedExpenses.append(FixedExpense(name: "Insurance", amount: 900, cadence: .quarterly))
    return NavigationStack {
        PlanView(plan: plan)
    }
    .modelContainer(container)
}
