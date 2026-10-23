import SwiftUI
import SwiftData

struct OnboardingView: View {
    let plan: MonthPlan
    var onComplete: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var step = 0
    @State private var isEditing = false
    @State private var replacesAmount = true
    @State private var saveError: String?
    @State private var usesPercent = false
    @State private var flatSavings: Decimal = 0
    @State private var percentSavings: Decimal = 20
    @State private var draft: MonthPlan

    init(plan: MonthPlan, onComplete: @escaping () -> Void) {
        self.plan = plan
        self.onComplete = onComplete
        // A detached draft uses the same calculations without changing the store
        // until the user finishes. Existing itemized plans are retained on save.
        let draft = MonthPlan(monthStart: plan.monthStart, monthlyIncome: plan.incomeTotal,
                              savingsGoal: plan.savingsAmount, createdAt: plan.createdAt)
        draft.fixedExpenses = [FixedExpense(name: "Recurring expenses", amount: plan.fixedTotal)]
        draft.carriedGross = plan.carriedGross
        draft.carriedAllocated = plan.carriedAllocated
        _draft = State(initialValue: draft)
        let percent = plan.savingsGoals.count == 1 ? plan.savingsGoals.first?.percent :
            (plan.savingsGoals.isEmpty ? plan.savingsPercent : nil)
        _usesPercent = State(initialValue: percent != nil)
        _flatSavings = State(initialValue: plan.savingsAmount)
        _percentSavings = State(initialValue: percent ?? 20)
        draft.savingsPercent = percent
    }

    private var isTeaching: Bool { step < 3 }
    private var isApplying: Bool { (3...5).contains(step) }
    private var showsFloatingKeypad: Bool { isApplying && isEditing && !dynamicTypeSize.isAccessibilitySize }
    private var background: Color {
        switch step {
        case 0: .leftOnboardingPromise
        case 1: .leftOnboardingProtection
        case 2: .leftOnboardingRollover
        default: .leftSurface
        }
    }

    var body: some View {
        Group {
            if isApplying && hasItemizedPlan {
                PlanView(plan: plan, isOnboarding: true, onBack: { step = 2 }, onComplete: {
                    draft.monthlyIncome = plan.incomeTotal
                    draft.fixedExpenses.first?.amount = plan.fixedTotal
                    flatSavings = plan.savingsAmount
                    usesPercent = false
                    draft.savingsPercent = nil
                    draft.savingsGoal = plan.savingsAmount
                    step = 6
                })
            } else {
                flow
            }
        }
    }

    private var hasItemizedPlan: Bool {
        plan.incomeSources.count > 1 || plan.fixedExpenses.count > 1 || plan.savingsGoals.count > 1
            || plan.incomeSources.contains { !$0.covers(month: plan.monthStart) }
            || plan.fixedExpenses.contains { !$0.covers(month: plan.monthStart) }
    }

