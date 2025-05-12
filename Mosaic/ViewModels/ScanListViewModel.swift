import Foundation
import Combine
// No need to import RoomPlan here unless the ViewModel directly uses its types
// Removed: @_implementationOnly import RoomPlan

// Removed typealiases - ScanMetadata and FileManagerService should be directly accessible
// if defined in the same app target.

// ViewModel responsible for managing the list of saved scans
class ScanListViewModel: ObservableObject {
    // Published properties will trigger UI updates when changed
    @Published var savedScans: [ScanMetadata] = [] // Array of scan metadata objects
    @Published var isLoading: Bool = false // Flag to indicate loading state
    @Published var errorMessage: String? // Optional string to hold error messages

    // Instance of the service responsible for file operations
    private var fileManagerService = FileManagerService()
    // Set to store Combine subscriptions to manage their lifecycle
    private var cancellables = Set<AnyCancellable>()

    // Function to load the list of saved scan metadata from storage
    func loadSavedScans() {
        print("ScanListViewModel: Loading saved scans...")
        self.isLoading = true // Set loading state to true
        self.errorMessage = nil // Clear any previous error message

        // Attempt to load the scan list using the file manager service
        do {
            // This call is synchronous but might throw an error
            let scans = try fileManagerService.loadScanList()
            print("ScanListViewModel: Successfully loaded \(scans.count) scans.")
            // Update the published property on the main thread to trigger UI updates
            DispatchQueue.main.async {
                self.savedScans = scans
                self.isLoading = false // Set loading state back to false
            }
        } catch {
            // If an error occurs during loading
            print("ScanListViewModel: Error loading scans - \(error.localizedDescription)")
            // Update error message and loading state on the main thread
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load scans: \(error.localizedDescription)"
                self.isLoading = false // Set loading state back to false
            }
        }
    }

    // Function to delete a specific scan (identified by its UUID)
    // NOTE: Implementation details for deletion are not yet included.
    func deleteScan(withID id: UUID) {
        print("ScanListViewModel: Attempting to delete scan with ID \(id)... (Not Implemented)")
        // 1. Call fileManagerService to delete the corresponding files/directory.
        // Example (assuming service has a delete method):
        /*
        do {
            try fileManagerService.deleteScan(id: id)
            print("ScanListViewModel: Successfully deleted scan \(id). Reloading list.")
            // 2. Remove the item from the local array or reload the list
            // Option A: Remove locally (faster UI update)
            // DispatchQueue.main.async {
            //     self.savedScans.removeAll { $0.id == id }
            // }
            // Option B: Reload from storage (ensures consistency)
             self.loadSavedScans()
        } catch {
            print("ScanListViewModel: Error deleting scan \(id) - \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete scan: \(error.localizedDescription)"
            }
        }
        */

        // Placeholder: For now, just reload the list to simulate potential changes
        // In a real implementation, you'd handle file deletion first.
         self.loadSavedScans() // Reload after attempted deletion
    }

    // Helper function to format the date of a scan for display in the UI
    func formattedDate(for scan: ScanMetadata) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium // e.g., "Sep 12, 2023"
        formatter.timeStyle = .short // e.g., "9:41 AM"
        return formatter.string(from: scan.dateCreated)
    }
}
