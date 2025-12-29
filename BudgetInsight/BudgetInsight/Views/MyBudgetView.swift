import SwiftUI

struct MyBudgetView: View {
    @EnvironmentObject var viewModel: BudgetViewModel
    @State private var showAddCategory = false
    @State private var showClearDataAlert = false
    @State private var showTaxBreakdown = false
    @State private var isEditing = false

    // Temporary state for editing
    @State private var editAnnualSalary: String = ""
    @State private var editContribution401k: String = ""
    @State private var editCategories: [BudgetCategory] = []

    var body: some View {
        Form {
            // MARK: - Income Section
            Section(header: Text("Income")) {
                if isEditing {
                    // Edit Mode - Form-like with text fields
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Annual Salary")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Enter amount", text: $editAnnualSalary)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("401k Contribution")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("Enter amount", text: $editContribution401k)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.body)
                    }
                    .padding(.vertical, 4)
                } else {
                    // View Mode - Clean, read-only presentation with currency formatting
                    if !viewModel.annualSalaryInput.isEmpty {
                        HStack {
                            Text("Annual Salary")
                            Spacer()
                            Text(formatCurrency(viewModel.annualSalaryInput))
                                .foregroundColor(.primary)
                        }
                    }

                    if !viewModel.contribution401kInput.isEmpty {
                        HStack {
                            Text("401k Contribution")
                            Spacer()
                            Text(formatCurrency(viewModel.contribution401kInput))
                                .foregroundColor(.primary)
                        }
                    }
                }
            }

            // MARK: - Take Home & Tax Info
            if let income = viewModel.userIncome {
                Section(header: Text("Take Home")) {
                    HStack {
                        Text("Annual Take Home")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("$\(Int(income.annualTakeHome))")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Text("Monthly Take Home")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("$\(Int(income.monthlyTakeHome))")
                            .fontWeight(.bold)
                            .foregroundColor(.green)
                    }

                    // Tax Breakdown in Disclosure Group
                    DisclosureGroup(
                        isExpanded: $showTaxBreakdown,
                        content: {
                            TaxRow(label: "Federal Tax", amount: income.federalTax)
                            TaxRow(label: "Social Security", amount: income.socialSecurityTax)
                            TaxRow(label: "Medicare", amount: income.medicareTax)
                            TaxRow(label: "NY State Tax", amount: income.nyStateTax)
                            TaxRow(label: "NYC Tax", amount: income.nycTax)
                        },
                        label: {
                            HStack {
                                Text("Total Taxes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("$\(Int(income.totalTaxes))")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
                }
            }

            // MARK: - Budget Allocation
            if let income = viewModel.userIncome {
                let categories =
                    isEditing ? editCategories : viewModel.budgetCategories.filter { $0.isActive }
                let totalPercentage = categories.reduce(0.0) { $0 + $1.percentage }
                let remainingPercentage = 100.0 - totalPercentage

                Section(
                    header:
                        HStack {
                            Text("Budget Allocation")
                            Spacer()
                            if isEditing {
                                Text("\(Int(totalPercentage))% allocated")
                                    .foregroundColor(totalPercentage <= 100 ? .secondary : .red)
                            }
                        }
                ) {
                    ForEach(categories) { category in
                        if isEditing {
                            CategoryAllocationRow(
                                category: category,
                                monthlyTakeHome: income.monthlyTakeHome,
                                isEditing: true,
                                onUpdate: { newPercentage in
                                    if let index = editCategories.firstIndex(where: {
                                        $0.id == category.id
                                    }) {
                                        editCategories[index].percentage = newPercentage
                                    }
                                }
                            )
                        } else {
                            CategoryAllocationRow(
                                category: category,
                                monthlyTakeHome: income.monthlyTakeHome,
                                isEditing: false,
                                onUpdate: { _ in }
                            )
                        }
                    }
                    .onDelete { indexSet in
                        if isEditing {
                            editCategories.remove(atOffsets: indexSet)
                        }
                    }

                    // Remaining percentage display - only in edit mode
                    if isEditing {
                        if remainingPercentage > 0 {
                            HStack {
                                Text("Unallocated")
                                    .foregroundColor(.orange)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(String(format: "%.1f", remainingPercentage))%")
                                Text(
                                    "($\(Int(income.monthlyTakeHome * remainingPercentage / 100)))"
                                )
                                .foregroundColor(.secondary)
                            }
                        } else if remainingPercentage < 0 {
                            HStack {
                                Text("Over Allocated")
                                    .foregroundColor(.red)
                                    .fontWeight(.medium)
                                Spacer()
                                Text("\(String(format: "%.1f", abs(remainingPercentage)))%")
                                    .foregroundColor(.red)
                            }
                        }

                        Button(action: { showAddCategory = true }) {
                            Label("Add Category", systemImage: "plus.circle.fill")
                        }
                    }
                }
            }

            // MARK: - Debug/Reset Section
            Section(header: Text("Reset")) {
                Button(
                    role: .destructive,
                    action: {
                        showClearDataAlert = true
                    }
                ) {
                    Label("Clear All Budget Data", systemImage: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("My Budget")
        .navigationBarBackButtonHidden(isEditing)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isEditing {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(!canSave)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                }
            }

            if isEditing {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        cancelEditing()
                    }
                }
            }
        }
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(
                viewModel: viewModel,
                isEditMode: true,
                onAdd: { category in
                    editCategories.append(category)
                }
            )
        }
        .alert("Clear All Data?", isPresented: $showClearDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                viewModel.clearAllData()
            }
        } message: {
            Text(
                "This will remove all budget categories, income data, and budget plans. This action cannot be undone."
            )
        }
    }

    // MARK: - Helper Functions

    private func formatCurrency(_ value: String) -> String {
        guard let number = Double(value) else { return "$0" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: number)) ?? "$0"
    }

    private var canSave: Bool {
        let totalPercentage = editCategories.reduce(0.0) { $0 + $1.percentage }
        return totalPercentage <= 100.0 && !editAnnualSalary.isEmpty
    }

    private func startEditing() {
        editAnnualSalary = viewModel.annualSalaryInput
        editContribution401k = viewModel.contribution401kInput
        editCategories = viewModel.budgetCategories.filter { $0.isActive }
        isEditing = true
    }

    private func cancelEditing() {
        isEditing = false
        editAnnualSalary = ""
        editContribution401k = ""
        editCategories = []
    }

    private func saveChanges() {
        // Save income changes
        viewModel.annualSalaryInput = editAnnualSalary
        viewModel.contribution401kInput = editContribution401k
        viewModel.updateIncome()

        // Save category changes
        // First, mark all current categories as inactive
        for category in viewModel.budgetCategories {
            if category.isActive {
                viewModel.deleteCategory(categoryId: category.id)
            }
        }

        // Then add all edited categories
        for category in editCategories {
            viewModel.addCategory(
                name: category.name,
                percentage: category.percentage,
                icon: category.icon
            )
        }

        isEditing = false
        editAnnualSalary = ""
        editContribution401k = ""
        editCategories = []
    }
}

