import SwiftUI
import SwiftData

enum SavingsMode: String, CaseIterable, Identifiable {
    case amount, percent

    var id: String { rawValue }

    var label: String {
        switch self {
        case .amount: "Amount"
        case .percent: "% of income"
        }
    }
}

struct SavingsGoalSheet: View {
    let plan: MonthPlan
    let goal: SavingsGoal?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draftName: String
    @State private var amountText: String
    @State private var percentText: String
    @State private var mode: SavingsMode
    @State private var contentHeight: CGFloat = 380
    @State private var showsDeleteConfirmation = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isValueFocused: Bool

    init(plan: MonthPlan, goal: SavingsGoal? = nil) {
        self.plan = plan
        self.goal = goal
        _draftName = State(initialValue: goal?.name ?? "")
        _amountText = State(initialValue: goal.map { Self.entry($0.amount) } ?? "")
        _percentText = State(initialValue: Self.entry(goal?.percent ?? 20))
        _mode = State(initialValue: goal?.usesPercent == true ? .percent : .amount)
    }

    private static func entry(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    private var valueText: Binding<String> {
        mode == .amount ? $amountText : $percentText
    }

    private var parsedValue: Decimal? {
        guard !valueText.wrappedValue.isEmpty,
              let value = try? Decimal(valueText.wrappedValue, format: .number), value > 0 else { return nil }
        if mode == .percent {
            return value <= SavingsGoal.maxPercent ? value : nil
        }
        // Retain legacy fractional goals; newly entered plan amounts are whole dollars.
        guard value == value.rounded(scale: 0) || value == goal?.amount else { return nil }
        return value
    }

    private var draftValue: Decimal { parsedValue ?? 0 }
    private var trimmedName: String { draftName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && parsedValue != nil }
    private var monthName: String { plan.monthStart.formatted(.dateTime.month(.wide)) }
    private var resolvedAmount: Decimal {
        mode == .amount ? draftValue : (max(0, plan.incomeTotal) * draftValue / 100).roundedToCents()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(goal == nil ? "New savings goal" : "Savings goal")
                    .font(.dmSans(.body, weight: .medium))
                    .accessibilityAddTraits(.isHeader)
                    .frame(maxWidth: .infinity, minHeight: 48)

                VStack(spacing: AppSpacing.xl) {
                    MoneyField(value: .constant(draftValue),
                               unit: mode == .percent ? .percent : .currency,
                               prominence: .sheet,
                               accessibilityLabel: mode == .percent ? "Percent of income for this savings goal" : "Monthly savings goal amount",
                               focus: $isValueFocused, text: valueText)
                    TextField("Name this goal", text: $draftName)
                        .font(.dmSans(.callout))
                        .multilineTextAlignment(.center)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.done)
                        .focused($isNameFocused)
                        .accessibilityLabel("Savings goal name")
                        .onSubmit { isNameFocused = false }
                }
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.xxl)

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: 0) {
                        ForEach(SavingsMode.allCases) { option in
                            Button { changeMode(to: option) } label: {
                                Text(option.label)
                                    .font(.dmSans(.callout, weight: mode == option ? .medium : .regular))
                                    .foregroundStyle(mode == option ? Color.leftTextPrimary : Color.leftTextSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 38)
                                    .background(mode == option ? Color.leftSurface : .clear,
                                                in: RoundedRectangle(cornerRadius: 8))
                            }
                            .accessibilityAddTraits(mode == option ? .isSelected : [])
                        }
                    }
                    .padding(3)
                    .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 10))

                    // Both modes keep their supporting line, including empty drafts.
                    ZStack(alignment: .topLeading) {
                        ForEach(SavingsMode.allCases) { option in
                            Text(explanation(for: option))
                                .opacity(mode == option ? 1 : 0)
                                .accessibilityHidden(mode != option)
                        }
                    }
                    .font(.dmSans(.footnote))
                    .foregroundStyle(Color.leftTextTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.xxs)
                }
                actions.padding(.top, AppSpacing.lg)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.top, AppSpacing.lg)
            .padding(.bottom, AppSpacing.xl)
            .background(GeometryReader { proxy in
                Color.clear.preference(key: SavingsSheetHeight.self, value: proxy.size.height)
            })
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollDismissesKeyboard(.interactively)
        .onPreferenceChange(SavingsSheetHeight.self) { height in
            if height > 0 { contentHeight = height }
        }
        .onChange(of: isValueFocused) { _, focused in
            if !focused, let parsedValue { valueText.wrappedValue = Self.entry(parsedValue) }
        }
        .background(Color.leftSheet.ignoresSafeArea())
        .presentationBackground(Color.leftSheet)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .tint(.leftAccent)
        .buttonStyle(.plain)
        .alert("Remove “\(goal?.name ?? "savings goal")”?", isPresented: $showsDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive, action: removeGoal)
        } message: {
            Text("This removes this savings goal from \(monthName) and future plans. Earlier months stay unchanged.")
        }
    }

    private func explanation(for option: SavingsMode) -> String {
        if option == .percent {
            let amount = resolvedAmount.formatted(.currency(code: "USD").precision(.fractionLength(0)))
            return "\(amount) this month. It moves with your planned income."
        }
        guard plan.incomeTotal > 0 else { return "A fixed amount set aside in \(monthName)'s plan." }
        let percent = (draftValue / plan.incomeTotal * 100).formatted(.number.precision(.fractionLength(0)))
        return "About \(percent)% of \(monthName)'s income"
    }

    private func changeMode(to newMode: SavingsMode) {
        guard newMode != mode else { return }
        if newMode == .amount {
            amountText = Self.entry(resolvedAmount.rounded(scale: 0))
        } else if plan.incomeTotal > 0, draftValue > 0 {
            percentText = Self.entry(min(SavingsGoal.maxPercent, (draftValue / plan.incomeTotal * 100).rounded(scale: 0)))
        }
        mode = newMode
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.md) {
            if goal != nil {
                Button { showsDeleteConfirmation = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.leftTextSecondary)
                        .frame(width: 52, height: 52)
                        .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Remove savings goal")
            }
            Button(action: save) {
                Text(goal == nil ? "Add goal" : "Save")
                    .font(.dmSans(.body, weight: .medium))
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .foregroundStyle(canSave ? Color.leftTextOnAccent : Color.leftDisabledForeground)
                    .background(canSave ? Color.leftAccent : Color.leftDisabledFill,
                                in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(OpaqueButtonStyle())
            .disabled(!canSave)
        }
    }

    private func removeGoal() {
        guard let goal else { return }
        let isLastGoal = plan.savingsGoals.count == 1
        plan.savingsGoals.removeAll { $0.persistentModelID == goal.persistentModelID }
        modelContext.delete(goal)
        if isLastGoal { plan.savingsTarget = .amount(0) }
        HapticFeedback.lightImpact()
        dismiss()
    }

    private func save() {
        guard let value = parsedValue, canSave else { return }
        if let goal {
            goal.name = trimmedName
            goal.target = mode == .percent ? .percentOfIncome(value) : .amount(value)
        } else {
            plan.savingsGoals.append(SavingsGoal(name: trimmedName,
                                                amount: mode == .amount ? value : 0,
                                                percent: mode == .percent ? value : nil))
        }
        HapticFeedback.lightImpact()
        dismiss()
    }
}

private struct SavingsSheetHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: MonthPlan.self, IncomeSource.self, SavingsGoal.self, FixedExpense.self, Transaction.self,
        configurations: config
    )
    let plan = MonthPlan(monthStart: .now, monthlyIncome: 0, savingsGoal: 0)
    container.mainContext.insert(plan)
    plan.incomeSources.append(IncomeSource(name: "Salary", amount: 6200, affirmedAt: .now))
    let goal = SavingsGoal(name: "Roth IRA", amount: 500)
    plan.savingsGoals.append(goal)
    return Color.leftBackground
        .sheet(isPresented: .constant(true)) {
            SavingsGoalSheet(plan: plan, goal: goal)
        }
        .modelContainer(container)
}
