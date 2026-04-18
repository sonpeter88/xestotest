import ARKit
import simd

class DepthDataProcessor {
    func depthMapToPointCloud(depthMap: CVPixelBuffer, intrinsics: matrix_float3x3, cropRect: CGRect? = nil) -> PointCloud {
        let pointCloud = PointCloud()

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return pointCloud }

        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

        let minDepth: Float = 0.1
        let maxDepth: Float = 1.5

        let croppingRect = cropRect ?? CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        let minX = Int(Float(width) * Float(croppingRect.minX))
        let maxX = Int(Float(width) * Float(croppingRect.maxX))
        let minY = Int(Float(height) * Float(croppingRect.minY))
        let maxY = Int(Float(height) * Float(croppingRect.maxY))

        for y in stride(from: minY, to: maxY, by: 2) {
            for x in stride(from: minX, to: maxX, by: 2) {
                let depthValue = floatBuffer[y * width + x]

                guard depthValue > minDepth && depthValue < maxDepth else { continue }

                let normalizedX = Float(x) / Float(width)
                let normalizedY = Float(y) / Float(height)

                let pixelCoord = simd_float3(normalizedX, normalizedY, 1)
                let invK = simd_float3x3(
                    [1.0 / intrinsics[0][0], 0, -intrinsics[0][2] / intrinsics[0][0]],
                    [0, 1.0 / intrinsics[1][1], -intrinsics[1][2] / intrinsics[1][1]],
                    [0, 0, 1]
                )

                let cameraCoord = invK * pixelCoord * depthValue

                let r = UInt8((1 - (depthValue - minDepth) / (maxDepth - minDepth)) * 255)
                let point = Point3D(
                    x: cameraCoord.x,
                    y: cameraCoord.y,
                    z: cameraCoord.z,
                    r: r, g: r, b: r
                )

                pointCloud.points.append(point)
            }
        }

        return pointCloud
    }

    func filterPointCloudOutliers(_ pointCloud: PointCloud, neighborhoodRadius: Float = 0.05, minNeighbors: Int = 5) -> PointCloud {
        let filtered = PointCloud()
        filtered.timestamp = pointCloud.timestamp
        filtered.handRotation = pointCloud.handRotation

        for point in pointCloud.points {
            let pointVec = point.simdVector
            let neighbors = pointCloud.points.filter { neighbor in
                let distance = simd_distance(pointVec, neighbor.simdVector)
                return distance < neighborhoodRadius && distance > 0
            }

            if neighbors.count >= minNeighbors {
                filtered.points.append(point)
            }
        }

        return filtered
    }

    func smoothPointCloud(_ pointCloud: PointCloud, radius: Float = 0.03, iterations: Int = 1) -> PointCloud {
        var smoothed = pointCloud

        for _ in 0..<iterations {
            let newPoints = smoothed.points.map { point -> Point3D in
                let pointVec = point.simdVector
                var sumPosition = pointVec
                var count: Float = 1

                for neighbor in smoothed.points {
                    let distance = simd_distance(pointVec, neighbor.simdVector)
                    if distance < radius && distance > 0 {
                        sumPosition += neighbor.simdVector
                        count += 1
                    }
                }

                let smoothedPos = sumPosition / count
                return Point3D(
                    x: smoothedPos.x,
                    y: smoothedPos.y,
                    z: smoothedPos.z,
                    r: point.r,
                    g: point.g,
                    b: point.b
                )
            }

            smoothed.points = newPoints
        }

        return smoothed
    }
}
