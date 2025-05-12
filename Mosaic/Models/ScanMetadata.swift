import Foundation
import RoomPlan
import simd // Explicitly import simd

// Main structure to hold metadata extracted from a CapturedRoom
struct ScanMetadata: Codable, Identifiable { // Added Identifiable for list usage
    let id: UUID
    let dateCreated: Date
    var name: String // Made 'name' mutable if needed later
    let walls: [SurfaceMetadata]
    let doors: [SurfaceMetadata]
    let windows: [SurfaceMetadata]
    let floors: [SurfaceMetadata]
    let objects: [ObjectMetadata]
    let openings: [SurfaceMetadata]

    // Initializer to create metadata from a CapturedRoom object
    init(id: UUID = UUID(),
         dateCreated: Date = Date(),
         name: String,
         capturedRoom: CapturedRoom) {
        self.id = id
        self.dateCreated = dateCreated
        self.name = name

        // Extract surface data by filtering using pattern matching where needed
        let allSurfaces = capturedRoom.walls + capturedRoom.doors + capturedRoom.windows + capturedRoom.floors + capturedRoom.openings

        // Filter for walls
        self.walls = allSurfaces.filter { $0.category == .wall }.map { surface in
            SurfaceMetadata(surface: surface)
        }
        // Filter for doors using pattern matching (ignores isOpen state)
        self.doors = allSurfaces.filter { surface in
            if case .door = surface.category { return true } // Check if it's a door case
            return false
        }.map { surface in
            SurfaceMetadata(surface: surface)
        }
        // Filter for windows
        self.windows = allSurfaces.filter { $0.category == .window }.map { surface in
            SurfaceMetadata(surface: surface)
        }
        // Filter for floors
        self.floors = allSurfaces.filter { $0.category == .floor }.map { surface in
            SurfaceMetadata(surface: surface)
        }
        // Filter for openings
        self.openings = allSurfaces.filter { $0.category == .opening }.map { surface in
            SurfaceMetadata(surface: surface)
        }


        // Extract object data
        self.objects = capturedRoom.objects.map { object in
            return ObjectMetadata(
                identifier: object.identifier.uuidString,
                // Use the specific Object.Category description extension
                category: object.category.description,
                dimensions: [object.dimensions.x, object.dimensions.y, object.dimensions.z],
                transform: object.transform.toArray()
            )
        }
    }
}

// MARK: - Component Metadata Structures -

// Generic structure for surface metadata (walls, doors, windows, openings, floors)
struct SurfaceMetadata: Codable, Hashable {
    let identifier: String
    let category: String // String description of the category
    let dimensions: [Float] // [x, y, z]
    let transform: [Float] // 4x4 matrix as 16 floats

    // Convenience initializer from CapturedRoom.Surface
    init(surface: CapturedRoom.Surface) {
        self.identifier = surface.identifier.uuidString
        // Use the Surface.Category description extension
        self.category = surface.category.description
        self.dimensions = [surface.dimensions.x, surface.dimensions.y, surface.dimensions.z]
        self.transform = surface.transform.toArray()
    }
}

// Codable structure for object metadata
struct ObjectMetadata: Codable, Hashable {
    let identifier: String
    let category: String // String description of the category
    let dimensions: [Float] // [x, y, z]
    let transform: [Float] // 4x4 matrix as 16 floats
}


// MARK: - Helper Extensions -

// Helper extension to convert simd_float4x4 matrix to a flat array for JSON serialization
extension simd_float4x4 {
    func toArray() -> [Float] {
        // Access matrix columns and their components (x, y, z, w)
        return [
            columns.0.x, columns.0.y, columns.0.z, columns.0.w,
            columns.1.x, columns.1.y, columns.1.z, columns.1.w,
            columns.2.x, columns.2.y, columns.2.z, columns.2.w,
            columns.3.x, columns.3.y, columns.3.z, columns.3.w
        ]
    }
}

// Extension for CapturedRoom.Surface.Category to provide string descriptions
extension CapturedRoom.Surface.Category {
    var description: String {
        switch self {
        // Use pattern matching for cases with associated values if needed for description
        case .door: return "Door" // Simple description, ignoring isOpen state
        case .opening: return "Opening"
        case .wall: return "Wall"
        case .window: return "Window"
        case .floor: return "Floor"
        @unknown default: return "Unknown Surface"
        }
    }
}

// Extension for CapturedRoom.Object.Category to provide string descriptions
extension CapturedRoom.Object.Category {
    var description: String {
        // Provide a user-friendly string for each category
        switch self {
        case .storage: return "Storage"
        case .refrigerator: return "Refrigerator"
        case .stove: return "Stove"
        case .bed: return "Bed"
        case .sink: return "Sink"
        // Removed .washbasin case due to persistent build error
        // case .washbasin: return "Washbasin"
        case .bathtub: return "Bathtub"
        case .toilet: return "Toilet"
        case .table: return "Table"
        case .sofa: return "Sofa"
        case .chair: return "Chair"
        case .fireplace: return "Fireplace"
        case .television: return "Television"
        case .stairs: return "Stairs"
        case .washerDryer: return "Washer/Dryer"
        case .oven: return "Oven"
        case .dishwasher: return "Dishwasher"
        @unknown default: return "Unknown Object"
        }
    }
}
