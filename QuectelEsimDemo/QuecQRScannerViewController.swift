//
//  QuecQRScannerViewController.swift
//  QuectelEsimDemo
//
//  Created by quectel.tank on 3/18/26.
//

import UIKit
import AVFoundation

class QuecQRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    /// 扫描完成回调
    var onScanComplete: ((String) -> Void)?
    /// 扫描取消回调
    var onScanCancel: (() -> Void)?

    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        setupNavigationBar()
        setupCaptureSession()
    }

    // MARK: - Navigation Bar
    private func setupNavigationBar() {
        let navBarHeight: CGFloat = 44
        let statusBarHeight = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 44
        let navBar = UINavigationBar(frame: CGRect(x: 0, y: 0, width: view.bounds.width, height: statusBarHeight + navBarHeight))
        let navItem = UINavigationItem(title: "扫码")
        let cancelItem = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelTapped))
        navItem.rightBarButtonItem = cancelItem
        navBar.items = [navItem]
        navBar.barTintColor = .systemBackground
        navBar.tintColor = .systemBlue
        navBar.isTranslucent = false
        view.addSubview(navBar)
    }

    @objc private func cancelTapped() {
        stopCapture()
        onScanCancel?()
        dismiss(animated: true)
    }

    // MARK: - Capture Session
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()

        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            onScanCancel?()
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoCaptureDevice) else {
            onScanCancel?()
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            onScanCancel?()
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            onScanCancel?()
            return
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(previewLayer, at: 0)

        captureSession.startRunning()
    }

    private func stopCapture() {
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCapture()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        stopCapture()
        if let metadataObject = metadataObjects.first,
           let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
           let stringValue = readableObject.stringValue {
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            onScanComplete?(stringValue)
            dismiss(animated: true)
        } else {
            onScanCancel?()
            dismiss(animated: true)
        }
    }
}
