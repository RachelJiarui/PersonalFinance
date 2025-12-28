import SwiftUI

struct MyBudgetView: View {
    @EnvironmentObject var viewModel: BudgetViewModel
    @State private var showAddCategory = false
    @State private var showClearDataAlert = false

    var body: some View {
        Form {
            // MARK: - Income Section
            Section(header: Text("Income")) {
                HStack {
                    Text("Annual Salary")
                    Spacer()
                    TextField("$0", text: $viewModel.annualSalaryInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                HStack {
                    Text("401k Contribution")
                    Spacer()
                    TextField("$0", text: $viewModel.contribution401kInput)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }

                Button("Calculate Taxes") {
                    viewModel.updateIncome()
                }
                .disabled(viewModel.annualSalaryInput.isEmpty)
            }

            // MARK: - Tax Breakdown
            if let income = viewModel.userIncome {
                Section(header: Text("Tax Breakdown")) {
                    TaxRow(label: "Federal Tax", amount: income.federalTax)
                    TaxRow(label: "Social Security", amount: income.socialSecurityTax)
                    TaxRow(label: "Medicare", amount: income.medicareTax)
                    TaxRow(label: "NY State Tax", amount: income.nyStateTax)
                    TaxRow(label: "NYC Tax", amount: income.nycTax)

                    Divider()

                    HStack {
                        Text("Total Taxes")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("$\(Int(income.totalTaxes))")
                            .fontWeight(.semibold)
                            .foregroundColor(.red)
                    }
                }

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
                }
            }

            // MARK: - Budget Allocation
            if let income = viewModel.userIncome {
                Section(
                    header:
                        HStack {
                            Text("Budget Allocation")
                            Spacer()
                            Text("\(Int(viewModel.totalPercentageAllocated))% allocated")
                                .foregroundColor(viewModel.isAllocationValid ? .secondary : .red)
                        }
                ) {
                    ForEach(viewModel.budgetCategories.filter { $0.isActive }) { category in
                        CategoryAllocationRow(
                            category: category,
                            monthlyTakeHome: income.monthlyTakeHome,
                            onUpdate: { newPercentage in
                                viewModel.updateCategoryPercentage(
                                    categoryId: category.id,
                                    percentage: newPercentage
                                )
                            }
                        )
                    }
                    .onDelete { indexSet in
                        let activeCategories = viewModel.budgetCategories.filter { $0.isActive }
                        for index in indexSet {
                            let category = activeCategories[index]
                            viewModel.deleteCategory(categoryId: category.id)
                        }
                    }

                    // Remaining percentage display
                    let remainingPercentage = 100.0 - viewModel.totalPercentageAllocated
                    if remainingPercentage > 0 {
                        HStack {
                            Text("Unallocated")
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(String(format: "%.1f", remainingPercentage))%")
                            Text("($\(Int(income.monthlyTakeHome * remainingPercentage / 100)))")
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: { showAddCategory = true }) {
                        Label("Add Category", systemImage: "plus.circle.fill")
                    }
                }

                // Validation Error
                if let error = viewModel.validationError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
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
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet(viewModel: viewModel)
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
    let onUpdate: (Double) -> Void

    @State private var percentageInput: String

    init(category: BudgetCategory, monthlyTakeHome: Double, onUpdate: @escaping (Double) -> Void) {
        self.category = category
        self.monthlyTakeHome = monthlyTakeHome
        self.onUpdate = onUpdate
        _percentageInput = State(initialValue: String(format: "%.1f", category.percentage))
    }

    var dollarAmount: Double {
        category.dollarAmount(monthlyTakeHome: monthlyTakeHome)
    }

    var body: some View {
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

                Text("%")

                Spacer()

                Text("$\(Int(dollarAmount))")
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct AddCategorySheet: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: BudgetViewModel

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
                            viewModel.addCategory(
                                name: name,
                                percentage: pct,
                                icon: selectedIcon
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || percentage.isEmpty)
                }
            }
        }
    }
}
