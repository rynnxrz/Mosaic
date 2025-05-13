import Foundation
import RoomPlan
import RealityKit // Needed for ModelEntity if/when RoomBuilder is used

class FileManagerService {

    enum FileError: Error {
        case directoryCreationFailed
        case fileWriteFailed(Error) // Store associated error
        case fileReadFailed(Error) // Store associated error
        case invalidURL
        case jsonEncodingFailed(Error) // Store associated error
        case jsonDecodingFailed(Error) // Store associated error
        case exportFailed(Error) // Specific error for USDZ export
        // case buildFailed(Error) // Removed as direct export is used
    }

    // MARK: - Directory Handling -

    /// Gets the URL for the main scans directory, creating it if necessary.
    var scansDirectoryURL: URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            fatalError("Could not access Documents directory.")
        }
        let scansDirectory = documentsDirectory.appendingPathComponent("Scans", isDirectory: true)

        if !FileManager.default.fileExists(atPath: scansDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: scansDirectory, withIntermediateDirectories: true, attributes: nil)
                print("FileManagerService: Created Scans directory at: \(scansDirectory.path)")
            } catch {
                print("FileManagerService: Error creating Scans directory: \(error)")
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
        let metadata = ScanMetadata(name: name, capturedRoom: room)
        let scanID = metadata.id
        let scanDirectory = directoryURL(for: scanID)

        if !FileManager.default.fileExists(atPath: scanDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: scanDirectory, withIntermediateDirectories: true, attributes: nil)
                print("FileManagerService: Created directory for scan \(scanID) at: \(scanDirectory.path)")
            } catch {
                print("FileManagerService: Error creating directory for scan \(scanID): \(error)")
                throw FileError.directoryCreationFailed
            }
        }

        let jsonURL = scanDirectory.appendingPathComponent("metadata.json")
        print("FileManagerService: Attempting to save metadata to: \(jsonURL.path)")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(metadata)
            try jsonData.write(to: jsonURL)
            print("FileManagerService: Successfully saved metadata.json")
        } catch {
            print("FileManagerService: Error saving JSON metadata: \(error)")
            throw FileError.jsonEncodingFailed(error)
        }

        let usdzURL = scanDirectory.appendingPathComponent("model.usdz")
        print("FileManagerService: Attempting to export USDZ to: \(usdzURL.path)")
        do {
            // Remove 'await' as room.export(to:) is synchronous
            // This assumes room.export(to:) is not an async function based on compiler errors.
            try room.export(to: usdzURL)
            print("FileManagerService: Successfully exported model.usdz")
        } catch let exportError {
            print("FileManagerService: Error exporting to USDZ: \(exportError)")
            throw FileError.exportFailed(exportError)
        }

        return metadata
    }

    // MARK: - Load Methods -

    /// Loads the list of all saved scan metadata objects from the Scans directory.
    func loadScanList() throws -> [ScanMetadata] {
        var scans: [ScanMetadata] = []
        let fileManager = FileManager.default
        let rootScansURL = scansDirectoryURL

        print("FileManagerService: Loading scan list from: \(rootScansURL.path)")

        let scanDirectories: [URL]
        do {
            scanDirectories = try fileManager.contentsOfDirectory(
                at: rootScansURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            ).filter { url in
                var isDirectory: ObjCBool = false
                return fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
            }
            print("FileManagerService: Found \(scanDirectories.count) potential scan directories.")

        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
             print("FileManagerService: Scans directory does not exist yet. Returning empty list.")
             return []
         } catch {
            print("FileManagerService: Error reading contents of Scans directory: \(error)")
            throw FileError.fileReadFailed(error)
        }

        for directory in scanDirectories {
            let metadataURL = directory.appendingPathComponent("metadata.json")
            guard fileManager.fileExists(atPath: metadataURL.path) else {
                print("FileManagerService: Skipping directory (missing metadata.json): \(directory.lastPathComponent)")
                continue
            }
            do {
                let data = try Data(contentsOf: metadataURL)
                let scanMetadata = try JSONDecoder().decode(ScanMetadata.self, from: data)
                scans.append(scanMetadata)
                print("FileManagerService: Successfully loaded metadata for scan: \(directory.lastPathComponent)")
            } catch {
                print("FileManagerService: Error reading or decoding metadata.json in \(directory.lastPathComponent): \(error)")
            }
        }
        return scans.sorted { $0.dateCreated > $1.dateCreated }
    }

    /// Gets the file URLs for the USDZ model and JSON metadata for a specific scan ID.
    func getFileURLs(for scanID: UUID) -> (usdzURL: URL, jsonURL: URL) {
        let scanDirectory = directoryURL(for: scanID)
        let usdzURL = scanDirectory.appendingPathComponent("model.usdz")
        let jsonURL = scanDirectory.appendingPathComponent("metadata.json")
        return (usdzURL, jsonURL)
    }

    /// Loads a specific scan's metadata using its UUID.
    func loadScanMetadata(for scanID: UUID) throws -> ScanMetadata {
        let (_, jsonURL) = getFileURLs(for: scanID)
        print("FileManagerService: Loading specific scan metadata from: \(jsonURL.path)")
        do {
            let data = try Data(contentsOf: jsonURL)
            let metadata = try JSONDecoder().decode(ScanMetadata.self, from: data)
            print("FileManagerService: Successfully loaded metadata for scan \(scanID)")
            return metadata
        } catch {
            print("FileManagerService: Error loading or decoding metadata for scan \(scanID): \(error)")
            throw FileError.jsonDecodingFailed(error)
        }
    }

    // MARK: - Delete Methods -

    /// Deletes the directory and all contents for a specific scan.
    func deleteScan(id scanID: UUID) throws {
        let scanDirectory = directoryURL(for: scanID)
        print("FileManagerService: Attempting to delete scan directory: \(scanDirectory.path)")
        guard FileManager.default.fileExists(atPath: scanDirectory.path) else {
            print("FileManagerService: Scan directory not found, nothing to delete.")
            return
        }
        do {
            try FileManager.default.removeItem(at: scanDirectory)
            print("FileManagerService: Successfully deleted scan directory for \(scanID)")
        } catch {
            print("FileManagerService: Error deleting scan directory for \(scanID): \(error)")
            throw error
        }
    }
}
