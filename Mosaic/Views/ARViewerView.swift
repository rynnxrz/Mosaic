import SwiftUI
import RealityKit

struct ARViewerView: View {
    @StateObject var viewModel = ARViewModel()
    let scanID: UUID
    
    var body: some View {
        ZStack {
            if viewModel.isLoading {
                ProgressView("Loading model...")
            } else if let errorMessage = viewModel.errorMessage {
                VStack {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                        .padding()
                    
                    Text(errorMessage)
                        .multilineTextAlignment(.center)
                        .padding()
                    
                    Button("Retry") {
                        viewModel.loadScan(scanID: scanID)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                // AR View with model
                ARViewContainer(modelURL: viewModel.modelURL)
                    .ignoresSafeArea()
                
                // Help button overlay
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button {
                            // Show help info
                        } label: {
                            Image(systemName: "questionmark.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .padding()
                    }
                }
            }
        }
        .navigationTitle("3D Viewer")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.loadScan(scanID: scanID)
        }
    }
} 