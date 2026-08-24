import XCTest
import SwiftData
@testable import Left

final class LeftTests: XCTestCase {
    @MainActor
    func testJSONExportImportRoundTripPreservesGraphAndIsIdempotent() throws {
#if DEBUG
        let source = try makeContainer()
        let sourceContext = source.mainContext
        let month = Date(timeIntervalSince1970: 1_787_616_000)
        let planID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let plan = MonthPlan(monthStart: month, monthlyIncome: Decimal(string: "6200.25")!,
                             savingsGoal: Decimal(string: "1000.10")!, savingsPercent: Decimal(string: "20.5")!,
                             incomeCadence: .variable, createdAt: month, id: planID)
        plan.incomeConfirmedAt = month.addingTimeInterval(60)
        plan.carriedGross = Decimal(string: "41.17")!
        plan.carriedAllocated = Decimal(string: "12.34")!
        plan.carryAnnouncedAt = month.addingTimeInterval(120)

        let income = IncomeSource(name: "Consulting", amount: Decimal(string: "5200.15")!, cadence: .variable,
                                  affirmedAt: month.addingTimeInterval(180), inherited: true, startsOn: month,
                                  endsAfter: month, id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let goal = SavingsGoal(name: "Emergency fund", amount: Decimal(string: "500.05")!,
                               percent: Decimal(string: "12.5")!, id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!)
        let allocation = SavingsAllocation(name: "Roth IRA", amount: Decimal(string: "275.19")!,
                                           date: month.addingTimeInterval(240), confirmedAt: month.addingTimeInterval(300),
                                           id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        let expense = FixedExpense(name: "Rent", amount: Decimal(string: "1840.99")!, cadence: .annually,
                                   startsOn: month, endsAfter: month,
                                   id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!)
        let transaction = Transaction(amount: Decimal(string: "6.50")!, date: month.addingTimeInterval(360),
                                      category: .coffee, note: "Screenshot coffee",
                                      id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!)
        plan.incomeSources = [income]
        plan.savingsGoals = [goal]
        plan.savingsAllocations = [allocation]
        plan.fixedExpenses = [expense]
        plan.transactions = [transaction]
        sourceContext.insert(plan)
        try sourceContext.save()

        let exportURL = try LeftDataTransfer.export(from: sourceContext, now: month)
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let pending = try LeftDataTransfer.decodeImport(at: exportURL)
        XCTAssertEqual(pending.counts, ImportCounts(monthPlans: 1, incomeSources: 1, savingsGoals: 1,
                                                    savingsAllocations: 1, fixedExpenses: 1, transactions: 1))

        let destination = try makeContainer()
        let destinationContext = destination.mainContext
        let placeholder = MonthPlan(monthStart: month, monthlyIncome: 1, savingsGoal: 0)
        let placeholderTransaction = Transaction(amount: 1, date: month, category: .other)
        let placeholderTransactionID = placeholderTransaction.id
        placeholder.transactions = [placeholderTransaction]
        destinationContext.insert(placeholder)
        try destinationContext.save()

        XCTAssertThrowsError(try LeftDataTransfer.importEnvelope(pending.envelope,
                                                                 into: destinationContext))
        try LeftDataTransfer.importEnvelope(pending.envelope,
                                            into: destinationContext,
                                            monthConflictPolicy: .overwrite)
        try assertImportedGraph(in: destinationContext, planID: planID)
        XCTAssertFalse(try destinationContext.fetch(FetchDescriptor<Transaction>())
            .contains { $0.id == placeholderTransactionID })
        try LeftDataTransfer.importEnvelope(pending.envelope, into: destinationContext)
        try assertImportedGraph(in: destinationContext, planID: planID)
#endif
    }

#if DEBUG
    private func makeContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: PersistentStore.schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: PersistentStore.schema, configurations: [configuration])
    }

    private func assertImportedGraph(in context: ModelContext, planID: UUID) throws {
        let plans = try context.fetch(FetchDescriptor<MonthPlan>())
        let incomes = try context.fetch(FetchDescriptor<IncomeSource>())
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>())
        let allocations = try context.fetch(FetchDescriptor<SavingsAllocation>())
        let expenses = try context.fetch(FetchDescriptor<FixedExpense>())
        let transactions = try context.fetch(FetchDescriptor<Transaction>())
        XCTAssertEqual([plans.count, incomes.count, goals.count, allocations.count, expenses.count, transactions.count],
                       [1, 1, 1, 1, 1, 1])

        let plan = try XCTUnwrap(plans.first)
        XCTAssertEqual(plan.id, planID)
        XCTAssertEqual(plan.monthlyIncome, Decimal(string: "6200.25")!)
        XCTAssertEqual(plan.savingsPercent, Decimal(string: "20.5")!)
        XCTAssertEqual(plan.incomeSources.map(\.id), incomes.map(\.id))
        XCTAssertEqual(plan.savingsGoals.map(\.id), goals.map(\.id))
        XCTAssertEqual(plan.savingsAllocations.map(\.id), allocations.map(\.id))
        XCTAssertEqual(plan.fixedExpenses.map(\.id), expenses.map(\.id))
        XCTAssertEqual(plan.transactions.map(\.id), transactions.map(\.id))
        XCTAssertEqual(incomes.first?.plan?.id, planID)
        XCTAssertEqual(goals.first?.plan?.id, planID)
        XCTAssertEqual(allocations.first?.plan?.id, planID)
        XCTAssertEqual(expenses.first?.plan?.id, planID)
        XCTAssertEqual(transactions.first?.plan?.id, planID)
        XCTAssertEqual(transactions.first?.amount, Decimal(string: "6.50")!)
        XCTAssertEqual(transactions.first?.category, .coffee)
        XCTAssertEqual(transactions.first?.note, "Screenshot coffee")
    }
#endif
}