    private var flow: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ScrollView {
                    Group {
                        if isTeaching {
                            teaching(minHeight: max(0, geometry.size.height - 84))
                        } else if isApplying {
                            application(topSpace: max(24, geometry.size.height * 0.14 - (step == 5 ? 68 : 0)))
                        } else {
                            summary(minHeight: max(0, geometry.size.height - 84))
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity)
                    if isApplying && isEditing && dynamicTypeSize.isAccessibilitySize {
                        keypad
                    }
                }
                .scrollIndicators(.hidden)
                .id(step)

                if isApplying && isEditing {
                    if !dynamicTypeSize.isAccessibilitySize {
                        keypad
                            .padding(8)
                            .transition(.move(edge: .bottom))
                    }
                } else {
                    navigation
                }
            }
        }
        // The floating keypad sits 8pt from the screen edge, below the home
        // indicator area, like the system's inset sheets.
        .ignoresSafeArea(.container, edges: showsFloatingKeypad ? .bottom : [])
        .foregroundStyle(Color.leftAccent)
        .background(background.ignoresSafeArea())
        .interactiveDismissDisabled()
        .toolbar(.hidden, for: .navigationBar)
        .alert("Couldn't save your plan", isPresented: Binding(
            get: { saveError != nil }, set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }

    private func teaching(minHeight: CGFloat) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            Image(onboardingArtwork)
                .resizable()
                .scaledToFit()
                .modifier(OnboardingArtworkContrast(isDark: colorScheme == .dark))
                .frame(maxWidth: 324)
                .aspectRatio(1, contentMode: .fit)
                .accessibilityHidden(true)
            Spacer(minLength: 24)
            VStack(spacing: step == 2 ? 4 : 8) {
                Text(title)
                    .font(.dmSans(size: 28, weight: .semibold, relativeTo: .title))
                    .tracking(-0.84)
                    .frame(maxWidth: step == 0 ? 270 : step == 2 ? 320 : 300)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(.dmSansSupporting())
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 24)
        }
        .frame(minHeight: minHeight)
    }

    private var onboardingArtwork: String {
        switch step {
        case 0: "OnboardingPromise"
        case 1: "OnboardingProtection"
        default: "OnboardingRollover"
        }
    }

    private func application(topSpace: CGFloat) -> some View {
        VStack(spacing: 24) {
            allocationBar
                .padding(.top, topSpace)
            VStack(spacing: 12) {
                Text(title)
                    .font(.dmSans(size: 22, weight: .bold, relativeTo: .title2))
                    .tracking(-0.44)
                    .accessibilityAddTraits(.isHeader)
                Text(detail)
                    .font(.dmSansSupporting())
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            if step == 5 {
                SegmentedControl(options: [false, true], selection: $usesPercent) {
                    $0 ? "Percentage" : "Amount"
                }
                .frame(minHeight: 44)
                .onChange(of: usesPercent) {
                    draft.savingsGoal = flatSavings
                    draft.savingsPercent = usesPercent ? percentSavings : nil
                    replacesAmount = true
                }
            }

            Button {
                guard !isEditing else { return }
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { isEditing = true }
                replacesAmount = true
            } label: {
                Group {
                    if step == 5 && usesPercent {
                        Text(percentSavings / 100, format: .percent.precision(.fractionLength(0...2)))
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(fieldAmount.symbol)
                                .font(.dmSans(size: 24, weight: .medium, relativeTo: .title2))
                                .foregroundStyle(Color.leftPlaceholder)
                            Text(fieldAmount.number)
                                .foregroundStyle(amount == 0 && !isEditing ? Color.leftPlaceholder : Color.leftAccent)
                        }
                    }
                }
                .font(.dmSans(size: 40, weight: .medium, relativeTo: .largeTitle))
                .tracking(-0.8)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity, minHeight: 72)
                .padding(.horizontal, 12)
                .background(Color.leftBackground, in: RoundedRectangle(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.leftDivider, lineWidth: 0.5)
                }
                // The focus ring sits outside the field's edge, like a CSS outline.
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isEditing ? fieldColor : .clear, lineWidth: 2)
                        .padding(-2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(step == 3 ? "Monthly income" : step == 4 ? "Monthly recurring expenses" : "Monthly savings")
            .accessibilityValue(step == 5 && usesPercent ? "\(percentSavings.formatted(.number)) percent" : amount.formatted(.currency(code: "USD")))
            .accessibilityHint(step == 5 && usesPercent ? "Opens the percentage keypad" : "Opens the whole-dollar keypad")

            if step == 5 && !canContinue {
                Text("This plan leaves no money for daily spending. Lower savings or go back to adjust income and recurring expenses.")
                    .font(.dmSansSupporting())
                    .foregroundStyle(Color.leftFeedbackNegative)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 24)
    }

    private func summary(minHeight: CGFloat) -> some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)
            VStack(spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    if !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .firstTextBaseline, spacing: 4) { summaryAmount; summarySuffix }
                    }
                    VStack(spacing: 4) { summaryAmount; summarySuffix }
                }
                .accessibilityElement(children: .combine)
                Text("This is what’s available for everyday spending based on the plan you just made.")
                    .font(.dmSansSupporting())
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                allocationBar
            }
            VStack(spacing: 14) {
                receiptRow("Income", amount: draft.incomeTotal)
                receiptRow("Recurring expenses", amount: -draft.fixedTotal)
                receiptRow(usesPercent ? "Savings (\(percentSavings.formatted(.number))%)" : "Savings", amount: -draft.savingsAmount)
                Divider()
                receiptRow("Monthly spending budget", amount: draft.monthlySpendable)
                AdaptiveValuePair {
                    Text("÷ \(draft.daysInMonth()) days").foregroundStyle(.secondary)
                } value: {
                    Text("\(draft.dailyRate, format: .currency(code: "USD"))/day")
                        .font(.dmSans(size: 19, weight: .bold))
                        .foregroundStyle(Color.leftPlanSpendableText)
                        .monospacedDigit()
                }
                if draft.firstActiveDay > 1 {
                    Text("Starting \(firstActiveDate.formatted(.dateTime.month(.wide).day())), you’ll accrue \(draft.plannedSpend, format: .currency(code: "USD")) for spending through \(monthEndDate.formatted(.dateTime.month(.wide).day())).")
                        .font(.dmSans(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .font(.dmSansSupporting())
            .padding(16)
            .background(Color.leftBackground, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.leftNeutralFill, lineWidth: 0.5))
            Spacer(minLength: 36)
            Text("Money you don't spend rolls over to tomorrow.")
                .font(.dmSans(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 36)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(minHeight: minHeight, alignment: .top)
    }

    private var summaryAmount: some View {
        HeroMoneyText(amount: draft.remainingToday(on: .now, spentAsOf: plan.spent()), size: 64)
    }
    private var firstActiveDate: Date {
        Calendar.current.date(byAdding: .day, value: draft.firstActiveDay - 1, to: draft.monthStart)!
    }
    private var monthEndDate: Date {
        Calendar.current.date(byAdding: .day, value: draft.daysInMonth() - 1, to: draft.monthStart)!
    }
    private var summarySuffix: some View {
        Text("left today").font(.dmSans(size: 20, weight: .medium)).foregroundStyle(.secondary)
    }

    private func receiptRow(_ title: String, amount: Decimal) -> some View {
        AdaptiveValuePair {
            Text(title).foregroundStyle(.secondary)
        } value: {
            MoneyText(amount: amount, showsCents: amount != Decimal(NSDecimalNumber(decimal: amount).intValue))
                .font(.dmSans(.subheadline, weight: .medium))
        }
    }

    private var allocationBar: some View {
        GeometryReader { geometry in
            let values = segmentValues
            let total = values.reduce(0, +)
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: 10)
                        .fill([Color.leftPlanExpenses, .leftPlanSavings, .leftPlanSpendable][index])
                        .opacity(step == 3 ? 0.2 : (step == 4 && index > 0) || (step == 5 && index == 2) ? 0.3 : 1)
                        .frame(width: max(0, geometry.size.width - 24) * values[index] / total)
                }
            }
            .padding(6)
            .background(Color.leftNeutralFill, in: RoundedRectangle(cornerRadius: 16))
        }
        .frame(height: 68)
        .accessibilityElement(children: .ignore)
        .overlay {
            if step > 3 && draft.incomeTotal > 0 && draft.monthlySpendable <= 0 {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.leftFeedbackOverspentBg)
                    .padding(6)
            }
        }
        .accessibilityLabel("Monthly allocation: recurring expenses, savings, and spendable")
        .accessibilityValue("\(draft.fixedTotal.formatted(.currency(code: "USD"))), \(draft.savingsAmount.formatted(.currency(code: "USD"))), \(draft.monthlySpendable.formatted(.currency(code: "USD")))")
    }

    private var segmentValues: [CGFloat] {
        guard step > 3, draft.incomeTotal > 0 else { return [1, 1, 1] }
        let income = NSDecimalNumber(decimal: draft.incomeTotal).doubleValue
        let values = [draft.fixedTotal, draft.savingsAmount, max(0, draft.monthlySpendable)]
        // A small visible mark keeps zero and not-yet-entered categories legible.
        return values.map { max(0.03, CGFloat(NSDecimalNumber(decimal: $0).doubleValue / income)) }
    }

    private var keypad: some View {
        VStack(spacing: 12) {
            NumpadView(onDigit: appendDigit, onBackspace: deleteDigit)
            actionButton("Confirm", primary: true, action: closeKeypad)
        }
        .padding(.horizontal, 24)
        .padding(.top, 32)
        .padding(.bottom, 24)
        .background(Color.leftBackground, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.leftNeutralFill, lineWidth: 0.5)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Capsule()
                .fill(Color.leftHandle)
                .frame(width: 32, height: 4)
                .padding(.top, 8)
                .accessibilityHidden(true)
        }
        // The handle promises the sheet can be pulled away; doing so keeps the
        // entered amount, same as Confirm.
        .gesture(DragGesture(minimumDistance: 20).onEnded { value in
            if value.translation.height > 60 { closeKeypad() }
        })
        .accessibilityAction(.escape, closeKeypad)
    }

    private func closeKeypad() {
        HapticFeedback.lightImpact()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { isEditing = false }
    }

    private var navigation: some View {
        navigationLayout {
            if step > 0 {
                actionButton("Back", primary: false) { move(by: -1) }
                    .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : 92)
            }
            actionButton(step == 2 ? "Set up my month" : step == 6 ? "Start using Left" : "Continue", primary: true) {
                if step == 6 { save() } else { move(by: 1) }
            }
            .disabled(!canContinue)
        }
        .transition(.opacity)
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    private var navigationLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(spacing: 12))
    }

    private func actionButton(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.dmSans(size: 16, weight: primary ? .semibold : .medium))
                .foregroundStyle(primary && !canContinue ? Color.leftDisabledForeground : primary ? Color.leftTextOnAccent : Color.leftAccent)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(primary && !canContinue ? Color.leftDisabledFill : primary ? Color.leftAccent : isTeaching ? Color.leftBackground : Color.leftNeutralFill,
                            in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(OpaqueButtonStyle())
    }

    // Income is the neutral whole, so its focus ring stays neutral.
    private var fieldColor: Color { step == 4 ? .leftPlanExpenses : step == 5 ? .leftPlanSavings : .leftDivider }

    // Foundation formats the amount; its symbol run is split out so the
    // prefix can be set smaller and lighter, as in the design.
    private var fieldAmount: (symbol: String, number: String) {
        let text = amount.formatted(.currency(code: "USD").precision(.fractionLength(0...2)).attributed)
        var symbol = "", number = ""
        for run in text.runs {
            let part = String(text[run.range].characters)
            if run.numberSymbol == .currency { symbol += part } else { number += part }
        }
        return (symbol, number.trimmingCharacters(in: .whitespaces))
    }
    private var canContinue: Bool {
        switch step {
        case 3: draft.incomeTotal > 0
        case 5, 6: draft.monthlySpendable > 0
        default: true
        }
    }
    private var amount: Decimal {
        switch step {
        case 3: draft.incomeTotal
        case 4: draft.fixedTotal
        default: usesPercent ? percentSavings : flatSavings
        }
    }

    private func setAmount(_ value: Decimal) {
        switch step {
        case 3: draft.monthlyIncome = value
        case 4: draft.fixedExpenses.first?.amount = value
        default:
            if usesPercent { percentSavings = min(100, value) } else { flatSavings = value }
            draft.savingsGoal = flatSavings
            draft.savingsPercent = usesPercent ? percentSavings : nil
        }
    }

    private func appendDigit(_ digit: Int) {
        let next = replacesAmount ? Decimal(digit) : amount * 10 + Decimal(digit)
        guard next <= 999_999_999 else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { setAmount(next) }
        replacesAmount = false
    }

    private func deleteDigit() {
        setAmount(Decimal(NSDecimalNumber(decimal: amount / 10).intValue))
        replacesAmount = false
    }

    private func move(by delta: Int) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.22)) {
            step += delta
            isEditing = false
            replacesAmount = true
        }
    }

    private func save() {
        guard canContinue else { return }
        // Preserve existing itemized data. A resumed legacy onboarding with
        // multiple items uses the established editors instead of flattening it.
        if !hasItemizedPlan {
            if plan.incomeTotal != draft.incomeTotal {
                if let source = plan.incomeSources.first {
                    source.amount = draft.incomeTotal
                    source.affirmedAt = .now
                } else {
                    plan.incomeSources.append(IncomeSource(name: "Income", amount: draft.incomeTotal))
                }
            }
            if plan.fixedTotal != draft.fixedTotal {
                if let expense = plan.fixedExpenses.first {
                    expense.amount = draft.fixedTotal * expense.effectiveCadence.divisorToMonthly
                } else if draft.fixedTotal > 0 {
                    plan.fixedExpenses.append(FixedExpense(name: "Recurring expenses", amount: draft.fixedTotal))
                }
            }
            if plan.savingsAmount != draft.savingsAmount || plan.savingsGoals.first?.percent != draft.savingsPercent {
                if let goal = plan.savingsGoals.first {
                    goal.amount = flatSavings
                    goal.percent = draft.savingsPercent
                } else {
                    plan.savingsGoals.append(SavingsGoal(name: "Savings", amount: flatSavings, percent: draft.savingsPercent))
                }
            }
        }
        do {
            try modelContext.save()
            HapticFeedback.lightImpact()
            onComplete()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var title: String {
        switch step {
        case 0: "Know what you can spend today"
        case 1: "Protect the important stuff first."
        case 2: "Use it today,\nor keep it for later."
        case 3: "What's coming in?"
        case 4: "What's recurring every month?"
        default: "What are you setting aside?"
        }
    }
    private var detail: String {
        switch step {
        case 0: "Left turns your monthly plan into one clear number for everyday spending."
        case 1: "Recurring expenses in your plan are already covered. You only log everyday purchases."
        case 2: "Whatever you don’t spend carries forward. Larger days use what you’ve built up, and Left adjusts automatically."
        case 3: "Add the income you expect this month.\nYou can update it later if things change."
        case 4: "Add rent, utilities, and other recurring costs. Left will account for them automatically."
        default: "Choose an amount or percentage to protect before Left calculates your daily spending."
        }
    }
}

private struct OnboardingArtworkContrast: ViewModifier {
    let isDark: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isDark {
            content.colorInvert()
        } else {
            content
        }
    }
}
