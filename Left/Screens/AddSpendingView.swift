import SwiftUI
import SwiftData
import UIKit

// Presented full-screen rather than as a sheet. The numpad drives amount entry
// without the system keyboard, so the only keyboard in this flow belongs to the
// note — and the note now lives on its own pushed screen, where a keyboard is
// unremarkable. Nothing here resizes, so there are no detent heights to compute
// or keep in sync with focus.
struct AddSpendingView: View {
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

    private var showsDateContext: Bool {
        !Calendar.current.isDateInToday(date)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Amount, note, and category are one group — the things being
                // described. The keypad below is the instrument you describe
                // them with, so it sits apart, anchored to the thumb.
                VStack(spacing: AppSpacing.lg) {
                    HeroMoneyText(amount: amount, size: amountSize)
                        .foregroundStyle(digits.isEmpty ? Color.secondary : Color.primary)
                        .contentTransition(.numericText())
                        .animation(.spring(duration: 0.2), value: amount)
                        .padding(.horizontal, AppSpacing.xl)

                    noteRow
                        .padding(.horizontal, AppSpacing.xl)

                    // Owns its own horizontal padding so chips scroll edge to
                    // edge instead of clipping inside an inset container.
                    categoryChips
                }
                .padding(.top, AppSpacing.xl)

                Spacer(minLength: AppSpacing.lg)

                VStack(spacing: AppSpacing.md) {
                    NumpadView(onDigit: appendDigit, onBackspace: backspace)
                    primaryButton
                    if isEditing {
                        deleteButton
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.bottom, AppSpacing.sm)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(uiColor: .systemBackground))
            .toolbar {
                // Full-screen presentation has no drag-to-dismiss, so an
                // explicit close control is required, not decorative.
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.dmSans(.subheadline, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Cancel")
                }

                if showsDateContext {
                    ToolbarItem(placement: .principal) {
                        Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.dmSans(.caption, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .navigationDestination(isPresented: $isEditingNote) {
                NoteEditor(note: $note)
            }
        }
    }

    // MARK: - Note

    private var noteRow: some View {
        Button {
            isEditingNote = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Text(note.isEmpty ? "Add note" : note)
                    .font(.dmSans(.body))
                    .foregroundStyle(note.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.dmSans(.caption2, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(note.isEmpty ? "Add note" : "Note, \(note)")
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
                .background(selected ? Color.primary : Color(uiColor: .secondarySystemFill))
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

// MARK: - Note editor

// A pushed screen rather than an inline field: at full height the keyboard has
// somewhere to go, so nothing has to shrink to accommodate it.
private struct NoteEditor: View {
    @Binding var note: String
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            TextField("Add note", text: $note, axis: .vertical)
                .font(.dmSans(.title3))
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit { dismiss() }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xl)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
                    .font(.dmSans(.body, weight: .medium))
            }
        }
        .onAppear { focused = true }
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
        .fullScreenCover(isPresented: .constant(true)) {
            AddSpendingView(plan: plan)
        }
        .modelContainer(container)
}
