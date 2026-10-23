import SwiftUI
import SwiftData

// Draft values stay local until Save; dismissing the sheet discards them.
// Reference pattern for fitted sheets: retain both detents and animate selection,
// anchor actions in UIKit, and reveal expanding controls after resize.
struct RecurringExpenseSheet: View {
    let plan: MonthPlan
    let expense: FixedExpense?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var draftName: String
    @State private var amountText: String
    @State private var draftCadence: ExpenseCadence
    @State private var draftEndsAfter: Date?
    @State private var showsEndPicker = false
    @State private var pickerIsVisible = false
    @State private var gridYear: Int
    @State private var contentHeight: CGFloat = 350
    @State private var actionsHeight: CGFloat = 92
    @State private var pickerHeight: CGFloat = 240
    @State private var selectedDetent: PresentationDetent = .height(442)
    @State private var isConfirmingDelete = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isAmountFocused: Bool

    private let calendar = Calendar.current
    // The new editor changes the end month only. Preserve existing start dates.
    private var startsOn: Date? { expense?.startsOn }
    private var startMonth: Date { startsOn ?? plan.monthStart }
    private var minimumYear: Int { calendar.component(.year, from: startMonth) }

    init(plan: MonthPlan, expense: FixedExpense? = nil) {
        self.plan = plan
        self.expense = expense
        _draftName = State(initialValue: expense?.name ?? "")
        _amountText = State(initialValue: expense.map {
            $0.amount.formatted(.number.precision(.fractionLength(0...2)))
        } ?? "")
        _draftCadence = State(initialValue: expense?.effectiveCadence ?? .monthly)
        _draftEndsAfter = State(initialValue: expense?.endsAfter)
        _gridYear = State(initialValue: Calendar.current.component(.year, from: expense?.endsAfter ?? expense?.startsOn ?? plan.monthStart))
    }

    private var parsedAmount: Decimal? {
        guard !amountText.isEmpty,
              let value = try? Decimal(amountText, format: .number), value > 0 else { return nil }
        // Keep legacy fractional bills intact; new plan amounts use whole dollars.
        guard value == value.rounded(scale: 0) || value == expense?.amount else { return nil }
        return value
    }
    private var draftAmount: Decimal { parsedAmount ?? 0 }
    private var trimmedName: String { draftName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && parsedAmount != nil }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    Text(expense == nil ? "New recurring expense" : "Recurring expense")
                        .font(.dmSans(.body, weight: .medium))
                        .accessibilityAddTraits(.isHeader)
                        .frame(maxWidth: .infinity, minHeight: 48)

