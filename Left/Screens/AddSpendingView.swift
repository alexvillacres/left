import SwiftUI
import SwiftData
import UIKit

// Presented full-screen rather than as a sheet. Amount entry uses the custom
// numpad; focusing the inline note temporarily trades it for the system keyboard.
struct AddSpendingView: View {
    let plan: MonthPlan
    @State private var date: Date
    private let dateRange: ClosedRange<Date>?
    private let transaction: Transaction?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // Cents-first entry: raw digit string, so typing 6 5 0 → $6.50.
    @State private var digits = ""
    // Nil until a chip is chosen; saves as the uncategorized `.other`.
    @State private var category: Category?
    @State private var note = ""
    @State private var fixedCanvasHeight: CGFloat?
    @FocusState private var isNoteFocused: Bool
    // Not a scaled metric: HeroMoneyText already scales relative to
    // .largeTitle, and scaling here as well compounds at large text sizes.
    private static let amountSize: CGFloat = 64
    private static let topBarHeight: CGFloat = 52

    init(plan: MonthPlan, date: Date = .now, transaction: Transaction? = nil,
         dateRange: ClosedRange<Date>? = nil) {
        self.plan = plan
        self.transaction = transaction
        _date = State(initialValue: transaction?.date ?? date)
        self.dateRange = dateRange

        if let transaction {
            _digits = State(initialValue: Self.digits(for: transaction.amount))
            _category = State(initialValue: Category.allCases.contains(transaction.category)
                              ? transaction.category : nil)
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
        GeometryReader { geometry in
            Color.clear
                .overlay(alignment: .top) {
                    // This is a fixed canvas. The system keyboard is allowed to
                    // cover its lower portion instead of changing the proposed
                    // height and shifting or removing spending-entry content.
                    // Navigation chrome sits on the same canvas, above the entry
                    // content rather than over it.
                    VStack(spacing: 0) {
                        topBar

                        // At large text sizes the entry content can be taller
                        // than the screen; it scrolls instead of running past
                        // the bottom edge. When it fits, it stays anchored to
                        // the bottom of the screen.
                        ScrollView {
                            entryContent
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: max(0, (fixedCanvasHeight ?? geometry.size.height) - Self.topBarHeight),
                                       alignment: .bottom)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                        .scrollDismissesKeyboard(.interactively)
                    }
                    .background(Color.leftEntryBackground)
                    .frame(
                        width: geometry.size.width,
                        height: fixedCanvasHeight ?? geometry.size.height,
                        alignment: .top
                    )
                }
                .onAppear {
                    fixedCanvasHeight = geometry.size.height
                }
                .onChange(of: geometry.size.height) { _, newHeight in
                    // Adopt real viewport changes such as rotation only while
                    // the keyboard is absent. Keyboard-driven reductions must
                    // never become the fixed canvas size.
                    guard !isNoteFocused else { return }
                    fixedCanvasHeight = newHeight
                }
            }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        // Paint the home-indicator area beyond the fixed content canvas.
        .background(Color.leftEntryBackground.ignoresSafeArea())
        // Always dark, so every control and dynamic palette token resolves
        // against the dark ground regardless of the system appearance.
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .onAppear {
            HapticFeedback.prepareLight()
        }
    }

    private var entryContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: AppSpacing.lg)

            // Amount, note, and category are one group — the things being
            // described. The keypad below is the instrument you describe
            // them with.
            VStack(spacing: AppSpacing.lg) {
                HeroMoneyText(amount: amount, size: Self.amountSize)
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
            .padding(.bottom, AppSpacing.lg)

            VStack(spacing: AppSpacing.md) {
                NumpadView(onDigit: appendDigit, onBackspace: backspace)
                primaryButton
                if isEditing {
                    deleteButton
                }
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.sm)
            .allowsHitTesting(!isNoteFocused)
            .accessibilityHidden(isNoteFocused)
        }
    }

    private var topBar: some View {
        HStack {
            FlatBackButton(accessibilityLabel: "Cancel")

            Spacer()

            if let dateRange {
                DatePicker("Spending date", selection: $date, in: dateRange, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
            } else if showsDateContext {
                Text(date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                    .font(.dmSansSupporting(weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .frame(height: Self.topBarHeight)
    }

    // MARK: - Note

    private var noteRow: some View {
        TextField("Add note", text: $note)
            .font(.dmSans(.body))
            .textFieldStyle(.plain)
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.sentences)
            .submitLabel(.done)
            .focused($isNoteFocused)
            .onSubmit { isNoteFocused = false }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
    }

    // MARK: - Category chips

    // No chip starts selected, so an unchosen category is visibly unchosen.
    // When editing, the chosen chip is scrolled into view so it is never
    // selected off-screen.
    private var categoryChips: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Category.allCases) { cat in
                        chip(cat)
                            .id(cat)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
            }
            .onAppear {
                if let category { proxy.scrollTo(category, anchor: .center) }
            }
        }
    }

    // Tapping the selected chip clears it back to uncategorized.
    private func chip(_ cat: Category) -> some View {
        let selected = cat == category
        return Button {
            category = selected ? nil : cat
        } label: {
            Label {
                Text(cat.label)
            } icon: {
                CategoryIcon(category: cat)
            }
                .font(.dmSans(.subheadline, weight: .medium))
                .foregroundStyle(selected ? Color.leftBackground : Color.primary)
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .frame(minHeight: 44)
                .background(selected ? Color.primary : Color(uiColor: .secondarySystemFill))
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "Double-tap to clear the category" : "")
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
                .foregroundStyle(isActive ? Color.leftBackground : Color.leftDisabledForeground)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 52)
                .background(isActive ? Color.primary : Color.leftDisabledFill)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(OpaqueButtonStyle())
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
        .foregroundStyle(Color.leftFeedbackNegative)
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
            // History edits stay inside the selected monthly plan. Clamp the
            // retained time to now when moving an older entry onto today.
            if dateRange != nil { transaction.date = min(date, .now) }
            transaction.category = category ?? .other
            transaction.note = trimmed.isEmpty ? nil : trimmed
        } else {
            let tx = Transaction(amount: amount,
                                 date: dateRange == nil ? date : min(date, .now),
                                 category: category ?? .other,
                                 note: trimmed.isEmpty ? nil : trimmed)
            modelContext.insert(tx)
            tx.plan = plan
        }
        HapticFeedback.lightImpact()
        dismiss()
    }

    private func deleteTransaction() {
        guard let transaction else { return }
        modelContext.delete(transaction)
        HapticFeedback.lightImpact()
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
        for: MonthPlan.self, IncomeSource.self, SavingsGoal.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let plan = MonthPlan(monthStart: .now, monthlyIncome: 6200, savingsGoal: 1000)
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 6200, cadence: .fixed, affirmedAt: .now))
    return Color.clear
        .fullScreenCover(isPresented: .constant(true)) {
            AddSpendingView(plan: plan)
        }
        .modelContainer(container)
}
