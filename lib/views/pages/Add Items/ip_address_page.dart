import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pos_system_legphel/bloc/ip_address_bloc/bloc/ip_address_bloc.dart';

class IpAddressPage extends StatefulWidget {
  const IpAddressPage({super.key});

  @override
  State<IpAddressPage> createState() => _IpAddressPageState();
}

class _IpAddressPageState extends State<IpAddressPage> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  bool _isSubmitting = false;

  // Apple Fruit Color Palette 🍎
  final Color appleRed = const Color(0xFFE74C3C);
  final Color appleGreen = const Color(0xFF2ECC71);
  final Color appleLeaf = const Color(0xFF27AE60);
  final Color appleStem = const Color(0xFF8B4513);
  final Color appleCream = const Color(0xFFFDF2E9);

  @override
  void initState() {
    super.initState();
    context.read<IpAddressBloc>().add(const LoadIpAddress());
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? appleRed : appleGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  bool _isValidIpAddress(String ip) {
    final ipv4Regex = RegExp(
        r'^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$');
    return ipv4Regex.hasMatch(ip);
  }

  bool _isValidPort(String port) {
    final portNum = int.tryParse(port);
    return portNum != null && portNum > 0 && portNum <= 65535;
  }

  void _saveIpAddress() {
    if (_formKey.currentState!.validate()) {
      final fullAddress =
          '${_ipController.text.trim()}:${_portController.text.trim()}';

      print('🔍 About to save: $fullAddress'); // Debug print

      context.read<IpAddressBloc>().add(SaveIpAddress(fullAddress));

      // Force reset after 5 seconds as backup
      Future.delayed(Duration(seconds: 5), () {
        if (mounted && _isSubmitting) {
          print('🔍 Force resetting _isSubmitting'); // Debug print
          setState(() => _isSubmitting = false);
          _showSnackBar('Operation timed out. Please try again.',
              isError: true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appleCream,
      appBar: AppBar(
        title: const Text('Server Connection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: appleLeaf,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: BlocListener<IpAddressBloc, IpAddressState>(
          listener: (context, state) {
            print('🔍 Current state: ${state.runtimeType}'); // Debug print
            print('🔍 _isSubmitting before: $_isSubmitting'); // Debug print

            if (state is IpAddressLoading) {
              if (!_isSubmitting) {
                setState(() => _isSubmitting = true);
                print('🔍 Set _isSubmitting to true'); // Debug print
              }
            } else {
              // Always reset loading for any non-loading state
              if (_isSubmitting) {
                setState(() => _isSubmitting = false);
                print('🔍 Reset _isSubmitting to false'); // Debug print
              }

              if (state is IpAddressError) {
                _showSnackBar(state.message, isError: true);
                print('🔍 Error state: ${state.message}'); // Debug print
              } else if (state is IpAddressLoaded) {
                if (_ipController.text.isNotEmpty) {
                  _showSnackBar('Connection saved successfully!');
                }
                final parts = state.ipAddress.split(':');
                if (parts.length == 2) {
                  _ipController.text = parts[0];
                  _portController.text = parts[1];
                }
                print('🔍 Loaded state: ${state.ipAddress}'); // Debug print
              }
            }

            print('🔍 _isSubmitting after: $_isSubmitting'); // Debug print
          },
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: appleStem.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // IP Address Field
                    TextFormField(
                      controller: _ipController,
                      decoration: InputDecoration(
                        labelText: 'IP Address',
                        hintText: '192.168.1.100',
                        prefixIcon: Icon(Icons.computer, color: appleLeaf),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: appleStem.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: appleGreen, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_isValidIpAddress(value)) return 'Invalid IP';
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // Port Field
                    TextFormField(
                      controller: _portController,
                      decoration: InputDecoration(
                        labelText: 'Port',
                        hintText: '8080',
                        prefixIcon: Icon(Icons.numbers, color: appleLeaf),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              BorderSide(color: appleStem.withOpacity(0.3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: appleGreen, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
                      ],
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Required';
                        if (!_isValidPort(value))
                          return 'Invalid Port (1-65535)';
                        return null;
                      },
                    ),

                    const SizedBox(height: 30),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _saveIpAddress,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appleRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 3,
                          shadowColor: appleRed.withOpacity(0.4),
                        ),
                        child: _isSubmitting
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('SAVING...',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ],
                              )
                            : const Text('SAVE CONNECTION',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