                    VStack(spacing: AppSpacing.xl) {
                        MoneyField(value: .constant(draftAmount), prominence: .sheet,
                                   accessibilityLabel: "Recurring expense amount", focus: $isAmountFocused,
                                   text: $amountText)
                        TextField("Name this expense", text: $draftName)
                            .font(.dmSans(.callout))
                            .multilineTextAlignment(.center)
                            .textInputAutocapitalization(.words)
                            .focused($isNameFocused)
                            .submitLabel(.next)
                            .onSubmit { isNameFocused = false; isAmountFocused = true }
                            .accessibilityLabel("Recurring expense name")
                    }
                    .padding(.top, AppSpacing.xl)
                    .padding(.bottom, AppSpacing.xxl)

                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        cadenceControl
                        Text(cadenceExplanation)
                            .font(.dmSans(.footnote))
                            .foregroundStyle(Color.leftTextTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, AppSpacing.xxs)
                        endDateRow
                        VStack(spacing: AppSpacing.sm) {
                            yearStepper
                            monthGrid
                            Button {
                                draftEndsAfter = nil
                                setEndPicker(false)
                            } label: {
                                Text("No end date")
                                    .font(.dmSans(.subheadline))
                                    .foregroundStyle(Color.leftTextSecondary)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .background(GeometryReader { proxy in
                            Color.clear.preference(key: ExpensePickerHeight.self, value: proxy.size.height)
                        })
                        .frame(height: showsEndPicker ? nil : 0, alignment: .top)
                        .clipped()
                        .opacity(showsEndPicker && pickerIsVisible ? 1 : 0)
                        .allowsHitTesting(pickerIsVisible)
                        .accessibilityHidden(!pickerIsVisible)
                    }
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.top, AppSpacing.lg)
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ExpenseSheetHeight.self, value: proxy.size.height)
                })
            }
            .clipped()
            .scrollBounceBehavior(.basedOnSize)
            .scrollDismissesKeyboard(.interactively)

            Color.clear.frame(height: actionsHeight)
        }
        .background {
            ExpenseSheetFooter {
                actions
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xl)
                    .background(Color.leftSheet.ignoresSafeArea(.container, edges: .bottom))
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ExpenseActionsHeight.self, value: proxy.size.height)
                    })
                    .onPreferenceChange(ExpenseActionsHeight.self) { height in
                        if height > 0 { actionsHeight = height }
                    }
            }
        }
        .onPreferenceChange(ExpensePickerHeight.self) { height in
            if height > 0 { pickerHeight = height }
        }
        .onPreferenceChange(ExpenseSheetHeight.self) { height in
            let base = height - (showsEndPicker ? pickerHeight : 0)
            guard base > 0, abs(base - contentHeight) > 0.5 else { return }
            contentHeight = base
            selectedDetent = dynamicTypeSize.isAccessibilitySize ? .large : .height(base + actionsHeight + (showsEndPicker ? pickerHeight : 0))
        }
        .task(id: showsEndPicker) {
            guard showsEndPicker else {
                pickerIsVisible = false
                return
            }
            if !reduceMotion {
                do { try await Task.sleep(for: .milliseconds(150)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) {
                pickerIsVisible = true
            }
        }
        .onChange(of: isNameFocused) { _, focused in if focused { setEndPicker(false) } }
        .onChange(of: isAmountFocused) { _, focused in
            if focused { setEndPicker(false) }
            else if let parsedAmount {
                amountText = parsedAmount.formatted(.number.precision(.fractionLength(0...2)))
            }
        }
        .background(Color.leftSheet.ignoresSafeArea())
        .presentationBackground(Color.leftSheet)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [collapsedDetent, expandedDetent], selection: $selectedDetent)
        .onChange(of: selectedDetent) { _, detent in
            // Keep the picker in sync when the user drags between the two heights.
            if !dynamicTypeSize.isAccessibilitySize {
                showsEndPicker = detent == expandedDetent
            }
        }
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .tint(.leftAccent)
        .buttonStyle(.plain)
        .alert("Remove “\(expense?.name ?? "expense")”?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive, action: delete)
        } message: {
            Text("This removes this expense from this month's plan and future plans. Earlier months stay unchanged.")
        }
    }

    private var cadenceControl: some View {
        HStack(spacing: 0) {
            ForEach(ExpenseCadence.allCases) { cadence in
                Button { draftCadence = cadence } label: {
                    Text(cadence == .annually ? "Yearly" : cadence.label)
                        .font(.dmSans(.callout, weight: draftCadence == cadence ? .medium : .regular))
                        .foregroundStyle(draftCadence == cadence ? Color.leftTextPrimary : Color.leftTextSecondary)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(draftCadence == cadence ? Color.leftSurface : .clear,
                                    in: RoundedRectangle(cornerRadius: 8))
                }
                .accessibilityAddTraits(draftCadence == cadence ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 10))
    }

    private var cadenceExplanation: String {
        let billing: String
        switch draftCadence {
        case .monthly: billing = "Billed every month"
        case .quarterly: billing = "Billed every 3 months"
        case .annually: billing = "Billed once a year"
        }
        let monthly = (draftAmount / draftCadence.divisorToMonthly)
            .formatted(.currency(code: "USD").precision(.fractionLength(0...2)))
        return "\(billing) · \(monthly) a month in your plan"
    }

    private var endDateRow: some View {
        Button {
            isNameFocused = false
            isAmountFocused = false
            if !showsEndPicker {
                gridYear = calendar.component(.year, from: draftEndsAfter ?? startMonth)
            }
            setEndPicker(!showsEndPicker)
        } label: {
            HStack(spacing: AppSpacing.lg) {
                Text("Ends").foregroundStyle(Color.leftTextSecondary)
                Spacer(minLength: AppSpacing.sm)
                Text(draftEndsAfter.map { "After \($0.formatted(.dateTime.month(.wide).year()))" } ?? "No end date")
                    .foregroundStyle(Color.leftTextPrimary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.leftIconMuted)
                    .frame(width: 13, height: 13)
                    .rotationEffect(.degrees(showsEndPicker ? 90 : 0))
            }
            .font(.dmSans(.callout))
            .frame(minHeight: 44)
            .padding(.horizontal, AppSpacing.xxs)
            .contentShape(Rectangle())
        }
        .buttonStyle(EndDateRowButtonStyle())
        .transaction { $0.animation = nil }
        .accessibilityHint(showsEndPicker ? "Closes month selection" : "Opens month selection")
    }

    private var collapsedDetent: PresentationDetent { .height(contentHeight + actionsHeight) }
    private var expandedDetent: PresentationDetent { .height(contentHeight + actionsHeight + pickerHeight) }

    private func setEndPicker(_ visible: Bool) {
        showsEndPicker = visible
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            selectedDetent = dynamicTypeSize.isAccessibilitySize ? .large : (visible ? expandedDetent : collapsedDetent)
        }
    }

    private var yearStepper: some View {
        HStack {
            yearButton("chevron.left", label: "Previous year", enabled: gridYear > minimumYear, delta: -1)
            Spacer()
            Text(String(gridYear))
                .font(.dmSans(.callout, weight: .medium))
                .monospacedDigit()
                .contentTransition(.numericText())
            Spacer()
            yearButton("chevron.right", label: "Next year", enabled: gridYear < max(minimumYear + 30, calendar.component(.year, from: draftEndsAfter ?? startMonth)), delta: 1)
        }
        .padding(.horizontal, AppSpacing.xxs)
    }

    private func yearButton(_ symbol: String, label: String, enabled: Bool, delta: Int) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) { gridYear += delta }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(Color.leftTextSecondary)
                .frame(width: 44, height: 32)
                .contentShape(Rectangle())
        }
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private var monthGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.xs), count: 4), spacing: AppSpacing.xs) {
            ForEach(1...12, id: \.self) { number in
                if let month = calendar.date(from: DateComponents(year: gridYear, month: number, day: 1)) {
                    monthButton(month)
                }
            }
        }
    }

    private func monthButton(_ month: Date) -> some View {
        let selected = month == draftEndsAfter
        return Button {
            draftEndsAfter = month
            HapticFeedback.lightImpact()
        } label: {
            Text(month.formatted(.dateTime.month(.abbreviated)))
                .font(.dmSans(.callout, weight: selected ? .medium : .regular))
                .foregroundStyle(selected ? Color.leftTextOnAccent : Color.leftTextPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(selected ? Color.leftAccent : Color.leftTrack,
                            in: RoundedRectangle(cornerRadius: 10))
        }
        .disabled(month < startMonth)
        .opacity(month < startMonth ? 0.4 : 1)
        .accessibilityLabel(month.formatted(.dateTime.month(.wide).year()))
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var actions: some View {
        HStack(spacing: AppSpacing.md) {
            if expense != nil {
                Button { isConfirmingDelete = true } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.leftTextSecondary)
                        .frame(width: 52, height: 52)
                        .background(Color.leftTrack, in: RoundedRectangle(cornerRadius: 14))
                }
                .accessibilityLabel("Remove recurring expense")
            }
            Button(action: save) {
                Text(expense == nil ? "Add expense" : "Save")
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
            expense.startsOn = startsOn
            expense.endsAfter = draftEndsAfter
        } else {
            plan.fixedExpenses.append(
                FixedExpense(name: trimmedName,
                             amount: draftAmount,
                             cadence: draftCadence,
                             startsOn: startsOn,
                             endsAfter: draftEndsAfter)
            )
        }
        HapticFeedback.lightImpact()
        dismiss()
    }
}

