import Foundation
import RoomPlan
import RealityKit // Needed for ModelEntity

class FileManagerService {

    enum FileError: Error {
        case directoryCreationFailed
        case fileWriteFailed(Error) // Store associated error
        case fileReadFailed(Error) // Store associated error
        case invalidURL
        case jsonEncodingFailed(Error) // Store associated error
        case jsonDecodingFailed(Error) // Store associated error
        case exportFailed(Error) // Specific error for USDZ export
        case buildFailed(Error) // Specific error for RoomBuilder build step
    }

    // MARK: - Directory Handling -

    /// Gets the URL for the main scans directory, creating it if necessary.
    var scansDirectoryURL: URL {
        // Best practice: handle potential nil from .first
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Documents directory.") // Or handle more gracefully
        }
        let scansDirectory = documentsDirectory.appendingPathComponent("Scans", isDirectory: true)

        // Check and create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: scansDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: scansDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Created Scans directory at: \(scansDirectory.path)")
            } catch {
                // Log the error but don't crash the app here. The function will return the URL anyway.
                // Operations using it later will fail if creation truly failed.
                print("Error creating Scans directory: \(error)")
            }
        }

        return scansDirectory
    }

    /// Gets the URL for a specific scan's directory using its UUID.
    func directoryURL(for scanID: UUID) -> URL {
        return scansDirectoryURL.appendingPathComponent(scanID.uuidString, isDirectory: true)
    }

    // MARK: - Save Methods -

    /// Saves a CapturedRoom by exporting its geometry to USDZ and saving metadata to JSON.
    /// - Parameters:
    ///   - room: The `CapturedRoom` object containing the scan data.
    ///   - name: A user-provided name for the scan.
    /// - Returns: The `ScanMetadata` object for the saved scan.
    /// - Throws: `FileError` if saving fails at any step.
    func saveScan(room: CapturedRoom, name: String) async throws -> ScanMetadata {
        // 1. Create metadata object first (contains the UUID)
        let metadata = ScanMetadata(name: name, capturedRoom: room)
        let scanID = metadata.id
        let scanDirectory = directoryURL(for: scanID)

        // 2. Create directory for this specific scan
        if !FileManager.default.fileExists(atPath: scanDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: scanDirectory, withIntermediateDirectories: true, attributes: nil)
                print("Created directory for scan \(scanID) at: \(scanDirectory.path)")
            } catch {
                print("Error creating directory for scan \(scanID): \(error)")
                throw FileError.directoryCreationFailed
            }
        }

        // 3. Save JSON metadata
        let jsonURL = scanDirectory.appendingPathComponent("metadata.json")
        print("Attempting to save metadata to: \(jsonURL.path)")
        do {
            // Use pretty printing for easier debugging if needed
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(metadata)
            try jsonData.write(to: jsonURL)
            print("Successfully saved metadata.json")
        } catch {
            print("Error saving JSON metadata: \(error)")
            throw FileError.jsonEncodingFailed(error)
        }

        // 4. Export USDZ geometry using RoomCaptureSession's export method
        let usdzURL = scanDirectory.appendingPathComponent("model.usdz")
        print("Attempting to export USDZ to: \(usdzURL.path)")
        
        do {
            // Use the RoomPlan's direct export method to save the captured room
            try await room.export(to: usdzURL)
            
            print("Successfully exported model.usdz")
        } catch let exportError {
            print("Error exporting to USDZ: \(exportError)")
            throw FileError.exportFailed(exportError)
        }

        // 5. Return the created metadata
        return metadata
    }

    // MARK: - Load Methods -

    /// Loads the list of all saved scan metadata objects from the Scans directory.
    /// - Returns: An array of `ScanMetadata`, sorted by date (newest first).
    /// - Throws: `FileError.fileReadFailed` if the Scans directory cannot be read.
    func loadScanList() throws -> [ScanMetadata] {
        var scans: [ScanMetadata] = []
        let fileManager = FileManager.default
        let rootScansURL = scansDirectoryURL // Ensure directory exists or is attempted first

        print("Loading scan list from: \(rootScansURL.path)")

        let scanDirectories: [URL]
        do {
            // Get contents, filtering for directories only
            scanDirectories = try fileManager.contentsOfDirectory(
                at: rootScansURL,
                includingPropertiesForKeys: [.isDirectoryKey], // Ensure we only get directories
                options: .skipsHiddenFiles
            ).filter { url in
                // Double check it's a directory
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            print("Found \(scanDirectories.count) potential scan directories.")

        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
             // If the Scans directory itself doesn't exist, return empty list gracefully
             print("Scans directory does not exist yet. Returning empty list.")
             return []
         } catch {
            print("Error reading contents of Scans directory: \(error)")
            throw FileError.fileReadFailed(error)
        }

        // Iterate through each potential scan directory
        for directory in scanDirectories {
            let metadataURL = directory.appendingPathComponent("metadata.json")
            // Check if metadata.json exists within the directory
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                print("Skipping directory (missing metadata.json): \(directory.lastPathComponent)")
                continue
            }

            // Attempt to load and decode metadata.json
            do {
                let data = try Data(contentsOf: metadataURL)
                let scanMetadata = try JSONDecoder().decode(ScanMetadata.self, from: data)
                scans.append(scanMetadata)
                print("Successfully loaded metadata for scan: \(directory.lastPathComponent)")
            } catch {
                // Log error but continue trying to load others
                print("Error reading or decoding metadata.json in \(directory.lastPathComponent): \(error)")
            }
        }

        // Sort scans by dateCreated, newest first
        return scans.sorted { $0.dateCreated > $1.dateCreated }
    }

    /// Gets the file URLs for the USDZ model and JSON metadata for a specific scan ID.
    /// - Parameter scanID: The `UUID` of the scan.
    /// - Returns: A tuple containing the `URL` for the USDZ file and the JSON file.
    func getFileURLs(for scanID: UUID) -> (usdzURL: URL, jsonURL: URL) {
        let scanDirectory = directoryURL(for: scanID)
        let usdzURL = scanDirectory.appendingPathComponent("model.usdz")
        let jsonURL = scanDirectory.appendingPathComponent("metadata.json")
        return (usdzURL, jsonURL)
    }

    /// Loads a specific scan's metadata using its UUID.
    /// - Parameter scanID: The `UUID` of the scan to load.
    /// - Returns: The `ScanMetadata` object.
    /// - Throws: `FileError.jsonDecodingFailed` if the metadata file cannot be read or decoded.
    func loadScanMetadata(for scanID: UUID) throws -> ScanMetadata {
        let (_, jsonURL) = getFileURLs(for: scanID)
        print("Loading specific scan metadata from: \(jsonURL.path)")

        do {
            let data = try Data(contentsOf: jsonURL)
            let metadata = try JSONDecoder().decode(ScanMetadata.self, from: data)
            print("Successfully loaded metadata for scan \(scanID)")
            return metadata
        } catch {
            print("Error loading or decoding metadata for scan \(scanID): \(error)")
            throw FileError.jsonDecodingFailed(error)
        }
    }

    // MARK: - Delete Methods (Added Placeholder) -

    /// Deletes the directory and all contents for a specific scan.
    /// - Parameter scanID: The `UUID` of the scan to delete.
    /// - Throws: `FileError` or other file system errors if deletion fails.
    func deleteScan(id scanID: UUID) throws {
        let scanDirectory = directoryURL(for: scanID)
        print("Attempting to delete scan directory: \(scanDirectory.path)")

        guard FileManager.default.fileExists(atPath: scanDirectory.path) else {
            print("Scan directory not found, nothing to delete.")
            return // Or throw specific error? No - deleting non-existent is fine.
        }

        do {
            try FileManager.default.removeItem(at: scanDirectory)
            print("Successfully deleted scan directory for \(scanID)")
        } catch {
            print("Error deleting scan directory for \(scanID): \(error)")
            throw error // Re-throw the underlying file system error
        }
    }
}
