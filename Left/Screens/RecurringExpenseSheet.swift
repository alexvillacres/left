import SwiftUI
import SwiftData

// One recurring expense, edited on a sheet that stays as short as its content.
//
// The expense is a card: name and amount on one line, then a button for how
// often it repeats and a button for how long it lasts. Each button opens its
// options inside the card, so the sheet grows only when there is something to
// choose. Only one panel is open at a time. The amount is one of those panels:
// tapping it opens the app's numpad in the card, with whole-dollar entry and a
// "." key, so typing 340 means $340 rather than the spending screen's $3.40.
//
// The daily allowance is deliberately absent. Rent is not optional because the
// daily number moved, and putting that number here invites reading a bill as a
// choice. The thin bar below the card is the plan context this screen owes the
// user: how much of the month's income is already spoken for.
struct RecurringExpenseSheet: View {
    let plan: MonthPlan
    let expense: FixedExpense?

    private enum Panel { case none, amount, repeats, duration }
    private enum MonthTarget { case start, end }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var draftName: String
    @State private var draftAmount: Decimal
    // Typed digits, kept apart from the value so "14." and "14.0" survive
    // while being entered.
    @State private var amountEntry: String
    @State private var draftCadence: ExpenseCadence
    @State private var draftStartsOn: Date?
    @State private var draftEndsAfter: Date?
    @State private var panel: Panel = .none
    @State private var monthTarget: MonthTarget = .end
    @State private var gridYear: Int
    @State private var contentHeight: CGFloat = 0
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool

    private let calendar = Calendar.current

    init(plan: MonthPlan, expense: FixedExpense? = nil) {
        self.plan = plan
        self.expense = expense
        _draftName = State(initialValue: expense?.name ?? "")
        _draftAmount = State(initialValue: expense?.amount ?? 0)
        _amountEntry = State(initialValue: expense.map { Self.entry(for: $0.amount) } ?? "")
        _draftCadence = State(initialValue: expense?.effectiveCadence ?? .monthly)
        _draftStartsOn = State(initialValue: expense?.startsOn)
        _draftEndsAfter = State(initialValue: expense?.endsAfter)
        let anchor = expense?.endsAfter ?? expense?.startsOn ?? plan.monthStart
        _gridYear = State(initialValue: Calendar.current.component(.year, from: anchor))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.lg) {
                        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                            Text(expense == nil ? "New recurring expense" : "Edit recurring expense")
                                .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                                .tracking(BudgetTypography.headingTracking)
                                .accessibilityAddTraits(.isHeader)

                            Spacer(minLength: 0)

                            if expense != nil { deleteButton }
                        }
                        .padding(.bottom, AppSpacing.sm)

