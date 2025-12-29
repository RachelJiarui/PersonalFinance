import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dashboardViewModel: DashboardViewModel
    @EnvironmentObject var budgetViewModel: BudgetViewModel
    @EnvironmentObject var historyViewModel: HistoryViewModel

    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard
        case budget
        case perennial
        case history
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationView {
                DashboardView()
                    .environmentObject(dashboardViewModel)
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.pie.fill")
            }
            .tag(Tab.dashboard)

            NavigationView {
                MyBudgetView()
                    .environmentObject(budgetViewModel)
            }
            .tabItem {
                Label("My Budget", systemImage: "dollarsign.circle.fill")
            }
            .tag(Tab.budget)

            NavigationView {
                PerennialView()
            }
            .tabItem {
                Label("Perennial", systemImage: "leaf.fill")
            }
            .tag(Tab.perennial)

            NavigationView {
                GrandSchemeView()
                    .environmentObject(historyViewModel)
            }
            .tabItem {
                Label("Grand Scheme", systemImage: "calendar")
            }
            .tag(Tab.history)
        }
    }
}
