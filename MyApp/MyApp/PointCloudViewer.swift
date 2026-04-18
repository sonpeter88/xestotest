import UIKit
import SceneKit

class PointCloudViewer: UIViewController {
    private let sceneView = SCNView()
    private let scene = SCNScene()
    private var pointCloudNode: SCNNode?

    var pointCloud: PointCloud? {
        didSet {
            if isViewLoaded {
                updateVisualization()
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupSceneKit()
        updateVisualization()
    }

    private func setupSceneKit() {
        view.addSubview(sceneView)
        sceneView.frame = view.bounds
        sceneView.scene = scene
        sceneView.autoenablesDefaultLighting = true
        sceneView.allowsCameraControl = true
        sceneView.backgroundColor = .black

        let camera = SCNCamera()
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 0.5)
        scene.rootNode.addChildNode(cameraNode)

        addControlPanel()
    }

    private func addControlPanel() {
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Done", for: .normal)
        closeButton.backgroundColor = .systemBlue
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        let exportButton = UIButton(type: .system)
        exportButton.setTitle("Export PLY", for: .normal)
        exportButton.backgroundColor = .systemGreen
        exportButton.setTitleColor(.white, for: .normal)
        exportButton.layer.cornerRadius = 8
        exportButton.translatesAutoresizingMaskIntoConstraints = false
        exportButton.addTarget(self, action: #selector(exportTapped), for: .touchUpInside)
        view.addSubview(exportButton)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            closeButton.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            closeButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 100),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            exportButton.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            exportButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            exportButton.widthAnchor.constraint(equalToConstant: 100),
            exportButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    private func updateVisualization() {
        pointCloudNode?.removeFromParentNode()

        guard let pointCloud = pointCloud else { return }

        pointCloudNode = createPointCloudNode(from: pointCloud)
        if let node = pointCloudNode {
            scene.rootNode.addChildNode(node)
        }
    }

    private func createPointCloudNode(from pointCloud: PointCloud) -> SCNNode {
        let node = SCNNode()

        let geometry = SCNGeometry()
        var sources: [SCNGeometrySource] = []
        var colors: [SCNGeometryElement] = []

        let positions = pointCloud.points.map { point -> SCNVector3 in
            SCNVector3(point.x, point.y, point.z)
        }

        let positionData = NSData(
            bytes: positions,
            length: MemoryLayout<SCNVector3>.size * positions.count
        ) as Data

        let positionSource = SCNGeometrySource(
            data: positionData,
            semantic: .vertex,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )
        sources.append(positionSource)

        let colorData = NSMutableData()
        for point in pointCloud.points {
            var r = Float(point.r) / 255.0
            var g = Float(point.g) / 255.0
            var b = Float(point.b) / 255.0
            var a: Float = 1.0
            colorData.append(&r, length: MemoryLayout<Float>.size)
            colorData.append(&g, length: MemoryLayout<Float>.size)
            colorData.append(&b, length: MemoryLayout<Float>.size)
            colorData.append(&a, length: MemoryLayout<Float>.size)
        }

        let colorSource = SCNGeometrySource(
            data: colorData as Data,
            semantic: .color,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 4,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.size
        )
        sources.append(colorSource)

        let indices = Array(0..<UInt32(positions.count))
        let indexData = NSData(
            bytes: indices,
            length: MemoryLayout<UInt32>.size * indices.count
        ) as Data

        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .point,
            primitiveCount: positions.count,
            bytesPerIndex: MemoryLayout<UInt32>.size
        )
        colors.append(element)

        geometry.sources = sources
        geometry.elements = colors

        node.geometry = geometry

        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]

        return node
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func exportTapped() {
        guard let pointCloud = pointCloud else { return }

        let exporter = PLYExporter()
        let fileName = "hand_model_\(Date().timeIntervalSince1970).ply"
        if let fileURL = exporter.exportPointCloudToPLY(pointCloud, fileName: fileName) {
            let alert = UIAlertController(
                title: "Export Successful",
                message: "Saved to: \(fileURL.lastPathComponent)",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
}
