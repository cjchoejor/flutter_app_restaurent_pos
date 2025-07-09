import "dart:async";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:pos_system_legphel/bloc/navigation_bloc/bloc/navigation_bloc.dart";
import "package:pos_system_legphel/services/network_service.dart";
import "package:pos_system_legphel/services/network_manager.dart";
import "package:connectivity_plus/connectivity_plus.dart";
import "dart:io";

class DrawerWidget extends StatefulWidget {
  const DrawerWidget({super.key});

  @override
  State<DrawerWidget> createState() => _DrawerWidgetState();
}

class _DrawerWidgetState extends State<DrawerWidget> {
  bool _isServerAvailable = false;
  bool _isNetworkAvailable = false;
  String _networkType = 'Unknown';
  String _networkStatus = 'Checking...';
  bool _isNetworkBinding = false;
  bool _isBindingInProgress = false;
  Color _statusColor = Colors.grey;
  IconData _statusIcon = Icons.help;

  final NetworkService _networkService =
      NetworkService(baseUrl: 'http://119.2.105.142:3800');
  Timer? _statusTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    // Check status every 10 seconds for more responsive updates
    _statusTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _checkStatus();
    });

    _connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      _checkStatus();
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      setState(() {
        _networkStatus = 'Checking...';
        _statusColor = Colors.orange;
        _statusIcon = Icons.refresh;
      });

      // Get network manager status
      final networkStatus = await NetworkManager.getNetworkStatus();

      // Check basic connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      bool hasConnectivity = connectivityResult != ConnectivityResult.none;

      // Determine network type
      String networkType = 'None';
      if (connectivityResult == ConnectivityResult.wifi) {
        networkType = 'WiFi';
      } else if (connectivityResult == ConnectivityResult.mobile) {
        networkType = 'Mobile';
      }

      // Check internet access with timeout
      bool hasInternetAccess = false;
      if (hasConnectivity) {
        try {
          setState(() {
            _networkStatus = 'Testing internet...';
          });

          final result = await InternetAddress.lookup('google.com')
              .timeout(const Duration(seconds: 10));
          hasInternetAccess =
              result.isNotEmpty && result[0].rawAddress.isNotEmpty;
        } on SocketException catch (_) {
          hasInternetAccess = false;
        } catch (e) {
          print('Internet test error: $e');
          hasInternetAccess = false;
        }
      }

      // Check server availability with timeout
      bool isServerAvailable = false;
      if (hasInternetAccess) {
        try {
          setState(() {
            _networkStatus = 'Testing server...';
          });

          isServerAvailable = await _networkService.isServerAvailable();
        } catch (e) {
          print('Server test error: $e');
          isServerAvailable = false;
        }
      }

      // Determine overall status
      String networkStatusText;
      Color statusColor;
      IconData statusIcon;

      if (!hasConnectivity) {
        networkStatusText = 'No Connection';
        statusColor = Colors.red;
        statusIcon = Icons.signal_wifi_off;
      } else if (networkStatus.isBindingInProgress) {
        networkStatusText = 'Connecting to Mobile...';
        statusColor = Colors.orange;
        statusIcon = Icons.sync;
      } else if (networkStatus.isBindingActive) {
        if (isServerAvailable) {
          networkStatusText = 'WiFi + Mobile Data';
          statusColor = Colors.blue;
          statusIcon = Icons.wifi_tethering;
        } else {
          networkStatusText = 'Mobile Bound, No Server';
          statusColor = Colors.orange;
          statusIcon = Icons.signal_cellular_4_bar;
        }
      } else if (!hasInternetAccess) {
        networkStatusText = 'No Internet';
        statusColor = Colors.red;
        statusIcon = Icons.signal_wifi_connected_no_internet_4;
      } else if (!isServerAvailable) {
        networkStatusText = 'Server Offline';
        statusColor = Colors.orange;
        statusIcon = Icons.cloud_off;
      } else {
        networkStatusText = 'All Systems Online';
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
      }

      if (mounted) {
        setState(() {
          _isNetworkAvailable = hasConnectivity && hasInternetAccess;
          _isServerAvailable = isServerAvailable;
          _networkType = networkType;
          _networkStatus = networkStatusText;
          _isNetworkBinding = networkStatus.isBindingActive;
          _isBindingInProgress = networkStatus.isBindingInProgress;
          _statusColor = statusColor;
          _statusIcon = statusIcon;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isNetworkAvailable = false;
          _isServerAvailable = false;
          _networkType = 'Error';
          _networkStatus = 'Check Failed';
          _isNetworkBinding = false;
          _isBindingInProgress = false;
          _statusColor = Colors.red;
          _statusIcon = Icons.error;
        });
      }
    }
  }

  Future<void> _refreshNetworkBinding() async {
    try {
      setState(() {
        _networkStatus = 'Refreshing...';
        _statusColor = Colors.orange;
        _statusIcon = Icons.refresh;
      });

      final success = await NetworkManager.refreshNetworkBinding();

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network binding refreshed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to refresh network binding'),
            backgroundColor: Colors.red,
          ),
        );
      }

      // Refresh status
      await Future.delayed(const Duration(seconds: 2));
      _checkStatus();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error refreshing network: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showNetworkDiagnostics() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Network Diagnostics'),
        content: const SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Running network diagnostics...'),
            ],
          ),
        ),
      ),
    );

    try {
      await NetworkManager.diagnoseNetwork();
      await NetworkManager.debugNetworkBinding();
      final networkInfo = await NetworkManager.getNetworkInfo();

      Navigator.of(context).pop(); // Close loading dialog

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Network Diagnostics Results'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDiagnosticItem('Network Type', _networkType),
                  _buildDiagnosticItem('Status', _networkStatus),
                  _buildDiagnosticItem(
                      'Internet Available', _isNetworkAvailable.toString()),
                  _buildDiagnosticItem(
                      'Server Available', _isServerAvailable.toString()),
                  _buildDiagnosticItem(
                      'Mobile Binding Active', _isNetworkBinding.toString()),
                  _buildDiagnosticItem(
                      'Binding In Progress', _isBindingInProgress.toString()),
                  const Divider(),
                  const Text('Detailed Info:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    networkInfo.toString(),
                    style:
                        const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      await NetworkManager.debugNetworkBinding();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Debug output printed to console'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
                    child: const Text('Run Debug Test'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Diagnostics failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildDiagnosticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.pink.shade50,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            UserAccountsDrawerHeader(
              accountName: const Text(
                "Legphel Hotel",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: const Text(
                "hotel.legphel@gmail.com",
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/logo.png',
                    width: 90,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFD62D20), // Apple red
                    Color(0xFFFF7F7F), // Lighter red/pink
                  ],
                ),
              ),
            ),

            // Enhanced Status Indicators
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildDetailedStatusCard(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusIndicator(
                          icon: Icons.cloud_done,
                          label: 'Server',
                          isAvailable: _isServerAvailable,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusIndicator(
                          icon: Icons.wifi,
                          label: 'Internet',
                          isAvailable: _isNetworkAvailable,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _refreshNetworkBinding,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Refresh',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showNetworkDiagnostics,
                          icon: const Icon(Icons.bug_report, size: 16),
                          label: const Text('Diagnose',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Force Mobile Binding Button
                  const SizedBox(height: 8),
                  if (_networkType == 'WiFi' && !_isServerAvailable)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await NetworkManager.forceNetworkBinding();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Force binding attempted - check console'),
                                backgroundColor: Colors.purple,
                              ),
                            );
                            _checkStatus();
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Force binding failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.power, size: 16),
                        label: const Text('Force Mobile Binding',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: Colors.black12),

            // Navigation Items
            SingleChildScrollView(
              child: Column(
                children: [
                  _buildListTile(
                    context,
                    icon: Icons.add_shopping_cart_outlined,
                    title: "Sales",
                    color: const Color(0xFF34C759), // Apple green
                    navigationEvent: NavigateToSales(),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.receipt,
                    title: "Receipt",
                    color: const Color(0xFF5856D6), // Apple purple
                    navigationEvent: NavigateToReceipt(),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.add_card,
                    title: "Edit Items",
                    color: const Color(0xFF007AFF), // Apple blue
                    navigationEvent: NavigateToItems(),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.notification_add,
                    title: "Notification",
                    color: const Color(0xFFFF9500), // Apple orange
                    navigationEvent: NavigateToNotification(),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.person_add_rounded,
                    title: "Shift",
                    color: const Color(0xFFAF52DE), // Apple pink
                    navigationEvent: NavigateToShift(),
                  ),
                  const Divider(
                    color: Colors.black12,
                    thickness: 1,
                    height: 20,
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.settings,
                    title: "Settings",
                    color: Colors.grey.shade700,
                    navigationEvent: NavigateToSettings(),
                  ),
                  _buildListTile(
                    context,
                    icon: Icons.exit_to_app,
                    title: "Exit",
                    color: const Color(0xFFFF3B30), // Apple red
                    onTap: () => _confirmExit(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatusCard() {
    return GestureDetector(
      onTap: _showNetworkDiagnostics,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _statusColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _statusColor.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _isBindingInProgress
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(_statusColor),
                        ),
                      )
                    : Icon(_statusIcon, color: _statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _networkStatus,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _statusColor,
                    ),
                  ),
                ),
                if (_isNetworkBinding)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DUAL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Network: $_networkType',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            if (_isNetworkBinding)
              Text(
                'Using WiFi + Mobile Data',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator({
    required IconData icon,
    required String label,
    required bool isAvailable,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAvailable
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isAvailable ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                ),
              ),
              Text(
                isAvailable ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isAvailable ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    dynamic navigationEvent,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: color,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap ??
          () {
            if (navigationEvent != null) {
              context.read<NavigationBloc>().add(navigationEvent);
            }
            Navigator.pop(context);
          },
    );
  }

  void _confirmExit(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Exit App"),
          content: const Text("Are you sure you want to exit the app?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                SystemNavigator.pop();
              },
              child: const Text(
                "Exit",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
