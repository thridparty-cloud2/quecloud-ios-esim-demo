//
//  QuecEsimTestViewController.swift
//  QuectelEsimDemo
//
//  Created by quectel.tank on 1/22/26.
//

import UIKit
import Network
import WebKit
import QuecEsimManagerSdk
import QuecIpaSdk

@objc class QuecEsimTestViewController: UIViewController {

    private let ipTextField = UITextField()
    private let portTextField = UITextField()
    private let urlTextField = UITextField()
    private let appKeyTextField = UITextField()
    private let appSecretTextField = UITextField()
    
//    private let connectButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let openH5Button = UIButton(type: .system)
    
    private let profileTestButton = UIButton(type: .system)
    
    private var apduContinuation: CheckedContinuation<Data, Error>?
    
    private var socketer = QuecSocketManager.sharedInstance()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupKeyboardDismiss()
    }

    private func setupUI() {
        title = "eSIM 测试"
        view.backgroundColor = .systemGroupedBackground

        ipTextField.placeholder = "服务器 IP"
        ipTextField.borderStyle = .roundedRect
        ipTextField.keyboardType = .numbersAndPunctuation
        ipTextField.text = ""

        portTextField.placeholder = "端口 Port"
        portTextField.borderStyle = .roundedRect
        portTextField.keyboardType = .numberPad
        portTextField.text = ""
        
        urlTextField.placeholder = "H5 Url"
        urlTextField.borderStyle = .roundedRect
        urlTextField.keyboardType = .numbersAndPunctuation
        urlTextField.text = ""
        
        
        appKeyTextField.placeholder = "appKey"
        appKeyTextField.borderStyle = .roundedRect
        appKeyTextField.keyboardType = .numbersAndPunctuation
        appKeyTextField.text = ""
        
        
        appSecretTextField.placeholder = "appSecret"
        appSecretTextField.borderStyle = .roundedRect
        appSecretTextField.keyboardType = .numbersAndPunctuation
        appSecretTextField.text = ""

//        connectButton.setTitle("连接服务器", for: .normal)
//        connectButton.backgroundColor = .systemBlue
//        connectButton.setTitleColor(.white, for: .normal)
//        connectButton.layer.cornerRadius = 8
//        connectButton.addTarget(self, action: #selector(connectAction), for: .touchUpInside)

        statusLabel.text = "● 未连接"
        statusLabel.textColor = .systemRed
        statusLabel.textAlignment = .center

        openH5Button.setTitle("Open H5 Page", for: .normal)
        openH5Button.backgroundColor = .red
        openH5Button.setTitleColor(.white, for: .normal)
        openH5Button.layer.cornerRadius = 8
        openH5Button.addTarget(self, action: #selector(openH5Action), for: .touchUpInside)
        
        profileTestButton.setTitle("Profile Test", for: .normal)
        profileTestButton.backgroundColor = .systemBlue
        profileTestButton.setTitleColor(.white, for: .normal)
        profileTestButton.layer.cornerRadius = 8
        profileTestButton.addTarget(self, action: #selector(profileTestAction), for: .touchUpInside)
        profileTestButton.isHidden = true

        let stack = UIStackView(arrangedSubviews: [
            ipTextField,
            portTextField,
            urlTextField,
            appKeyTextField,
            appSecretTextField,
            statusLabel,
            UIView(),
            openH5Button,
            profileTestButton
        ])
        stack.axis = .vertical
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])
        openH5Button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        profileTestButton.heightAnchor.constraint(equalToConstant: 44).isActive = true
    }

    private func setupKeyboardDismiss() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    @objc private func connectAction() {
        guard
            let host = ipTextField.text, !host.isEmpty,
            let portText = portTextField.text,
            let port = UInt16(portText)
        else {
            return
        }
        if self.statusLabel.text != "● connected" {
            statusLabel.text = "● connecting..."
        }
        statusLabel.textColor = .systemOrange
        
        socketer.connect(toHost: host, onPort: port, socketId: "123456")
        socketer.add(self)
    }
    
    @objc private func initEsimStoreModel() -> QuecEsimStoreModel{
        let config = QuecEsimStoreModel()

//        config.storeStyle = .chinese
        config.url = urlTextField.text ?? ""
        config.appKey = appKeyTextField.text ?? ""
        config.appSecret = appSecretTextField.text ?? ""
        config.presentStyle = .push

        if let backImg = UIImage(
            named: "back",
            in: Bundle.main,
            compatibleWith: nil
        ) {
            config.webNavReturnImg = backImg
        }

        config.webNavTitleAttrs = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 18, weight: .medium)
        ]
        config.webNavTitle = "eSIM Store"
        config.webNavTintColor = .white
        return config;
    }

    @objc private func openH5Action() {
        connectAction()
        let config = initEsimStoreModel()
        config.webNavBackgroundColor = .red
        let manager = QuecEsimManager.shared()
        manager.delegate = self
        manager.openStore(from: self, config: config)
    }
    
    func transmitApduAsync(
        channel: UInt8,
        data: Data
    ) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            // 保存 continuation，等 socket 回包时用
            self.apduContinuation = continuation

            // 通过 socket 发送 APDU
            socketer.sendData(bySocketId: "123456", data: data)
        }
    }
    
    func topMostViewController() -> UIViewController? {
        var top = UIApplication.shared.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
    
    @MainActor
    func scanQrAsync() async -> String {
        await withCheckedContinuation { continuation in
            let scannerVC = QuecQRScannerViewController()
            scannerVC.onScanComplete = { result in
                scannerVC.dismiss(animated: true) {
                    continuation.resume(returning: result)
                }
            }
            scannerVC.onScanCancel = {
                scannerVC.dismiss(animated: true) {
                    continuation.resume(returning: "")
                }
            }
            DispatchQueue.main.async {
                if let topVC = self.topMostViewController() {
                    topVC.present(scannerVC, animated: true)
                } else {
                    continuation.resume(returning: "")
                }
            }
        }
    }
    
    @objc private func profileTestAction() {
        print("profileTestAction")
    }
    
}

