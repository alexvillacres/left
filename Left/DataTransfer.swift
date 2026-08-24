#if DEBUG
import Foundation
import SwiftData

struct LeftExportEnvelope: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let exportedAt: Date
    let records: LeftExportRecords
}

struct LeftExportRecords: Codable {
    let monthPlans: [MonthPlanDTO]
    let incomeSources: [IncomeSourceDTO]
    let savingsGoals: [SavingsGoalDTO]
    let savingsAllocations: [SavingsAllocationDTO]
    let fixedExpenses: [FixedExpenseDTO]
    let transactions: [TransactionDTO]

    var counts: ImportCounts {
        ImportCounts(monthPlans: monthPlans.count,
                     incomeSources: incomeSources.count,
                     savingsGoals: savingsGoals.count,
                     savingsAllocations: savingsAllocations.count,
                     fixedExpenses: fixedExpenses.count,
                     transactions: transactions.count)
    }
}

struct MonthPlanDTO: Codable {
    let id: UUID
    let monthStart: Date
    let monthlyIncome: String
    let savingsGoal: String
    let savingsPercent: String?
    let incomeCadence: String?
    let incomeConfirmedAt: Date?
    let createdAt: Date?
    let carriedGross: String?
    let carriedAllocated: String
    let carryAnnouncedAt: Date?
    let incomeSourceIDs: [UUID]
    let savingsGoalIDs: [UUID]
    let savingsAllocationIDs: [UUID]
    let fixedExpenseIDs: [UUID]
    let transactionIDs: [UUID]
}

struct IncomeSourceDTO: Codable {
    let id: UUID
    let name: String
    let amount: String
    let cadence: String?
    let affirmedAt: Date?
    let inherited: Bool
    let startsOn: Date?
    let endsAfter: Date?
    let planID: UUID?
}

struct SavingsGoalDTO: Codable {
    let id: UUID
    let name: String
    let amount: String
    let percent: String?
    let planID: UUID?
}

struct SavingsAllocationDTO: Codable {
    let id: UUID
    let name: String
    let amount: String
    let date: Date
    let confirmedAt: Date?
    let planID: UUID?
}

struct FixedExpenseDTO: Codable {
    let id: UUID
    let name: String
    let amount: String
    let cadence: String?
    let startsOn: Date?
    let endsAfter: Date?
    let planID: UUID?
}

struct TransactionDTO: Codable {
    let id: UUID
    let amount: String
    let date: Date
    let category: String
    let note: String?
    let planID: UUID?
}

struct ImportCounts: Equatable {
    let monthPlans: Int
    let incomeSources: Int
    let savingsGoals: Int
    let savingsAllocations: Int
    let fixedExpenses: Int
    let transactions: Int

    var rows: [(String, Int)] {
        [
            ("Month plans", monthPlans),
            ("Income sources", incomeSources),
            ("Savings goals", savingsGoals),
            ("Savings allocations", savingsAllocations),
            ("Fixed expenses", fixedExpenses),
            ("Transactions", transactions),
        ]
    }
}

struct PendingLeftImport {
    let envelope: LeftExportEnvelope
    let sourceURL: URL
    var counts: ImportCounts { envelope.records.counts }
}

enum LeftDataTransferError: LocalizedError {
    case unsupportedSchema(Int)
    case invalidDecimal(field: String, recordID: UUID, value: String)
    case invalidEnum(field: String, recordID: UUID, value: String)
    case duplicateID(type: String, id: UUID)
    case missingReference(type: String, recordID: UUID, field: String, referencedID: UUID)
    case inconsistentRelationship(type: String, recordID: UUID, planID: UUID)
    case monthConflict(month: Date, existingID: UUID, importedID: UUID)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            "This backup uses schema version \(version). This build supports version \(LeftExportEnvelope.currentSchemaVersion)."
        case .invalidDecimal(let field, let id, let value):
            "Record \(id) has an invalid decimal for \(field): \(value)."
        case .invalidEnum(let field, let id, let value):
            "Record \(id) has an unknown value for \(field): \(value)."
        case .duplicateID(let type, let id):
            "The backup contains duplicate \(type) id \(id)."
        case .missingReference(let type, let id, let field, let referencedID):
            "\(type) \(id) references missing \(field) id \(referencedID)."
        case .inconsistentRelationship(let type, let id, let planID):
            "\(type) \(id) and month plan \(planID) disagree about their relationship."
        case .monthConflict(let month, let existingID, let importedID):
            "A plan for \(month.formatted(date: .abbreviated, time: .omitted)) already exists with id \(existingID), but the backup uses id \(importedID)."
        }
    }
}

