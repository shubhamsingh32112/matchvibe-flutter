import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'eazy talks';
  
  // ═══════════════════════════════════════════════════════════════════════════
  // 🔥 CRITICAL: Backend API Base URL Configuration
  // ═══════════════════════════════════════════════════════════════════════════
  // 
  // This class automatically selects the correct base URL based on the platform:
  // • Android Emulator → http://10.0.2.2:3000/api/v1
  // • iOS Simulator → http://localhost:3000/api/v1
  // • Real Device → http://<LAN_IP>:3000/api/v1
  //
  // ❗ For real devices, you MUST update LAN_IP_ADDRESS below with your desktop's IP
  //    Your IP can change when you reconnect to Wi-Fi or restart your router
  //
  // 📍 How to find your desktop IP:
  //    Windows: Open CMD → type "ipconfig" → look for "IPv4 Address"
  //    Mac/Linux: Open Terminal → type "ifconfig" → look for "inet" under your Wi-Fi adapter
  //
  // ✅ Requirements for connection to work:
  //    1. Backend server is running (check terminal for "Server running on port 3000")
  //    2. Backend is bound to 0.0.0.0 (already configured in backend/src/server.ts)
  //    3. Phone and laptop are on the SAME Wi-Fi network
  //    4. Mobile data is DISABLED on phone
  //    5. Firewall allows inbound connections on port 3000
  //
  // 🧪 Quick test: Open this URL in your phone's browser:
  //    http://YOUR_IP:3000/health
  //    If it shows JSON → backend is reachable, Flutter config is wrong
  //    If it doesn't open → backend/network issue (see troubleshooting above)
  //
  // ═══════════════════════════════════════════════════════════════════════════
  
  // 🔧 UPDATE THIS IP when your network changes (for real devices only):
  // 
  // ⚠️  CRITICAL: If you get "No route to host" (errno 113):
  //     1. Run: adb reverse tcp:3000 tcp:3000 (or use setup-usb-tunnel.ps1)
  //     2. Then set USE_USB_TUNNEL = true below
  //     3. Hot restart Flutter app (not just hot reload)
  //     4. This bypasses Wi-Fi routing issues completely
  //
  static const bool USE_USB_TUNNEL = true; // Set to true if using adb reverse
  static const String LAN_IP_ADDRESS = '192.168.1.5';
  static const int BACKEND_PORT = 3000;
  static const String API_VERSION = 'v1';
  
  // Platform-aware base URL getter
  // Automatically selects correct URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      // Web platform - use localhost
      return 'http://localhost:$BACKEND_PORT/api/$API_VERSION';
    }
    
    // USB Reverse Tunnel (bypasses Wi-Fi routing issues)
    // Run: adb reverse tcp:3000 tcp:3000
    // Then set USE_USB_TUNNEL = true above
    if (USE_USB_TUNNEL) {
      return 'http://localhost:$BACKEND_PORT/api/$API_VERSION';
    }
    
    // Check if running on emulator/simulator
    if (Platform.isAndroid) {
      // Android: Check if emulator (10.0.2.2) or real device (LAN IP)
      const bool useEmulatorIp = bool.fromEnvironment('USE_EMULATOR_IP', defaultValue: false);
      if (useEmulatorIp) {
        return 'http://10.0.2.2:$BACKEND_PORT/api/$API_VERSION';
      }
      // Real Android device - use LAN IP
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/api/$API_VERSION';
    } else if (Platform.isIOS) {
      // iOS: Check if simulator (localhost) or real device (LAN IP)
      const bool useSimulatorIp = bool.fromEnvironment('USE_SIMULATOR_IP', defaultValue: true);
      if (useSimulatorIp) {
        return 'http://localhost:$BACKEND_PORT/api/$API_VERSION';
      }
      // Real iOS device - use LAN IP
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/api/$API_VERSION';
    }
    
    // Fallback to LAN IP
    return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/api/$API_VERSION';
  }
  
  // Socket.IO URL (without /api/v1 prefix)
  // Used for real-time availability updates
  static String get socketUrl {
    if (kIsWeb) {
      return 'http://localhost:$BACKEND_PORT';
    }
    
    // USB Reverse Tunnel
    if (USE_USB_TUNNEL) {
      return 'http://localhost:$BACKEND_PORT';
    }
    
    if (Platform.isAndroid) {
      const bool useEmulatorIp = bool.fromEnvironment('USE_EMULATOR_IP', defaultValue: false);
      if (useEmulatorIp) {
        return 'http://10.0.2.2:$BACKEND_PORT';
      }
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT';
    } else if (Platform.isIOS) {
      const bool useSimulatorIp = bool.fromEnvironment('USE_SIMULATOR_IP', defaultValue: true);
      if (useSimulatorIp) {
        return 'http://localhost:$BACKEND_PORT';
      }
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT';
    }
    
    return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT';
  }
  
  // Health check URL (without /api/v1 prefix)
  static String get healthCheckUrl {
    if (kIsWeb) {
      return 'http://localhost:$BACKEND_PORT/health';
    }
    
    // USB Reverse Tunnel
    if (USE_USB_TUNNEL) {
      return 'http://localhost:$BACKEND_PORT/health';
    }
    
    if (Platform.isAndroid) {
      const bool useEmulatorIp = bool.fromEnvironment('USE_EMULATOR_IP', defaultValue: false);
      if (useEmulatorIp) {
        return 'http://10.0.2.2:$BACKEND_PORT/health';
      }
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/health';
    } else if (Platform.isIOS) {
      const bool useSimulatorIp = bool.fromEnvironment('USE_SIMULATOR_IP', defaultValue: true);
      if (useSimulatorIp) {
        return 'http://localhost:$BACKEND_PORT/health';
      }
      return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/health';
    }
    
    return 'http://$LAN_IP_ADDRESS:$BACKEND_PORT/health';
  }
  
  // SharedPreferences keys
  static const String keyAuthToken = 'auth_token';
  static const String keyUserId = 'user_id';
  static const String keyUserEmail = 'user_email';
  static const String keyUserPhone = 'user_phone';
  static const String keyUserCoins = 'user_coins';
  
  // Stream Chat Configuration
  // TODO: Get this from your Stream Dashboard (should match STREAM_API_KEY in backend .env)
  // This is the public API key (safe to expose in client)
  static const String streamApiKey = 'd536t7g4q75v';
}

