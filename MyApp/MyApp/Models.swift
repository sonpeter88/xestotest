import Foundation
import simd

struct Point3D: Codable {
    let x: Float
    let y: Float
    let z: Float
    let r: UInt8
    let g: UInt8
    let b: UInt8

    init(x: Float, y: Float, z: Float, r: UInt8 = 255, g: UInt8 = 255, b: UInt8 = 255) {
        self.x = x
        self.y = y
        self.z = z
        self.r = r
        self.g = g
        self.b = b
    }

    var simdVector: SIMD3<Float> {
        SIMD3(x, y, z)
    }
}

class PointCloud {
    var points: [Point3D] = []
    var timestamp: Date = Date()
    var handRotation: HandRotation = .neutral

    var centroid: SIMD3<Float> {
        guard !points.isEmpty else { return SIMD3(0, 0, 0) }
        let sum = points.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.simdVector }
        return sum / Float(points.count)
    }

    func normalizeByRemovingCentroid() {
        let center = centroid
        points = points.map { point in
            Point3D(
                x: point.x - center.x,
                y: point.y - center.y,
                z: point.z - center.z,
                r: point.r, g: point.g, b: point.b
            )
        }
    }

    func downsample(by factor: Int) -> PointCloud {
        let downsampled = PointCloud()
        downsampled.timestamp = timestamp
        downsampled.handRotation = handRotation
        downsampled.points = stride(from: 0, to: points.count, by: factor).map { points[$0] }
        return downsampled
    }
}

enum HandRotation: Int, Codable {
    case neutral = 0
    case rotation_30 = 1
    case rotation_60 = 2
    case rotation_90 = 3
    case rotation_120 = 4
    case rotation_150 = 5
    case rotation_180 = 6
    case rotation_210 = 7
    case rotation_240 = 8
    case rotation_270 = 9
    case rotation_300 = 10
    case rotation_330 = 11

    var degrees: Int {
        rawValue * 30
    }

    var displayString: String {
        "Rotate to \(degrees)°"
    }

    static let allCases: [HandRotation] = (0..<12).compactMap { HandRotation(rawValue: $0) }

    var next: HandRotation? {
        guard rawValue < 11 else { return nil }
        return HandRotation(rawValue: rawValue + 1)
    }
}

struct HandLandmarks {
    let wristPosition: simd_float3
    let handedness: String // "left" or "right"
    let confidence: Float
    var allPositions: [simd_float3]

    func estimateHandRotationAroundYAxis() -> Float {
        // Use middle finger and wrist to estimate rotation
        guard allPositions.count > 12 else { return 0 }
        let wrist = allPositions[0]
        let middleFingerMcp = allPositions[12]
        let direction = middleFingerMcp - wrist
        let angle = atan2(direction.x, direction.z)
        return angle
    }
}
