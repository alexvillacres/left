import SwiftUI
import SwiftData

struct PlanView: View {
    private struct ActiveIncomeSheet: Identifiable {
        let id = UUID()
        var source: IncomeSource?
    }

    private struct ActiveSavingsSheet: Identifiable {
        let id = UUID()
        var goal: SavingsGoal?
    }

    private struct ActiveExpenseSheet: Identifiable {
        let id = UUID()
        var expense: FixedExpense?
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var plan: MonthPlan
    var isOnboarding: Bool = false
    var onBack: (() -> Void)?
    var onComplete: (() -> Void)?
    var availablePlans: [MonthPlan] = []
    var onSelectMonth: ((Date) -> Void)?
    var opensIncome: Bool = false
    var onResetDemo: (() throws -> Void)?

    @State private var activeExpenseSheet: ActiveExpenseSheet?
    @State private var activeIncomeSheet: ActiveIncomeSheet?
    @State private var activeSavingsSheet: ActiveSavingsSheet?
    @State private var expenseBasis: ExpenseBasis = .monthly
    @State private var onboardingStep: OnboardingStep = .income
    @State private var isIncomePresented = false
    @State private var isSettingsPresented = false
    @State private var incomeUpdateNote: String?
    @FocusState private var isMoneyFieldFocused: Bool
    @ScaledMetric private var planTotalSize: CGFloat = 44

    private var monthName: String { plan.monthStart.formatted(.dateTime.month(.wide)) }
    private var canEditPlan: Bool {
        isOnboarding || Calendar.current.isDate(plan.monthStart, equalTo: .now, toGranularity: .month)
    }

    private var orderedPlans: [MonthPlan] {
        availablePlans.filter { $0.monthStart <= Calendar.current.leftMonthStart(for: .now) }
            .sorted { $0.monthStart < $1.monthStart }
    }