struct TaxRow: View {
    let label: String
    let amount: Double

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text("$\(Int(amount))")
                .foregroundColor(.secondary)
        }
    }
}

struct CategoryAllocationRow: View {
    let category: BudgetCategory
    let monthlyTakeHome: Double
    let isEditing: Bool
    let onUpdate: (Double) -> Void

    @State private var percentageInput: String

    init(
        category: BudgetCategory, monthlyTakeHome: Double, isEditing: Bool,
        onUpdate: @escaping (Double) -> Void
    ) {
        self.category = category
        self.monthlyTakeHome = monthlyTakeHome
        self.isEditing = isEditing
        self.onUpdate = onUpdate
        _percentageInput = State(initialValue: String(format: "%.1f", category.percentage))
    }

    var dollarAmount: Double {
        category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
    }

    var body: some View {
        if isEditing {
            // Edit Mode - Form-like with text fields
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.icon)
                        .foregroundColor(.blue)
                    Text(category.name)
                        .fontWeight(.medium)
                    Spacer()
                }

                HStack {
                    TextField("0.0", text: $percentageInput)
                        .keyboardType(.decimalPad)
                        .frame(width: 60)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: percentageInput) { newValue in
                            if let percentage = Double(newValue) {
                                onUpdate(percentage)
                            }
                        }
                        .onAppear {
                            percentageInput = String(format: "%.1f", category.percentage)
                        }

                    Text("%")

                    Spacer()

                    Text("$\(Int(dollarAmount))")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } else {
            // View Mode - Clean, read-only presentation
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(category.name)

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("$\(Int(dollarAmount))")
                        .foregroundColor(.primary)
                    Text("\(String(format: "%.1f", category.percentage))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: BudgetViewModel

    var isEditMode: Bool = false
    var onAdd: ((BudgetCategory) -> Void)? = nil

    @State private var name: String = ""
    @State private var percentage: String = ""
    @State private var selectedIcon: String = "dollarsign.circle"
    @State private var selectedColor: String = "blue"

    let iconOptions = [
        "dollarsign.circle", "cart.fill", "house.fill", "car.fill",
        "fork.knife", "tv.fill", "airplane", "heart.fill",
        "phone.fill", "book.fill", "gamecontroller.fill", "cross.case.fill",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Category Details")) {
                    TextField("Category Name", text: $name)

                    HStack {
                        TextField("Percentage", text: $percentage)
                            .keyboardType(.decimalPad)
                        Text("%")
                    }
                }

                Section(header: Text("Icon")) {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 50))
                        ], spacing: 16
                    ) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundColor(selectedIcon == icon ? .blue : .gray)
                                    .frame(width: 50, height: 50)
                                    .background(
                                        selectedIcon == icon ? Color.blue.opacity(0.1) : Color.clear
                                    )
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let pct = Double(percentage), !name.isEmpty {
                            if isEditMode, let onAdd = onAdd {
                                // In edit mode, just add to temporary array
                                let newCategory = BudgetCategory(
                                    name: name,
                                    percentage: pct,
                                    icon: selectedIcon,
                                    isActive: true
                                )
                                onAdd(newCategory)
                            } else {
                                // Not in edit mode, add directly to view model
                                viewModel.addCategory(
                                    name: name,
                                    percentage: pct,
                                    icon: selectedIcon
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || percentage.isEmpty)
                }
            }
        }
    }
}
