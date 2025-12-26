import Foundation

struct Transaction: Identifiable, Codable {
    let id: String
    let accountId: String
    let amount: Double
    let date: Date
    let merchantName: String?
    let category: [String]
    let pending: Bool

    var primaryCategory: String {
        category.first ?? "Other"
    }

    var isExpense: Bool {
        amount > 0
    }
}

enum TransactionCategory: String, CaseIterable, Codable {
    case food = "Food & Dining"
    case shopping = "Shopping"
    case transportation = "Transportation"
    case entertainment = "Entertainment"
    case utilities = "Utilities"
    case healthcare = "Healthcare"
    case travel = "Travel"
    case personal = "Personal"
    case income = "Income"
    case other = "Other"

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .shopping: return "bag.fill"
        case .transportation: return "car.fill"
        case .entertainment: return "tv.fill"
        case .utilities: return "house.fill"
        case .healthcare: return "cross.case.fill"
        case .travel: return "airplane"
        case .personal: return "person.fill"
        case .income: return "dollarsign.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    static func categorize(_ plaidCategories: [String]) -> TransactionCategory {
        guard let primary = plaidCategories.first?.lowercased() else {
            return .other
        }

        if primary.contains("food") || primary.contains("restaurant") {
            return .food
        } else if primary.contains("shop") || primary.contains("retail") {
            return .shopping
        } else if primary.contains("transport") || primary.contains("gas") {
            return .transportation
        } else if primary.contains("entertainment") || primary.contains("recreation") {
            return .entertainment
        } else if primary.contains("utilities") || primary.contains("telecom") {
            return .utilities
        } else if primary.contains("healthcare") || primary.contains("medical") {
            return .healthcare
        } else if primary.contains("travel") {
            return .travel
        } else if primary.contains("income") || primary.contains("payment") {
            return .income
        } else {
            return .other
        }
    }
}
