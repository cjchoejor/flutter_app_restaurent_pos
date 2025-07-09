import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_system_legphel/services/csv_import_service.dart';

class ImportMenuPage extends StatefulWidget {
  const ImportMenuPage({super.key});

  @override
  State<ImportMenuPage> createState() => _ImportMenuPageState();
}

class _ImportMenuPageState extends State<ImportMenuPage> {
  bool _isImporting = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    bool hasPermission = await CsvImportService.checkStoragePermission();
    setState(() {
      _hasPermission = hasPermission;
    });
  }

  Future<void> _requestPermission() async {
    PermissionStatus permission = await Permission.storage.request();
    if (permission != PermissionStatus.granted) {
      await Permission.manageExternalStorage.request();
    }
    await _checkPermission();
  }

  Future<void> _importCsv() async {
    print('🎯 Import button pressed'); // Debug
    setState(() => _isImporting = true);

    try {
      print('🎯 Calling CsvImportService.importAllFromCsv()'); // Debug
      Map<String, dynamic> result = await CsvImportService.importAllFromCsv();
      print('🎯 Import completed with result: $result'); // Debug

      setState(() => _isImporting = false);

      // Show detailed result dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(result['success'] ? 'Import Results' : 'Import Failed'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(result['message']),
                if (result['success']) ...[
                  const SizedBox(height: 10),
                  Text('📊 Total Imported: ${result['imported']} items'),
                  const SizedBox(height: 8),
                  if (result['categoryResult'] != null) ...[
                    Text('📁 Categories Result:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '  • Imported: ${result['categoryResult']['categoryImported'] ?? 0} categories'),
                    Text(
                        '  • Imported: ${result['categoryResult']['subcategoryImported'] ?? 0} subcategories'),
                    if (result['categoryResult']['foundPath'] != null)
                      Text(
                          '  • Found at: ${result['categoryResult']['foundPath']}'),
                    const SizedBox(height: 8),
                  ],
                  if (result['menuResult'] != null) ...[
                    Text('🍽️ Menu Result:',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                        '  • Imported: ${result['menuResult']['imported'] ?? 0} menu items'),
                    if (result['menuResult']['failed'] != null &&
                        result['menuResult']['failed'] > 0)
                      Text(
                          '  • Failed: ${result['menuResult']['failed']} items'),
                    if (result['menuResult']['skipped'] != null &&
                        result['menuResult']['skipped'] > 0)
                      Text(
                          '  • Skipped: ${result['menuResult']['skipped']} rows'),
                    if (result['menuResult']['foundPath'] != null)
                      Text(
                          '  • Found at: ${result['menuResult']['foundPath']}'),
                  ],
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                if (result['success']) {
                  Navigator.pop(context);
                }
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('💥 Error in _importCsv: $e'); // Debug
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import CSV Files'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.upload_file, size: 80, color: Colors.blue),
              const SizedBox(height: 20),
              const Text(
                'Import Categories & Menu from CSV',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Import categories first, then menu items',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Permission Status
              Card(
                color: _hasPermission ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        _hasPermission ? Icons.check_circle : Icons.warning,
                        color: _hasPermission ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _hasPermission
                              ? 'Storage permission granted ✅'
                              : 'Storage permission required ❌',
                          style: TextStyle(
                            color: _hasPermission
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!_hasPermission)
                        ElevatedButton(
                          onPressed: _requestPermission,
                          child: const Text('Grant'),
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Instructions Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Instructions:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      const Text('1. Convert your Excel sheets to CSV format:'),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                '   • categories.csv (Categories & Subcategories)'),
                            Text('   • menu_data.csv (Menu Items)'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text('2. Copy both files to Downloads folder'),
                      const Text('3. Grant storage permission above'),
                      const Text('4. Tap "Import CSV Files" button below'),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'If one file is missing, it will be skipped automatically',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed:
                    (_isImporting || !_hasPermission) ? null : _importCsv,
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  backgroundColor: Colors.green,
                ),
                child: _isImporting
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text('Importing...'),
                        ],
                      )
                    : Text(
                        _hasPermission
                            ? 'IMPORT CSV FILES'
                            : 'GRANT PERMISSION FIRST',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),

              const SizedBox(height: 20),

              // File format info
              Card(
                color: Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Expected File Formats:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 8),
                      const Text('categories.csv:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const Text('CATEGORIES',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text('categoryId,categoryName,status,sortOrder',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text('...category data...',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text('SUBCATEGORIES',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text(
                          'subcategoryId,subcategoryName,categoryId,status,sortOrder',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text('...subcategory data...',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('menu_data.csv:',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 12)),
                      const Text('MENU',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text(
                          'menuId,menuName,menuType,subMenuType,price,...',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                      const Text('...menu data...',
                          style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
