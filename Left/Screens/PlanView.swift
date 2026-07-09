import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var plan: MonthPlan
    var isOnboarding: Bool = false

    @State private var isAddingExpense = false
    @State private var newExpenseName = ""
    @State private var newExpenseAmount: Decimal = 0

    var body: some View {
        Form {
            Section("Monthly income") {
                TextField("0", value: $plan.monthlyIncome, format: Decimal.FormatStyle())
                    .keyboardType(.decimalPad)
            }

            Section("Fixed expenses") {
                ForEach(plan.fixedExpenses) { expense in
                    @Bindable var expense = expense
                    HStack(spacing: AppSpacing.sm) {
                        TextField("Name", text: $expense.name)
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", value: $expense.amount, format: Decimal.FormatStyle())
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 80)
                    }
                }
                .onDelete { indexSet in
                    for expense in indexSet.map({ plan.fixedExpenses[$0] }) {
                        modelContext.delete(expense)
                    }
                }

                Button {
                    newExpenseName = ""
                    newExpenseAmount = 0
                    isAddingExpense = true
                } label: {
                    Text("Add expense")
                        .font(.figtree(.subheadline, weight: .semibold))
                        .foregroundStyle(Color.budgetPrimaryActionForeground)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(Color.budgetPrimaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            Section("Savings goal") {
                TextField("0", value: $plan.savingsGoal, format: Decimal.FormatStyle())
                    .keyboardType(.decimalPad)
            }

            Section {
                derivationLine
                    .font(.figtree(.subheadline))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.budgetBackground.ignoresSafeArea())
        .navigationTitle(isOnboarding ? "Get started" : "My Plan")
        .toolbar {
            if isOnboarding {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done")
                            .font(.figtree(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.budgetPrimaryActionForeground)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.budgetPrimaryAction)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(isPresented: $isAddingExpense) {
            addExpenseSheet
        }
    }

    private var addExpenseSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $newExpenseName)
                }
                Section {
                    HStack {
                        Text("$").foregroundStyle(.secondary)
                        TextField("0", value: $newExpenseAmount, format: Decimal.FormatStyle())
                            .keyboardType(.decimalPad)
                    }
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
                            .font(.figtree(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.budgetSecondaryActionForeground)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.budgetSecondaryActionBackground)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addExpense()
                    } label: {
                        Text("Add")
                            .font(.figtree(.subheadline, weight: .semibold))
                            .foregroundStyle(Color.budgetPrimaryActionForeground)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.budgetPrimaryAction)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(newExpenseName.isEmpty || newExpenseAmount <= 0)
                    .opacity(newExpenseName.isEmpty || newExpenseAmount <= 0 ? 0.35 : 1)
                }
            }
        }
        .presentationDetents([.height(240)])
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
        plan.fixedExpenses.append(FixedExpense(name: newExpenseName, amount: newExpenseAmount))
        isAddingExpense = false
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
    return NavigationStack {
        PlanView(plan: plan)
    }
    .modelContainer(container)
}
