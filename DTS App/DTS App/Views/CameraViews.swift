//
//  CameraViews.swift
//  DTS App
//
//  Created by GitHub Copilot on 8/18/25.
//

import SwiftUI
import AVFoundation
import CoreLocation
import UIKit

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var captureCount: Int
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> NativeCameraViewController {
        let cameraVC = NativeCameraViewController()
        cameraVC.delegate = context.coordinator
        return cameraVC
    }

    func updateUIViewController(_ uiViewController: NativeCameraViewController, context: Context) {
        // Camera view controller doesn't need updates
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func didCapturePhoto(_ image: UIImage) {
            parent.onImageCaptured(image)
            parent.captureCount += 1
        }

        func didCancel() {
            parent.isPresented = false
        }
    }
}

class NativeCameraViewController: UIViewController {
    weak var delegate: CameraView.Coordinator?

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var currentDevice: AVCaptureDevice!
    private var currentCameraInput: AVCaptureDeviceInput?

    // Available camera lenses on device
    private var availableLenses: [AVCaptureDevice] = []

    // UI Elements (matching native Camera app)
    private var previewView: UIView!
    private var controlsContainer: UIView!
    private var shutterButton: UIButton!
    private var switchCameraButton: UIButton!
    private var flashButton: UIButton!
    private var closeButton: UIButton!
    private var zoomButtonsStack: UIStackView!
    private var photoCounterLabel: UILabel!

    // Zoom levels with lens switching: 0.5x (ultra-wide), 1x (wide), 2x (telephoto), 5x (telephoto + digital)
    private let zoomLevels: [Float] = [0.5, 1.0, 2.0, 5.0]
    private var currentZoomIndex = 1 // Start at 1x (wide-angle)

    private var flashMode: AVCaptureDevice.FlashMode = .auto
    private var photoCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        // Force portrait orientation and disable rotation
        self.modalPresentationStyle = .fullScreen

        setupCamera()
        setupUI()
        setupConstraints()

        // Force interface to stay in portrait
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()

