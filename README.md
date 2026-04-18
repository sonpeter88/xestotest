# 3D Hand Scanner

A comprehensive iOS application for capturing and reconstructing 3D models of your hand using depth camera technology and computer vision.

## Features

- **Hand Pose Detection**: Real-time hand landmark detection using Vision framework
- **Depth Capture**: Automatic depth map capture via ARKit
- **Multi-Rotation Scanning**: Captures 12 different hand rotations (30° increments) for complete coverage
- **Point Cloud Generation**: Converts depth maps to 3D point clouds
- **Intelligent Stitching**: ICP (Iterative Closest Point) algorithm to register and merge point clouds
- **3D Visualization**: Real-time SceneKit viewer for visualizing point clouds
- **PLY Export**: Export final 3D model in PLY format for use in 3D software

## Technical Architecture

### Core Components

#### Hand Pose Detection (`HandPoseDetector.swift`)
- Uses Vision framework's `VNDetectHumanHandPoseRequest`
- Extracts 21 hand landmarks for pose estimation
- Calculates hand rotation angle for guidance system
- Provides rotation tolerance checking (±0.3 radians)

#### Depth Processing (`DepthDataProcessor.swift`)
- Converts depth maps to 3D point clouds using camera intrinsics
- Implements statistical outlier removal (neighborhood-based filtering)
- Gaussian smoothing for noise reduction
- Configurable depth range (0.1m - 1.5m)

#### Point Cloud Registration (`PointCloudRegistration.swift`)
- ICP algorithm for point cloud alignment
- Automatic correspondence finding using nearest neighbor search
- Iterative refinement up to 50 iterations
- SVD-based rotation extraction
- Convergence detection with error thresholding

#### Data Models (`Models.swift`)
- `Point3D`: Individual 3D point with RGB color
- `PointCloud`: Collection of points with metadata
- `HandRotation`: Enum for 12 rotation states (0°-330° in 30° increments)
- `HandLandmarks`: Hand pose data with confidence scores

#### Export (`PLYExporter.swift`)
- ASCII PLY format (Polygon File Format)
- Vertex position (X, Y, Z) and color (R, G, B)
- Compatible with major 3D software (Blender, Meshlab, CloudCompare)

#### AR Session Management (`ARSessionManager.swift`)
- Initializes ARKit with depth data support
- Handles frame-by-frame depth captures
- Requires LiDAR sensor (iPhone 12 Pro and later)

#### UI Controllers
- `ViewController.swift`: Main menu with app introduction
- `CaptureViewController.swift`: Real-time capture workflow with guidance
- `PointCloudViewer.swift`: 3D visualization and export interface

## Hardware Requirements

- **iPhone 12 Pro or later** (requires LiDAR depth sensor)
- **iPad Pro (2020 or later)** with LiDAR
- iOS 14.0 or later
- Adequate lighting for hand visibility

## Usage Instructions

### 1. Launch and Permissions
- App requests camera access on first launch
- Allow access to proceed with scanning

### 2. Start Scanning
- Tap "Start Scanning" on main menu
- Hold closed fist in front of camera with good lighting
- Keep hand visible and steady

### 3. Rotation Guidance
- Follow on-screen rotation prompts (0°, 30°, 60°... 330°)
- Wait for rotation confirmation (yellow guidance text)
- App automatically captures when rotation is correct
- 1-second delay between captures to prevent duplicates

### 4. Capture Progress
- Green progress bar shows rotation completion
- Real-time status updates
- Currently capturing: X/12 rotations

### 5. Processing
- After final rotation, app stitches all point clouds
- Processing happens on background thread to prevent UI freeze
- SceneKit viewer loads with complete 3D model

### 6. Visualization and Export
- Rotate and zoom model using touch gestures
- Pan with two-finger drag
- Tap "Export PLY" to save model
- Tap "Done" to return to main menu

## Building and Running

### From Xcode
```bash
open MyApp.xcodeproj
# Select iPhone 12 Pro or later in simulator/device
# Cmd+R to build and run
```

