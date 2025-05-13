//
//  ARViewContainer.swift
//  Mosaic
//
//  Displays a USDZ (or other Reality File) in an ARView.
//  Owns its OWN ARSession but pauses it in `dismantleUIView`.
//

import SwiftUI
import RealityKit
import ARKit
import Combine

struct ARViewContainer: UIViewRepresentable {

    var modelURL: URL?

    // Keep a single ARView instance so its session survives updates
    private let arView = ARView(frame: .zero,
                                cameraMode: .ar,
                                automaticallyConfigureSession: true)

    // MARK: – UIViewRepresentable
    func makeUIView(context: Context) -> ARView {
        print("[ARView] makeUIView")

        // If ARView didn’t autoconfigure, give it a simple config
        if arView.session.configuration == nil {
            let cfg = ARWorldTrackingConfiguration()
            cfg.planeDetection = [.horizontal, .vertical]
            arView.session.run(cfg,
                               options: [.resetTracking, .removeExistingAnchors])
        }

        context.coordinator.arView = arView
        context.coordinator.installGestures()
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        print("[ARView] updateUIView – model=\(modelURL?.lastPathComponent ?? "nil")")

        uiView.scene.anchors.removeAll()                 // clear previous model

        guard let url = modelURL else { return }

        Task { @MainActor in
            do {
                let modelEntity = try await loadModel(from: url)
                let anchor      = AnchorEntity(world: .zero)
                anchor.addChild(modelEntity)
                uiView.scene.addAnchor(anchor)

                // Center model
                DispatchQueue.main.async {
                    let bounds = modelEntity.visualBounds(relativeTo: anchor)
                    modelEntity.position = -bounds.center
                }
            } catch {
                print("[ARView] load error: \(error.localizedDescription)")
            }
        }
    }

    static func dismantleUIView(_ uiView: ARView,
                                coordinator: Coordinator)
    {
        print("[ARView] dismantleUIView – pausing session")
        uiView.session.pause()
    }

    // MARK: – Model loading
    private func loadModel(from url: URL) async throws -> ModelEntity {
        if #available(iOS 18.0, *) {
            return try await ModelEntity(contentsOf: url)
        } else {
            return try await withCheckedThrowingContinuation { cont in
                var cancellable: AnyCancellable?
                cancellable = Entity.loadModelAsync(contentsOf: url)
                    .sink { completion in
                        if case .failure(let err) = completion { cont.resume(throwing: err) }
                        cancellable?.cancel()
                    } receiveValue: { ent in cont.resume(returning: ent) }
            }
        }
    }

    // MARK: – Coordinator for gestures
    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        weak var arView: ARView?
        private var initialTransform: simd_float4x4?
        private var baseScale: Float = 1

        // Gesture setup once
        func installGestures() {
            guard let view = arView, view.gestureRecognizers?.isEmpty ?? true else { return }
            view.addGestureRecognizer(UIPanGestureRecognizer(target: self,
                                                             action: #selector(pan(_:))))
            view.addGestureRecognizer(UIPinchGestureRecognizer(target: self,
                                                               action: #selector(pinch(_:))))
        }

        // ───── Pan = rotate model
        @objc private func pan(_ g: UIPanGestureRecognizer) {
            guard let view = arView, let anchor = view.scene.anchors.first else { return }
            switch g.state {
            case .began:
                initialTransform = anchor.transform.matrix
            case .changed:
                guard let start = initialTransform else { return }
                let t = g.translation(in: view)
                let rotX = simd_quatf(angle: Float(t.y) * 0.005, axis: [1,0,0])
                let rotY = simd_quatf(angle: Float(t.x) * 0.005, axis: [0,1,0])
                anchor.transform.matrix = start * simd_float4x4(rotY * rotX)
            default: break
            }
        }

        // ───── Pinch = scale model
        @objc private func pinch(_ g: UIPinchGestureRecognizer) {
            guard let view = arView, let anchor = view.scene.anchors.first else { return }
            if g.state == .changed {
                anchor.scale = SIMD3(repeating: baseScale * Float(g.scale))
            } else if g.state == .ended || g.state == .cancelled {
                baseScale = anchor.scale.x
                g.scale = 1
            }
        }
    }
}
