import SwiftUI

struct CalendarContainerView: View {
    @EnvironmentObject var vm: CalendarViewModel
    @EnvironmentObject var friends: FriendsViewModel
    @EnvironmentObject var auth: AuthViewModel
    @State private var showCreateEvent = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("View", selection: $vm.displayMode) {
                    ForEach(CalendarViewModel.CalendarDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Divider()

                // Calendar body
                Group {
                    switch vm.displayMode {
                    case .month:
                        MonthView()
                    case .week:
                        WeekView()
                    case .day:
                        DayView()
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: vm.displayMode)
            }
            .navigationTitle(vm.visibleMonthTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Today") {
                        vm.selectedDate = .now
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if vm.unifiedService.isLoading {
                            ProgressView()
                        }
                        Button {
                            showCreateEvent = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .refreshable {
                await vm.fetchEvents()
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateSharedEventView()
                    .environmentObject(friends)
                    .environmentObject(auth)
            }
        }
    }
}
