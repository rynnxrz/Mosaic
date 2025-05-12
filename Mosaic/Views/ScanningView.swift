import SwiftUI
import RoomPlan

struct ScanningView: View {
    @State private var scanResult: CapturedRoom? = nil
    @State private var isScanning: Bool = false
    @State private var showExportOptions = false
    
    var body: some View {
        VStack {
            if let result = scanResult {
                // Show confirmation or next steps after scan is complete
                Text("Scan Complete!")
                    .font(.headline)
                Text("Objects identified: \(result.objects.count)")
                Text("Walls identified: \(result.walls.count)")
                
                Button("Export Scan") {
                    // Trigger export logic
                    showExportOptions = true
                }
                .buttonStyle(.borderedProminent)
                .padding()
                
                Button("Scan Again") {
                    scanResult = nil // Clear previous result
                    isScanning = true // Start a new scan
                }
                .buttonStyle(.bordered)
                
            } else {
                // Show the scanning view
                ZStack(alignment: .bottom) {
                    RoomCaptureViewRepresentable(capturedRoom: $scanResult, isSessionRunning: $isScanning)
                        .ignoresSafeArea()
                    
                    // Start/Stop Button Overlay
                    Button {
                        isScanning.toggle()
                    } label: {
                        Text(isScanning ? "Stop Scan" : "Start Scan")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(isScanning ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Room Scanner")
        .sheet(isPresented: $showExportOptions) {
            if let resultToExport = scanResult {
                ExportView(capturedRoom: resultToExport)
            }
        }
        .onDisappear {
            if isScanning {
                isScanning = false
            }
        }
    }
}

// View for exporting scan data
struct ExportView: View {
    let capturedRoom: CapturedRoom
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Text("Export Options")
                .font(.title)
            
            Button("Save USDZ and JSON") {
                saveRoomData(capturedRoom)
                dismiss()
            }
            .padding()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
    
    private func saveRoomData(_ room: CapturedRoom) {
        // This would be implemented to call your FileManagerService
        print("Attempting to save USDZ and JSON for room...")
        // TODO: Implement actual saving logic
    }
} 
