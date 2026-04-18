import ARKit
import Metal

class ARSessionManager: NSObject, ARSessionDelegate {
    let arSession = ARSession()
    var depthDataDelegate: DepthDataDelegate?
    var lastDepthFrame: (depthMap: CVPixelBuffer, intrinsics: matrix_float3x3)?

    override init() {
        super.init()
        arSession.delegate = self
    }

    func startARSession() throws {
        guard ARWorldTrackingConfiguration.isSupported else {
            throw ARSessionError.notSupported
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = []
        configuration.frameSemantics.insert(.personSegmentationWithDepth)

        if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentationWithDepth) {
            arSession.run(configuration)
        } else {
            throw ARSessionError.depthNotSupported
        }
    }

    func pauseARSession() {
        arSession.pause()
    }

    func resumeARSession() {
        try? startARSession()
    }

    func captureDepthFrame() -> (CVPixelBuffer, matrix_float3x3)? {
        return lastDepthFrame
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        if let depthData = frame.capturedDepthData {
            let depthMap = depthData.depthMap
            guard let intrinsics = frame.camera.intrinsics else { return }

            lastDepthFrame = (depthMap, intrinsics)
            depthDataDelegate?.didCaptureDepth(depthMap, intrinsics: intrinsics, frame: frame)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("AR Session failed: \(error)")
    }
}

enum ARSessionError: Error {
    case notSupported
    case depthNotSupported
}

protocol DepthDataDelegate: AnyObject {
    func didCaptureDepth(_ depthMap: CVPixelBuffer, intrinsics: matrix_float3x3, frame: ARFrame)
}