private struct EndDateRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

// UIKit owns the bottom anchor so it follows the presentation controller's
// animated bounds, rather than SwiftUI's immediately updated target size.
private struct ExpenseSheetFooter<Content: View>: UIViewControllerRepresentable {
    @ViewBuilder var content: () -> Content

    func makeUIViewController(context: Context) -> FooterController<Content> {
        FooterController(content: content())
    }

    func updateUIViewController(_ controller: FooterController<Content>, context: Context) {
        controller.host.rootView = content()
        controller.host.view.invalidateIntrinsicContentSize()
    }

    static func dismantleUIViewController(_ controller: FooterController<Content>, coordinator: ()) {
        controller.removeFooter()
    }
}

private final class FooterController<Content: View>: UIViewController {
    let host: UIHostingController<Content>

    init(content: Content) {
        host = UIHostingController(rootView: content)
        host.sizingOptions = .intrinsicContentSize
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func loadView() {
        view = UIView()
        view.isUserInteractionEnabled = false
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        attachFooter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        attachFooter()
    }

    private func attachFooter() {
        guard host.parent == nil else { return }
        var target: UIViewController? = parent
        while let controller = target, !(controller.presentationController is UISheetPresentationController) {
            target = controller.parent
        }
        guard let target else { return }
        target.addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        target.view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: target.view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: target.view.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: target.view.keyboardLayoutGuide.topAnchor)
        ])
        host.didMove(toParent: target)
        target.view.layoutIfNeeded()
    }

    func removeFooter() {
        host.willMove(toParent: nil)
        host.view.removeFromSuperview()
        host.removeFromParent()
    }
}

private struct ExpensePickerHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct ExpenseActionsHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct ExpenseSheetHeight: PreferenceKey {
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
