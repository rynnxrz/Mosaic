//
//  RoomCaptureViewRepresentable.swift  (v15)
//

import SwiftUI
import RoomPlan
import ARKit
import Combine

struct RoomCaptureViewRepresentable: UIViewRepresentable {

    typealias UIViewType = RoomCaptureView

    // ───────── Bindings
    @Binding var capturedRoom: CapturedRoom?
    @Binding var isSessionRunning: Bool

    // ───────── Private state
    private let arSession  = ARSession()
    private let captureView: RoomCaptureView
    private let captureSession: RoomCaptureSession

    // MARK: init
    init(capturedRoom: Binding<CapturedRoom?>,
         isSessionRunning: Binding<Bool>)
    {
        _capturedRoom     = capturedRoom
        _isSessionRunning = isSessionRunning

        captureView    = RoomCaptureView(frame: .zero,
                                         arSession: arSession)
        captureSession = captureView.captureSession
    }

    // MARK: makeUIView
    func makeUIView(context: Context) -> RoomCaptureView {
        captureView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let cfg = ARWorldTrackingConfiguration()
        cfg.planeDetection       = [.horizontal, .vertical]
        cfg.environmentTexturing = .automatic
        arSession.run(cfg, options: [.resetTracking, .removeExistingAnchors])
        arSession.delegate = context.coordinator

        captureView.delegate    = context.coordinator
        captureSession.delegate = context.coordinator
        context.coordinator.arSession = arSession
        context.coordinator.roomPlan  = captureSession

        return captureView
    }

    // MARK: updateUIView
    func updateUIView(_ uiView: RoomCaptureView,
                      context: Context)
    {
        DispatchQueue.main.async {
            if isSessionRunning && !context.coordinator.isRoomPlanRunning {
                let rpCfg = RoomCaptureSession.Configuration()
                captureSession.run(configuration: rpCfg)
                context.coordinator.isRoomPlanRunning = true
            }
            if !isSessionRunning && context.coordinator.isRoomPlanRunning {
                captureSession.stop()
                arSession.pause()
                context.coordinator.isRoomPlanRunning = false
            }
        }
    }

    // MARK: dismantleUIView
    static func dismantleUIView(_ uiView: RoomCaptureView,
                                coordinator: Coordinator)
    {
        coordinator.roomPlan?.stop()
        coordinator.arSession?.pause()
        coordinator.isRoomPlanRunning = false
        coordinator.cancellables.forEach { $0.cancel() }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    // MARK: Coordinator
    @objc(MosaicRoomCaptureCoordinator)      // ← fixed Obj-C name (kills warning)
    final class Coordinator: NSObject,
                             RoomCaptureViewDelegate,
                             RoomCaptureSessionDelegate,
                             ARSessionDelegate,
                             NSSecureCoding {

        // NSSecureCoding
        static var supportsSecureCoding: Bool { true }
        required init?(coder: NSCoder) { fatalError() }
        func encode(with coder: NSCoder) {}

        // Weak refs
        weak var arSession : ARSession?
        weak var roomPlan  : RoomCaptureSession?

        var isRoomPlanRunning = false
        var cancellables = Set<AnyCancellable>()
        var parent: RoomCaptureViewRepresentable

        init(parent: RoomCaptureViewRepresentable) { self.parent = parent }

        // ARSessionDelegate
        func session(_ session: ARSession,
                     cameraDidChangeTrackingState camera: ARCamera) {
            if case .limited(let r) = camera.trackingState {
                print("AR tracking limited: \(r)")
            }
        }

        // RoomCaptureViewDelegate
        func captureView(_ captureView: RoomCaptureView,
                         shouldPresent roomDataForProcessing: CapturedRoomData,
                         error: Error?) -> Bool {
            if let e = error { print("RoomPlan shouldPresent error: \(e)"); return false }
            return true
        }

        func captureView(_ captureView: RoomCaptureView,
                         didPresent processedResult: CapturedRoom,
                         error: Error?) {
            if let e = error {
                print("RoomPlan didPresent error: \(e)")
            } else {
                DispatchQueue.main.async { self.parent.capturedRoom = processedResult }
            }
            DispatchQueue.main.async { self.parent.isSessionRunning = false }
        }

        // RoomCaptureSessionDelegate
        func captureSession(_ session: RoomCaptureSession,
                            didEndWith data: CapturedRoomData,
                            error: Error?) {
            isRoomPlanRunning = false
            parent.isSessionRunning = false
        }

        func captureSession(_ session: RoomCaptureSession,
                            didFailWith error: Error) {
            isRoomPlanRunning = false
            parent.isSessionRunning = false
            print("RoomPlan failed: \(error)")
        }
    }
}
