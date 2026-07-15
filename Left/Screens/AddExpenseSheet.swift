import SwiftUI
import SwiftData
import UIKit

struct AddExpenseSheet: View {
    let plan: MonthPlan
    private let date: Date
    private let transaction: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Cents-first entry: raw digit string, so typing 6 5 0 → $6.50.
    @State private var digits = ""
    @State private var category: Category = .other
    @State private var note = ""
    @ScaledMetric private var amountSize = 44

    init(plan: MonthPlan, date: Date = .now, transaction: Transaction? = nil) {
        self.plan = plan
        self.transaction = transaction
        self.date = transaction?.date ?? date

        if let transaction {
            _digits = State(initialValue: Self.digits(for: transaction.amount))
            _category = State(initialValue: transaction.category)
            _note = State(initialValue: transaction.note ?? "")
        }
    }

    private var amount: Decimal {
        Decimal(UInt64(digits) ?? 0) / 100
    }

    private var isEditing: Bool {
        transaction != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroMoneyText(amount: amount, size: amountSize)
                .padding(.horizontal, AppSpacing.xl)
                .foregroundStyle(digits.isEmpty ? Color.secondary : Color.budgetPrimaryAction)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: amount)
                .padding(.top, AppSpacing.xxl)

            if !Calendar.current.isDateInToday(date) {
                Text("Logging to \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                    .font(.figtree(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, AppSpacing.xs)
            }

            Spacer(minLength: AppSpacing.lg)

            categoryChips
                .padding(.bottom, AppSpacing.lg)

            TextField("Add note", text: $note)
                .font(.figtree(.subheadline))
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .padding(.bottom, AppSpacing.md)

            NumpadView(onDigit: appendDigit, onBackspace: backspace)
                .padding(.horizontal, AppSpacing.xl)

            primaryButton
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md)

            if isEditing {
                deleteButton
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.sm)
            }
        }
        .presentationDetents([.height(560)])
        .background(Color.budgetBackground)
    }

    // MARK: - Category chips

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(Category.allCases) { cat in
                    chip(cat)
                }
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }

    private func chip(_ cat: Category) -> some View {
        let selected = cat == category
        return Button {
            category = cat
        } label: {
            Label(cat.label, systemImage: cat.symbol)
                .font(.figtree(.subheadline, weight: .medium))
                .foregroundStyle(selected ? Color.budgetPrimaryActionForeground : Color.budgetSecondaryActionForeground)
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(selected ? Color.budgetPrimaryAction : Color.budgetSecondaryActionBackground)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private var primaryButton: some View {
        Button(action: save) {
            Text(isEditing ? "Save" : "Log it")
                .font(.figtree(.headline, weight: .medium))
                .foregroundStyle(Color.budgetPrimaryActionForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(Color.budgetPrimaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(amount == 0)
        .opacity(amount > 0 ? 1 : 0.35)
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: deleteTransaction) {
            Text("Delete expense")
                .font(.figtree(.subheadline, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.budgetNegative)
    }

    // MARK: - Entry

    private func appendDigit(_ n: Int) {
        guard !(digits.isEmpty && n == 0) else { return } // no leading zeros
        guard digits.count < 7 else { return }            // cap at $99,999.99
        digits.append(String(n))
    }

    private func backspace() {
        guard !digits.isEmpty else { return }
        digits.removeLast()
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        if let transaction {
            transaction.amount = amount
            transaction.category = category
            transaction.note = trimmed.isEmpty ? nil : trimmed
        } else {
            let tx = Transaction(amount: amount,
                                 date: date,
                                 category: category,
                                 note: trimmed.isEmpty ? nil : trimmed)
            modelContext.insert(tx)
            tx.plan = plan
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private func deleteTransaction() {
        guard let transaction else { return }
        modelContext.delete(transaction)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        dismiss()
    }

    private static func digits(for amount: Decimal) -> String {
        let cents = NSDecimalNumber(decimal: amount * 100).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain,
                scale: 0,
                raiseOnExactness: false,
                raiseOnOverflow: false,
                raiseOnUnderflow: false,
                raiseOnDivideByZero: false
            )
        ).uint64Value
        return cents == 0 ? "" : String(cents)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let plan = MonthPlan(monthStart: .now, monthlyIncome: 6200, savingsGoal: 1000)
    container.mainContext.insert(plan)
    return Color.clear
        .sheet(isPresented: .constant(true)) {
            AddExpenseSheet(plan: plan)
        }
        .modelContainer(container)
}
