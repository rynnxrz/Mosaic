import Foundation
import RealityKit
import Combine

class ARViewModel: ObservableObject {
    @Published var modelURL: URL?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    private let fileManagerService = FileManagerService()
    
    /// Loads a scan model by its ID
    func loadScan(scanID: UUID) {
        isLoading = true
        errorMessage = nil
        
        let (usdzURL, _) = fileManagerService.getFileURLs(for: scanID)
        
        // Verify file exists
        if FileManager.default.fileExists(atPath: usdzURL.path) {
            self.modelURL = usdzURL
        } else {
            self.errorMessage = "Model file not found."
        }
        
        isLoading = false
    }
    
    /// Handles error cases during model loading
    func handleError(_ error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Error loading model: \(error.localizedDescription)"
        }
    }
} 