        // Force portrait orientation when view appears
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        // Try to find all available back cameras
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )

        availableLenses = discoverySession.devices

        print("Found \(availableLenses.count) camera lenses:")
        for lens in availableLenses {
            print("  - \(lens.deviceType.displayName): \(lens.minAvailableVideoZoomFactor)x - \(lens.maxAvailableVideoZoomFactor)x")
        }

        // Start with wide-angle camera (1x)
        switchToCamera(for: 1.0)
    }

    private func switchToCamera(for zoomLevel: Float) {
        let targetLens: AVCaptureDevice?

        switch zoomLevel {
        case 0.5:
            targetLens = availableLenses.first { $0.deviceType == .builtInUltraWideCamera }
        case 1.0, 2.0, 5.0:
            // Use wide-angle for 1x, telephoto preferred for 2x and 5x
            if zoomLevel >= 2.0 {
                targetLens = availableLenses.first { $0.deviceType == .builtInTelephotoCamera }
                    ?? availableLenses.first { $0.deviceType == .builtInWideAngleCamera }
            } else {
                targetLens = availableLenses.first { $0.deviceType == .builtInWideAngleCamera }
            }
        default:
            targetLens = availableLenses.first { $0.deviceType == .builtInWideAngleCamera }
        }

        guard let newLens = targetLens else {
            print("No suitable lens found for \(zoomLevel)x zoom")
            return
        }

        // Skip if already using the correct lens
        if currentDevice?.uniqueID == newLens.uniqueID {
            // Just adjust zoom on current device
            setZoom(factor: max(zoomLevel, Float(newLens.minAvailableVideoZoomFactor)))
            return
        }

        captureSession.beginConfiguration()

        // Remove current input
        if let currentInput = captureSession.inputs.first {
            captureSession.removeInput(currentInput)
        }

        // Add new input
        do {
            let newInput = try AVCaptureDeviceInput(device: newLens)
            if captureSession.canAddInput(newInput) {
                captureSession.addInput(newInput)
                currentDevice = newLens

                // Set up photo output if needed
                if photoOutput == nil {
                    photoOutput = AVCapturePhotoOutput()
                    if captureSession.canAddOutput(photoOutput!) {
                        captureSession.addOutput(photoOutput!)
                    }
                }

                print("Switched to \(newLens.deviceType.displayName) lens")

                // Apply zoom if needed (for telephoto + digital zoom)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if zoomLevel > 2.0 && newLens.deviceType == .builtInTelephotoCamera {
                        // Use digital zoom on telephoto lens for 5x
                        self.setZoom(factor: zoomLevel / 2.0) // 5x total = 2x optical + 2.5x digital
                    } else {
                        self.setZoom(factor: max(zoomLevel, Float(newLens.minAvailableVideoZoomFactor)))
                    }
                }
            }
        } catch {
            print("Error switching camera: \(error)")
        }

        captureSession.commitConfiguration()
    }

    private func setupUI() {
        view.backgroundColor = .black

        // Preview view (full screen)
        previewView = UIView()
        previewView.backgroundColor = .black
        view.addSubview(previewView)

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(previewLayer)

        // Controls container (bottom section, native Camera app style)
        controlsContainer = UIView()
        controlsContainer.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        view.addSubview(controlsContainer)

        // Close button (top left, native style)
        closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        closeButton.layer.cornerRadius = 22
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        view.addSubview(closeButton)

        // Flash button (top left, next to close)
        flashButton = UIButton(type: .system)
        updateFlashButtonAppearance()
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        flashButton.layer.cornerRadius = 22
        flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        view.addSubview(flashButton)

        // Camera switch button (top right, native style)
        switchCameraButton = UIButton(type: .system)
        switchCameraButton.setImage(UIImage(systemName: "camera.rotate", withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)), for: .normal)
        switchCameraButton.tintColor = .white
        switchCameraButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        switchCameraButton.layer.cornerRadius = 22
        switchCameraButton.addTarget(self, action: #selector(switchCameraButtonTapped), for: .touchUpInside)
        view.addSubview(switchCameraButton)

        // Zoom buttons (horizontal stack, native Camera app style)
        setupZoomButtons()

        // Shutter button (large, white circle, native Camera app style)
        shutterButton = UIButton(type: .system)
        shutterButton.backgroundColor = .white
        shutterButton.layer.cornerRadius = 35
        shutterButton.layer.borderWidth = 3
        shutterButton.layer.borderColor = UIColor.white.cgColor
        shutterButton.addTarget(self, action: #selector(shutterButtonTapped), for: .touchUpInside)

        // Inner circle (native Camera app style)
        let innerCircle = UIView()
        innerCircle.backgroundColor = .white
        innerCircle.layer.cornerRadius = 30
        innerCircle.isUserInteractionEnabled = false
        shutterButton.addSubview(innerCircle)

        controlsContainer.addSubview(shutterButton)

        // Photo counter (native Camera app style)
        photoCounterLabel = UILabel()
        photoCounterLabel.textColor = .white
        photoCounterLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        photoCounterLabel.textAlignment = .center
        photoCounterLabel.text = "0"
        photoCounterLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        photoCounterLabel.layer.cornerRadius = 15
        photoCounterLabel.clipsToBounds = true
        controlsContainer.addSubview(photoCounterLabel)

        // Setup inner circle constraints
        innerCircle.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            innerCircle.centerXAnchor.constraint(equalTo: shutterButton.centerXAnchor),
            innerCircle.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            innerCircle.widthAnchor.constraint(equalToConstant: 60),
            innerCircle.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func setupZoomButtons() {
        zoomButtonsStack = UIStackView()
        zoomButtonsStack.axis = .horizontal
        zoomButtonsStack.spacing = 20
        zoomButtonsStack.distribution = .fillEqually

        for (index, zoom) in zoomLevels.enumerated() {
            let button = UIButton(type: .system)
            let zoomText = zoom == 1.0 ? "1×" : zoom < 1.0 ? "\(zoom)×" : "\(Int(zoom))×"
            button.setTitle(zoomText, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.setTitleColor(.yellow, for: .selected)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            button.backgroundColor = UIColor.white.withAlphaComponent(index == currentZoomIndex ? 0.3 : 0.1)
            button.layer.cornerRadius = 20
            button.tag = index
            button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)

            if index == currentZoomIndex {
                button.isSelected = true
            }

            zoomButtonsStack.addArrangedSubview(button)
        }

        view.addSubview(zoomButtonsStack)
    }

    private func setupConstraints() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        switchCameraButton.translatesAutoresizingMaskIntoConstraints = false
        shutterButton.translatesAutoresizingMaskIntoConstraints = false
        photoCounterLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomButtonsStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Preview view (full screen above controls)
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor),

            // Controls container (bottom, native height)
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            controlsContainer.heightAnchor.constraint(equalToConstant: 120),

            // Close button (top left)
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            // Flash button (next to close button)
            flashButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 15),
            flashButton.widthAnchor.constraint(equalToConstant: 44),
            flashButton.heightAnchor.constraint(equalToConstant: 44),

            // Switch camera button (top right)
            switchCameraButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            switchCameraButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            switchCameraButton.widthAnchor.constraint(equalToConstant: 44),
            switchCameraButton.heightAnchor.constraint(equalToConstant: 44),

            // Zoom buttons (bottom center of preview, above controls)
            zoomButtonsStack.bottomAnchor.constraint(equalTo: controlsContainer.topAnchor, constant: -20),
            zoomButtonsStack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            zoomButtonsStack.heightAnchor.constraint(equalToConstant: 40),

            // Shutter button (center of controls)
            shutterButton.centerXAnchor.constraint(equalTo: controlsContainer.centerXAnchor),
            shutterButton.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),

            // Photo counter (left of shutter button)
            photoCounterLabel.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            photoCounterLabel.trailingAnchor.constraint(equalTo: shutterButton.leadingAnchor, constant: -30),
            photoCounterLabel.widthAnchor.constraint(equalToConstant: 40),
            photoCounterLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewView.bounds
    }

    private func startSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    private func stopSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession.stopRunning()
        }
    }

    @objc private func closeButtonTapped() {
        delegate?.didCancel()
    }

    @objc private func flashButtonTapped() {
        switch flashMode {
        case .off:
            flashMode = .auto
        case .auto:
            flashMode = .on
        case .on:
            flashMode = .off
        @unknown default:
            flashMode = .off
        }
        updateFlashButtonAppearance()
    }

    private func updateFlashButtonAppearance() {
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        switch flashMode {
        case .off:
            flashButton.setImage(UIImage(systemName: "bolt.slash", withConfiguration: config), for: .normal)
            flashButton.tintColor = .white
        case .auto:
            flashButton.setImage(UIImage(systemName: "bolt.badge.a", withConfiguration: config), for: .normal)
            flashButton.tintColor = .yellow
        case .on:
            flashButton.setImage(UIImage(systemName: "bolt", withConfiguration: config), for: .normal)
            flashButton.tintColor = .yellow
        @unknown default:
            flashButton.setImage(UIImage(systemName: "bolt.slash", withConfiguration: config), for: .normal)
            flashButton.tintColor = .white
        }
    }

    @objc private func switchCameraButtonTapped() {
        // Implementation for camera switching would go here
        print("Switch camera tapped")
    }

    @objc private func zoomButtonTapped(_ sender: UIButton) {
        let newZoomIndex = sender.tag
        currentZoomIndex = newZoomIndex

        // Update button appearances
        for (index, button) in zoomButtonsStack.arrangedSubviews.enumerated() {
            if let btn = button as? UIButton {
                btn.isSelected = (index == newZoomIndex)
                btn.backgroundColor = UIColor.white.withAlphaComponent(index == newZoomIndex ? 0.3 : 0.1)
            }
        }

        // Switch to appropriate lens/camera for zoom level
        let zoomLevel = zoomLevels[newZoomIndex]
        switchToCamera(for: zoomLevel)
    }

    private func setZoom(factor: Float) {
        guard let device = currentDevice else { return }

        do {
            try device.lockForConfiguration()
            // Allow zoom factors starting from device minimum (including sub-1.0 for ultra-wide)
            let clampedZoom = CGFloat(min(max(factor, Float(device.minAvailableVideoZoomFactor)), Float(device.maxAvailableVideoZoomFactor)))
            device.videoZoomFactor = clampedZoom
            device.unlockForConfiguration()
            print("Set zoom to \(clampedZoom)x on \(device.deviceType.displayName)")
        } catch {
            print("Error setting zoom: \(error)")
        }
    }

    @objc private func shutterButtonTapped() {
        // Add haptic feedback (native Camera app style)
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        // Animate shutter button (native Camera app style)
        UIView.animate(withDuration: 0.1, animations: {
            self.shutterButton.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { _ in
            UIView.animate(withDuration: 0.1) {
                self.shutterButton.transform = CGAffineTransform.identity
            }
        }

        capturePhoto()
    }

    private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = flashMode

        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension NativeCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Error processing photo: \(error?.localizedDescription ?? "Unknown error")")
            return
        }

        // Pass the captured image to the coordinator
        DispatchQueue.main.async {
            self.delegate?.didCapturePhoto(image)

            // Update photo counter (native Camera app style)
            self.photoCount += 1
            self.photoCounterLabel.text = "\(self.photoCount)"

            // Brief flash animation (native Camera app style)
            let flashView = UIView(frame: self.view.bounds)
            flashView.backgroundColor = .white
            self.view.addSubview(flashView)

            UIView.animate(withDuration: 0.1, animations: {
                flashView.alpha = 0
            }) { _ in
                flashView.removeFromSuperview()
            }
        }
    }

    // MARK: - Orientation Handling

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }
}

