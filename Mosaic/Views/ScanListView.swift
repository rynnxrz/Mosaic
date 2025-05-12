import SwiftUI

struct ScanListView: View {
    @StateObject var viewModel = ScanListViewModel()
    @State private var showingScanningView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if viewModel.isLoading {
                    ProgressView("Loading scans...")
                } else if viewModel.savedScans.isEmpty {
                    VStack {
                        Text("No scans yet")
                            .font(.headline)
                        
                        Button("Scan a Room") {
                            showingScanningView = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 20)
                    }
                } else {
                    // List of saved scans
                    List {
                        ForEach(viewModel.savedScans, id: \.id) { scan in
                            NavigationLink(destination: ARViewerView(scanID: scan.id)) {
                                ScanRowView(scan: scan, dateString: viewModel.formattedDate(for: scan))
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let scan = viewModel.savedScans[index]
                                viewModel.deleteScan(withID: scan.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Saved Scans")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingScanningView = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingScanningView) {
                ScanningView()
                    .onDisappear {
                        // Refresh scan list when returning from scanning
                        viewModel.loadSavedScans()
                    }
            }
            .onAppear {
                viewModel.loadSavedScans()
            }
            .refreshable {
                viewModel.loadSavedScans()
            }
            .alert(
                "Error",
                isPresented: Binding<Bool>(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                ),
                actions: {
                    Button("OK") { viewModel.errorMessage = nil }
                },
                message: {
                    if let error = viewModel.errorMessage {
                        Text(error)
                    }
                }
            )
        }
    }
}

struct ScanRowView: View {
    let scan: ScanMetadata
    let dateString: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(scan.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "calendar")
                    .imageScale(.small)
                    .foregroundColor(.secondary)
                Text(dateString)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
} 