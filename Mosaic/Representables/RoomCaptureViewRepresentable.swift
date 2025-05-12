import SwiftUI
import RoomPlan
import Combine

struct RoomCaptureViewRepresentable: UIViewRepresentable {

    // MARK: - Properties -

    @Binding var capturedRoom: CapturedRoom?
    @Binding var isSessionRunning: Bool

    private let roomCaptureView: RoomCaptureView
    private let captureSession: RoomCaptureSession

    init(capturedRoom: Binding<CapturedRoom?>, isSessionRunning: Binding<Bool>) {
        self._capturedRoom = capturedRoom
        self._isSessionRunning = isSessionRunning
        self.roomCaptureView = RoomCaptureView(frame: .zero)
        self.captureSession = RoomCaptureSession()
        print("RoomCaptureViewRepresentable Initialized")
    }

    // MARK: - UIViewRepresentable Methods -

    func makeUIView(context: Context) -> RoomCaptureView {
        print("Making RoomCaptureView (makeUIView)")
        roomCaptureView.delegate = context.coordinator
        captureSession.delegate = context.coordinator
        return roomCaptureView
    }

    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        print("Updating RoomCaptureView (updateUIView), isSessionRunning: \(isSessionRunning), coordinator.sessionActive: \(context.coordinator.sessionActive)")
        DispatchQueue.main.async {
             if isSessionRunning && !context.coordinator.sessionActive {
                 print("Starting RoomPlan session via updateUIView...")
                 let configuration = RoomCaptureSession.Configuration()
                 captureSession.run(configuration: configuration)
                 // Coordinator's sessionActive will be updated by delegate
             } else if !isSessionRunning && context.coordinator.sessionActive {
                 print("Stopping RoomPlan session via updateUIView...")
                 captureSession.stop()
                 // Coordinator's sessionActive will be updated by delegate
            }
        }
    }

    static func dismantleUIView(_ uiView: RoomCaptureView, coordinator: Coordinator) {
        print("Dismantling RoomCaptureView (dismantleUIView)")
        if coordinator.sessionActive {
             print("Stopping session during dismantle because coordinator.sessionActive is true...")
             coordinator.parent.captureSession.stop()
        }
        coordinator.cancellables.forEach { $0.cancel() }
        print("Dismantle complete.")
    }

    // MARK: - Coordinator -

    func makeCoordinator() -> Coordinator {
        print("Making Coordinator")
        return Coordinator(parent: self)
    }

    @objc(MosaicRoomCaptureCoordinator) // Unique name for Objective-C runtime
    class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate, NSSecureCoding { // Added NSSecureCoding

        // MARK: NSSecureCoding Conformance (Stub)
        // Required for NSSecureCoding, indicates that this class supports secure coding.
        static var supportsSecureCoding: Bool {
            return true
        }

        // Required initializer for NSCoding.
        // This coordinator is not intended to be decoded, so we provide a minimal implementation.
        required init?(coder: NSCoder) {
            // 'parent' is non-optional and cannot be decoded easily here without more context.
            // Since this Coordinator is tied to the lifecycle of RoomCaptureViewRepresentable
            // and created by it, direct decoding is not a typical use case.
            // If this init were ever called, it would indicate an unexpected scenario.
            print("Coordinator: init(coder:) called, which is not expected.")
            // One option is to fatalError if you're sure it should never be decoded.
            // fatalError("init(coder:) has not been implemented and should not be called for MosaicRoomCaptureCoordinator")
            // Another is to try and re-initialize minimally, though 'parent' makes this hard.
            // For now, we'll allow it to proceed but 'parent' will be uninitialized if created this way.
            // This will likely lead to a crash if methods relying on 'parent' are called.
            // A more robust solution would involve a proper decoding strategy if needed,
            // or ensuring this init is never actually called.
            // For the purpose of satisfying compiler, we must call super.init().
            // However, 'parent' must be initialized before super.init() if it's a non-optional let.
            // Making 'parent' an implicitly unwrapped optional or optional could bypass this,
            // but changes its semantics.
            // Given 'parent' is `RoomCaptureViewRepresentable`, we can't decode it simply.
            // The most straightforward stub for a class not meant to be decoded
            // is often to make this initializer failable and return nil, or fatalError.
            // However, to avoid changing 'parent' type, we'll proceed with a basic super.init(),
            // acknowledging this path is problematic if actually taken.
            // This is a common issue with delegates that are NSObject subclasses.
            // The compiler often wants NSCoding if @objc is involved deeply.

            // To satisfy the non-optional 'parent', we'd need a way to get it or make it optional.
            // Since 'parent' is crucial, and we can't get it from the coder easily here,
            // this path remains problematic if actually used for decoding.
            // For now, to make it compile without changing 'parent's type:
            // This will crash if parent is accessed after being created by this init.
            // A better approach if decoding was real: make parent optional or reconstruct.
            // To simply satisfy the compiler for a non-decoded class:
            if let decodedParent = coder.decodeObject(forKey: "parent") as? RoomCaptureViewRepresentable {
                 self.parent = decodedParent // This won't actually work as RoomCaptureViewRepresentable is a struct
            } else {
                // This is the problematic part. A struct parent cannot be simply decoded and assigned.
                // If this init is truly never called, a fatalError is the cleanest way to indicate that.
                fatalError("MosaicRoomCaptureCoordinator.init(coder:) parent could not be decoded. This init should not be used.")
            }
            // If parent was a class, you might decode it. Since it's a struct, this is more complex.
            // The simplest way to make this compile if parent MUST be non-optional
            // and this init is purely for conformance is often to fatalError.
            // Let's assume for now the fatalError is the intent if this path is hit.
            // self.parent = RoomCaptureViewRepresentable(capturedRoom: .constant(nil), isSessionRunning: .constant(false)) // Dummy, not ideal
            super.init() // Call super.init() after all properties of this class are initialized.
            print("Coordinator Initialized via init(coder:), parent might be in an invalid state.")
        }

        // Required method for NSCoding.
        // This coordinator does not need to save any state.
        func encode(with coder: NSCoder) {
            print("Coordinator: encode(with:) called.")
            // coder.encode(parent, forKey: "parent") // Can't encode parent struct directly this way
            // No properties to encode for this simple delegate coordinator.
        }

        // MARK: Original Properties and Methods
        var parent: RoomCaptureViewRepresentable
        var cancellables = Set<AnyCancellable>()
        var sessionActive: Bool = false

        init(parent: RoomCaptureViewRepresentable) {
            self.parent = parent
            super.init()
            print("Coordinator Initialized with parent, sessionActive = false")
        }

        // ... rest of the delegate methods from v5 ...
        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            print("RoomPlan Delegate: captureView(shouldPresent:error:)")
            if let error = error {
                 print("  Error before processing: \(error.localizedDescription)")
                 return false
            }
            print("  Proceeding with processing.")
            return true
        }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            print("RoomPlan Delegate: captureView(didPresent:error:), current sessionActive: \(sessionActive)")
            if let error = error {
                print("  Error during processing: \(error.localizedDescription)")
                 DispatchQueue.main.async {
                     self.parent.isSessionRunning = false
                 }
                return
            }
            print("  Processing successful. Updating parent's capturedRoom binding.")
            DispatchQueue.main.async {
                self.parent.capturedRoom = processedResult
                self.parent.isSessionRunning = false
            }
        }

        func captureSession(_ session: RoomCaptureSession, didChange states: RoomCaptureSession.Configuration) {
            print("RoomPlan Delegate: captureSession(didChange states: \(states)), current sessionActive: \(sessionActive)")
            if self.parent.isSessionRunning && !self.sessionActive {
                print("  Session configuration changed, likely started. Setting sessionActive = true")
                self.sessionActive = true
            }
        }

        func captureSession(_ session: RoomCaptureSession, didUpdate room: CapturedRoom) {
             // print("RoomPlan Delegate: captureSession(didUpdate room)")
        }

        func captureSession(_ session: RoomCaptureSession, didEndWith data: CapturedRoomData, error: Error?) {
             print("RoomPlan Delegate: captureSession(didEndWith:error:), current sessionActive: \(sessionActive)")
             if let error = error {
                 print("  Session ended with error: \(error.localizedDescription)")
             } else {
                 print("  Session ended successfully.")
             }
             DispatchQueue.main.async {
                  self.parent.isSessionRunning = false
                  self.sessionActive = false
                  print("  Set sessionActive = false in didEndWith")
             }
         }

        func captureSession(_ session: RoomCaptureSession, didFailWithError error: Error) {
            print("RoomPlan Delegate: captureSession(didFailWithError: \(error.localizedDescription)), current sessionActive: \(sessionActive)")
            DispatchQueue.main.async {
                 self.parent.isSessionRunning = false
                 self.sessionActive = false
                 print("  Set sessionActive = false in didFailWithError")
            }
        }
    }
}
