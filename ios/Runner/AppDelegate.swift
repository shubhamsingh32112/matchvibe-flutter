import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var securityChannel: FlutterMethodChannel?
  private var isScreenCaptured = false
  private let captureShieldView = UIView()
  private let secureContainer = UITextField()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for security
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    securityChannel = FlutterMethodChannel(
      name: "com.zztherapy/security",
      binaryMessenger: controller.binaryMessenger
    )
    
    securityChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      
      switch call.method {
      case "startScreenCaptureDetection":
        self.startScreenCaptureDetection()
        result(nil)
      case "stopScreenCaptureDetection":
        // App-wide security must stay active for the full app lifecycle.
        self.startScreenCaptureDetection()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // Enforce app-wide protection from launch.
    startScreenCaptureDetection()
    secureAppWindow()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func startScreenCaptureDetection() {
    // Listen for screen capture notifications
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(screenCaptureDidChange),
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(userDidTakeScreenshot),
      name: UIApplication.userDidTakeScreenshotNotification,
      object: nil
    )
    
    // Check initial state
    checkScreenCaptureStatus()
  }
  
  private func stopScreenCaptureDetection() {
    NotificationCenter.default.removeObserver(
      self,
      name: UIScreen.capturedDidChangeNotification,
      object: nil
    )
  }
  
  @objc private func screenCaptureDidChange() {
    checkScreenCaptureStatus()
  }

  @objc private func userDidTakeScreenshot() {
    securityChannel?.invokeMethod("onScreenCaptureChanged", arguments: true)
  }
  
  private func checkScreenCaptureStatus() {
    let isCaptured = UIScreen.main.isCaptured
    updateCaptureShield(isCaptured: isCaptured)
    
    if isCaptured != isScreenCaptured {
      isScreenCaptured = isCaptured
      
      // Notify Flutter about screen capture state change
      securityChannel?.invokeMethod("onScreenCaptureChanged", arguments: isCaptured)
    }
  }

  private func secureAppWindow() {
    guard let window = self.window else { return }

    secureContainer.isSecureTextEntry = true
    secureContainer.isUserInteractionEnabled = false
    secureContainer.backgroundColor = .clear
    secureContainer.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(secureContainer)
    NSLayoutConstraint.activate([
      secureContainer.leadingAnchor.constraint(equalTo: window.leadingAnchor),
      secureContainer.trailingAnchor.constraint(equalTo: window.trailingAnchor),
      secureContainer.topAnchor.constraint(equalTo: window.topAnchor),
      secureContainer.bottomAnchor.constraint(equalTo: window.bottomAnchor)
    ])

    // Route rendering through a secure text container so iOS capture APIs
    // treat the app window as protected content.
    if let superLayer = window.layer.superlayer,
       let secureLayer = secureContainer.layer.sublayers?.first {
      superLayer.addSublayer(secureContainer.layer)
      secureLayer.addSublayer(window.layer)
    }

    setupCaptureShield(on: window)
  }

  private func setupCaptureShield(on window: UIWindow) {
    captureShieldView.backgroundColor = .black
    captureShieldView.translatesAutoresizingMaskIntoConstraints = false
    captureShieldView.isHidden = true
    captureShieldView.isUserInteractionEnabled = true

    let titleLabel = UILabel()
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    titleLabel.text = "Screen capture blocked"
    titleLabel.textColor = .white
    titleLabel.font = UIFont.boldSystemFont(ofSize: 20)

    let subtitleLabel = UILabel()
    subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
    subtitleLabel.text = "Disable recording or screen sharing to continue."
    subtitleLabel.textColor = .lightGray
    subtitleLabel.font = UIFont.systemFont(ofSize: 14)

    captureShieldView.addSubview(titleLabel)
    captureShieldView.addSubview(subtitleLabel)
    window.addSubview(captureShieldView)

    NSLayoutConstraint.activate([
      captureShieldView.leadingAnchor.constraint(equalTo: window.leadingAnchor),
      captureShieldView.trailingAnchor.constraint(equalTo: window.trailingAnchor),
      captureShieldView.topAnchor.constraint(equalTo: window.topAnchor),
      captureShieldView.bottomAnchor.constraint(equalTo: window.bottomAnchor),
      titleLabel.centerXAnchor.constraint(equalTo: captureShieldView.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: captureShieldView.centerYAnchor, constant: -10),
      subtitleLabel.centerXAnchor.constraint(equalTo: captureShieldView.centerXAnchor),
      subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8)
    ])
  }

  private func updateCaptureShield(isCaptured: Bool) {
    captureShieldView.isHidden = !isCaptured
  }
}