enum MonthConflictPolicy {
    case fail
    case overwrite
}

enum LeftDataTransfer {
    static func export(from context: ModelContext, now: Date = .now) throws -> URL {
        let envelope = try makeEnvelope(from: context, exportedAt: now)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(envelope)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        let filename = "left-export-\(formatter.string(from: now)).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url, options: .atomic)
        return url
    }

    static func makeEnvelope(from context: ModelContext,
                             exportedAt: Date = .now) throws -> LeftExportEnvelope {
        let plans = try context.fetch(FetchDescriptor<MonthPlan>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let incomes = try context.fetch(FetchDescriptor<IncomeSource>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let goals = try context.fetch(FetchDescriptor<SavingsGoal>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let allocations = try context.fetch(FetchDescriptor<SavingsAllocation>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let expenses = try context.fetch(FetchDescriptor<FixedExpense>()).sorted { $0.id.uuidString < $1.id.uuidString }
        let transactions = try context.fetch(FetchDescriptor<Transaction>()).sorted { $0.id.uuidString < $1.id.uuidString }

        let records = LeftExportRecords(
            monthPlans: plans.map {
                MonthPlanDTO(id: $0.id,
                             monthStart: $0.monthStart,
                             monthlyIncome: decimalString($0.monthlyIncome),
                             savingsGoal: decimalString($0.savingsGoal),
                             savingsPercent: $0.savingsPercent.map(decimalString),
                             incomeCadence: $0.incomeCadence?.rawValue,
                             incomeConfirmedAt: $0.incomeConfirmedAt,
                             createdAt: $0.createdAt,
                             carriedGross: $0.carriedGross.map(decimalString),
                             carriedAllocated: decimalString($0.carriedAllocated),
                             carryAnnouncedAt: $0.carryAnnouncedAt,
                             incomeSourceIDs: $0.incomeSources.map(\.id).sorted(by: uuidOrder),
                             savingsGoalIDs: $0.savingsGoals.map(\.id).sorted(by: uuidOrder),
                             savingsAllocationIDs: $0.savingsAllocations.map(\.id).sorted(by: uuidOrder),
                             fixedExpenseIDs: $0.fixedExpenses.map(\.id).sorted(by: uuidOrder),
                             transactionIDs: $0.transactions.map(\.id).sorted(by: uuidOrder))
            },
            incomeSources: incomes.map {
                IncomeSourceDTO(id: $0.id, name: $0.name, amount: decimalString($0.amount),
                                cadence: $0.cadence?.rawValue, affirmedAt: $0.affirmedAt,
                                inherited: $0.inherited, startsOn: $0.startsOn, endsAfter: $0.endsAfter,
                                planID: $0.plan?.id)
            },
            savingsGoals: goals.map {
                SavingsGoalDTO(id: $0.id, name: $0.name, amount: decimalString($0.amount),
                               percent: $0.percent.map(decimalString), planID: $0.plan?.id)
            },
            savingsAllocations: allocations.map {
                SavingsAllocationDTO(id: $0.id, name: $0.name, amount: decimalString($0.amount),
                                     date: $0.date, confirmedAt: $0.confirmedAt, planID: $0.plan?.id)
            },
            fixedExpenses: expenses.map {
                FixedExpenseDTO(id: $0.id, name: $0.name, amount: decimalString($0.amount),
                                cadence: $0.cadence?.rawValue, startsOn: $0.startsOn,
                                endsAfter: $0.endsAfter, planID: $0.plan?.id)
            },
            transactions: transactions.map {
                TransactionDTO(id: $0.id, amount: decimalString($0.amount), date: $0.date,
                               category: $0.category.rawValue, note: $0.note, planID: $0.plan?.id)
            })
        return LeftExportEnvelope(schemaVersion: LeftExportEnvelope.currentSchemaVersion,
                                  exportedAt: exportedAt,
                                  records: records)
    }

    static func decodeImport(at url: URL) throws -> PendingLeftImport {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let envelope = try decoder.decode(LeftExportEnvelope.self, from: data)
        guard envelope.schemaVersion == LeftExportEnvelope.currentSchemaVersion else {
            throw LeftDataTransferError.unsupportedSchema(envelope.schemaVersion)
        }
        try validate(envelope.records)
        return PendingLeftImport(envelope: envelope, sourceURL: url)
    }

    static func importEnvelope(_ envelope: LeftExportEnvelope,
                               into context: ModelContext,
                               monthConflictPolicy: MonthConflictPolicy = .fail) throws {
        guard envelope.schemaVersion == LeftExportEnvelope.currentSchemaVersion else {
            throw LeftDataTransferError.unsupportedSchema(envelope.schemaVersion)
        }
        try validate(envelope.records)
        let records = envelope.records

        do {
            var plans = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<MonthPlan>()).map { ($0.id, $0) })
            var incomes = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<IncomeSource>()).map { ($0.id, $0) })
            var goals = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SavingsGoal>()).map { ($0.id, $0) })
            var allocations = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<SavingsAllocation>()).map { ($0.id, $0) })
            var expenses = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<FixedExpense>()).map { ($0.id, $0) })
            var transactions = Dictionary(uniqueKeysWithValues: try context.fetch(FetchDescriptor<Transaction>()).map { ($0.id, $0) })

            let existingMonths = try context.fetch(FetchDescriptor<MonthPlan>())
            for dto in records.monthPlans {
                if let conflict = existingMonths.first(where: { $0.monthStart == dto.monthStart && $0.id != dto.id }) {
                    guard monthConflictPolicy == .overwrite else {
                        throw LeftDataTransferError.monthConflict(month: dto.monthStart,
                                                                  existingID: conflict.id,
                                                                  importedID: dto.id)
                    }

                    // Reuse the existing MonthPlan row so the unique
                    // monthStart constraint is never temporarily violated.
                    // Its owned records are replaced by the backup's graph.
                    let previousID = conflict.id
                    for object in conflict.incomeSources {
                        incomes.removeValue(forKey: object.id); context.delete(object)
                    }
                    for object in conflict.savingsGoals {
                        goals.removeValue(forKey: object.id); context.delete(object)
                    }
                    for object in conflict.savingsAllocations {
                        allocations.removeValue(forKey: object.id); context.delete(object)
                    }
                    for object in conflict.fixedExpenses {
                        expenses.removeValue(forKey: object.id); context.delete(object)
                    }
                    for object in conflict.transactions {
                        transactions.removeValue(forKey: object.id); context.delete(object)
                    }
                    conflict.incomeSources = []
                    conflict.savingsGoals = []
                    conflict.savingsAllocations = []
                    conflict.fixedExpenses = []
                    conflict.transactions = []
                    plans.removeValue(forKey: previousID)
                    conflict.stableID = dto.id
                    plans[dto.id] = conflict
                }
                let plan = plans[dto.id] ?? MonthPlan(monthStart: dto.monthStart,
                                                      monthlyIncome: 0,
                                                      savingsGoal: 0,
                                                      id: dto.id)
                if plans[dto.id] == nil { context.insert(plan); plans[dto.id] = plan }
                plan.monthStart = dto.monthStart
                plan.monthlyIncome = try decimal(dto.monthlyIncome, field: "monthlyIncome", id: dto.id)
                plan.savingsGoal = try decimal(dto.savingsGoal, field: "savingsGoal", id: dto.id)
                plan.savingsPercent = try optionalDecimal(dto.savingsPercent, field: "savingsPercent", id: dto.id)
                plan.incomeCadence = try optionalEnum(dto.incomeCadence, field: "incomeCadence", id: dto.id)
                plan.incomeConfirmedAt = dto.incomeConfirmedAt
                plan.createdAt = dto.createdAt
                plan.carriedGross = try optionalDecimal(dto.carriedGross, field: "carriedGross", id: dto.id)
                plan.carriedAllocated = try decimal(dto.carriedAllocated, field: "carriedAllocated", id: dto.id)
                plan.carryAnnouncedAt = dto.carryAnnouncedAt
            }

            for dto in records.incomeSources {
                let object = incomes[dto.id] ?? IncomeSource(name: dto.name, amount: 0, id: dto.id)
                if incomes[dto.id] == nil { context.insert(object); incomes[dto.id] = object }
                object.name = dto.name
                object.amount = try decimal(dto.amount, field: "amount", id: dto.id)
                object.cadence = try optionalEnum(dto.cadence, field: "cadence", id: dto.id)
                object.affirmedAt = dto.affirmedAt; object.inherited = dto.inherited
                object.startsOn = dto.startsOn; object.endsAfter = dto.endsAfter
            }
            for dto in records.savingsGoals {
                let object = goals[dto.id] ?? SavingsGoal(name: dto.name, amount: 0, id: dto.id)
                if goals[dto.id] == nil { context.insert(object); goals[dto.id] = object }
                object.name = dto.name
                object.amount = try decimal(dto.amount, field: "amount", id: dto.id)
                object.percent = try optionalDecimal(dto.percent, field: "percent", id: dto.id)
            }
            for dto in records.savingsAllocations {
                let object = allocations[dto.id] ?? SavingsAllocation(name: dto.name, amount: 0, date: dto.date, id: dto.id)
                if allocations[dto.id] == nil { context.insert(object); allocations[dto.id] = object }
                object.name = dto.name; object.amount = try decimal(dto.amount, field: "amount", id: dto.id)
                object.date = dto.date; object.confirmedAt = dto.confirmedAt
            }
            for dto in records.fixedExpenses {
                let object = expenses[dto.id] ?? FixedExpense(name: dto.name, amount: 0, id: dto.id)
                if expenses[dto.id] == nil { context.insert(object); expenses[dto.id] = object }
                object.name = dto.name; object.amount = try decimal(dto.amount, field: "amount", id: dto.id)
                object.cadence = try optionalEnum(dto.cadence, field: "cadence", id: dto.id)
                object.startsOn = dto.startsOn; object.endsAfter = dto.endsAfter
            }
            for dto in records.transactions {
                let category: Category = try requiredEnum(dto.category, field: "category", id: dto.id)
                let object = transactions[dto.id] ?? Transaction(amount: 0, date: dto.date, category: category, id: dto.id)
                if transactions[dto.id] == nil { context.insert(object); transactions[dto.id] = object }
                object.amount = try decimal(dto.amount, field: "amount", id: dto.id)
                object.date = dto.date; object.category = category; object.note = dto.note
            }

            // Pass two: relationship arrays are authoritative and set both sides through SwiftData inverses.
            for dto in records.monthPlans {
                let plan = plans[dto.id]!
                plan.incomeSources = dto.incomeSourceIDs.compactMap { incomes[$0] }
                plan.savingsGoals = dto.savingsGoalIDs.compactMap { goals[$0] }
                plan.savingsAllocations = dto.savingsAllocationIDs.compactMap { allocations[$0] }
                plan.fixedExpenses = dto.fixedExpenseIDs.compactMap { expenses[$0] }
                plan.transactions = dto.transactionIDs.compactMap { transactions[$0] }
            }
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func validate(_ records: LeftExportRecords) throws {
        try unique(records.monthPlans.map(\.id), type: "month plan")
        try unique(records.incomeSources.map(\.id), type: "income source")
        try unique(records.savingsGoals.map(\.id), type: "savings goal")
        try unique(records.savingsAllocations.map(\.id), type: "savings allocation")
        try unique(records.fixedExpenses.map(\.id), type: "fixed expense")
        try unique(records.transactions.map(\.id), type: "transaction")

        let planIDs = Set(records.monthPlans.map(\.id))
        let incomeIDs = Set(records.incomeSources.map(\.id))
        let goalIDs = Set(records.savingsGoals.map(\.id))
        let allocationIDs = Set(records.savingsAllocations.map(\.id))
        let expenseIDs = Set(records.fixedExpenses.map(\.id))
        let transactionIDs = Set(records.transactions.map(\.id))

        for plan in records.monthPlans {
            try references(plan.incomeSourceIDs, in: incomeIDs, type: "Month plan", id: plan.id, field: "income source")
            try references(plan.savingsGoalIDs, in: goalIDs, type: "Month plan", id: plan.id, field: "savings goal")
            try references(plan.savingsAllocationIDs, in: allocationIDs, type: "Month plan", id: plan.id, field: "savings allocation")
            try references(plan.fixedExpenseIDs, in: expenseIDs, type: "Month plan", id: plan.id, field: "fixed expense")
            try references(plan.transactionIDs, in: transactionIDs, type: "Month plan", id: plan.id, field: "transaction")
        }
        try validateChildren(records.incomeSources.map { ($0.id, $0.planID) }, plans: records.monthPlans, planIDs: planIDs, keyPath: \MonthPlanDTO.incomeSourceIDs, type: "Income source")
        try validateChildren(records.savingsGoals.map { ($0.id, $0.planID) }, plans: records.monthPlans, planIDs: planIDs, keyPath: \MonthPlanDTO.savingsGoalIDs, type: "Savings goal")
        try validateChildren(records.savingsAllocations.map { ($0.id, $0.planID) }, plans: records.monthPlans, planIDs: planIDs, keyPath: \MonthPlanDTO.savingsAllocationIDs, type: "Savings allocation")
        try validateChildren(records.fixedExpenses.map { ($0.id, $0.planID) }, plans: records.monthPlans, planIDs: planIDs, keyPath: \MonthPlanDTO.fixedExpenseIDs, type: "Fixed expense")
        try validateChildren(records.transactions.map { ($0.id, $0.planID) }, plans: records.monthPlans, planIDs: planIDs, keyPath: \MonthPlanDTO.transactionIDs, type: "Transaction")

        for dto in records.monthPlans {
            _ = try decimal(dto.monthlyIncome, field: "monthlyIncome", id: dto.id)
            _ = try decimal(dto.savingsGoal, field: "savingsGoal", id: dto.id)
            _ = try optionalDecimal(dto.savingsPercent, field: "savingsPercent", id: dto.id)
            let _: IncomeCadence? = try optionalEnum(dto.incomeCadence, field: "incomeCadence", id: dto.id)
            _ = try optionalDecimal(dto.carriedGross, field: "carriedGross", id: dto.id)
            _ = try decimal(dto.carriedAllocated, field: "carriedAllocated", id: dto.id)
        }
        for dto in records.incomeSources {
            _ = try decimal(dto.amount, field: "amount", id: dto.id)
            let _: IncomeCadence? = try optionalEnum(dto.cadence, field: "cadence", id: dto.id)
        }
        for dto in records.savingsGoals {
            _ = try decimal(dto.amount, field: "amount", id: dto.id)
            _ = try optionalDecimal(dto.percent, field: "percent", id: dto.id)
        }
        for dto in records.savingsAllocations { _ = try decimal(dto.amount, field: "amount", id: dto.id) }
        for dto in records.fixedExpenses {
            _ = try decimal(dto.amount, field: "amount", id: dto.id)
            let _: ExpenseCadence? = try optionalEnum(dto.cadence, field: "cadence", id: dto.id)
        }
        for dto in records.transactions {
            _ = try decimal(dto.amount, field: "amount", id: dto.id)
            let _: Category = try requiredEnum(dto.category, field: "category", id: dto.id)
        }
    }

    private static func validateChildren(_ children: [(UUID, UUID?)],
                                         plans: [MonthPlanDTO],
                                         planIDs: Set<UUID>,
                                         keyPath: KeyPath<MonthPlanDTO, [UUID]>,
                                         type: String) throws {
        for (id, planID) in children {
            guard let planID else { continue }
            guard planIDs.contains(planID) else {
                throw LeftDataTransferError.missingReference(type: type, recordID: id, field: "month plan", referencedID: planID)
            }
            guard plans.first(where: { $0.id == planID })?[keyPath: keyPath].contains(id) == true else {
                throw LeftDataTransferError.inconsistentRelationship(type: type, recordID: id, planID: planID)
            }
        }
    }

    private static func references(_ ids: [UUID], in available: Set<UUID>, type: String, id: UUID, field: String) throws {
        for reference in ids where !available.contains(reference) {
            throw LeftDataTransferError.missingReference(type: type, recordID: id, field: field, referencedID: reference)
        }
    }

    private static func unique(_ ids: [UUID], type: String) throws {
        var seen = Set<UUID>()
        for id in ids where !seen.insert(id).inserted {
            throw LeftDataTransferError.duplicateID(type: type, id: id)
        }
    }

    nonisolated private static func decimalString(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }

    private static func decimal(_ value: String, field: String, id: UUID) throws -> Decimal {
        guard let result = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            throw LeftDataTransferError.invalidDecimal(field: field, recordID: id, value: value)
        }
        return result
    }

    private static func optionalDecimal(_ value: String?, field: String, id: UUID) throws -> Decimal? {
        guard let value else { return nil }
        return try decimal(value, field: field, id: id)
    }

    private static func optionalEnum<T: RawRepresentable>(_ value: String?, field: String, id: UUID) throws -> T? where T.RawValue == String {
        guard let value else { return nil }
        return try requiredEnum(value, field: field, id: id)
    }

    private static func requiredEnum<T: RawRepresentable>(_ value: String, field: String, id: UUID) throws -> T where T.RawValue == String {
        guard let result = T(rawValue: value) else {
            throw LeftDataTransferError.invalidEnum(field: field, recordID: id, value: value)
        }
        return result
    }

    nonisolated private static func uuidOrder(_ lhs: UUID, _ rhs: UUID) -> Bool {
        lhs.uuidString < rhs.uuidString
    }
}
#endif
