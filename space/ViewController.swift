import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var previewView: UIView! = nil
    // Helps to transfer data between one or more device inputs like camera or microphone
    let captureSession = AVCaptureSession()
    // Helps to render the camera view finder in the ViewController
    var previewLayer: AVCaptureVideoPreviewLayer! = nil
    var bufferSize: CGSize = .zero
    var detectionOverlay: CALayer! = nil
    var videoOutput : AVCaptureVideoDataOutput! = nil
    
    var backCamera : AVCaptureDevice!
    var frontCamera : AVCaptureDevice!
    var backInput : AVCaptureInput!
    var frontInput : AVCaptureInput!
    
    var takePicture = true
    var backCameraOn = false
    
    let switchCameraButton : UIButton = {
        let button = UIButton()
        let image = UIImage(named: "switchcamera")?.withRenderingMode(.alwaysTemplate)
        button.setImage(image, for: .normal)
        button.tintColor = .white
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let captureImageButton : UIButton = {
        let button = UIButton()
        button.backgroundColor = .white
        button.tintColor = .white
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    let capturedImageView = CapturedImageView()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissions()
        setupCaptureSession()
        captureSession.startRunning()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        captureSession.stopRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        previewView = view
        let bounds = previewView.layer.bounds
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.insertSublayer(previewLayer, below: switchCameraButton.layer)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = bounds
        previewView.layer.insertSublayer(previewLayer, below: switchCameraButton.layer)
        
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0, y: 0.0, width: bufferSize.width, height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        previewView.layer.addSublayer(detectionOverlay)
        
        updateLayerGeometry()
    }
    
    func setupCaptureSession(){
        
        captureSession.beginConfiguration()
//        captureSession.sessionPreset = .vga640x480
        if self.captureSession.canSetSessionPreset(.photo) {
            self.captureSession.sessionPreset = .photo
        }
        self.captureSession.automaticallyConfiguresCaptureDeviceForWideColor = true
        setupInputs()
        
        videoOutput = AVCaptureVideoDataOutput()
        let videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated, autoreleaseFrequency: .workItem)
        
        if captureSession.canAddOutput(videoOutput) {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)]
            videoOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            captureSession.addOutput(videoOutput)
        } else {
            print("Could not add video data output to the session")
            captureSession.commitConfiguration()
            return
        }
        
        let captureConnection = videoOutput.connection(with: .video)
        
        // Always process the frames
        captureConnection?.isEnabled = true
        do {
            try frontCamera.lockForConfiguration()
            let dimensions = CMVideoFormatDescriptionGetDimensions(frontCamera.activeFormat.formatDescription)
            bufferSize.width = CGFloat(dimensions.width)
            bufferSize.height = CGFloat(dimensions.height)
            frontCamera.unlockForConfiguration()
        } catch {
            print(error)
        }
        captureSession.commitConfiguration()
    }
    
    func setupInputs() {
        if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video ,position: .back) {
            backCamera = captureDevice
        } else {
            print("no back camera")
            return }
        guard let bInput = try? AVCaptureDeviceInput(device: backCamera) else {
            print("could not add back camera input to capture session")
            return }
        backInput = bInput
        if !captureSession.canAddInput(backInput) {
            captureSession.commitConfiguration()
            print("could not add back camera input to capture session")
            return }
        
        if let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video ,position: .front) {
            frontCamera = captureDevice
        } else {
            print("no front camera")
            return }
        guard let fInput = try? AVCaptureDeviceInput(device: frontCamera) else {
            print("could not add front camera input to capture session")
            return }
        frontInput = fInput
        if !captureSession.canAddInput(frontInput) {
            captureSession.commitConfiguration()
            print("could not add back camera input to capture session")
            return }
        captureSession.addInput(frontInput)
    }
    
    override func viewDidLayoutSubviews() {
        previewLayer.frame = view.bounds
        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = self.previewView.window?.windowScene?.interfaceOrientation.videoOrientation ?? .portrait
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        if !takePicture {
            
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectHumanBodyPoseRequest {
            (request, error) in
            
            guard let results = request.results as? [VNHumanBodyPoseObservation] else { return }
            
            DispatchQueue.main.async {
                
                self.detectionOverlay?.sublayers = nil // remove all the old recognized objects
                
                CATransaction.begin()
                CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
                
                for poseObservation in results {
                    guard let recognizedPoints = try? poseObservation.recognizedPoints(.all) else { return }
                    self.drawHuman(points: recognizedPoints)
                }
                self.updateLayerGeometry()
                CATransaction.commit()
            }
        }
        
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
            return //we have nothing to do with the image buffer
        }

        //try and get a CVImageBuffer out of the sample buffer
        guard let cvBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        //get a CIImage out of the CVImageBuffer
        let ciImage = CIImage(cvImageBuffer: cvBuffer)

        //get UIImage out of CIImage
        let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: .down)

        DispatchQueue.main.async {
            self.capturedImageView.image = uiImage
            
            self.takePicture = false
        }
    }
    
    func updateLayerGeometry() {
        let bounds = previewView.layer.bounds
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        var scale = fmax(xScale, yScale)
        
        if scale.isInfinite { scale = 1.0 }
        
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        CATransaction.commit()
    }
    
    
    func switchCameraInput(){
        //don't let user spam the button, fun for the user, not fun for performance
        switchCameraButton.isUserInteractionEnabled = false
        
        //reconfigure the input
        captureSession.beginConfiguration()
        if backCameraOn {
            captureSession.removeInput(backInput)
            captureSession.addInput(frontInput)
            backCameraOn = false
        } else {
            captureSession.removeInput(frontInput)
            captureSession.addInput(backInput)
            backCameraOn = true
        }
        
        //deal with the connection again for portrait mode
        videoOutput.connections.first?.videoOrientation = .portrait
        
        //mirror the video stream for front camera
        videoOutput.connections.first?.isVideoMirrored = !backCameraOn
        
        //commit config
        captureSession.commitConfiguration()
        
        //acitvate the camera button again
        switchCameraButton.isUserInteractionEnabled = true
    }
    
    @objc func switchCamera(_ sender: UIButton?){
        switchCameraInput()
    }
    
    @objc func captureImage(_ sender: UIButton?){
        takePicture = true
    }
    
}

extension UIInterfaceOrientation {
    var videoOrientation: AVCaptureVideoOrientation? {
        switch self {
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeRight
        case .landscapeLeft:
            return .landscapeLeft
        case .portrait:
            return .portrait
        default:
            return nil
        }
    }
}