### Command Line
```bash
xcodebuild -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Release \
  -destination 'platform=iOS,name=iPhone 12 Pro'
```

## Project Structure

```
MyApp/
├── AppDelegate.swift           # App lifecycle management
├── SceneDelegate.swift         # Scene lifecycle (iOS 13+)
├── ViewController.swift        # Main menu UI
├── Models.swift               # Data structures
├── HandPoseDetector.swift     # Vision framework integration
├── DepthDataProcessor.swift   # Depth-to-point cloud conversion
├── PointCloudRegistration.swift # ICP stitching algorithm
├── PLYExporter.swift          # File export
├── ARSessionManager.swift     # ARKit session handling
├── CaptureViewController.swift # Capture workflow UI
├── PointCloudViewer.swift     # 3D visualization
├── LaunchScreen.storyboard    # Launch screen
└── Info.plist                 # App configuration
```

## Required Frameworks

- **ARKit**: Depth data capture
- **Vision**: Hand pose detection
- **SceneKit**: 3D visualization
- **MetalKit**: GPU acceleration (optional)
- **RealityKit**: AR features
- **AVFoundation**: Camera permissions
- **simd**: Vector/matrix math

## Algorithms

### Hand Rotation Estimation
```swift
angle = atan2(middleFingerDirection.x, middleFingerDirection.z)
```
Uses wrist-to-middle-finger vector for Y-axis rotation detection.

### Outlier Removal
- Neighborhood radius: 5cm
- Minimum neighbors required: 5
- Removes isolated points with insufficient local density

### Point Cloud Smoothing
- Gaussian-like smoothing with configurable radius (3cm default)
- Iterative refinement (1 iteration default)

### Point Cloud Registration
- **Correspondence**: Nearest neighbor search (brute force)
- **Transformation**: SVD-based least squares
- **Convergence**: Error threshold 1e-6
- **Maximum iterations**: 50

## Performance Considerations

### Point Cloud Density
- Default: Every 2nd pixel sampled (2x decimation)
- Typical output: 50,000-100,000 points per rotation
- Total stitched cloud: 600,000-1,200,000 points

### Processing Time
- Depth capture: Real-time (device dependent)
- Hand pose detection: ~30-50ms
- Point cloud generation: ~100-200ms
- ICP registration: ~2-5 seconds per pair
- Total stitching: ~10-20 seconds for 12 rotations

### Memory Usage
- Single point cloud: ~5-10MB
- All 12 rotations in memory: ~60-120MB
- Post-stitching: ~30-40MB

## Export and Post-Processing

### PLY File Format
```
ply
format ascii 1.0
element vertex 850000
property float x
property float y
property float z
property uchar red
property uchar green
property uchar blue
end_header
```

### Recommended 3D Software
- **Blender**: Free, full-featured 3D modeling
- **Meshlab**: Point cloud processing and analysis
- **CloudCompare**: Cloud comparison and registration
- **MeshLab**: Surface reconstruction from points

## Troubleshooting

### "AR not available"
- Ensure device supports ARKit with depth
- Check iOS version is 14.0+

### "Hand not detected"
- Ensure adequate lighting
- Keep hand clearly visible
- Hand should be fully in frame

### Poor point cloud quality
- Improve lighting conditions
- Hold hand more steadily
- Move camera closer (0.3-0.8m distance)

### Stitching artifacts
- Ensure good overlap between rotations
- Maintain consistent hand position
- Rotate in small increments (30°)

## Future Enhancements

- [ ] Real-time point cloud preview during capture
- [ ] Manual point cloud alignment adjustment
- [ ] Mesh reconstruction from point clouds
- [ ] Texture mapping support
- [ ] Multi-hand detection
- [ ] Hand gesture recognition
- [ ] Cloud storage integration
- [ ] Comparison tools for hand models over time

## Requirements

- **Xcode**: 15.3 or later
- **iOS**: 14.0 or later (preferably 16.0+)
- **Swift**: 5.0 or later
- **Hardware**: iPhone 12 Pro+ or iPad Pro with LiDAR

## License

This project is provided as-is for educational and research purposes.
