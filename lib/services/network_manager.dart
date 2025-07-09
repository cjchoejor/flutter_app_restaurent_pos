import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class NetworkManager {
  static const MethodChannel _channel = MethodChannel('network_manager');
  static bool _isInitialized = false;
  static bool _isBindingActive = false;
  static bool _isBindingInProgress = false;

  /// Initialize network manager when app starts
  static Future<void> initialize() async {
    if (_isInitialized) return;

    print('🌐 Initializing NetworkManager...');

    try {
      await _requestNetworkPermissions();
      _startNetworkMonitoring();

      // Initial network check with delay
      await Future.delayed(const Duration(seconds: 3));
      await _attemptNetworkBinding();

      _isInitialized = true;
      print('✅ NetworkManager initialized successfully');
    } catch (e) {
      print('⚠️ NetworkManager initialization failed: $e');
      print('📱 App will continue with default network behavior');
    }
  }

  static Future<void> _requestNetworkPermissions() async {
    try {
      print('🔐 Requesting network permissions...');

      Map<Permission, PermissionStatus> permissions = await [
        Permission.phone,
      ].request();

      final hasWriteSettings =
          await _channel.invokeMethod('checkWriteSettingsPermission');

      if (!hasWriteSettings) {
        print('⚠️ WRITE_SETTINGS permission needed - requesting...');
        await _channel.invokeMethod('requestWriteSettingsPermission');

        // Wait for user to grant permission
        await Future.delayed(const Duration(seconds: 2));
      }

      print('✅ Network permissions requested');
    } catch (e) {
      print('⚠️ Error requesting network permissions: $e');
    }
  }

  static Future<NetworkStatus> getNetworkStatus() async {
    try {
      final connectivityResults = await Connectivity().checkConnectivity();
      final hasInternet = await _checkInternetAccess();

      final primaryConnectivity = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;

      return NetworkStatus(
        connectivity: primaryConnectivity,
        hasInternet: hasInternet,
        isBindingActive: _isBindingActive,
        isBindingInProgress: _isBindingInProgress,
      );
    } catch (e) {
      print('❌ Error checking network status: $e');
      return NetworkStatus(
        connectivity: ConnectivityResult.none,
        hasInternet: false,
        isBindingActive: false,
        isBindingInProgress: false,
      );
    }
  }

  static Future<bool> _attemptNetworkBinding() async {
    if (_isBindingInProgress) {
      print('⏳ Network binding already in progress, skipping...');
      return false;
    }

    try {
      final status = await getNetworkStatus();

      print('📊 Network Status: ${status.toString()}');

      // More aggressive binding conditions
      if (status.connectivity == ConnectivityResult.wifi) {
        print('📶 On WiFi - checking if binding is needed...');

        // Test if we can reach our specific server
        bool canReachServer = false;
        try {
          final serverResult = await InternetAddress.lookup('119.2.105.142')
              .timeout(const Duration(seconds: 8));
          canReachServer = serverResult.isNotEmpty;
          print('🏢 Server reachability test: $canReachServer');
        } catch (e) {
          print('❌ Server reachability test failed: $e');
          canReachServer = false;
        }

        // If WiFi can't reach our server OR has limited internet, try binding
        if (!status.hasInternet || !canReachServer) {
          print('⚠️ WiFi has issues - attempting mobile binding...');
          print('   - Has Internet: ${status.hasInternet}');
          print('   - Can Reach Server: $canReachServer');
          return await _bindToMobileNetwork();
        } else {
          print('✅ WiFi is working properly, no binding needed');
          return true;
        }
      }

      return true;
    } catch (e) {
      print('❌ Network binding attempt failed: $e');
      return false;
    }
  }

  static Future<bool> _bindToMobileNetwork() async {
    if (!Platform.isAndroid) {
      print('⚠️ Network binding only supported on Android');
      return false;
    }

    if (_isBindingInProgress) {
      print('⏳ Network binding already in progress');
      return false;
    }

    try {
      _isBindingInProgress = true;
      print('📱 Starting mobile network binding process...');

      // Release any existing binding first
      if (_isBindingActive) {
        await releaseNetworkBinding();
        await Future.delayed(const Duration(seconds: 3));
      }

      // First attempt: Try binding with WiFi still connected
      print('🔄 Attempt 1: Binding with WiFi connected...');
      final result1 = await _channel
          .invokeMethod('bindToMobileNetwork')
          .timeout(const Duration(seconds: 60));

      if (result1 == true) {
        _isBindingActive = true;
        print('✅ Successfully bound to mobile network (attempt 1)');

        // Verify binding worked
        await Future.delayed(const Duration(seconds: 5));
        final hasInternet = await _checkInternetAccess();

        if (hasInternet) {
          print(
              '✅ Mobile network binding verified - internet access confirmed');
          return true;
        } else {
          print(
              '⚠️ Binding succeeded but no internet - trying alternative approach...');
        }
      }

      // If first attempt failed or no internet, try alternative approach
      print('🔄 Attempt 2: Alternative binding approach...');

      // Release binding and try again with longer delays
      await releaseNetworkBinding();
      await Future.delayed(const Duration(seconds: 5));

      final result2 = await _channel
          .invokeMethod('bindToMobileNetwork')
          .timeout(const Duration(seconds: 60));

      if (result2 == true) {
        _isBindingActive = true;
        print('✅ Successfully bound to mobile network (attempt 2)');

        // Wait longer for verification
        await Future.delayed(const Duration(seconds: 8));
        final hasInternet = await _checkInternetAccess();

        if (hasInternet) {
          print('✅ Mobile network binding verified on attempt 2');
          return true;
        }
      }

      print('❌ All binding attempts failed');
      return false;
    } catch (e) {
      print('❌ Error binding to mobile network: $e');
      return false;
    } finally {
      _isBindingInProgress = false;
    }
  }

  static Future<bool> releaseNetworkBinding() async {
    if (!_isBindingActive && !_isBindingInProgress) return true;

    try {
      print('🔓 Releasing network binding...');

      final result = await _channel
          .invokeMethod('releaseNetworkBinding')
          .timeout(const Duration(seconds: 10));

      if (result == true) {
        _isBindingActive = false;
        _isBindingInProgress = false;
        print('✅ Network binding released');
        return true;
      } else {
        print('❌ Failed to release network binding');
        return false;
      }
    } catch (e) {
      print('❌ Error releasing network binding: $e');
      return false;
    }
  }

  static void _startNetworkMonitoring() {
    print('👁️ Starting network monitoring...');

    Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      print('🔄 Network changed to: $results');
      _handleNetworkChange(results);
    });
  }

  static Future<void> _handleNetworkChange(
      List<ConnectivityResult> results) async {
    if (_isBindingInProgress) {
      print('⏳ Network binding in progress, skipping network change handling');
      return;
    }

    try {
      final primaryResult =
          results.isNotEmpty ? results.first : ConnectivityResult.none;

      switch (primaryResult) {
        case ConnectivityResult.wifi:
          print('📶 Connected to WiFi - checking internet access...');

          // Wait longer for WiFi to stabilize
          await Future.delayed(const Duration(seconds: 5));

          final hasInternet = await _checkInternetAccess();

          if (!hasInternet) {
            print('⚠️ WiFi has no internet - attempting mobile binding...');
            await _attemptNetworkBinding();
          } else {
            print('✅ WiFi has internet access');
            if (_isBindingActive) {
              print('🔄 Releasing mobile binding since WiFi has internet');
              await releaseNetworkBinding();
            }
          }
          break;

        case ConnectivityResult.mobile:
          print('📱 Connected to mobile data');
          if (_isBindingActive) {
            print('🔄 Releasing network binding since we\'re on mobile');
            await releaseNetworkBinding();
          }
          break;

        case ConnectivityResult.none:
          print('❌ No network connection');
          if (_isBindingActive) {
            await releaseNetworkBinding();
          }
          break;

        default:
          print('🔍 Unknown network type: $primaryResult');
      }
    } catch (e) {
      print('❌ Error handling network change: $e');
    }
  }

  static Future<bool> _checkInternetAccess() async {
    try {
      print('🌐 Testing internet connectivity...');

      // Get current connectivity type
      final connectivityResults = await Connectivity().checkConnectivity();
      final primaryConnectivity = connectivityResults.isNotEmpty
          ? connectivityResults.first
          : ConnectivityResult.none;

      // If we're on WiFi, we need to be more strict about internet testing
      if (primaryConnectivity == ConnectivityResult.wifi) {
        print('📶 On WiFi - performing strict internet test...');

        // Test multiple endpoints with stricter criteria for WiFi
        final testEndpoints = [
          {'host': 'google.com', 'timeout': 6},
          {'host': 'cloudflare.com', 'timeout': 6},
          {'host': '8.8.8.8', 'timeout': 5},
          {'host': '1.1.1.1', 'timeout': 5},
        ];

        int successCount = 0;
        int totalTests = testEndpoints.length;

        for (final endpoint in testEndpoints) {
          try {
            final result =
                await InternetAddress.lookup(endpoint['host'] as String)
                    .timeout(Duration(seconds: endpoint['timeout'] as int));

            if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
              successCount++;
              print('✅ WiFi test success for ${endpoint['host']}');
            }
          } catch (e) {
            print('❌ WiFi test failed for ${endpoint['host']}: $e');
          }
        }

        // For WiFi, require at least 75% of tests to pass (3 out of 4)
        final hasInternet = successCount >= 3;
        print(
            '📊 WiFi internet test: $successCount/$totalTests passed - Result: $hasInternet');
        return hasInternet;
      } else {
        // For mobile/other connections, use the original logic
        final testEndpoints = [
          {'host': 'google.com', 'timeout': 8},
          {'host': '8.8.8.8', 'timeout': 5},
          {'host': '1.1.1.1', 'timeout': 5},
        ];

        for (final endpoint in testEndpoints) {
          try {
            final result =
                await InternetAddress.lookup(endpoint['host'] as String)
                    .timeout(Duration(seconds: endpoint['timeout'] as int));

            if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
              print('✅ Internet access confirmed via ${endpoint['host']}');
              return true;
            }
          } catch (e) {
            print('❌ Internet test failed for ${endpoint['host']}: $e');
            continue;
          }
        }

        print('❌ All internet connectivity tests failed');
        return false;
      }
    } catch (e) {
      print('❌ Internet connectivity test error: $e');
      return false;
    }
  }

  static Future<bool> refreshNetworkBinding() async {
    print('🔄 Manually refreshing network binding...');

    try {
      // Release current binding
      await releaseNetworkBinding();
      await Future.delayed(const Duration(seconds: 3));

      // Attempt new binding
      return await _attemptNetworkBinding();
    } catch (e) {
      print('❌ Error refreshing network binding: $e');
      return false;
    }
  }

  static Future<void> forceNetworkBinding() async {
    print('🔧 === FORCING NETWORK BINDING ===');

    try {
      // Release any existing binding
      await releaseNetworkBinding();
      await Future.delayed(const Duration(seconds: 2));

      // Force binding regardless of current status
      _isBindingInProgress = true;
      print('📱 Force starting SIMPLE mobile network binding...');

      // Try the simple method first
      final result = await _channel
          .invokeMethod('bindToMobileNetworkSimple')
          .timeout(const Duration(seconds: 45));

      if (result == true) {
        _isBindingActive = true;
        print('✅ Force binding successful');

        // Test the binding
        await Future.delayed(const Duration(seconds: 5));
        await debugNetworkBinding();
      } else {
        print('❌ Force binding failed');
      }
    } catch (e) {
      print('❌ Force binding error: $e');
    } finally {
      _isBindingInProgress = false;
    }

    print('🔧 === FORCE BINDING COMPLETE ===');
  }

  // KEEP ONLY ONE testNetworkBinding() method
  static Future<Map<String, dynamic>> testNetworkBinding() async {
    try {
      final result = await _channel
          .invokeMethod('testNetworkBinding')
          .timeout(const Duration(seconds: 15));

      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }

      return {'error': 'Invalid response format'};
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final status = await getNetworkStatus();
      final bindingTest = await testNetworkBinding();

      return {
        'connectivity': status.connectivity.toString(),
        'hasInternet': status.hasInternet,
        'isBindingActive': status.isBindingActive,
        'isBindingInProgress': status.isBindingInProgress,
        'bindingTest': bindingTest,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static Future<void> diagnoseNetwork() async {
    print('🔍 === NETWORK DIAGNOSIS START ===');

    try {
      // Test connectivity
      final connectivityResults = await Connectivity().checkConnectivity();
      print('📶 Connectivity: $connectivityResults');

      // Test multiple endpoints with timing
      final endpoints = ['google.com', '8.8.8.8', '1.1.1.1', 'cloudflare.com'];

      for (final endpoint in endpoints) {
        try {
          final stopwatch = Stopwatch()..start();
          final result = await InternetAddress.lookup(endpoint)
              .timeout(const Duration(seconds: 15));
          stopwatch.stop();

          if (result.isNotEmpty) {
            print(
                '✅ $endpoint: ${stopwatch.elapsedMilliseconds}ms - ${result[0].address}');
          } else {
            print('❌ $endpoint: No results');
          }
        } catch (e) {
          print('❌ $endpoint: $e');
        }
      }

      // Test your server specifically
      try {
        final stopwatch = Stopwatch()..start();
        final result = await InternetAddress.lookup('119.2.105.142')
            .timeout(const Duration(seconds: 15));
        stopwatch.stop();

        if (result.isNotEmpty) {
          print(
              '✅ Your Server IP: ${stopwatch.elapsedMilliseconds}ms - ${result[0].address}');
        } else {
          print('❌ Your Server IP: No results');
        }
      } catch (e) {
        print('❌ Your Server IP: $e');
      }

      // Check current network info
      final info = await getNetworkInfo();
      print('📊 Network Info: $info');
    } catch (e) {
      print('❌ Diagnosis error: $e');
    }

    print('🔍 === NETWORK DIAGNOSIS END ===');
  }

  static Future<void> debugNetworkBinding() async {
    print('🔍 === DEBUG NETWORK BINDING ===');

    try {
      // Check current connectivity
      final connectivity = await Connectivity().checkConnectivity();
      print('📶 Current connectivity: $connectivity');

      // Test internet through different methods
      print('🌐 Testing internet access...');

      // Test 1: Basic lookup
      try {
        final result1 = await InternetAddress.lookup('8.8.8.8')
            .timeout(Duration(seconds: 10));
        print('✅ Test 1 (8.8.8.8): ${result1.length} results');
      } catch (e) {
        print('❌ Test 1 failed: $e');
      }

      // Test 2: Google
      try {
        final result2 = await InternetAddress.lookup('google.com')
            .timeout(Duration(seconds: 10));
        print('✅ Test 2 (google.com): ${result2.length} results');
      } catch (e) {
        print('❌ Test 2 failed: $e');
      }

      // Test 3: Your server
      try {
        final result3 = await InternetAddress.lookup('119.2.105.142')
            .timeout(Duration(seconds: 10));
        print('✅ Test 3 (your server): ${result3.length} results');
      } catch (e) {
        print('❌ Test 3 failed: $e');
      }

      // Check binding status
      final bindingTest = await testNetworkBinding();
      print('🔗 Binding test: $bindingTest');
    } catch (e) {
      print('❌ Debug error: $e');
    }

    print('🔍 === END DEBUG ===');
  }
}

class NetworkStatus {
  final ConnectivityResult connectivity;
  final bool hasInternet;
  final bool isBindingActive;
  final bool isBindingInProgress;
  NetworkStatus({
    required this.connectivity,
    required this.hasInternet,
    required this.isBindingActive,
    required this.isBindingInProgress,
  });

  @override
  String toString() {
    return 'NetworkStatus(connectivity: $connectivity, hasInternet: $hasInternet, isBindingActive: $isBindingActive, isBindingInProgress: $isBindingInProgress)';
  }
}
