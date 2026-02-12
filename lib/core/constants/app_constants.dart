import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static const String appName = 'eazy talks';
  
  // Backend API Base URL
  // For USB debugging on physical device, use your desktop's local IP address
  // For USB debugging with ADB reverse tunnel: use localhost
  // Run: .\setup-adb-tunnels.ps1  (sets up adb reverse tcp:3000 tcp:3000)
  // Fallback IP (WiFi): 192.168.1.5
  static const String _staticBaseUrl = 'http://localhost:3000/api/v1';
  
  // Socket.IO URL (same host as REST API, no /api/v1 suffix)
  static const String _staticSocketUrl = 'http://localhost:3000';
  
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