extension QuecEsimTestViewController: QuecEsimApduDelegate {
    
    func transmitApdu(withChannel channel: UInt8, data: Data, completion: @escaping @Sendable (Data, (any Error)?) -> Void) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                completion(Data(), NSError(
                    domain: "com.quectel.apdu",
                    code: -999,
                    userInfo: [NSLocalizedDescriptionKey: "controller released"]
                ))
                return
            }
            do {
                // APDU异步交互
                let rsp = try await self.transmitApduAsync(
                    channel: channel,
                    data: data
                )
                completion(rsp, nil)

            } catch {
                completion(Data(), error)
            }
        }
    }
    
    @objc
    func onNeedScanQr(_ completion: @escaping (String) -> Void) {
        Task.detached { [weak self] in
            guard let self else {
                completion("")
                return
            }
            // UI在主线程
            let qr = await self.scanQrAsync()
            completion(qr)
        }
    }

    @objc
    func onStartDownloadProfile(_ completion: @escaping (Bool) -> Void) {
        Task.detached {
            // 如果有耗时逻辑
            // await downloadPrepare()
            completion(true)
        }
    }
}

extension QuecEsimTestViewController: QuecSocketDelegate {

    func quecSocket(_ socketId: String, didConnectToHost host: String, port: UInt16) {
        Task { @MainActor in
            DispatchQueue.main.async {
                self.statusLabel.text = "● connected"
                self.statusLabel.textColor = .systemGreen
            }
        }
    }

    func quecSocket(_ socketId: String, didDisconnectwithError err: Error?) {
        Task { @MainActor in
            DispatchQueue.main.async {
                self.statusLabel.text = "● disconnect"
                self.statusLabel.textColor = .systemRed
            }
        }
    }

    func quecSocket(_ socketId: String, didRead data: Data) {
        Task { @MainActor in
            guard let continuation = self.apduContinuation else {
                return
            }
            self.apduContinuation = nil
            continuation.resume(returning: data)
        }
    }
}
