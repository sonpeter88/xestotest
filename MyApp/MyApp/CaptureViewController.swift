import UIKit
import ARKit
import RealityKit

class CaptureViewController: UIViewController, DepthDataDelegate {
    private let arSessionManager = ARSessionManager()
    private let handPoseDetector = HandPoseDetector()
    private let depthProcessor = DepthDataProcessor()
    private let registration = PointCloudRegistration()

    private var capturedPointClouds: [PointCloud] = []
    private var currentRotationTarget: HandRotation = .neutral
    private var isCapturing = false
    private var frameCount = 0
    private var lastCaptureTime = Date()

    private let arView = ARView(frame: .zero)
    private let statusLabel = UILabel()
    private let rotationLabel = UILabel()
    private let captureButton = UIButton(type: .system)
    private let progressView = UIProgressView()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupARSession()
    }

    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(arView)
        arView.frame = view.bounds

        statusLabel.textColor = .white
        statusLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        view.addSubview(statusLabel)

        rotationLabel.textColor = .yellow
        rotationLabel.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        rotationLabel.textAlignment = .center
        view.addSubview(rotationLabel)

        progressView.tintColor = .green
        view.addSubview(progressView)

        captureButton.setTitle("Start Capture", for: .normal)
        captureButton.backgroundColor = .systemBlue
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.layer.cornerRadius = 10
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        view.addSubview(captureButton)

        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: safeArea.topAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),

            rotationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            rotationLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 15),
            rotationLabel.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            rotationLabel.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),

            progressView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            progressView.topAnchor.constraint(equalTo: rotationLabel.bottomAnchor, constant: 15),
            progressView.widthAnchor.constraint(equalTo: safeArea.widthAnchor, multiplier: 0.8),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 200),
            captureButton.heightAnchor.constraint(equalToConstant: 50),
        ])

        for subview in [statusLabel, rotationLabel, progressView, captureButton] {
            subview.translatesAutoresizingMaskIntoConstraints = false
        }

        updateUI()
    }

    private func setupARSession() {
        arSessionManager.depthDataDelegate = self
        do {
            try arSessionManager.startARSession()
        } catch {
            statusLabel.text = "AR not available: \(error)"
        }
    }

    @objc private func captureButtonTapped() {
        isCapturing.toggle()
        currentRotationTarget = .neutral
        capturedPointClouds.removeAll()
        updateUI()
    }

    func didCaptureDepth(_ depthMap: CVPixelBuffer, intrinsics: matrix_float3x3, frame: ARFrame) {
        guard isCapturing else { return }

        frameCount += 1
        if frameCount % 10 != 0 { return } // Process every 10th frame

        Task {
            guard let pixelBuffer = frame.capturedImage as? CVPixelBuffer else { return }
            let landmarks = await handPoseDetector.detectHandPose(from: pixelBuffer)

            DispatchQueue.main.async {
                if let landmarks = landmarks {
                    let isRotationCorrect = self.handPoseDetector.isHandInTargetRotation(landmarks, target: self.currentRotationTarget)

                    if isRotationCorrect && Date().timeIntervalSince(self.lastCaptureTime) > 1.0 {
                        self.capturePointCloud(depthMap, intrinsics: intrinsics)
                        self.lastCaptureTime = Date()
                        self.advanceToNextRotation()
                    }

                    self.updateUI()
                }
            }
        }
    }

    private func capturePointCloud(_ depthMap: CVPixelBuffer, intrinsics: matrix_float3x3) {
        var pointCloud = depthProcessor.depthMapToPointCloud(depthMap: depthMap, intrinsics: intrinsics)
        pointCloud = depthProcessor.filterPointCloudOutliers(pointCloud)
        pointCloud = depthProcessor.smoothPointCloud(pointCloud)
        pointCloud.handRotation = currentRotationTarget
        pointCloud.timestamp = Date()

        capturedPointClouds.append(pointCloud)
        print("Captured point cloud \(capturedPointClouds.count) at rotation \(currentRotationTarget.degrees)°")
    }

    private func advanceToNextRotation() {
        if let next = currentRotationTarget.next {
            currentRotationTarget = next
        } else {
            completeCapture()
        }
    }

    private func completeCapture() {
        isCapturing = false
        stitchPointClouds()
    }

    private func stitchPointClouds() {
        var stitchedCloud = capturedPointClouds.first ?? PointCloud()

        for i in 1..<capturedPointClouds.count {
            let (registered, _) = registration.registerPointClouds(capturedPointClouds[i], to: stitchedCloud)
            stitchedCloud.points.append(contentsOf: registered.points)
        }

        stitchedCloud.normalizeByRemovingCentroid()
        let exporter = PLYExporter()
        if let fileURL = exporter.exportPointCloudToPLY(stitchedCloud) {
            showCompletion(fileURL: fileURL)
        }
    }

    private func showCompletion(fileURL: URL) {
        let alert = UIAlertController(title: "Capture Complete!", message: "Model saved to Documents folder", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }

    private func updateUI() {
        statusLabel.text = isCapturing
            ? "Capturing...\n\(capturedPointClouds.count)/12 rotations"
            : "Ready to scan hand"

        rotationLabel.text = currentRotationTarget.displayString
        progressView.progress = Float(capturedPointClouds.count) / 12.0
        captureButton.setTitle(isCapturing ? "Stop Capture" : "Start Capture", for: .normal)
        captureButton.backgroundColor = isCapturing ? .systemRed : .systemBlue
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        arSessionManager.pauseARSession()
    }
}
