import SwiftUI

struct TaskCommandPalette: View {
    @ObservedObject var viewModel: TaskViewModel
    @Binding var isPresented: Bool
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    var filteredTasks: [DevTask] {
        if searchText.isEmpty {
            return viewModel.tasks
        } else {
            return viewModel.tasks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search tasks...", text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Task List
            List {
                ForEach(filteredTasks) { task in
                    HStack {
                        Circle()
                            .fill(task.priority.color)
                            .frame(width: 8, height: 8)
                        VStack(alignment: .leading) {
                            Text(task.title)
                                .font(.headline)
                            Text(task.status.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Action: Select task or show details
                        isPresented = false
                    }
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 300)
            
            Divider()
            
            // Footer
            HStack {
                Text("\(filteredTasks.count) tasks found")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Esc to close")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(8)
        }
        .frame(width: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 20)
        .onAppear {
            isFocused = true
        }
    }
}
