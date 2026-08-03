import SwiftUI
import SwiftData
import UIKit

struct AddSpendingSheet: View {
    let plan: MonthPlan
    private let date: Date
    private let transaction: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Cents-first entry: raw digit string, so typing 6 5 0 → $6.50.
    @State private var digits = ""
    @State private var category: Category = .other
    @State private var note = ""
    @State private var isEditingNote = false
    @FocusState private var noteFocused: Bool
    @ScaledMetric private var amountSize = 56

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

    private var sheetDetent: PresentationDetent {
        .height(isEditingNote ? 224 : 532)
    }

    var body: some View {
        VStack(spacing: 0) {
            HeroMoneyText(amount: amount, size: amountSize)
                .padding(.horizontal, AppSpacing.xl)
                .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.2), value: amount)
                .padding(.top, AppSpacing.xxl)

            if !Calendar.current.isDateInToday(date) {
                Text("Logging to \(date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))")
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, AppSpacing.xs)
            }

            Spacer(minLength: AppSpacing.lg)

            ZStack {
                TextField("Add note", text: $note)
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .focused($noteFocused)
                    .submitLabel(.done)
                    .onSubmit { endNoteEditing() }
                    .opacity(isEditingNote ? 1 : 0)
                    .allowsHitTesting(isEditingNote)
                    .accessibilityHidden(!isEditingNote)

                if !isEditingNote {
                    Button(action: beginNoteEditing) {
                        Text(note.isEmpty ? "Add note" : note)
                            .foregroundStyle(note.isEmpty ? Color.secondary : Color.primary)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.dmSans(.title3))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.lg)

            // The bottom of the sheet is a single input slot: the system
            // keyboard replaces the numpad while the note is being edited.
            if !isEditingNote {
                categoryChips
                    .padding(.bottom, AppSpacing.lg)

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
        }
        .presentationDetents([sheetDetent])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(uiColor: .systemBackground))
        .onChange(of: noteFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                isEditingNote = false
            }
        }
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
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(selected ? Color(uiColor: .systemBackground) : Color.primary)
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(selected ? Color.black : Color(uiColor: .secondarySystemFill))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    // Disabled is its own treatment, not a faded copy of the enabled one: a muted
    // fill with full-strength label text, so "Log it" stays readable while the
    // amount is still $0.00.
    private var primaryButton: some View {
        let isActive = amount > 0
        return Button(action: save) {
            Text(isEditing ? "Save" : "Log it")
                .font(.dmSans(.headline, weight: .medium))
                .foregroundStyle(isActive ? Color(uiColor: .systemBackground) : Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(isActive ? Color.primary : Color(uiColor: .secondarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!isActive)
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .accessibilityHint(isActive ? "" : "Enter an amount first")
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: deleteTransaction) {
            Text("Delete")
                .font(.dmSans(.subheadline, weight: .medium))
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.leftNegative)
    }

    // MARK: - Entry

    private func beginNoteEditing() {
        isEditingNote = true
        noteFocused = true
    }

    private func endNoteEditing() {
        noteFocused = false
        isEditingNote = false
    }

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
            AddSpendingSheet(plan: plan)
        }
        .modelContainer(container)
}
