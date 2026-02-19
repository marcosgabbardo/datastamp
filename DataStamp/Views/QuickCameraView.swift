import SwiftUI
import SwiftData
import AVFoundation

/// Quick camera view for instant timestamps
struct QuickCameraView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let manager: DataStampManager
    let onComplete: (Bool) -> Void
    
    @State private var capturedImage: UIImage?
    @State private var isProcessing = false
    @State private var showSuccess = false
    @State private var error: String?
    
    var body: some View {
        ZStack {
            // Camera
            CameraPreviewView(capturedImage: $capturedImage)
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(Circle().fill(.black.opacity(0.5)))
                    }
                    
                    Spacer()
                    
                    // Flash toggle could go here
                }
                .padding()
                
                Spacer()
                
                // Status
                if isProcessing {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Creating timestamp...")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.7)))
                } else if showSuccess {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.green)
                        
                        Text("Timestamp Created!")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.7)))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onComplete(true)
                            dismiss()
                        }
                    }
                } else if let error {
                    VStack(spacing: 12) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                        
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        
                        Button("Try Again") {
                            self.error = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(24)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.black.opacity(0.7)))
                }
                
                Spacer()
                
                // Bottom controls
                if !isProcessing && !showSuccess && error == nil {
                    HStack(spacing: 60) {
                        // Photo library (optional)
                        Color.clear
                            .frame(width: 50, height: 50)
                        
                        // Capture button
                        Button {
                            capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 70, height: 70)
                                
                                Circle()
                                    .fill(.white)
                                    .frame(width: 58, height: 58)
                            }
                        }
                        
                        // Switch camera (optional)
                        Color.clear
                            .frame(width: 50, height: 50)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                Task {
                    await processImage(image)
                }
            }
        }
    }
    
    private func capturePhoto() {
        NotificationCenter.default.post(name: .capturePhoto, object: nil)
    }
    
    private func processImage(_ image: UIImage) async {
        isProcessing = true
        
        do {
            // Generate automatic title with timestamp
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let title = "Photo \(formatter.string(from: Date()))"
            
            _ = try await manager.createPhotoTimestamp(
                image: image,
                title: title,
                context: modelContext
            )
            
            HapticManager.shared.success()
            showSuccess = true
            
        } catch {
            self.error = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isProcessing = false
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CameraPreviewView
        
        init(_ parent: CameraPreviewView) {
            self.parent = parent
        }
        
        func didCapturePhoto(_ image: UIImage) {
            parent.capturedImage = image
        }
    }
}

// MARK: - Camera View Controller

protocol CameraViewControllerDelegate: AnyObject {
    func didCapturePhoto(_ image: UIImage)
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturePhoto),
            name: .capturePhoto,
            object: nil
        )
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupCamera() {
        // Bug #10: Check camera authorization
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async { self?.configureSession() }
                } else {
                    DispatchQueue.main.async { self?.showPermissionDenied() }
                }
            }
            return
        case .denied, .restricted:
            showPermissionDenied()
            return
        case .authorized:
            break
        @unknown default:
            break
        }
        
        configureSession()
    }
    
    private func showPermissionDenied() {
        let label = UILabel()
        label.text = "Camera access denied.\nGo to Settings > DataStamp to enable."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 16)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32)
        ])
    }
    
    private func configureSession() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)
        
        self.captureSession = session
        self.photoOutput = output
        self.previewLayer = previewLayer
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
    
    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: @preconcurrency AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.delegate?.didCapturePhoto(image)
        }
    }
}

// MARK: - Notification

extension Notification.Name {
    static let capturePhoto = Notification.Name("capturePhoto")
}

// MARK: - Preview

#Preview {
    QuickCameraView(manager: DataStampManager()) { _ in }
        .modelContainer(for: DataStampItem.self, inMemory: true)
}
