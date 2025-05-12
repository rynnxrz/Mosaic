import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    var modelURL: URL?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        arView.session.run(config)
        context.coordinator.arView = arView
        context.coordinator.setupGestures()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        uiView.scene.anchors.forEach { $0.removeFromParent() }

        if let url = modelURL {
            Task {
                do {
                    let modelEntity = try await Entity.loadModel(contentsOf: url)
                    let anchorEntity = AnchorEntity(world: .zero)
                    anchorEntity.addChild(modelEntity)

                    let bounds = modelEntity.visualBounds(relativeTo: anchorEntity)
                    modelEntity.position = SIMD3<Float>(
                        -bounds.center.x,
                        -bounds.center.y,
                        -bounds.center.z
                    )

                    DispatchQueue.main.async {
                        uiView.scene.addAnchor(anchorEntity)
                    }
                } catch {
                    print("Error loading model: \(error.localizedDescription)")
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: ARViewContainer
        weak var arView: ARView?
        private var startingPanTransform: simd_float4x4?
        private var startingPinchDistance: CGFloat = 1.0
        private var currentScale: Float = 1.0

        init(_ parent: ARViewContainer) {
            self.parent = parent
        }

        func setupGestures() {
            guard let arView = arView else { return }
            arView.addGestureRecognizer(
                UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            )
            arView.addGestureRecognizer(
                UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            )
        }

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            guard
                let arView = arView,
                let rootEntity = arView.scene.anchors.first
            else { return }

            switch gesture.state {
            case .began:
                startingPanTransform = rootEntity.transform.matrix
            case .changed:
                guard let startMatrix = startingPanTransform else { return }
                let translation = gesture.translation(in: arView)
                let rotY = Float(translation.x) * 0.01
                let rotX = Float(translation.y) * 0.01

                var matrix = startMatrix
                matrix = matrix * simd_float4x4(simd_quaternion(rotX, SIMD3<Float>(1, 0, 0)))
                matrix = matrix * simd_float4x4(simd_quaternion(rotY, SIMD3<Float>(0, 1, 0)))

                rootEntity.transform = Transform(matrix: matrix)
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            guard
                let arView = arView,
                let rootEntity = arView.scene.anchors.first
            else { return }

            switch gesture.state {
            case .began:
                startingPinchDistance = gesture.scale
            case .changed:
                let delta = Float(gesture.scale / startingPinchDistance)
                var newScale = currentScale * delta
                newScale = min(max(newScale, 0.1), 10.0)
                rootEntity.scale = SIMD3<Float>(newScale, newScale, newScale)
                currentScale = newScale
                startingPinchDistance = gesture.scale
            default:
                break
            }
        }
    }
}