                        card
                        planContext
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                        }
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)

                actions
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                    .background(Color.leftBackground)
            }
            .background(Color.leftBackground.ignoresSafeArea())
        }
        .onPreferenceChange(ContentHeightKey.self) { contentHeight = $0 }
        // The keyboard and the numpad never share the sheet.
        .onChange(of: isNameFocused) { _, focused in
            if focused && panel != .none {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { panel = .none }
            }
        }
        .presentationDetents(detents)
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.leftBackground)
    }

    // Accessibility sizes outgrow any fitted height, so they get a full sheet.
    private var detents: Set<PresentationDetent> {
        guard !dynamicTypeSize.isAccessibilitySize, contentHeight > 0 else { return [.large] }
        let actionsAndInset: CGFloat = 70
        return [.height(min(contentHeight + actionsAndInset, 720))]
    }

    // A corner button is easy to hit by accident, so it asks once. Past months
    // keep their own copy; only this plan and the months cloned after it lose it.
    private var deleteButton: some View {
        Button { isConfirmingDelete = true } label: {
            Image(systemName: "trash")
                .font(.system(.body, weight: .medium))
                .foregroundStyle(Color.leftFeedbackNegative)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete \(expense?.name ?? "expense")")
        .confirmationDialog("Delete \(expense?.name ?? "this expense")?",
                            isPresented: $isConfirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: delete)
        } message: {
            Text("It comes out of this month's plan and won't carry into next month. Earlier months keep it.")
        }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: 0) {
            nameAndAmount

            if panel == .amount {
                NumpadView(onDigit: appendDigit, onBackspace: deleteDigit, onDecimal: appendDecimal)
                    .padding(.bottom, AppSpacing.md)
                    .transition(.opacity)
            }

            Divider()
                .overlay(Color.leftDivider)

            (dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
                : AnyLayout(HStackLayout(spacing: AppSpacing.sm))) {
                chip(cadenceChipLabel, isOpen: panel == .repeats) { toggle(.repeats) }
                chip(durationChipLabel, isOpen: panel == .duration) { toggle(.duration) }
                Spacer(minLength: 0)
            }
            .padding(.vertical, AppSpacing.md)

            switch panel {
            case .repeats: repeatsPanel
            case .duration: durationPanel
            case .none, .amount: EmptyView()
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.bottom, panel == .none || panel == .amount ? AppSpacing.xxs : AppSpacing.md)
        .background(Color.leftSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.leftDivider, lineWidth: 0.5)
        }
    }

    private var nameAndAmount: some View {
        // Accessibility sizes can't fit both on one line, so the amount moves under the name.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AppSpacing.md))
        return layout {
            HStack(spacing: AppSpacing.md) {
                // Orange names the category once, as a mark rather than a fill.
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Color.leftPlanExpenses)
                    .frame(width: 4, height: 26)
                    .accessibilityHidden(true)

                TextField("Name this expense", text: $draftName)
                    .font(.dmSans(.title3, weight: .semibold))
                    .textInputAutocapitalization(.words)
                    .focused($isNameFocused)
                    // Return finishes the name; a keyboard toolbar floats awkwardly
                    // over a short sheet. With no amount yet, it goes on to the keypad.
                    .submitLabel(amountEntry.isEmpty ? .next : .done)
                    .onSubmit {
                        isNameFocused = false
                        if amountEntry.isEmpty { toggle(.amount) }
                    }
                    .accessibilityLabel("Recurring expense name")
            }

            amountButton
        }
        .padding(.vertical, AppSpacing.md)
    }

    private var amountButton: some View {
        let isOpen = panel == .amount
        return Button { toggle(.amount) } label: {
            Text(amountDisplay)
                .font(.dmSans(.title3, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(amountEntry.isEmpty ? Color.leftPlaceholder : Color.leftAccent)
                .contentTransition(.numericText())
                .lineLimit(1)
                .padding(.horizontal, AppSpacing.sm)
                .frame(minWidth: 72, minHeight: 44, alignment: .trailing)
                .background {
                    // The open amount reads as the field being typed into.
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isOpen ? Color.leftAccent : .clear, lineWidth: 1.5)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The name gives way to the amount, never the reverse.
        .fixedSize()
        .accessibilityLabel("Recurring expense amount")
        .accessibilityValue(amountEntry.isEmpty ? "Empty" : money(draftAmount))
        .accessibilityAddTraits(isOpen ? [.isSelected] : [])
        .accessibilityHint(isOpen ? "Closes the keypad" : "Opens the keypad")
    }

    private func chip(_ title: String, isOpen: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.xs) {
                Text(title)
                    .font(.dmSans(.subheadline, weight: .medium))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .rotationEffect(.degrees(isOpen ? 180 : 0))
            }
            .foregroundStyle(isOpen ? Color.leftTextOnAccent : Color.leftAccent)
            .padding(.horizontal, AppSpacing.md)
            .frame(minHeight: 44)
            .background(isOpen ? Color.leftAccent : Color.leftBackground, in: Capsule())
            .overlay {
                Capsule().strokeBorder(isOpen ? .clear : Color.leftDivider, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOpen ? [.isSelected] : [])
        .accessibilityHint(isOpen ? "Closes the options" : "Opens the options")
    }

    private func toggle(_ target: Panel) {
        isNameFocused = false
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            panel = panel == target ? .none : target
        }
    }

    // MARK: - Amount entry

    private var amountDisplay: String {
        guard !amountEntry.isEmpty else { return money(Decimal(0)) }
        // Once "." is typed, show both cent places so the entry reads as cents.
        guard amountEntry.contains(".") else { return money(draftAmount) }
        return draftAmount.formatted(.currency(code: "USD").precision(.fractionLength(2)))
    }

    private func appendDigit(_ digit: Int) {
        var next = amountEntry
        if let dot = next.firstIndex(of: ".") {
            guard next.distance(from: dot, to: next.endIndex) <= 2 else { return }
        } else {
            guard next.count < 7 else { return } // cap at $9,999,999
            if next == "0" { next = "" }
        }
        next.append(String(digit))
        setEntry(next)
    }

    private func appendDecimal() {
        guard !amountEntry.contains(".") else { return }
        setEntry((amountEntry.isEmpty ? "0" : amountEntry) + ".")
    }

    private func deleteDigit() {
        guard !amountEntry.isEmpty else { return }
        var next = amountEntry
        next.removeLast()
        setEntry(next == "0" ? "" : next)
    }

    private func setEntry(_ entry: String) {
        amountEntry = entry
        withAnimation(reduceMotion ? nil : .spring(duration: 0.2)) {
            draftAmount = Decimal(string: entry, locale: Locale(identifier: "en_US_POSIX")) ?? 0
        }
    }

    private static func entry(for amount: Decimal) -> String {
        guard amount > 0 else { return "" }
        let rounded = NSDecimalNumber(decimal: amount).rounding(
            accordingToBehavior: NSDecimalNumberHandler(
                roundingMode: .plain, scale: 2,
                raiseOnExactness: false, raiseOnOverflow: false,
                raiseOnUnderflow: false, raiseOnDivideByZero: false
            )
        )
        return rounded.description(withLocale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: - Repeats

    private var repeatsPanel: some View {
        VStack(spacing: 0) {
            ForEach(ExpenseCadence.allCases) { cadence in
                Button {
                    draftCadence = cadence
                    toggle(.repeats)
                } label: {
                    HStack(spacing: AppSpacing.md) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(cadence.label)
                                .font(.dmSans(.body, weight: draftCadence == cadence ? .semibold : .medium))
                                .foregroundStyle(Color.leftAccent)

                            Text(cadenceDetail(cadence))
                                .font(.dmSans(.caption))
                                .foregroundStyle(.secondary)
                        }
                        .multilineTextAlignment(.leading)

                        Spacer(minLength: AppSpacing.sm)

                        if draftCadence == cadence {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.leftAccent)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background {
                        if draftCadence == cadence {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.leftBackground)
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.leftDivider, lineWidth: 0.5)
                                }
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(draftCadence == cadence ? [.isSelected] : [])
            }
        }
    }

    // Spelling out the monthly share is the whole point of showing cadences:
    // a yearly bill still has to be divided before the plan can use it.
    private func cadenceDetail(_ cadence: ExpenseCadence) -> String {
        let amount = money(draftAmount)
        let monthly = money(draftAmount / cadence.divisorToMonthly)
        switch cadence {
        case .monthly:
            return "\(amount) every month"
        case .quarterly:
            return "\(amount) every 3 months · \(monthly)/mo in plan"
        case .annually:
            return "\(amount) once a year · \(monthly)/mo in plan"
        }
    }

    // MARK: - Duration

    private var durationPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SegmentedControl(options: [false, true], selection: endsAfterBinding) {
                $0 ? "Ends after" : "No end date"
            }
            .frame(minHeight: 44)

            if draftEndsAfter != nil || monthTarget == .start {
                yearStepper
                monthGrid
                durationSummary
            } else {
                Text("This expense stays in every month's plan until you give it an end.")
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.bottom, AppSpacing.xs)
    }

    private var endsAfterBinding: Binding<Bool> {
        Binding(
            get: { draftEndsAfter != nil },
            set: { endsAfter in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    if endsAfter {
                        monthTarget = .end
                        draftEndsAfter = calendar.date(byAdding: .month, value: 11, to: startMonth)
                            .map { calendar.leftMonthStart(for: $0) }
                        gridYear = calendar.component(.year, from: draftEndsAfter ?? startMonth)
                    } else {
                        monthTarget = .end
                        draftEndsAfter = nil
                    }
                }
            }
        )
    }

    private var yearStepper: some View {
        HStack {
            stepperButton("chevron.left", label: "Previous year", enabled: gridYear > minimumYear) {
                gridYear -= 1
            }

            Spacer()

            Text(String(gridYear))
                .font(.dmSans(.body, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .accessibilityLabel("Year \(String(gridYear))")

            Spacer()

            stepperButton("chevron.right", label: "Next year", enabled: gridYear < minimumYear + 30) {
                gridYear += 1
            }
        }
    }

    private func stepperButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.leftAccent)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.3)
        .accessibilityLabel(label)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 4),
                  spacing: AppSpacing.xs) {
            ForEach(gridMonths, id: \.self) { month in
                monthButton(month)
            }
        }
    }

    private func monthButton(_ month: Date) -> some View {
        let isSelected = month == (monthTarget == .start ? startMonth : draftEndsAfter)
        let isDisabled = isUnavailable(month)

        return Button {
            select(month)
        } label: {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.dmSans(.subheadline, weight: isSelected ? .semibold : .medium))
                .foregroundStyle(isSelected ? Color.leftTextOnAccent : isDisabled ? Color.leftPlaceholder : Color.leftAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color.leftAccent : isDisabled ? Color.leftNeutralFill : Color.leftBackground,
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if !isSelected && !isDisabled {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.leftDivider, lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var durationSummary: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
            Text(rangeSummary)
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    monthTarget = monthTarget == .start ? .end : .start
                    gridYear = calendar.component(.year, from: monthTarget == .start ? startMonth : (draftEndsAfter ?? startMonth))
                }
            } label: {
                Text(monthTarget == .start ? "Change end" : "Change start")
                    .font(.dmSans(.caption, weight: .semibold))
                    .foregroundStyle(Color.leftAccent)
                    .underline()
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Plan context

    @ViewBuilder
    private var planContext: some View {
        if plan.incomeTotal > 0 {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                GeometryReader { proxy in
                    HStack(spacing: 3) {
                        segment(width: proxy.size.width, share: previewFixedTotal - draftShare, color: Color.leftPlanExpenses.opacity(0.45))
                        segment(width: proxy.size.width, share: draftShare, color: Color.leftPlanExpenses)
                        segment(width: proxy.size.width, share: plan.savingsAmount, color: Color.leftPlanSavings.opacity(0.45))
                        segment(width: proxy.size.width, share: previewSpendable, color: Color.leftPlanSpendable.opacity(0.45))
                    }
                }
                .frame(height: 8)

                HStack {
                    Text("Recurring \(money(previewFixedTotal))")
                    Spacer(minLength: AppSpacing.sm)
                    Text("of \(money(plan.incomeTotal)) income")
                }
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Recurring expenses \(money(previewFixedTotal)) of \(money(plan.incomeTotal)) income")
        }
    }

    private func segment(width: CGFloat, share: Decimal, color: Color) -> some View {
        let fraction = (share / plan.incomeTotal as NSDecimalNumber).doubleValue
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(color)
            .frame(width: max(0, width * CGFloat(min(1, max(0, fraction)))))
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: AppSpacing.md) {
            Button { dismiss() } label: {
                Text("Cancel")
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(Color.leftAccent)
                    .frame(width: 100)
                    .frame(minHeight: 52)
                    .background(Color.leftNeutralFill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: save) {
                Text(expense == nil ? "Add expense" : "Save")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color.leftTextOnAccent)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.leftAccent, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.35)
        }
    }

    // MARK: - Values

    // Cents only when there are any: $340, but $113.33 a month — never $340.5.
    private func money(_ value: Decimal) -> String {
        let hasCents = value.roundedToCents() != value.rounded(scale: 0)
        return value.formatted(.currency(code: "USD").precision(.fractionLength(hasCents ? 2 : 0)))
    }

    private var cadenceChipLabel: String { draftCadence.label }

    private var durationChipLabel: String {
        guard let end = draftEndsAfter else { return "No end date" }
        return "Until \(monthYear(end))"
    }

    private var trimmedName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool { !trimmedName.isEmpty && draftAmount > 0 }

    private var startMonth: Date { draftStartsOn ?? plan.monthStart }
    private var minimumYear: Int { calendar.component(.year, from: startMonth) }

    private var gridMonths: [Date] {
        (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: gridYear, month: month, day: 1))
        }
    }

    // A window cannot end before it starts, and moving the start past the end
    // would silently drop the expense out of every month.
    private func isUnavailable(_ month: Date) -> Bool {
        switch monthTarget {
        case .end:
            return month < startMonth
        case .start:
            return draftEndsAfter.map { month > $0 } ?? false
        }
    }

    private func select(_ month: Date) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
            switch monthTarget {
            case .end:
                draftEndsAfter = month
            case .start:
                draftStartsOn = month
                monthTarget = .end
            }
        }
        HapticFeedback.lightImpact()
    }

    private var rangeSummary: String {
        let start = monthYear(startMonth)
        guard let end = draftEndsAfter else { return "From \(start) · no end date" }
        let months = (calendar.dateComponents([.month], from: startMonth, to: end).month ?? 0) + 1
        return "\(start) – \(monthYear(end)) · \(months) \(months == 1 ? "month" : "months")"
    }

    private func monthYear(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var draftCoversPlanMonth: Bool {
        (draftStartsOn.map { $0 <= plan.monthStart } ?? true)
            && (draftEndsAfter.map { plan.monthStart <= $0 } ?? true)
    }

    private var draftShare: Decimal {
        draftCoversPlanMonth ? draftAmount / draftCadence.divisorToMonthly : 0
    }

    private var previewFixedTotal: Decimal {
        let original = expense?.covers(month: plan.monthStart) == true ? expense?.monthlyAmount ?? 0 : 0
        return plan.fixedTotal - original + draftShare
    }

    private var previewSpendable: Decimal {
        max(0, plan.incomeTotal - previewFixedTotal - plan.savingsAmount)
    }

    private func delete() {
        guard let expense else { return }
        plan.fixedExpenses.removeAll { $0.persistentModelID == expense.persistentModelID }
        modelContext.delete(expense)
        HapticFeedback.lightImpact()
        dismiss()
    }

    private func save() {
        guard canSave else { return }
        if let expense {
            expense.name = trimmedName
            expense.amount = draftAmount
            expense.cadence = draftCadence
            expense.startsOn = draftStartsOn
            expense.endsAfter = draftEndsAfter
        } else {
            plan.fixedExpenses.append(
                FixedExpense(name: trimmedName,
                             amount: draftAmount,
                             cadence: draftCadence,
                             startsOn: draftStartsOn,
                             endsAfter: draftEndsAfter)
            )
        }
        HapticFeedback.lightImpact()
        dismiss()
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 8700, cadence: .fixed, affirmedAt: .now))
    plan.savingsGoals.append(SavingsGoal(name: "Savings", amount: 1000))
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.fixedExpenses.append(FixedExpense(name: "Utilities", amount: 200))
    return Color.leftBackground
        .sheet(isPresented: .constant(true)) {
            RecurringExpenseSheet(plan: plan, expense: nil)
        }
        .modelContainer(container)
}