// MARK: - Camera Permission View

struct CameraPermissionView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera")
                .font(.system(size: 60))
                .foregroundColor(.gray)

            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)

            Text("This app needs access to your camera to take photos.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

// MARK: - Photo Library Picker

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> PhotoLibraryCoordinator {
        PhotoLibraryCoordinator(self)
    }

    class PhotoLibraryCoordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryPicker

        init(_ parent: PhotoLibraryPicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageSelected(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Camera View Controller with AVCaptureSession

class CameraViewController: UIViewController {
    var coordinator: CameraView.Coordinator?
    var onClose: (() -> Void)?

    // AVCapture components for real camera control
    private var captureSession: AVCaptureSession!
    private var photoOutput: AVCapturePhotoOutput!
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    private var currentCameraInput: AVCaptureDeviceInput?
    private var currentZoomLevel: CGFloat = 1.0
    private var isFlashOn = false

    // UI Components
    private var previewView: UIView!
    private var overlayView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Force portrait orientation and disable rotation
        self.modalPresentationStyle = .fullScreen

        setupCamera()

        // Force interface to stay in portrait
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.startRunning()
        }

        // Force portrait orientation when view appears
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        DispatchQueue.global(qos: .background).async {
            self.captureSession?.stopRunning()
        }
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var shouldAutorotate: Bool {
        return false
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        return .portrait
    }

    private func setupCamera() {
        // Request camera permission
        AVCaptureDevice.requestAccess(for: .video) { granted in
            if granted {
                DispatchQueue.main.async {
                    self.configureCaptureSession()
                }
            } else {
                print("Camera permission denied")
                DispatchQueue.main.async {
                    self.dismiss(animated: true)
                }
            }
        }
    }

    private func configureCaptureSession() {
        // Create capture session
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        // Set session preset for high quality photos
        if captureSession.canSetSessionPreset(.photo) {
            captureSession.sessionPreset = .photo
        }

        // Setup camera input
        setupCameraInput()

        // Setup photo output
        setupPhotoOutput()

        // Commit configuration
        captureSession.commitConfiguration()

        // Setup UI
        setupPreviewAndOverlay()
    }

    private func setupCameraInput() {
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Unable to access back camera")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                currentCameraInput = input
            }
        } catch {
            print("Unable to initialize back camera: \(error.localizedDescription)")
        }
    }

    private func setupPhotoOutput() {
        photoOutput = AVCapturePhotoOutput()

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }
    }

    private func setupPreviewAndOverlay() {
        // Create preview view
        previewView = UIView()
        previewView.backgroundColor = .black
        view.addSubview(previewView)

        // Setup preview layer
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = .resizeAspectFill
        previewView.layer.addSublayer(videoPreviewLayer)

        // Create overlay view
        overlayView = createCameraOverlay()
        view.addSubview(overlayView)

        // Setup constraints
        previewView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            // Preview view fills entire screen
            previewView.topAnchor.constraint(equalTo: view.topAnchor),
            previewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Overlay view on top of preview
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // Update preview layer frame when view layout changes
        DispatchQueue.main.async {
            self.videoPreviewLayer.frame = self.previewView.bounds
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        videoPreviewLayer?.frame = previewView.bounds
    }

    private func createCameraOverlay() -> UIView {
        let overlayView = UIView()
        overlayView.backgroundColor = UIColor.clear

        // Create a gradient background for the UI elements
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.3).cgColor]
        gradientLayer.locations = [0.7, 1.0]

        // Bottom section for controls - reduced height for maximum camera view
        let bottomSection = UIView()
        bottomSection.translatesAutoresizingMaskIntoConstraints = false
        bottomSection.layer.addSublayer(gradientLayer)
        overlayView.addSubview(bottomSection)

        // Close button (top left)
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .medium)
        closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        closeButton.layer.cornerRadius = 20
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeCamera), for: .touchUpInside)
        overlayView.addSubview(closeButton)

        // Flash toggle button (top right)
        let flashButton = UIButton(type: .system)
        flashButton.setTitle("⚡", for: .normal)
        flashButton.setTitleColor(.white, for: .normal)
        flashButton.titleLabel?.font = UIFont.systemFont(ofSize: 20)
        flashButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        flashButton.layer.cornerRadius = 20
        flashButton.tag = 100 // Tag for flash button identification
        flashButton.translatesAutoresizingMaskIntoConstraints = false
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
        overlayView.addSubview(flashButton)

        // Camera capture button (center)
        let captureButton = UIButton(type: .system)
        captureButton.backgroundColor = UIColor.white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 3
        captureButton.layer.borderColor = UIColor.black.withAlphaComponent(0.3).cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        bottomSection.addSubview(captureButton)

        // Zoom buttons stack (left side of capture button)
        let zoomStackView = UIStackView()
        zoomStackView.axis = .horizontal
        zoomStackView.distribution = .equalSpacing
        zoomStackView.spacing = 8
        zoomStackView.translatesAutoresizingMaskIntoConstraints = false
        bottomSection.addSubview(zoomStackView)

        // Create zoom buttons with proper tags for identification (minimum 1.0x)
        let zoomLevels: [(String, CGFloat)] = [("1x", 1.0), ("2x", 2.0), ("3x", 3.0), ("5x", 5.0)]
        for (index, (title, zoomValue)) in zoomLevels.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(title, for: .normal)
            button.setTitleColor(.white, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
            button.backgroundColor = index == 0 ? UIColor.white.withAlphaComponent(0.9) : UIColor.black.withAlphaComponent(0.6) // Default to 1x
            button.setTitleColor(index == 0 ? .black : .white, for: .normal)
            button.layer.cornerRadius = 15
            button.tag = Int(zoomValue * 10) // Tag: 10, 20, 30, 50
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(zoomButtonTapped(_:)), for: .touchUpInside)

            // Set button size
            button.widthAnchor.constraint(equalToConstant: 40).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true

            zoomStackView.addArrangedSubview(button)
        }

        // Set up constraints
        NSLayoutConstraint.activate([
            // Close button (top left)
            closeButton.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Flash button (top right)
            flashButton.topAnchor.constraint(equalTo: overlayView.safeAreaLayoutGuide.topAnchor, constant: 20),
            flashButton.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor, constant: -20),
            flashButton.widthAnchor.constraint(equalToConstant: 40),
            flashButton.heightAnchor.constraint(equalToConstant: 40),

            // Bottom section
            bottomSection.leadingAnchor.constraint(equalTo: overlayView.leadingAnchor),
            bottomSection.trailingAnchor.constraint(equalTo: overlayView.trailingAnchor),
            bottomSection.bottomAnchor.constraint(equalTo: overlayView.bottomAnchor),
            bottomSection.heightAnchor.constraint(equalToConstant: 120),

            // Capture button (center)
            captureButton.centerXAnchor.constraint(equalTo: bottomSection.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: bottomSection.centerYAnchor, constant: -10),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70),

            // Zoom buttons (left of capture button)
            zoomStackView.trailingAnchor.constraint(equalTo: captureButton.leadingAnchor, constant: -20),
            zoomStackView.centerYAnchor.constraint(equalTo: captureButton.centerYAnchor)
        ])

        // Update gradient layer frame
        DispatchQueue.main.async {
            gradientLayer.frame = bottomSection.bounds
        }

        return overlayView
    }

    @objc private func closeCamera() {
        DispatchQueue.main.async {
            self.onClose?()
        }
    }

    @objc private func toggleFlash() {
        guard let device = currentCameraInput?.device else { return }

        do {
            try device.lockForConfiguration()

            isFlashOn.toggle()

            if device.hasTorch {
                device.torchMode = isFlashOn ? .on : .off
            }

            device.unlockForConfiguration()

            // Update flash button appearance
            if let flashButton = overlayView.viewWithTag(100) as? UIButton {
                flashButton.backgroundColor = isFlashOn ? UIColor.yellow.withAlphaComponent(0.8) : UIColor.black.withAlphaComponent(0.6)
                flashButton.setTitleColor(isFlashOn ? .black : .white, for: .normal)
            }

        } catch {
            print("Failed to configure flash: \(error.localizedDescription)")
        }
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()

        // Configure flash
        if isFlashOn {
            settings.flashMode = .on
        } else {
            settings.flashMode = .off
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func zoomButtonTapped(_ sender: UIButton) {
        guard let device = currentCameraInput?.device else { return }

        // Convert tag back to zoom value (tag is zoom * 10)
        let zoomValue = CGFloat(sender.tag) / 10.0

        do {
            try device.lockForConfiguration()

            // Ensure zoom value is within device limits (minimum 1.0)
            let maxZoom = device.activeFormat.videoMaxZoomFactor
            let clampedZoom = min(max(zoomValue, 1.0), maxZoom)

            // Apply zoom
            device.videoZoomFactor = clampedZoom
            currentZoomLevel = clampedZoom

            device.unlockForConfiguration()

            print("Applied real camera zoom: \(clampedZoom)x (max: \(maxZoom)x)")

            // Store the current zoom level for reference
            UserDefaults.standard.set(Double(clampedZoom), forKey: "currentZoomLevel")

            // Update button appearances
            updateZoomButtonAppearances(selectedButton: sender)

        } catch {
            print("Failed to set zoom: \(error.localizedDescription)")
        }
    }

    private func updateZoomButtonAppearances(selectedButton: UIButton) {
        // Find all zoom buttons and update their appearance
        findZoomButtons(in: overlayView).forEach { button in
            if button == selectedButton {
                // Selected button
                button.backgroundColor = UIColor.white.withAlphaComponent(0.9)
                button.setTitleColor(.black, for: .normal)
            } else {
                // Unselected buttons
                button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
                button.setTitleColor(.white, for: .normal)
            }
        }
    }

    private func findZoomButtons(in view: UIView) -> [UIButton] {
        var zoomButtons: [UIButton] = []

        func searchForZoomButtons(in view: UIView) {
            for subview in view.subviews {
                if let button = subview as? UIButton,
                   button.tag >= 10 && button.tag <= 50 { // Tags for zoom buttons (1.0x to 5.0x)
                    zoomButtons.append(button)
                }
                searchForZoomButtons(in: subview)
            }
        }

        searchForZoomButtons(in: view)
        return zoomButtons
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil else {
            print("Error capturing photo: \(error!.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to convert photo to image")
            return
        }

        // Log image details to understand zoom effects
        print("Captured image size: \(image.size), current zoom: \(currentZoomLevel)x")

        // Pass image to coordinator
        coordinator?.didCapturePhoto(image)

        // Turn off flash after taking photo
        if isFlashOn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.toggleFlash()
            }
        }
    }
}

// MARK: - Device Type Extensions
extension AVCaptureDevice.DeviceType {
    var sortOrder: Int {
        switch self {
        case .builtInUltraWideCamera:
            return 0
        case .builtInWideAngleCamera:
            return 1
        case .builtInTelephotoCamera:
            return 2
        default:
            return 3
        }
    }

    var displayName: String {
        switch self {
        case .builtInUltraWideCamera:
            return "Ultra Wide (0.5x)"
        case .builtInWideAngleCamera:
            return "Wide (1x)"
        case .builtInTelephotoCamera:
            return "Telephoto (2x)"
        default:
            return "Unknown"
        }
    }
}
