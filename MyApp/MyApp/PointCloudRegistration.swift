import simd

class PointCloudRegistration {
    func registerPointClouds(_ source: PointCloud, to target: PointCloud, maxIterations: Int = 50) -> (PointCloud, matrix_float4x4) {
        var sourcePoints = source.points
        var transformation = matrix_float4x4(1)
        var previousError: Float = .infinity

        for iteration in 0..<maxIterations {
            let (correspondences, error) = findCorrespondences(sourcePoints, target.points)

            guard !correspondences.isEmpty else { break }

            if abs(error - previousError) < 1e-6 {
                break
            }

            let newTransform = estimateTransform(correspondences)
            sourcePoints = applyTransform(sourcePoints, newTransform)
            transformation = newTransform * transformation
            previousError = error
        }

        let registered = PointCloud()
        registered.points = sourcePoints
        registered.timestamp = source.timestamp
        registered.handRotation = source.handRotation

        return (registered, transformation)
    }

    private func findCorrespondences(_ source: [Point3D], _ target: [Point3D]) -> ([(Point3D, Point3D)], Float) {
        var correspondences: [(Point3D, Point3D)] = []
        var totalDistance: Float = 0

        for sourcePoint in source {
            if let (closestTarget, distance) = findClosestPoint(sourcePoint, in: target) {
                correspondences.append((sourcePoint, closestTarget))
                totalDistance += distance
            }
        }

        let error = correspondences.isEmpty ? Float.infinity : totalDistance / Float(correspondences.count)
        return (correspondences, error)
    }

    private func findClosestPoint(_ point: Point3D, in cloud: [Point3D]) -> (Point3D, Float)? {
        var closest: (Point3D, Float)?
        var minDistance: Float = .infinity

        for targetPoint in cloud {
            let distance = simd_distance(point.simdVector, targetPoint.simdVector)
            if distance < minDistance {
                minDistance = distance
                closest = (targetPoint, distance)
            }
        }

        return closest
    }

    private func estimateTransform(_ correspondences: [(Point3D, Point3D)]) -> matrix_float4x4 {
        guard !correspondences.isEmpty else { return matrix_float4x4(1) }

        let sourceCenter = computeCentroid(correspondences.map { $0.0 })
        let targetCenter = computeCentroid(correspondences.map { $0.1 })

        var H = matrix_float3x3(0)
        for (source, target) in correspondences {
            let s = source.simdVector - sourceCenter
            let t = target.simdVector - targetCenter
            H += outerProduct(s, t)
        }

        let (rotation, _) = svdDecomposition(H)
        let translation = targetCenter - rotation * sourceCenter

        var transform = matrix_float4x4(1)
        transform[0][0] = rotation[0][0]
        transform[0][1] = rotation[0][1]
        transform[0][2] = rotation[0][2]
        transform[1][0] = rotation[1][0]
        transform[1][1] = rotation[1][1]
        transform[1][2] = rotation[1][2]
        transform[2][0] = rotation[2][0]
        transform[2][1] = rotation[2][1]
        transform[2][2] = rotation[2][2]
        transform[3][0] = translation.x
        transform[3][1] = translation.y
        transform[3][2] = translation.z

        return transform
    }

    private func computeCentroid(_ points: [Point3D]) -> SIMD3<Float> {
        guard !points.isEmpty else { return SIMD3(0, 0, 0) }
        let sum = points.reduce(SIMD3<Float>(0, 0, 0)) { $0 + $1.simdVector }
        return sum / Float(points.count)
    }

    private func outerProduct(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> matrix_float3x3 {
        matrix_float3x3(
            [a.x * b.x, a.x * b.y, a.x * b.z],
            [a.y * b.x, a.y * b.y, a.y * b.z],
            [a.z * b.x, a.z * b.y, a.z * b.z]
        )
    }

    private func svdDecomposition(_ matrix: matrix_float3x3) -> (matrix_float3x3, matrix_float3x3) {
        // Simplified SVD - using Gram-Schmidt for rotation extraction
        var U = matrix
        var col0 = SIMD3(U[0][0], U[1][0], U[2][0])
        let len0 = length(col0)
        if len0 > 0 { col0 /= len0 }

        var col1 = SIMD3(U[0][1], U[1][1], U[2][1])
        let proj1 = dot(col1, col0) * col0
        col1 -= proj1
        let len1 = length(col1)
        if len1 > 0 { col1 /= len1 }

        let col2 = cross(col0, col1)

        var result = matrix_float3x3(1)
        result[0][0] = col0.x; result[1][0] = col0.y; result[2][0] = col0.z
        result[0][1] = col1.x; result[1][1] = col1.y; result[2][1] = col1.z
        result[0][2] = col2.x; result[1][2] = col2.y; result[2][2] = col2.z

        return (result, matrix_float3x3(1))
    }

    private func applyTransform(_ points: [Point3D], _ transform: matrix_float4x4) -> [Point3D] {
        return points.map { point in
            let vec4 = simd_float4(point.x, point.y, point.z, 1)
            let transformed = transform * vec4
            return Point3D(
                x: transformed.x,
                y: transformed.y,
                z: transformed.z,
                r: point.r,
                g: point.g,
                b: point.b
            )
        }
    }
}
