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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var plan: MonthPlan
    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?

    @State private var isAddingExpense = false
    @State private var activeIncomeSheet: ActiveIncomeSheet?
    @State private var activeSavingsSheet: ActiveSavingsSheet?
    @State private var newExpenseName = ""
    @State private var newExpenseAmount: Decimal = 0
    @State private var newExpenseCadence: ExpenseCadence = .monthly
    @State private var expenseBasis: ExpenseBasis = .daily
    @State private var onboardingStep: OnboardingStep = .income
    @FocusState private var isMoneyFieldFocused: Bool

    var body: some View {
        Group {
            if isOnboarding {
                onboardingFlow
            } else {
                planEditor
            }
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
        .sheet(isPresented: $isAddingExpense) {
            recurringExpenseSheet
        }
        .sheet(item: $activeIncomeSheet) { sheet in
            IncomeSheet(plan: plan, source: sheet.source)
        }
        .sheet(item: $activeSavingsSheet) { sheet in
            SavingsGoalSheet(plan: plan, goal: sheet.goal)
        }
        .interactiveDismissDisabled(isOnboarding)
    }

    private var planEditor: some View {
        VStack(spacing: 0) {
            planScroll

            Divider()

            derivationLine
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.md)
                .background(Color(uiColor: .systemBackground))
        }
    }

    private var planScroll: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xl) {
                    screenTitle("My Plan")

                    planSection("Money available this month") {
                        incomeContent
                    }
                }
                .padding(.horizontal, AppSpacing.xl)

                Divider()

                planSection("Recurring expenses") {
                    fixedExpensesContent
                }
                .padding(.horizontal, AppSpacing.xl)

                Divider()

                planSection("Savings goals") {
                    savingsContent
                }
                .padding(.horizontal, AppSpacing.xl)
            }
            .padding(.top, AppSpacing.sm)
            .padding(.bottom, AppSpacing.xl)
        }
        .contentMargins(.horizontal, 0, for: .scrollContent)
    }

    // MARK: - Income

    private var incomeContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                ForEach(Array(plan.incomeSources.enumerated()), id: \.element.persistentModelID) { index, source in
                    incomeRow(source)

                    if index < plan.incomeSources.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack {
                Text("Total")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(plan.incomeTotal, format: .currency(code: "USD"))
                    .font(.dmSans(.title3, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }

            Button {
                activeIncomeSheet = ActiveIncomeSheet()
            } label: {
                Label("Add income source", systemImage: "plus")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func incomeRow(_ source: IncomeSource) -> some View {
        @Bindable var source = source

        return VStack(alignment: .leading, spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.sm) {
                TextField("Source name", text: $source.name)
                    .font(.dmSans(.body, weight: .medium))
                    .lineLimit(1)
                    .layoutPriority(1)

                MoneyField(value: incomeAmountBinding(source),
                           unit: .currency,
                           prominence: .compact,
                           accessibilityLabel: "\(source.name) income amount",
                           focus: $isMoneyFieldFocused)

                Button(role: .destructive) {
                    deleteIncome(source)
                } label: {
                    Image(systemName: "trash")
                        .font(.dmSans(.subheadline, weight: .medium))
                        .foregroundStyle(Color.leftNegative)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!canDeleteIncome)
                .opacity(canDeleteIncome ? 1 : 0.35)
                .accessibilityLabel("Remove \(source.name)")
                .accessibilityHint(!canDeleteIncome
                                   ? "Set its amount to zero, or add its replacement before removing it."
                                   : "")
            }

            Button {
                activeIncomeSheet = ActiveIncomeSheet(source: source)
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    if source.isUnconfirmed {
                        Text(carriedOverNote(for: source))
                    } else {
                        Text(source.effectiveCadence.label)
                    }
                    Image(systemName: "pencil")
                }
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(source.name), \(source.effectiveCadence.label)")
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private func incomeAmountBinding(_ source: IncomeSource) -> Binding<Decimal> {
        Binding {
            source.amount
        } set: { value in
            source.amount = max(0, value)
            source.affirmedAt = .now
        }
    }

    private func carriedOverNote(for source: IncomeSource) -> String {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: plan.monthStart) else {
            return "Not confirmed yet — tap to confirm"
        }
        let month = previous.formatted(.dateTime.month(.wide))
        return "Carried from \(month) — tap to confirm"
    }

    // MARK: - Savings

    private var savingsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if !plan.savingsGoals.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(plan.savingsGoals.enumerated()), id: \.element.persistentModelID) { index, goal in
                        savingsGoalRow(goal)

                        if index < plan.savingsGoals.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.md)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                activeSavingsSheet = ActiveSavingsSheet()
            } label: {
                Label("Add savings goal", systemImage: "plus")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(AppSpacing.md)
                    .background(Color(uiColor: .secondarySystemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Text("\(plan.savingsAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))) set aside this month.")
                .font(.dmSans(.subheadline))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
    }

    private func savingsGoalRow(_ goal: SavingsGoal) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Button {
                activeSavingsSheet = ActiveSavingsSheet(goal: goal)
            } label: {
                HStack(spacing: AppSpacing.md) {
                    VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                        Text(goal.name)
                            .font(.dmSans(.body, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let percent = goal.percent {
                            Text("\(percent.formatted(.number))% of income — moves with what you receive")
                                .font(.dmSans(.caption))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: AppSpacing.sm)

                    Text(goal.resolvedAmount(income: plan.incomeTotal),
                         format: .currency(code: "USD").precision(.fractionLength(0)))
                        .font(.dmSans(.body, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()
                        .layoutPriority(1)
                }
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(goal.name), \(goal.resolvedAmount(income: plan.incomeTotal).formatted(.currency(code: "USD"))) this month")

            Button(role: .destructive) {
                deleteSavingsGoal(goal)
            } label: {
                Image(systemName: "trash")
                    .font(.dmSans(.subheadline, weight: .medium))
                    .foregroundStyle(Color.leftNegative)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(goal.name)")
        }
        .padding(.vertical, AppSpacing.xs)
    }

    private var onboardingSavingsModePicker: some View {
        Picker("Savings basis", selection: savingsMode) {
            ForEach(SavingsMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
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

    private var derivationLine: some View {
        DerivationLine(plan: plan)
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
                .background(Color(uiColor: .systemBackground))
        }
        .accessibilityElement(children: .contain)
    }

    private var onboardingProgress: some View {
        VStack(spacing: AppSpacing.md) {
            Text("SET UP YOUR PLAN")
                .font(.dmSans(.caption2, weight: .medium))
                .tracking(0.08)
                .foregroundStyle(.secondary)

            HStack(spacing: AppSpacing.sm) {
                ForEach(OnboardingStep.allCases) { step in
                    Capsule()
                        .fill(step.rawValue <= onboardingStep.rawValue
                              ? Color.leftPositive
                              : Color(uiColor: .tertiarySystemFill))
                        .frame(maxWidth: .infinity)
                        .frame(height: 4)
                }
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
                title: "What's coming in?",
                description: "Add each source you expect this month. Mark steady income like salary as about the same, and invoices or hourly work as variable."
            )

            VStack(spacing: 0) {
                if plan.incomeSources.isEmpty {
                    Text("No income sources added")
                        .font(.dmSans(.subheadline))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.xl)
                } else {
                    ForEach(Array(plan.incomeSources.enumerated()), id: \.element.persistentModelID) { index, source in
                        onboardingIncomeRow(source)

                        if index < plan.incomeSources.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(Color(uiColor: .secondarySystemBackground))
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

                        Text(source.effectiveCadence.label)
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
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit \(source.name), \(source.amount.formatted(.currency(code: "USD"))), \(source.effectiveCadence.label)")

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
                    ForEach(Array(plan.fixedExpenses.enumerated()), id: \.element.persistentModelID) { index, expense in
                        onboardingExpenseRow(expense)

                        if index < plan.fixedExpenses.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.lg)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Button {
                newExpenseName = ""
                newExpenseAmount = 0
                newExpenseCadence = .monthly
                isAddingExpense = true
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
                        .foregroundStyle(Color.leftPositive)
                }
                .accessibilityElement(children: .combine)
            } else {
                Text("This plan leaves no money for daily spending. Lower your goal or go back and adjust your recurring expenses.")
                    .font(.dmSans(.subheadline))
                    .foregroundStyle(Color.leftNegative)
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
                .tracking(0.08)
                .foregroundStyle(Color.leftPositive)

            Text(title)
                .font(.dmSans(size: 32, weight: .bold, relativeTo: .largeTitle))
                .tracking(-0.02)
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
        .frame(minHeight: 64)
    }

    private var onboardingNavigation: some View {
        HStack(spacing: AppSpacing.md) {
            if onboardingStep != .income {
                Button {
                    moveOnboarding(by: -1)
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
                    .foregroundStyle(Color(uiColor: .systemBackground))
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

    private func moveOnboarding(by delta: Int) {
        isMoneyFieldFocused = false
        guard let next = OnboardingStep(rawValue: onboardingStep.rawValue + delta) else {
            return
        }

        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            onboardingStep = next
        }
    }

    private var fixedExpensesContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Picker("Expense basis", selection: $expenseBasis) {
                ForEach(ExpenseBasis.allCases) { basis in
                    Text(basis.label).tag(basis)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 280, alignment: .leading)

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(spacing: 0) {
                    ForEach(plan.fixedExpenses) { expense in
                        @Bindable var expense = expense
                        expenseRow(
                            expense: expense,
                            name: $expense.name,
                            amount: $expense.amount
                        )
                    }
                }

                Button {
                    newExpenseName = ""
                    newExpenseAmount = 0
                    newExpenseCadence = .monthly
                    isAddingExpense = true
                } label: {
                    Label("Add recurring expense", systemImage: "plus")
                        .labelStyle(.titleAndIcon)
                        .font(.dmSans(.subheadline, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(AppSpacing.md)
                        .background(Color(uiColor: .secondarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recurringExpenseSheet: some View {
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
                    moneyField(value: $newExpenseAmount, accessibilityLabel: "Recurring expense amount")
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
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("New recurring expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        isAddingExpense = false
                    } label: {
                        Text("Cancel")
                            .font(.dmSans(.subheadline, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .overlay {
                                Capsule()
                                    .stroke(Color(uiColor: .separator), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        addExpense()
                    } label: {
                        Text("Add")
                            .font(.dmSans(.subheadline, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .overlay {
                                Capsule()
                                    .stroke(Color(uiColor: .separator), lineWidth: 1)
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
                        .font(.dmSans(.subheadline, weight: .medium))
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
            .font(.dmSans(size: 32, weight: .bold, relativeTo: .largeTitle))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
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
            .font(.dmSans(.caption2, weight: .medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .tracking(0.44)
            .textCase(nil)
    }

    private func moneyField(value: Binding<Decimal>, accessibilityLabel: String = "Amount") -> some View {
        MoneyField(value: value,
                   unit: .currency,
                   prominence: .inline,
                   accessibilityLabel: accessibilityLabel,
                   focus: $isMoneyFieldFocused)
    }

    private func expenseRow(
        expense: FixedExpense,
        name: Binding<String>,
        amount: Binding<Decimal>
    ) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(alignment: .lastTextBaseline, spacing: AppSpacing.sm) {
                TextField("Name", text: name)
                    .font(.dmSans(.body, weight: .medium))
                    .multilineTextAlignment(.leading)
                    .lineLimit(1)
                    .layoutPriority(1)

                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text(expenseAmount(expense, for: expenseBasis), format: .currency(code: "USD"))
                        .font(.dmSans(.title3, weight: .semibold))
                        .foregroundStyle(.primary)
                        .monospacedDigit()

                    Text(expenseBasis.suffix)
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                }
                .fixedSize()

                Button(role: .destructive) {
                    deleteExpense(expense)
                } label: {
                    Image(systemName: "trash")
                        .font(.dmSans(.subheadline, weight: .medium))
                        .foregroundStyle(Color.leftNegative)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(expense.name)")
            }

            HStack(spacing: AppSpacing.xs) {
                Text("Billed \(expense.effectiveCadence.label.lowercased()) at")
                    .font(.dmSans(.caption))
                    .foregroundStyle(.secondary)

                MoneyField(value: amount,
                           unit: .currency,
                           prominence: .compact,
                           accessibilityLabel: "\(expense.name) billed amount",
                           focus: $isMoneyFieldFocused)
            }
        }
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contextMenu {
            Button("Delete \(expense.name)", systemImage: "trash", role: .destructive) {
                deleteExpense(expense)
            }
        }
        .accessibilityAction(named: Text("Delete \(expense.name)")) {
            deleteExpense(expense)
        }
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

    private func addExpense() {
        guard !newExpenseName.isEmpty, newExpenseAmount > 0 else { return }
        plan.fixedExpenses.append(FixedExpense(name: newExpenseName, amount: newExpenseAmount, cadence: newExpenseCadence))
        isAddingExpense = false
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