    var body: some View {
        Group {
            if isOnboarding {
                onboardingFlow
            } else {
                planEditor
            }
        }
        .background(Color.leftBackground.ignoresSafeArea())
        .toolbar {
            if isMoneyFieldFocused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isMoneyFieldFocused = false
                    }
                    .font(.dmSans(.subheadline, weight: .medium))
                }
            }
        }
        .sheet(item: $activeExpenseSheet) { sheet in
            RecurringExpenseSheet(plan: plan, expense: sheet.expense)
        }
        .sheet(item: $activeIncomeSheet) { sheet in
            IncomeSheet(plan: plan, source: sheet.source) { change in
                incomeUpdateNote = plan.needsIncomeSetup
                    ? "\(change.sourceName) updated for \(monthName)."
                    : "\(monthName) income updated to \(plan.incomeTotal.formatted(.currency(code: "USD")))."
            }
        }
        .sheet(item: $activeSavingsSheet) { sheet in
            SavingsGoalSheet(plan: plan, goal: sheet.goal)
        }
        .interactiveDismissDisabled(isOnboarding)
        .navigationDestination(isPresented: $isIncomePresented) {
            incomeEditor
        }
        .task {
            if opensIncome { isIncomePresented = true }
        }
    }

    private var planEditor: some View {
        VStack(spacing: 0) {
            planHeader

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    planDerivation

                    VStack(spacing: 0) {
                        Button {
                            isIncomePresented = true
                        } label: {
                            planSummaryRow(
                                title: "Income",
                                subtitle: incomeSummary,
                                amount: plan.incomeTotal,
                                indicatorColor: .leftNeutralFill,
                                subtractsFromPlan: false,
                                isPending: plan.needsIncomeSetup
                            )
                        }

                        NavigationLink {
                            fixedExpensesEditor
                        } label: {
                            planSummaryRow(
                                title: "Fixed expenses",
                                subtitle: itemCount(plan.fixedExpenses.count, singular: "expense"),
                                amount: plan.fixedTotal,
                                indicatorColor: .leftPlanExpenses,
                                subtractsFromPlan: true
                            )
                        }

                        NavigationLink {
                            savingsEditor
                        } label: {
                            planSummaryRow(
                                title: "Savings",
                                subtitle: savingsSummary,
                                amount: plan.savingsAmount,
                                indicatorColor: .leftPlanSavings,
                                subtractsFromPlan: true
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .screenSheet()
        }
        .navigationDestination(isPresented: $isSettingsPresented) {
            SettingsView(onResetDemo: onResetDemo)
                .toolbar(.visible, for: .navigationBar)
                .navigationBarTitleDisplayMode(.inline)
        }
        .navigationTitle("\(monthName) plan")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var planHeader: some View {
        ScreenGroundHeader(ground: .plan) {
            PeriodRow {
                PeriodPill(
                    label: plan.monthStart.formatted(.dateTime.month(.wide).year()),
                    isEnabled: orderedPlans.count > 1,
                    accessibilityLabel: "Plan month, \(plan.monthStart.formatted(.dateTime.month(.wide).year()))",
                    accessibilityHint: "Choose a previous month's plan"
                ) {
                    ForEach(orderedPlans.reversed()) { candidate in
                        Button {
                            selectMonth(candidate.monthStart)
                        } label: {
                            if candidate.monthStart == plan.monthStart {
                                Label(candidate.monthStart.formatted(.dateTime.month(.wide).year()),
                                      systemImage: "checkmark")
                            } else {
                                Text(candidate.monthStart, format: .dateTime.month(.wide).year())
                            }
                        }
                    }
                }
            } trailing: {
                PeriodStepper(previousLabel: "Previous plan",
                              nextLabel: "Next plan",
                              canGoPrevious: adjacentPlan(-1) != nil,
                              canGoNext: adjacentPlan(1) != nil,
                              onPrevious: { stepMonth(-1) },
                              onNext: { stepMonth(1) })
            }

            HStack(alignment: .top, spacing: AppSpacing.xs) {
                planTotal
                settingsLink
            }
            .padding(.top, AppSpacing.sm)
        }
    }

    // The tab bar names the screen, so Settings sits beside the headline.
    private var settingsLink: some View {
        Button {
            isSettingsPresented = true
        } label: {
            AppIcon(asset: "IconSettings", size: 22)
                .foregroundStyle(.secondary)
                .frame(width: ScreenHeaderMetrics.rowHeight,
                       height: ScreenHeaderMetrics.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
    }

    // The same slot Today and Activity fill with their headline number: what
    // this month's plan leaves to spend. The daily rate lives in the bar below.
    private var planTotal: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            // Whole dollars like every other plan amount: it is income minus
            // whole-dollar fixed expenses and savings. The daily rate below
            // keeps its cents because Today builds from it.
            HeroMoneyText(amount: plan.monthlySpendable, size: planTotalSize,
                          suffix: "to spend", showsCents: false)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .animation(reduceMotion ? nil : .spring(duration: 0.4), value: plan.monthlySpendable)

            if let planTotalCaption {
                Text(planTotalCaption)
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    // Shown only when the headline needs a caveat; a normal month has none.
    private var planTotalCaption: String? {
        guard canEditPlan else { return "Past plan · Read only" }
        guard !plan.needsIncomeSetup else { return "Add income to see your allowance" }
        return nil
    }

    private func stepMonth(_ delta: Int) {
        if let target = adjacentPlan(delta) { selectMonth(target.monthStart) }
    }

    private func adjacentPlan(_ delta: Int) -> MonthPlan? {
        guard let index = orderedPlans.firstIndex(where: { $0.monthStart == plan.monthStart }),
              orderedPlans.indices.contains(index + delta) else { return nil }
        return orderedPlans[index + delta]
    }

    private func selectMonth(_ month: Date) {
        guard month != plan.monthStart else { return }
        onSelectMonth?(month)
        HapticFeedback.lightImpact()
    }

    private func planSummaryRow(
        title: String,
        subtitle: String,
        amount: Decimal,
        indicatorColor: Color,
        subtractsFromPlan: Bool,
        isPending: Bool = false
    ) -> some View {
        HStack(spacing: AppSpacing.lg) {
            Capsule()
                .fill(indicatorColor)
                .frame(width: 8, height: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title)
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: AppSpacing.sm)

            Text(isPending ? "—" : summaryAmount(amount, subtractsFromPlan: subtractsFromPlan))
                .font(.dmSans(.body, weight: .medium))
                .foregroundStyle(.primary)
                .monospacedDigit()
                .contentTransition(.numericText())

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 64)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(isPending ? "Amount needed" : summaryAmount(amount, subtractsFromPlan: subtractsFromPlan))")
        .accessibilityHint("Opens \(monthName) \(title.lowercased())")
    }

    // MARK: - Editors

    private var incomeEditor: some View {
        editorScreen(title: "Income", total: plan.incomeTotal, isPending: plan.needsIncomeSetup) {
            VStack(alignment: .leading, spacing: 0) {
                if canEditPlan {
                    Text(plan.needsIncomeSetup
                         ? "Add \(monthName)’s amounts to see your daily allowance. You can enter zero for a source you’re not budgeting with this month."
                         : "Update the take-home income you’re budgeting with in \(monthName). Earlier months stay unchanged.")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, AppSpacing.md)
                }

                if let incomeUpdateNote {
                    Text(incomeUpdateNote)
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, AppSpacing.md)
                }

                if plan.incomeSources.isEmpty, plan.monthlyIncome > 0 {
                    historicalRow("Income", amount: plan.monthlyIncome, note: monthName)
                }

                ForEach(Array(sortedIncomeSources.enumerated()), id: \.element.persistentModelID) { index, source in
                    if canEditPlan {
                        incomeEditorRow(source)
                    } else {
                        historicalRow(source.name, amount: source.amount,
                                      note: source.needsMonthlyAmount ? "Amount not entered" : incomeNote(for: source))
                    }

                    if index < sortedIncomeSources.count - 1 {
                        Divider()
                            .padding(.horizontal, -AppSpacing.xl)
                    }
                }

                if !plan.incomeSources.isEmpty {
                    Divider()
                        .padding(.horizontal, -AppSpacing.xl)
                }

                if canEditPlan {
                    addRow("Add income source") {
                        activeIncomeSheet = ActiveIncomeSheet()
                    }
                }
            }
        }
    }

    private var fixedExpensesEditor: some View {
        editorScreen(title: "Fixed expenses", total: plan.fixedTotal) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SegmentedControl(
                    options: [ExpenseBasis.monthly, .daily],
                    selection: $expenseBasis,
                    label: \.label
                )

                VStack(spacing: 0) {
                    ForEach(Array(sortedFixedExpenses.enumerated()), id: \.element.persistentModelID) { index, expense in
                        if canEditPlan {
                            fixedExpenseEditorRow(expense)
                        } else {
                            historicalRow(expense.name, amount: expenseDisplayAmount(expense),
                                          note: expense.effectiveCadence.label)
                        }

                        if index < sortedFixedExpenses.count - 1 {
                            Divider()
                                .padding(.horizontal, -AppSpacing.xl)
                        }
                    }

                    if !plan.fixedExpenses.isEmpty {
                        Divider()
                            .padding(.horizontal, -AppSpacing.xl)
                    }

                    if canEditPlan {
                        addRow("Add expense") {
                            presentExpenseEditor()
                        }
                    }
                }
            }
        }
    }

    private var savingsEditor: some View {
        editorScreen(title: "Savings", total: plan.savingsAmount) {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(sortedSavingsGoals) { goal in
                    if canEditPlan {
                        savingsGoalCard(goal)
                    } else {
                        historicalRow(goal.name, amount: goal.resolvedAmount(income: plan.incomeTotal),
                                      note: goal.percent.map { "\($0.formatted(.number))% of income" } ?? "Monthly amount")
                    }
                }

                if plan.savingsGoals.isEmpty, plan.savingsAmount > 0 {
                    historicalRow("Savings", amount: plan.savingsAmount,
                                  note: plan.savingsPercent.map { "\($0.formatted(.number))% of income" } ?? "Monthly amount")
                }

                if canEditPlan {
                    addRow("Add savings goal") {
                        activeSavingsSheet = ActiveSavingsSheet()
                    }
                }
            }
        }
    }

    private func editorScreen<Content: View>(
        title: String,
        total: Decimal,
        isPending: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    FlatBackButton(accessibilityLabel: "Back")
                    .accessibilityHint("Returns to Plan")

                    Text("\(plan.monthStart.formatted(.dateTime.month(.wide).year()))\(canEditPlan ? "" : " · Read only")")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)

                    ViewThatFits(in: .horizontal) {
                      HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                        Text(title == "Income" ? "\(monthName) income" : title)
                            .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                            .tracking(BudgetTypography.headingTracking)
                            .foregroundStyle(.primary)

                        Spacer(minLength: AppSpacing.sm)

                        Text(isPending ? "—" : total.formatted(wholeDollarFormat))
                            .font(.dmSans(.title2, weight: .semibold))
                            .foregroundStyle(.primary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                      }
                      VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text(title == "Income" ? "\(monthName) income" : title)
                            .font(.dmSans(.title2, weight: .bold))
                        Text(isPending ? "—" : total.formatted(wholeDollarFormat))
                            .font(.dmSans(.title2, weight: .semibold))
                            .monospacedDigit()
                      }
                    }

                    content()
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xs)
                .padding(.bottom, AppSpacing.xl)
            }

            planDerivationBarFooter
        }
        .background(Color.leftBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func historicalRow(_ title: String, amount: Decimal, note: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(title).font(.dmSans(.body, weight: .medium))
                Text(note).font(.dmSans(.caption)).foregroundStyle(.secondary)
            }
            Spacer(minLength: AppSpacing.sm)
            MoneyText(amount: amount).layoutPriority(1)
        }
        .padding(.vertical, AppSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Income

    private func incomeEditorRow(_ source: IncomeSource) -> some View {
        let startsLater = source.startsOn.map { $0 > plan.monthStart } ?? false

        return Button {
            activeIncomeSheet = ActiveIncomeSheet(source: source)
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(source.name)
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let windowNote = windowNote(startsOn: source.startsOn, endsAfter: source.endsAfter) {
                        Text(windowNote)
                            .font(.dmSans(.caption))
                            .foregroundStyle(.secondary)
                    }

                    Text(incomeNote(for: source))
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: AppSpacing.sm)

                Text(source.needsMonthlyAmount ? "Add amount" : source.amount.formatted(wholeDollarFormat))
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .opacity(startsLater ? 0.52 : 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            if canDeleteIncome {
                Button("Delete \(source.name)", systemImage: "trash", role: .destructive) {
                    deleteIncome(source)
                }
            }
        }
        .accessibilityAction(named: Text("Delete \(source.name)")) {
            if canDeleteIncome {
                deleteIncome(source)
            }
        }
        .accessibilityLabel("\(source.name), \(source.needsMonthlyAmount ? "Amount needed" : source.amount.formatted(wholeDollarFormat)), \(incomeNote(for: source))")
        .accessibilityHint("Update \(monthName) income")
    }

    private func incomeNote(for source: IncomeSource) -> String {
        if source.needsMonthlyAmount { return "Needs an amount for \(monthName)" }
        if let end = source.endsAfter, end <= plan.monthStart { return "Ends in \(monthName)" }
        return source.carriesAmountForward ? "Amount repeats next month" : "New amount each month"
    }

    // MARK: - Fixed expenses

    private func fixedExpenseEditorRow(_ expense: FixedExpense) -> some View {
        let startsLater = expense.startsOn.map { $0 > plan.monthStart } ?? false

        return Button {
            presentExpenseEditor(expense)
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    HStack(spacing: AppSpacing.sm) {
                        Text(expense.name)
                            .font(.dmSans(.body, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let cadenceLabel = expenseCadenceLabel(expense) {
                            Text(cadenceLabel)
                                .font(.dmSans(.footnote))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 10)
                                .padding(.vertical, AppSpacing.xxs)
                                .background(Color(uiColor: .secondarySystemFill))
                                .clipShape(Capsule())
                        }
                    }

                    if let note = windowNote(startsOn: expense.startsOn, endsAfter: expense.endsAfter) {
                        Text(note)
                            .font(.dmSans(.caption))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: AppSpacing.sm)

                Text(expenseDisplayAmount(expense), format: expenseDisplayFormat)
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            .opacity(startsLater ? 0.52 : 1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete \(expense.name)", systemImage: "trash", role: .destructive) {
                deleteExpense(expense)
            }
        }
        .accessibilityAction(named: Text("Delete \(expense.name)")) {
            deleteExpense(expense)
        }
        .accessibilityLabel("\(expense.name), \(expenseCadenceLabel(expense) ?? "Billed monthly"), \(expenseDisplayAmount(expense).formatted(expenseDisplayFormat)), \(expenseBasis.label)")
        .accessibilityHint("Opens fixed expense editor")
    }

    // MARK: - Savings

    private func savingsGoalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                activeSavingsSheet = ActiveSavingsSheet(goal: goal)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                    Text(goal.name)
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: AppSpacing.sm)

                    Text(savingsGoalValue(goal))
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .frame(maxWidth: .infinity, minHeight: 28)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(goal.name), \(savingsGoalValue(goal))")

            SegmentedControl(
                options: SavingsMode.allCases,
                selection: savingsModeBinding(for: goal),
                label: \.label
            )

            Text(savingsResolution(for: goal))
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(AppSpacing.md)
        .background(Color.leftSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            Button("Delete \(goal.name)", systemImage: "trash", role: .destructive) {
                deleteSavingsGoal(goal)
            }
        }
        .accessibilityAction(named: Text("Delete \(goal.name)")) {
            deleteSavingsGoal(goal)
        }
    }

    private func savingsModeBinding(for goal: SavingsGoal) -> Binding<SavingsMode> {
        Binding {
            goal.usesPercent ? .percent : .amount
        } set: { mode in
            guard mode != (goal.usesPercent ? .percent : .amount) else { return }
            let resolved = goal.resolvedAmount(income: plan.incomeTotal)

            switch mode {
            case .amount:
                goal.target = .amount(resolved)
            case .percent:
                let percent = plan.incomeTotal > 0
                    ? (resolved / plan.incomeTotal * 100).rounded(scale: 1)
                    : 0
                goal.target = .percentOfIncome(percent)
            }
        }
    }

    private func savingsGoalValue(_ goal: SavingsGoal) -> String {
        if let percent = goal.percent {
            return "\(percent.formatted(.number))%"
        }
        return goal.amount.formatted(wholeDollarFormat)
    }

    private func savingsResolution(for goal: SavingsGoal) -> String {
        if goal.usesPercent {
            return "≈ \(goal.resolvedAmount(income: plan.incomeTotal).formatted(wholeDollarFormat)) this month"
        }

        guard plan.incomeTotal > 0 else { return "0% of income" }
        let percent = goal.amount / plan.incomeTotal * 100
        return "≈ \(percent.formatted(.number.precision(.fractionLength(1))))% of \(plan.incomeTotal.formatted(wholeDollarFormat))"
    }

    private var onboardingSavingsModePicker: some View {
        SegmentedControl(
            options: SavingsMode.allCases,
            selection: savingsMode,
            label: \.label
        )
        .frame(maxWidth: 280, alignment: .leading)
    }

    @ViewBuilder
    private var onboardingSavingsResolution: some View {
        if onboardingUsesPercentSavings {
            Text("\(onboardingSavingsAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))) this month, and it moves with what you receive")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if plan.incomeTotal > 0, onboardingSavingsAmount > 0 {
            Text("About \(equivalentPercent(for: onboardingSavingsAmount).formatted(.number))% of this month's income")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var savingsMode: Binding<SavingsMode> {
        Binding {
            onboardingUsesPercentSavings ? .percent : .amount
        } set: { mode in
            let goal = materializeOnboardingSavingsGoal()
            switch mode {
            case .amount:
                goal.target = .amount(goal.resolvedAmount(income: plan.incomeTotal))
            case .percent:
                goal.target = .percentOfIncome(
                    equivalentPercent(for: goal.resolvedAmount(income: plan.incomeTotal))
                )
            }
        }
    }

    private var onboardingSavingsAmountBinding: Binding<Decimal> {
        Binding {
            plan.savingsGoals.first?.amount ?? plan.savingsGoal
        } set: { newValue in
            materializeOnboardingSavingsGoal().target = .amount(newValue)
        }
    }

    private var onboardingSavingsPercentBinding: Binding<Decimal> {
        Binding {
            plan.savingsGoals.first?.percent ?? plan.savingsPercent ?? 0
        } set: { newValue in
            materializeOnboardingSavingsGoal().target = .percentOfIncome(newValue)
        }
    }

    private var onboardingUsesPercentSavings: Bool {
        plan.savingsGoals.first?.usesPercent ?? plan.usesPercentSavings
    }

    private var onboardingSavingsAmount: Decimal {
        if let goal = plan.savingsGoals.first {
            return goal.resolvedAmount(income: plan.incomeTotal)
        }
        return plan.savingsAmount
    }

    private func equivalentPercent(for amount: Decimal, fallback: Decimal = 20) -> Decimal {
        guard plan.incomeTotal > 0, amount > 0 else { return fallback }
        let percent = (amount / plan.incomeTotal * 100).rounded(scale: 0)
        return min(max(percent, 0), SavingsGoal.maxPercent)
    }

    @discardableResult
    private func materializeOnboardingSavingsGoal() -> SavingsGoal {
        if let goal = plan.savingsGoals.first { return goal }
        let goal = SavingsGoal(name: "Savings",
                               amount: plan.savingsGoal,
                               percent: plan.savingsPercent)
        plan.savingsGoals.append(goal)
        return goal
    }

    // MARK: - Derivation

    private var planDerivationBarFooter: some View {
        planDerivation
            .padding(.horizontal, AppSpacing.xl)
            .padding(.vertical, AppSpacing.md)
            .background(Color.leftBackground)
            .overlay(alignment: .top) { Divider() }
    }

    private var planDerivation: some View {
        Group {
            if plan.needsIncomeSetup {
                Text(canEditPlan ? "Your daily allowance will appear once \(monthName)’s income is set." : "Income wasn’t completed for this month.")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                DerivationBar(plan: plan)
            }
        }
    }

    private var wholeDollarFormat: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(0))
    }

    private var dailyDollarFormat: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(2))
    }

    private var expenseDisplayFormat: Decimal.FormatStyle.Currency {
        expenseBasis == .daily ? dailyDollarFormat : wholeDollarFormat
    }

    private var incomeSummary: String {
        if plan.needsIncomeSetup {
            return canEditPlan ? "Add monthly amounts" : "Income not completed"
        }
        let count = plan.incomeSources.isEmpty && plan.monthlyIncome > 0 ? 1 : plan.incomeSources.count
        return itemCount(count, singular: "source")
    }

    private var savingsSummary: String {
        let count = plan.savingsGoals.isEmpty && plan.savingsAmount > 0 ? 1 : plan.savingsGoals.count
        let goals = itemCount(count, singular: "goal")
        guard plan.incomeTotal > 0, plan.savingsAmount > 0 else { return goals }
        let percent = plan.savingsAmount / plan.incomeTotal * 100
        return "\(goals) · \(percent.formatted(.number.precision(.fractionLength(0))))% of income"
    }

    private var sortedIncomeSources: [IncomeSource] {
        plan.incomeSources.sorted {
            if $0.amount != $1.amount { return $0.amount > $1.amount }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var sortedFixedExpenses: [FixedExpense] {
        plan.fixedExpenses.sorted {
            if $0.monthlyAmount != $1.monthlyAmount { return $0.monthlyAmount > $1.monthlyAmount }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var sortedSavingsGoals: [SavingsGoal] {
        plan.savingsGoals.sorted {
            let leftAmount = $0.resolvedAmount(income: plan.incomeTotal)
            let rightAmount = $1.resolvedAmount(income: plan.incomeTotal)
            if leftAmount != rightAmount { return leftAmount > rightAmount }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func itemCount(_ count: Int, singular: String) -> String {
        "\(count) \(count == 1 ? singular : singular + "s")"
    }

    private func summaryAmount(_ amount: Decimal, subtractsFromPlan: Bool) -> String {
        let formatted = amount.formatted(wholeDollarFormat)
        return subtractsFromPlan && amount != 0 ? "−\(formatted)" : formatted
    }

    private func expenseDisplayAmount(_ expense: FixedExpense) -> Decimal {
        switch expenseBasis {
        case .daily:
            expense.monthlyAmount / Decimal(plan.daysInMonth())
        case .monthly:
            expense.monthlyAmount
        case .annually:
            expense.monthlyAmount * 12
        }
    }

    private func addRow(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.dmSans(.body, weight: .medium))
                .foregroundStyle(Color.leftAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, AppSpacing.lg)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Onboarding

    private var onboardingFlow: some View {
        VStack(spacing: 0) {
            onboardingProgress
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xl)

            GeometryReader { proxy in
                ScrollView {
                    onboardingStepContent
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: proxy.size.height)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }

            onboardingNavigation
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.md)
                .padding(.bottom, AppSpacing.lg)
                .background(Color.leftBackground)
        }
        .accessibilityElement(children: .contain)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var onboardingProgress: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(OnboardingStep.allCases) { step in
                Capsule()
                    .fill(step.rawValue <= onboardingStep.rawValue
                          ? Color.leftAccent
                          : Color(uiColor: .tertiarySystemFill))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(onboardingStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
    }

    @ViewBuilder
    private var onboardingStepContent: some View {
        switch onboardingStep {
        case .income:
            onboardingIncomeStep
        case .expenses:
            onboardingExpensesStep
        case .savings:
            onboardingSavingsStep
        }
    }

    private var onboardingIncomeStep: some View {
        VStack(spacing: AppSpacing.xl) {
            onboardingHeader(
                eyebrow: "MONEY COMING IN",
                title: "\(monthName)’s income",
                description: "Enter the take-home income you’re budgeting with this month. Choose whether each amount repeats next month. You can update your plan anytime."
            )

            VStack(spacing: 0) {
                if plan.incomeSources.isEmpty {
                    Text("No income sources added")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    ForEach(Array(sortedIncomeSources.enumerated()), id: \.element.persistentModelID) { index, source in
                        onboardingIncomeRow(source)

                        if index < sortedIncomeSources.count - 1 {
                            Divider()
                                .padding(.horizontal, -AppSpacing.lg)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(Color.leftSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                activeIncomeSheet = ActiveIncomeSheet()
            } label: {
                Label("Add income source", systemImage: "plus")
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            if plan.incomeTotal > 0 {
                HStack {
                    Text("Total")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(plan.incomeTotal, format: .currency(code: "USD"))
                        .font(.dmSans(.title3, weight: .semibold))
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func onboardingIncomeRow(_ source: IncomeSource) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                activeIncomeSheet = ActiveIncomeSheet(source: source)
            } label: {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(source.name)
                            .font(.dmSans(.body, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(incomeNote(for: source))
                            .font(.dmSans(.caption))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(source.amount, format: .currency(code: "USD"))
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .layoutPriority(1)
                }
                .padding(.vertical, AppSpacing.lg)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(source.name), \(source.amount.formatted(.currency(code: "USD"))), \(incomeNote(for: source))")

            Button(role: .destructive) {
                deleteIncome(source)
            } label: {
                Image(systemName: "xmark")
                    .font(.dmSans(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!canDeleteIncome)
            .opacity(canDeleteIncome ? 1 : 0.35)
            .accessibilityLabel("Remove \(source.name)")
        }
    }

    private var onboardingExpensesStep: some View {
        VStack(spacing: AppSpacing.xl) {
            onboardingHeader(
                eyebrow: "RECURRING EXPENSES",
                title: "What stays the same?",
                description: "Add recurring costs like rent, utilities, or insurance. Skip anything that changes month to month."
            )

            VStack(spacing: 0) {
                if plan.fixedExpenses.isEmpty {
                    Text("No recurring expenses added")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    ForEach(Array(sortedFixedExpenses.enumerated()), id: \.element.persistentModelID) { index, expense in
                        onboardingExpenseRow(expense)

                        if index < sortedFixedExpenses.count - 1 {
                            Divider()
                                .padding(.horizontal, -AppSpacing.lg)
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(Color.leftSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                presentExpenseEditor()
            } label: {
                Label("Add recurring expense", systemImage: "plus")
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    private var onboardingSavingsStep: some View {
        VStack(spacing: AppSpacing.xxl) {
            onboardingHeader(
                eyebrow: "SAVINGS GOAL",
                title: "What do you want to set aside?",
                description: "Protect a flat amount, or a share of income so savings ease off in a lighter month. A goal of zero is completely fine."
            )

            VStack(spacing: AppSpacing.md) {
                onboardingSavingsModePicker

                if onboardingUsesPercentSavings {
                    onboardingPercentField(value: onboardingSavingsPercentBinding)
                } else {
                    onboardingMoneyField(
                        value: onboardingSavingsAmountBinding,
                        accessibilityLabel: "Monthly savings goal"
                    )
                }

                onboardingSavingsResolution
                    .multilineTextAlignment(.center)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: onboardingUsesPercentSavings)

            if plan.monthlySpendable > 0 {
                VStack(spacing: AppSpacing.xs) {
                    Text("That leaves")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)

                    Text("\(plan.dailyRate.formatted(.currency(code: "USD"))) per day")
                        .font(.dmSans(.title2, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(Color.leftPlanSpendableText)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("This plan leaves no money for daily spending. Lower your goal or go back and adjust your recurring expenses.")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(Color.leftFeedbackNegative)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                    .accessibilityLabel("Plan needs adjustment. This plan leaves no money for daily spending.")
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            materializeOnboardingSavingsGoal()
        }
    }

    private func onboardingHeader(
        eyebrow: String,
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: AppSpacing.md) {
            Text(eyebrow)
                .font(.dmSans(.caption2, weight: .medium))
                .foregroundStyle(Color.secondary)

            Text(title)
                .font(.dmSans(size: BudgetTypography.headingSize, weight: .bold, relativeTo: .title2))
                .tracking(BudgetTypography.headingTracking)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)

            Text(description)
                .font(.dmSans(.body))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func onboardingMoneyField(
        value: Binding<Decimal>,
        accessibilityLabel: String
    ) -> some View {
        MoneyField(value: value,
                   unit: .currency,
                   prominence: .prominent,
                   accessibilityLabel: accessibilityLabel,
                   focus: $isMoneyFieldFocused)
    }

    private func onboardingPercentField(value: Binding<Decimal>) -> some View {
        MoneyField(value: value,
                   unit: .percent,
                   prominence: .prominent,
                   accessibilityLabel: "Savings percent of income",
                   focus: $isMoneyFieldFocused)
    }

    private func onboardingExpenseRow(_ expense: FixedExpense) -> some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                Text(expense.name)
                    .font(.dmSans(.body, weight: .medium))
                    .lineLimit(1)

                Text(expense.effectiveCadence.label)
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(expense.monthlyAmount, format: .currency(code: "USD"))
                .font(.dmSans(.body, weight: .medium))
                .monospacedDigit()
                .layoutPriority(1)

            Button(role: .destructive) {
                deleteExpense(expense)
            } label: {
                Image(systemName: "xmark")
                    .font(.dmSans(.caption, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(expense.name)")
        }
        .padding(.vertical, AppSpacing.lg)
    }

    private var onboardingNavigation: some View {
        HStack(spacing: AppSpacing.md) {
            if onboardingStep != .income || onBack != nil {
                Button {
                    goBackInOnboarding()
                } label: {
                    Text("Back")
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(width: 92)
                        .frame(minHeight: 52)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Button(action: continueOnboarding) {
                Text(onboardingStep == .savings ? "See today's budget" : "Continue")
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(Color.leftBackground)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 52)
                    .background(Color.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(!canContinueOnboarding)
            .opacity(canContinueOnboarding ? 1 : 0.35)
        }
    }

    private var canContinueOnboarding: Bool {
        switch onboardingStep {
        case .income:
            plan.incomeTotal > 0
        case .expenses:
            true
        case .savings:
            plan.savingsAmount >= 0 && plan.monthlySpendable > 0
        }
    }

    private func continueOnboarding() {
        guard canContinueOnboarding else { return }
        isMoneyFieldFocused = false

        if onboardingStep == .savings {
            materializeOnboardingSavingsGoal()
            if let onComplete {
                onComplete()
            } else {
                dismiss()
            }
        } else {
            moveOnboarding(by: 1)
        }
    }

    private func goBackInOnboarding() {
        isMoneyFieldFocused = false

        if onboardingStep == .income {
            onBack?()
        } else {
            moveOnboarding(by: -1)
        }
    }

    private func moveOnboarding(by delta: Int) {
        isMoneyFieldFocused = false
        guard let next = OnboardingStep(rawValue: onboardingStep.rawValue + delta) else {
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            onboardingStep = next
        }
    }

    private func screenTitle(_ title: String) -> some View {
        ScreenTitleRow(title: title)
    }

    private func moneyField(value: Binding<Decimal>, accessibilityLabel: String = "Amount") -> some View {
        MoneyField(value: value,
                   unit: .currency,
                   prominence: .inline,
                   accessibilityLabel: accessibilityLabel,
                   focus: $isMoneyFieldFocused)
    }

    private func presentExpenseEditor(_ expense: FixedExpense? = nil) {
        activeExpenseSheet = ActiveExpenseSheet(expense: expense)
    }

    private func deleteExpense(_ expense: FixedExpense) {
        plan.fixedExpenses.removeAll { $0.persistentModelID == expense.persistentModelID }
        modelContext.delete(expense)
    }

    private func deleteIncome(_ source: IncomeSource) {
        plan.incomeSources.removeAll { $0.persistentModelID == source.persistentModelID }
        modelContext.delete(source)
    }

    private func deleteSavingsGoal(_ goal: SavingsGoal) {
        let isLastGoal = plan.savingsGoals.count == 1
        plan.savingsGoals.removeAll { $0.persistentModelID == goal.persistentModelID }
        modelContext.delete(goal)

        // Once legacy savings have been materialized, removing the final goal
        // means "save nothing". Clear the dormant fallback so it cannot return.
        if isLastGoal {
            plan.savingsTarget = .amount(0)
        }
    }

    // Deleting a newly-created plan's final source correctly leaves zero. A
    // lazily migrated current plan still has its dormant legacy fallback, so
    // keep one source until a replacement exists rather than resurrecting it.
    private var canDeleteIncome: Bool {
        plan.incomeSources.count > 1 || plan.monthlyIncome <= 0
    }

    private func expenseCadenceLabel(_ expense: FixedExpense) -> String? {
        guard expense.effectiveCadence != .monthly else { return nil }
        return "Billed \(expense.effectiveCadence.label.lowercased())"
    }

    private func windowNote(startsOn: Date?, endsAfter: Date?) -> String? {
        if let startsOn, startsOn > plan.monthStart {
            return "Starts \(startsOn.formatted(.dateTime.month(.abbreviated).year()))"
        }
        if let endsAfter, endsAfter > plan.monthStart {
            return "Through \(endsAfter.formatted(.dateTime.month(.abbreviated).year()))"
        }
        return nil
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case income
    case expenses
    case savings

    var id: Int { rawValue }
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
            .padding(.vertical, AppSpacing.sm)
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
        for: MonthPlan.self, IncomeSource.self, SavingsGoal.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(from: cal.dateComponents([.year, .month], from: .now))!)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 0, savingsGoal: 0)
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 4700, cadence: .fixed, affirmedAt: .now))
    plan.incomeSources.append(IncomeSource(name: "Client X", amount: 1500, cadence: .variable))
    plan.savingsGoals.append(SavingsGoal(name: "Roth IRA", amount: 500))
    plan.savingsGoals.append(SavingsGoal(name: "Emergency fund", amount: 0, percent: 20))
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.fixedExpenses.append(FixedExpense(name: "Utilities", amount: 200))
    plan.fixedExpenses.append(FixedExpense(name: "Insurance", amount: 900, cadence: .quarterly))
    return NavigationStack {
        PlanView(plan: plan)
    }
    .modelContainer(container)
}
