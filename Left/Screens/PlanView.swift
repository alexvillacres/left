import SwiftUI
import SwiftData

struct PlanView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var plan: MonthPlan
    var isOnboarding: Bool = false
    var onComplete: (() -> Void)?

    @State private var isAddingExpense = false
    @State private var newExpenseName = ""
    @State private var newExpenseAmount: Decimal = 0
    @State private var newExpenseCadence: ExpenseCadence = .monthly
    @State private var expenseBasis: ExpenseBasis = .daily
    @State private var onboardingStep: OnboardingStep = .cadence
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

                planSection("Savings goal") {
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
            moneyField(value: incomeBinding, accessibilityLabel: "Money available this month")

            Text(incomeGuidance)
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            incomeCadencePicker

            incomeConfirmNote
        }
    }

    private var incomeCadencePicker: some View {
        Picker("Income cadence", selection: incomeCadenceBinding) {
            ForEach(IncomeCadence.allCases) { cadence in
                Text(cadence.label).tag(cadence)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 280, alignment: .leading)
    }

    // Typing a number is vouching for it, so editing here counts as confirming
    // and the note below retires on its own.
    private var incomeBinding: Binding<Decimal> {
        Binding {
            plan.monthlyIncome
        } set: { newValue in
            plan.monthlyIncome = max(0, newValue)
            plan.incomeConfirmedAt = .now
        }
    }

    private var incomeCadenceBinding: Binding<IncomeCadence> {
        Binding {
            plan.effectiveIncomeCadence
        } set: { plan.incomeCadence = $0 }
    }

    private var incomeGuidance: String {
        if plan.effectiveIncomeCadence == .variable {
            "Include invoices you expect to be paid this month, even if the work was completed earlier."
        } else {
            "Use the take-home amount you expect to receive this month."
        }
    }

    // Where an ignored or dismissed confirm row comes to rest. Unlike the row
    // on Today, this never expires — it's the permanent recovery path.
    @ViewBuilder
    private var incomeConfirmNote: some View {
        if plan.incomeIsUnconfirmed {
            Button {
                plan.confirmIncome()
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(carriedOverNote)
                    Image(systemName: "checkmark.circle")
                }
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Confirm money available this month: \(plan.monthlyIncome.formatted(.currency(code: "USD").precision(.fractionLength(0))))")
        }
    }

    private var carriedOverNote: String {
        guard let previous = Calendar.current.date(byAdding: .month, value: -1, to: plan.monthStart) else {
            return "Not confirmed yet. Tap to confirm what's expected this month."
        }
        return "Using \(previous.formatted(.dateTime.month(.wide)))'s amount. Tap to confirm what's expected this month."
    }

    // MARK: - Savings

    private var savingsContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            savingsModePicker

            if plan.usesPercentSavings {
                percentField(value: savingsPercentBinding)
            } else {
                moneyField(value: savingsAmountBinding, accessibilityLabel: "Monthly savings goal")
            }

            savingsResolution
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: plan.usesPercentSavings)
    }

    private var savingsModePicker: some View {
        Picker("Savings basis", selection: savingsMode) {
            ForEach(SavingsMode.allCases) { mode in
                Text(mode.label).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(maxWidth: 280, alignment: .leading)
    }

    // The other half of whichever number you typed: percent mode shows the
    // dollars it works out to this month, amount mode shows the share of
    // income it represents.
    @ViewBuilder
    private var savingsResolution: some View {
        if plan.usesPercentSavings {
            Text("\(plan.savingsAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))) this month, and it moves with your income")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        } else if plan.monthlyIncome > 0, plan.savingsGoal > 0 {
            Text("About \(plan.equivalentPercent().formatted(.number))% of this month's income")
                .font(.dmSans(.caption))
                .foregroundStyle(.secondary)
        }
    }

    private var savingsMode: Binding<SavingsMode> {
        Binding {
            plan.usesPercentSavings ? .percent : .amount
        } set: { mode in
            switch mode {
            case .amount:
                plan.savingsTarget = .amount(plan.savingsAmount)
            case .percent:
                plan.savingsTarget = .percentOfIncome(plan.equivalentPercent())
            }
        }
    }

    private var savingsAmountBinding: Binding<Decimal> {
        Binding {
            plan.savingsGoal
        } set: { newValue in
            plan.savingsTarget = .amount(newValue)
        }
    }

    private var savingsPercentBinding: Binding<Decimal> {
        Binding {
            plan.savingsPercent ?? 0
        } set: { newValue in
            plan.savingsTarget = .percentOfIncome(newValue)
        }
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
        case .cadence:
            onboardingCadenceStep
        case .income:
            onboardingIncomeStep
        case .expenses:
            onboardingExpensesStep
        case .savings:
            onboardingSavingsStep
        }
    }

    // Asked before income because it frames the income question — and because
    // it's the answer that decides whether this user is ever asked again.
    private var onboardingCadenceStep: some View {
        VStack(spacing: AppSpacing.xxl) {
            onboardingHeader(
                eyebrow: "MONEY COMING IN",
                title: "Does what you receive change?",
                description: "This decides how often Left asks what money is available for the month. You can change it later."
            )

            VStack(spacing: AppSpacing.md) {
                ForEach(IncomeCadence.allCases) { cadence in
                    cadenceCard(cadence)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func cadenceCard(_ cadence: IncomeCadence) -> some View {
        let isSelected = plan.incomeCadence == cadence

        return Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                plan.incomeCadence = cadence
            }
        } label: {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Image(systemName: cadence.symbol)
                    .font(.dmSans(.body, weight: .medium))
                    .foregroundStyle(isSelected ? Color.leftPositive : Color.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text(cadence.label)
                        .font(.dmSans(.body, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(cadence.detail)
                        .font(.dmSans(.caption))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.leftPositive : Color.clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(cadence.label). \(cadence.detail)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var onboardingIncomeStep: some View {
        let isVariable = plan.effectiveIncomeCadence == .variable

        return VStack(spacing: AppSpacing.xxl) {
            onboardingHeader(
                eyebrow: "MONEY AVAILABLE",
                title: isVariable ? "What do you expect to receive this month?" : "What do you usually receive each month?",
                description: isVariable
                    ? "Include invoices you expect to be paid this month, even if you completed the work earlier. Left checks in when a new month starts."
                    : "Enter your usual take-home amount. Left uses it as the money available for each month's plan."
            )

            onboardingMoneyField(
                value: $plan.monthlyIncome,
                accessibilityLabel: "Money available this month"
            )
        }
        .frame(maxWidth: .infinity)
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
                savingsModePicker

                if plan.usesPercentSavings {
                    onboardingPercentField(value: savingsPercentBinding)
                } else {
                    onboardingMoneyField(
                        value: savingsAmountBinding,
                        accessibilityLabel: "Monthly savings goal"
                    )
                }

                savingsResolution
                    .multilineTextAlignment(.center)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: plan.usesPercentSavings)

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
        case .cadence:
            // No preselection: the point is an explicit declaration, not a
            // default the user tapped past.
            plan.incomeCadence != nil
        case .income:
            plan.monthlyIncome > 0
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

    private func percentField(value: Binding<Decimal>) -> some View {
        MoneyField(value: value,
                   unit: .percent,
                   prominence: .inline,
                   accessibilityLabel: "Savings percent of income",
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
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
    case cadence
    case income
    case expenses
    case savings

    var id: Int { rawValue }
}

private enum SavingsMode: String, CaseIterable, Identifiable {
    case amount, percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amount: "Amount"
        case .percent: "% of income"
        }
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
        for: MonthPlan.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let cal = Calendar.current
    let start = cal.startOfDay(for: cal.date(from: cal.dateComponents([.year, .month], from: .now))!)
    let plan = MonthPlan(monthStart: start, monthlyIncome: 6200, savingsGoal: 1000, savingsPercent: 20)
    container.mainContext.insert(plan)
    plan.fixedExpenses.append(FixedExpense(name: "Rent", amount: 1800))
    plan.fixedExpenses.append(FixedExpense(name: "Utilities", amount: 200))
    plan.fixedExpenses.append(FixedExpense(name: "Insurance", amount: 900, cadence: .quarterly))
    return NavigationStack {
        PlanView(plan: plan)
    }
    .modelContainer(container)
}
