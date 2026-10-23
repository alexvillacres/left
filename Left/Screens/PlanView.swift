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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
    @State private var onboardingStep: OnboardingStep = .income
    @State private var isIncomePresented = false
    @State private var isSettingsPresented = false
    @State private var incomeUpdateNote: String?
    @FocusState private var isMoneyFieldFocused: Bool
    private let planTotalSize: CGFloat = 44
    private let detailTotalSize: CGFloat = 36

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
                    if !plan.needsIncomeSetup {
                        DerivationBar(plan: plan, showsDetails: false, isMeterOnly: true)
                    }

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
                                title: "Recurring expenses",
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

                    if !plan.needsIncomeSetup {
                        spendableRow
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xl)
            }
            .screenContent()
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
        ScreenHeader {
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

    private var spendableRow: some View {
        let isPositive = plan.monthlySpendable > 0
        let amount = plan.monthlySpendable.formatted(wholeDollarFormat)
        let daily = plan.dailyRate.formatted(.currency(code: "USD"))

        return HStack(spacing: AppSpacing.lg) {
            Capsule()
                .fill(isPositive ? Color.leftPlanSpendable : Color.leftFeedbackNegative)
                .frame(width: 8, height: 42)
                .accessibilityHidden(true)

            spendableLayout {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Spendable")
                        .font(.dmSans(.body, weight: .medium))
                        .foregroundStyle(.primary)

                    Text("\(daily)/day")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: AppSpacing.sm)
                }

                Text(amount)
                    .font(.dmSans(.body, weight: .semibold))
                    .foregroundStyle(isPositive ? Color.leftPlanSpendableText : Color.leftFeedbackNegative)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, AppSpacing.md)
        .padding(.horizontal, AppSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(isPositive ? Color.leftPlanSpendableSurface : Color.leftFeedbackNegativeBg)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spendable, \(amount), \(daily) per day")
    }

    private var spendableLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: AppSpacing.sm))
            : AnyLayout(HStackLayout(spacing: AppSpacing.lg))
    }

    private func planSummaryRow(
        title: String,
        subtitle: String,
        amount: Decimal,
        indicatorColor: Color,
        subtractsFromPlan: Bool,
        isPending: Bool = false
    ) -> some View {
        ListRow(title: title, subtitle: subtitle, accessory: .chevron) {
            Capsule()
                .fill(indicatorColor)
                .frame(width: 8, height: 42)
                .padding(.trailing, AppSpacing.xxs)
                .accessibilityHidden(true)
        } trailing: {
            RowAmount(text: isPending ? "—" : summaryAmount(amount, subtractsFromPlan: subtractsFromPlan))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(subtitle), \(isPending ? "Amount needed" : summaryAmount(amount, subtractsFromPlan: subtractsFromPlan))")
        .accessibilityHint("Opens \(monthName) \(title.lowercased())")
    }

    // MARK: - Editors

    private var incomeEditor: some View {
        editorScreen(label: "income", total: plan.incomeTotal, note: incomeFooter) {
            if plan.incomeSources.isEmpty, plan.monthlyIncome > 0 {
                historicalRow("Income", amount: plan.monthlyIncome, note: monthName)
            }

            ForEach(sortedIncomeSources, id: \.persistentModelID) { source in
                if canEditPlan {
                    incomeEditorRow(source)
                } else {
                    historicalRow(source.name, amount: source.amount,
                                  note: source.needsMonthlyAmount ? "Amount not entered" : incomeNote(for: source))
                }
            }

            if canEditPlan {
                ListAddRow("Add income") {
                    activeIncomeSheet = ActiveIncomeSheet()
                }
            }
        }
    }

    private var incomeFooter: String? {
        guard canEditPlan else { return nil }
        let pending = plan.incomeSources.filter(\.needsMonthlyAmount)
        guard let first = pending.first else {
            return "Sources that repeat carry their amount into next month. Others start blank so you can confirm what you earned."
        }
        let who = pending.count == 1 ? first.name : "your other sources"
        return "Add what \(who) brought in this month to see what you can spend."
    }

    private var fixedExpensesEditor: some View {
        editorScreen(label: "expenses", total: plan.fixedTotal, note: nil) {
            ForEach(fixedExpenseGroups, id: \.cadence) { group in
                VStack(alignment: .leading, spacing: 0) {
                    expenseGroupHeader(group.cadence, expenses: group.expenses)

                    ForEach(group.expenses, id: \.persistentModelID) { expense in
                        if canEditPlan {
                            fixedExpenseEditorRow(expense)
                        } else {
                            ListRow(title: expense.name, titleDetail: billedAmount(expense),
                                    subtitle: windowNote(startsOn: expense.startsOn, endsAfter: expense.endsAfter)) {
                                RowAmount(expense.monthlyAmount)
                            }
                        }
                    }
                }
                .padding(.bottom, AppSpacing.lg)
            }

            if canEditPlan {
                ListAddRow("Add expense") {
                    presentExpenseEditor()
                }
            }
        }
    }

    private var savingsEditor: some View {
        editorScreen(label: "savings", total: plan.savingsAmount,
                     note: "The monthly amount comes out of what you can spend. Savings you set aside are not spending.") {
            ForEach(sortedSavingsGoals) { goal in
                if canEditPlan {
                    savingsGoalRow(goal)
                } else {
                    historicalRow(goal.name, amount: goal.resolvedAmount(income: plan.incomeTotal),
                                  note: savingsSubtitle(for: goal))
                }
            }

            if plan.savingsGoals.isEmpty, plan.savingsAmount > 0 {
                historicalRow("Savings", amount: plan.savingsAmount,
                              note: plan.savingsPercent.map { "\($0.formatted(.number))% of income" } ?? "Monthly amount")
            }

            if canEditPlan {
                ListAddRow("Add savings goal") {
                    activeSavingsSheet = ActiveSavingsSheet()
                }
            }
        }
    }

    // Detail screens share the neutral header and content foundation.
    private func editorScreen<Content: View>(
        label: String,
        total: Decimal,
        note: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            ScreenHeader {
                PeriodRow {
                    PlanBackPill()
                } trailing: {
                    Text("\(plan.monthStart.formatted(.dateTime.month(.wide).year()))\(canEditPlan ? "" : " · Read only")")
                        .font(.dmSans(.callout, weight: .medium))
                        .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.periodSize))
                        .foregroundStyle(.primary)
                        .padding(.trailing, AppSpacing.md)
                }

                HeroMoneyText(amount: total, size: detailTotalSize, suffix: label, showsCents: false)
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .spring(duration: 0.4), value: total)
                    .padding(.top, AppSpacing.sm)
                    .accessibilityElement(children: .combine)
            }

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        content()
                    }
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.lg)
                }

                if let note {
                    Text(note)
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, AppSpacing.lg)
                }
            }
            .screenContent()
        }
        .background(Color.leftBackground.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    private func historicalRow(_ title: String, amount: Decimal, note: String) -> some View {
        ListRow(title: title, subtitle: note) {
            RowAmount(amount)
        }
    }

    // MARK: - Income

    private func incomeEditorRow(_ source: IncomeSource) -> some View {
        let startsLater = source.startsOn.map { $0 > plan.monthStart } ?? false
        let amount = source.amount.formatted(wholeDollarFormat)

        return Button {
            activeIncomeSheet = ActiveIncomeSheet(source: source)
        } label: {
            ListRow(title: source.name, subtitle: incomeSubtitle(for: source), accessory: .chevron) {
                if source.needsMonthlyAmount {
                    needsAmountChip
                } else {
                    RowAmount(source.amount)
                }
            }
            .opacity(startsLater ? 0.52 : 1)
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
        .accessibilityLabel("\(source.name), \(source.needsMonthlyAmount ? "Amount needed" : amount), \(incomeSubtitle(for: source))")
        .accessibilityHint("Update \(monthName) income")
    }

    private var needsAmountChip: some View {
        Text("Needs amount")
            .font(.dmSans(.subheadline, weight: .semibold))
            .foregroundStyle(Color.leftFeedbackWarningText)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 5)
            .background(Capsule().fill(Color.leftFeedbackWarningBg))
    }

    private func incomeNote(for source: IncomeSource) -> String {
        if let end = source.endsAfter, end <= plan.monthStart { return "Ends in \(monthName)" }
        return source.carriesAmountForward ? "Repeats monthly" : "Asks each month"
    }

    private func incomeSubtitle(for source: IncomeSource) -> String {
        [windowNote(startsOn: source.startsOn, endsAfter: source.endsAfter), incomeNote(for: source)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    // MARK: - Fixed expenses

    private func fixedExpenseEditorRow(_ expense: FixedExpense) -> some View {
        let startsLater = expense.startsOn.map { $0 > plan.monthStart } ?? false
        let subtitle = windowNote(startsOn: expense.startsOn, endsAfter: expense.endsAfter)
        let amount = expense.monthlyAmount.formatted(wholeDollarFormat)

        return Button {
            presentExpenseEditor(expense)
        } label: {
            ListRow(title: expense.name, titleDetail: billedAmount(expense), subtitle: subtitle,
                    accessory: .chevron) {
                RowAmount(expense.monthlyAmount)
            }
            .opacity(startsLater ? 0.52 : 1)
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
        .accessibilityLabel("\(expense.name), \(expenseBillingDescription(expense)), \(amount) a month")
        .accessibilityHint("Opens recurring expense editor")
    }

    // MARK: - Savings

    private func savingsGoalRow(_ goal: SavingsGoal) -> some View {
        let amount = goal.resolvedAmount(income: plan.incomeTotal).formatted(wholeDollarFormat)

        return Button {
            activeSavingsSheet = ActiveSavingsSheet(goal: goal)
        } label: {
            ListRow(title: goal.name, subtitle: savingsSubtitle(for: goal), accessory: .chevron) {
                RowAmount(goal.resolvedAmount(income: plan.incomeTotal))
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Delete \(goal.name)", systemImage: "trash", role: .destructive) {
                deleteSavingsGoal(goal)
            }
        }
        .accessibilityAction(named: Text("Delete \(goal.name)")) {
            deleteSavingsGoal(goal)
        }
        .accessibilityLabel("\(goal.name), \(amount), \(savingsSubtitle(for: goal))")
        .accessibilityHint("Edit savings goal")
    }

    private func savingsSubtitle(for goal: SavingsGoal) -> String {
        if let percent = goal.percent {
            return "\(percent.formatted(.number))% of income"
        }
        guard plan.incomeTotal > 0, goal.amount > 0 else { return "Monthly amount" }
        let percent = goal.amount / plan.incomeTotal * 100
        return "≈ \(percent.formatted(.number.precision(.fractionLength(0))))% of income"
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

    private var wholeDollarFormat: Decimal.FormatStyle.Currency {
        .init(code: "USD").precision(.fractionLength(0))
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
        HStack(spacing: 0) {
            Button {
                activeIncomeSheet = ActiveIncomeSheet(source: source)
            } label: {
                ListRow(title: source.name, subtitle: incomeNote(for: source)) {
                    RowAmount(source.amount)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(source.name), \(source.amount.formatted(wholeDollarFormat)), \(incomeNote(for: source))")

            ListRowRemoveButton(accessibilityLabel: "Remove \(source.name)") {
                deleteIncome(source)
            }
            .disabled(!canDeleteIncome)
            .opacity(canDeleteIncome ? 1 : 0.35)
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

    // No cadence sections here, so a non-monthly bill names its cadence.
    private func onboardingExpenseRow(_ expense: FixedExpense) -> some View {
        HStack(spacing: 0) {
            ListRow(title: expense.name,
                    titleDetail: billedAmount(expense).map { "\($0) \(expense.effectiveCadence.label.lowercased())" }) {
                RowAmount(expense.monthlyAmount)
            }
            .accessibilityLabel("\(expense.name), \(expenseBillingDescription(expense)), \(expense.monthlyAmount.formatted(wholeDollarFormat)) a month")

            ListRowRemoveButton(accessibilityLabel: "Remove \(expense.name)") {
                deleteExpense(expense)
            }
        }
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

    private func expenseBillingDescription(_ expense: FixedExpense) -> String {
        guard let billed = billedAmount(expense) else { return "Billed monthly" }
        return "\(billed) billed \(expense.effectiveCadence.label.lowercased())"
    }

    // The section names the cadence, so only non-monthly rows add their
    // actual bill beside the name; the trailing amount is the monthly share.
    private func billedAmount(_ expense: FixedExpense) -> String? {
        guard expense.effectiveCadence != .monthly else { return nil }
        return expense.amount.formatted(wholeDollarFormat)
    }

    private var fixedExpenseGroups: [(cadence: ExpenseCadence, expenses: [FixedExpense])] {
        let expenses = sortedFixedExpenses
        return ExpenseCadence.allCases.compactMap { cadence in
            let matching = expenses.filter { $0.effectiveCadence == cadence }
            return matching.isEmpty ? nil : (cadence, matching)
        }
    }

    private func expenseGroupHeader(_ cadence: ExpenseCadence, expenses: [FixedExpense]) -> some View {
        let title = cadence == .monthly ? cadence.label : "\(cadence.label), set aside monthly"
        let subtotal = expenses.reduce(Decimal.zero) { $0 + $1.monthlyAmount }.formatted(wholeDollarFormat)

        return ListSectionHeader(title: title, value: subtotal, reservesAccessory: canEditPlan)
            .accessibilityLabel("\(title), \(subtotal) a month")
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

/// Returns from a plan detail screen, on that screen's ground.
private struct PlanBackPill: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.periodPillFill) private var fill

    var body: some View {
        Button {
            dismiss()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "chevron.left")
                    .font(.system(size: ScreenHeaderMetrics.menuChevronSize + 2, weight: .semibold))
                    .foregroundStyle(.primary)

                Text("Plan")
                    .font(.dmSans(.callout, weight: .medium))
                    .tracking(BudgetTypography.tracking(for: ScreenHeaderMetrics.periodSize))
                    .foregroundStyle(.primary)
            }
            .padding(.leading, AppSpacing.md)
            .padding(.trailing, AppSpacing.lg)
            .padding(.vertical, 7)
            .background(Capsule().fill(fill))
            .frame(minHeight: ScreenHeaderMetrics.rowHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
        .accessibilityHint("Returns to Plan")
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
