import Vision
import CoreImage
import ARKit

class HandPoseDetector {
    private let handPoseRequest = VNDetectHumanHandPoseRequest()
    private let visionQueue = DispatchQueue(label: "com.myapp.handpose")

    func detectHandPose(from pixelBuffer: CVPixelBuffer) async -> HandLandmarks? {
        return await withCheckedContinuation { continuation in
            visionQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)

                do {
                    try requestHandler.perform([self.handPoseRequest])

                    guard let observations = self.handPoseRequest.results as? [VNHumanHandPoseObservation],
                          let observation = observations.first else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let landmarks = self.extractLandmarks(from: observation)
                    continuation.resume(returning: landmarks)
                } catch {
                    print("Hand pose detection error: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func extractLandmarks(from observation: VNHumanHandPoseObservation) -> HandLandmarks? {
        do {
            let allPoints = try observation.recognizedPoints(.all)
            guard let wristPoint = allPoints[.wrist] else { return nil }

            let wristPosition = simd_float3(
                Float(wristPoint.location.x),
                Float(wristPoint.location.y),
                0
            )

            var positions: [simd_float3] = []
            let sortedKeys: [VNHumanHandPoseObservation.JointName] = [
                .wrist, .thumbCMC, .thumbMP, .thumbIP, .thumbTip,
                .indexMCP, .indexPIP, .indexDIP, .indexTip,
                .middleMCP, .middlePIP, .middleDIP, .middleTip,
                .ringMCP, .ringPIP, .ringDIP, .ringTip,
                .littleMCP, .littlePIP, .littleDIP, .littleTip
            ]

            for key in sortedKeys {
                if let point = allPoints[key] {
                    positions.append(simd_float3(
                        Float(point.location.x),
                        Float(point.location.y),
                        Float(point.confidence)
                    ))
                }
            }

            let handedness = observation.chirality == .left ? "left" : "right"
            return HandLandmarks(
                wristPosition: wristPosition,
                handedness: handedness,
                confidence: Float(observation.confidence),
                allPositions: positions
            )
        } catch {
            print("Error extracting landmarks: \(error)")
            return nil
        }
    }

    func isHandInTargetRotation(_ landmarks: HandLandmarks, target: HandRotation, tolerance: Float = 0.3) -> Bool {
        let estimatedRotation = landmarks.estimateHandRotationAroundYAxis()
        let targetAngle = Float(target.degrees) * .pi / 180.0
        let angleDifference = abs(estimatedRotation - targetAngle)

        return angleDifference < tolerance || abs(angleDifference - 2 * .pi) < tolerance
    }
}
