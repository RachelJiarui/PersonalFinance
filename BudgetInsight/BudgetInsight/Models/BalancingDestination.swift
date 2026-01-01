import Foundation

enum BalancingDestinationType {
    case existingFund(String)  // Fund ID
    case newFund(name: String, icon: String, description: String)
    case existingDebt(String)  // Debt ID
    case newDebt(name: String, icon: String, description: String, goal: Double)
}

struct BalancingDestination {
    let type: BalancingDestinationType
    let amount: Double
}
