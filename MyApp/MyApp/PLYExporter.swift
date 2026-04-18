import Foundation

class PLYExporter {
    func exportPointCloudToPLY(_ pointCloud: PointCloud, fileName: String = "hand_model.ply") -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        var plyContent = generatePLYHeader(pointCount: pointCloud.points.count)

        for point in pointCloud.points {
            plyContent += String(format: "%.6f %.6f %.6f %d %d %d\n",
                                point.x, point.y, point.z,
                                Int(point.r), Int(point.g), Int(point.b))
        }

        do {
            try plyContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("PLY file exported to: \(fileURL)")
            return fileURL
        } catch {
            print("Failed to export PLY file: \(error)")
            return nil
        }
    }

    func exportMultiplePointCloudsToPLY(_ pointClouds: [PointCloud], fileName: String = "hand_model_combined.ply") -> URL? {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsURL.appendingPathComponent(fileName)

        let totalPoints = pointClouds.reduce(0) { $0 + $1.points.count }
        var plyContent = generatePLYHeader(pointCount: totalPoints)

        for pointCloud in pointClouds {
            for point in pointCloud.points {
                plyContent += String(format: "%.6f %.6f %.6f %d %d %d\n",
                                    point.x, point.y, point.z,
                                    Int(point.r), Int(point.g), Int(point.b))
            }
        }

        do {
            try plyContent.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Combined PLY file exported to: \(fileURL)")
            return fileURL
        } catch {
            print("Failed to export combined PLY file: \(error)")
            return nil
        }
    }

    private func generatePLYHeader(pointCount: Int) -> String {
        return """
        ply
        format ascii 1.0
        comment Hand 3D Model
        element vertex \(pointCount)
        property float x
        property float y
        property float z
        property uchar red
        property uchar green
        property uchar blue
        end_header
        """
    }
}
