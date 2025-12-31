import SwiftUI

struct PerennialView: View {
    @ObservedObject var fundService = FundService.shared
    @ObservedObject var debtService = DebtService.shared

    @State private var showAddFund = false
    @State private var showAddDebt = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: - Funds Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Funds", systemImage: "banknote")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            showAddFund = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal)

                    if fundService.getActiveFunds().isEmpty {
                        EmptyStateView(
                            icon: "dollarsign.circle",
                            title: "No Funds Yet",
                            description: "Create funds to save for larger purchases or goals",
                            actionText: "Add Fund",
                            action: {
                                showAddFund = true
                            }
                        )
                    } else {
                        ForEach(fundService.getActiveFunds()) { fund in
                            NavigationLink(destination: FundDetailView(fund: fund)) {
                                FundCard(fund: fund)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                Divider()
                    .padding(.vertical)

                // MARK: - Debts Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Debts", systemImage: "creditcard")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: {
                            showAddDebt = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal)

                    if debtService.getActiveDebts().isEmpty {
                        EmptyStateView(
                            icon: "creditcard",
                            title: "No Debts",
                            description:
                                "Debts are created when you overspend and need to pay back later",
                            actionText: "Add Debt",
                            action: {
                                showAddDebt = true
                            }
                        )
                    } else {
                        ForEach(debtService.getActiveDebts()) { debt in
                            NavigationLink(destination: DebtDetailView(debt: debt)) {
                                DebtCard(debt: debt)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Perennial")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(
                        role: .destructive,
                        action: {
                            clearAllLocalData()
                        }
                    ) {
                        Label("Clear All Local Data", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddFund) {
            AddFundView()
        }
        .sheet(isPresented: $showAddDebt) {
            AddDebtView()
        }
    }

    // MARK: - Helper Methods

    private func clearAllLocalData() {
        fundService.clearAllData()
        debtService.clearAllData()
        print("✅ Cleared all local Fund and Debt data")
    }
}

// MARK: - Fund Card

struct FundCard: View {
    let fund: Fund

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: fund.icon)
                    .font(.title2)
                    .foregroundColor(.green)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(fund.name)
                        .font(.headline)
                    if !fund.description.isEmpty {
                        Text(fund.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("$\(String(format: "%.2f", fund.balance))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    if let goal = fund.goal {
                        Text("of $\(String(format: "%.0f", goal))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Progress bar if goal exists
            if let progressRatio = fund.progressRatio() {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(fund.isGoalMet() ? Color.green : Color.blue)
                            .frame(
                                width: geometry.size.width * CGFloat(progressRatio), height: 8
                            )
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }

            // Deadline if exists
            if let deadline = fund.deadline {
                HStack {
                    Image(systemName: "calendar")
                        .font(.caption)
                    Text("Due: \(formattedDate(deadline))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Debt Card

struct DebtCard: View {
    let debt: Debt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: debt.icon)
                    .font(.title2)
                    .foregroundColor(.orange)
                    .frame(width: 40)

                VStack(alignment: .leading) {
                    Text(debt.name)
                        .font(.headline)
                    if !debt.description.isEmpty {
                        Text(debt.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("$\(String(format: "%.2f", debt.balance))")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    Text("of $\(String(format: "%.0f", debt.goal))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Progress bar (shows how much has been paid off)
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)

                    Rectangle()
                        .fill(debt.isPaidOff() ? Color.green : Color.orange)
                        .frame(
                            width: geometry.size.width * CGFloat(debt.progressRatio()),
                            height: 8
                        )
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)

            HStack {
                if let deadline = debt.deadline {
                    HStack {
                        Image(systemName: "calendar")
                            .font(.caption)
                        Text("Due: \(formattedDate(deadline))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Text("$\(String(format: "%.2f", debt.remainingToPay())) left")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .padding(.horizontal)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let description: String
    let actionText: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button(action: action) {
                Text(actionText)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Add Fund View

struct AddFundView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var fundService = FundService.shared

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = "dollarsign.circle"
    @State private var hasGoal: Bool = false
    @State private var goal: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Fund Details")) {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)

                    NavigationLink(destination: IconPickerView(selectedIcon: $icon)) {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.green)
                        }
                    }
                }

                Section(header: Text("Goal (Optional)")) {
                    Toggle("Set Goal", isOn: $hasGoal)

                    if hasGoal {
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $goal)
                                .keyboardType(.decimalPad)
                        }
                    }
                }

                Section(header: Text("Deadline (Optional)")) {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            displayedComponents: [.date]
                        )
                    }
                }
            }
            .navigationTitle("Add Fund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        saveFund()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveFund() {
        let goalValue = hasGoal ? Double(goal) : nil
        let deadlineValue = hasDeadline ? deadline : nil

        _ = fundService.createFund(
            name: name,
            icon: icon,
            description: description,
            balance: 0.0,
            goal: goalValue,
            deadline: deadlineValue
        )

        dismiss()
    }
}

// MARK: - Add Debt View

struct AddDebtView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var debtService = DebtService.shared

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var icon: String = "creditcard"
    @State private var goal: String = ""
    @State private var hasDeadline: Bool = false
    @State private var deadline: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Debt Details")) {
                    TextField("Name", text: $name)
                    TextField("Description (optional)", text: $description)

                    NavigationLink(destination: IconPickerView(selectedIcon: $icon)) {
                        HStack {
                            Text("Icon")
                            Spacer()
                            Image(systemName: icon)
                                .foregroundColor(.orange)
                        }
                    }
                }

                Section(header: Text("Total to Pay Off")) {
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        TextField("500", text: $goal)
                            .keyboardType(.decimalPad)
                    }
                }

                Section(header: Text("Deadline (Optional)")) {
                    Toggle("Set Deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $deadline,
                            displayedComponents: [.date]
                        )
                    }
                }

                Section {
                    Text(
                        "The debt will start at the total amount and decrease as you allocate income transactions to it."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Debt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        saveDebt()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isValid: Bool {
        !name.isEmpty && Double(goal) != nil
    }

    private func saveDebt() {
        guard let goalValue = Double(goal) else {
            return
        }

        let deadlineValue = hasDeadline ? deadline : nil

        _ = debtService.createDebt(
            name: name,
            icon: icon,
            description: description,
            balance: goalValue,  // Start with balance = goal (full debt amount)
            goal: goalValue,
            deadline: deadlineValue
        )

        dismiss()
    }
}

// MARK: - Icon Picker View

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) var dismiss

    let icons = [
        "dollarsign.circle", "banknote", "creditcard", "bag", "cart", "house",
        "car", "airplane", "gift", "fork.knife", "book", "graduationcap",
        "heart", "star", "flag", "trophy", "tv", "gamecontroller",
        "music.note", "camera", "photo", "paintbrush", "wrench", "hammer",
    ]

    let columns = [
        GridItem(.adaptive(minimum: 60))
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(icons, id: \.self) { icon in
                    Button(action: {
                        selectedIcon = icon
                        dismiss()
                    }) {
                        VStack {
                            Image(systemName: icon)
                                .font(.largeTitle)
                                .foregroundColor(selectedIcon == icon ? .blue : .primary)
                                .frame(width: 60, height: 60)
                                .background(
                                    selectedIcon == icon
                                        ? Color.blue.opacity(0.1) : Color.clear
                                )
                                .cornerRadius(10)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Select Icon")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Preview

struct PerennialView_Previews: PreviewProvider {
    static var previews: some View {
        PerennialView()
    }
}
