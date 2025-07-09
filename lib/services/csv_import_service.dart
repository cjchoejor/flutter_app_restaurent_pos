import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:pos_system_legphel/models/others/new_menu_model.dart';
import 'package:pos_system_legphel/models/others/category_model.dart';
import 'package:pos_system_legphel/models/others/sub_category_model.dart';
import 'package:pos_system_legphel/SQL/menu_local_db.dart';
import 'package:pos_system_legphel/SQL/category_databasehelper.dart';

class CsvImportService {
  static Future<Map<String, dynamic>> importAllFromCsv() async {
    print('🚀 Starting importAllFromCsv()'); // Debug

    try {
      // Request storage permission first
      print('📋 Checking permissions...'); // Debug
      PermissionStatus permission = await Permission.storage.request();

      if (permission != PermissionStatus.granted) {
        PermissionStatus managePermission =
            await Permission.manageExternalStorage.request();

        if (managePermission != PermissionStatus.granted &&
            permission != PermissionStatus.granted) {
          print('❌ Permission denied'); // Debug
          return {
            'success': false,
            'message':
                'Storage permission denied. Please grant storage permission in app settings to import CSV files.',
            'imported': 0,
            'total': 0
          };
        }
      }

      print('✅ Permissions granted'); // Debug

      // Import categories first, then menu (as requested)
      print('📁 Starting category import...'); // Debug
      Map<String, dynamic> categoryResult = await importCategoriesFromCsv();
      print('📁 Category import result: $categoryResult'); // Debug

      print('🍽️ Starting menu import...'); // Debug
      Map<String, dynamic> menuResult = await importMenuFromCsv();
      print('🍽️ Menu import result: $menuResult'); // Debug

      // Combine results
      List<String> messages = [];
      bool overallSuccess = false;

      if (categoryResult['success']) {
        messages.add('✅ Categories: ${categoryResult['message']}');
        overallSuccess = true;
      } else {
        messages.add('⚠️ Categories: ${categoryResult['message']}');
      }

      if (menuResult['success']) {
        messages.add('✅ Menu: ${menuResult['message']}');
        overallSuccess = true;
      } else {
        messages.add('⚠️ Menu: ${menuResult['message']}');
      }

      print('🎯 Final result: success=$overallSuccess'); // Debug

      return {
        'success': overallSuccess,
        'message': messages.join('\n\n'),
        'categoryResult': categoryResult,
        'menuResult': menuResult,
        'imported':
            (categoryResult['imported'] ?? 0) + (menuResult['imported'] ?? 0),
        'total': (categoryResult['total'] ?? 0) + (menuResult['total'] ?? 0),
      };
    } catch (e) {
      print('💥 Error in importAllFromCsv: $e'); // Debug
      return {
        'success': false,
        'message': 'Error importing files: $e',
        'imported': 0,
        'total': 0
      };
    }
  }

  static Future<Map<String, dynamic>> importCategoriesFromCsv() async {
    print('📂 Starting importCategoriesFromCsv()'); // Debug

    try {
      // Try multiple possible paths for categories.csv
      List<String> possiblePaths = [
        '/storage/emulated/0/Download/categories.csv',
        '/storage/emulated/0/Downloads/categories.csv',
        '/sdcard/Download/categories.csv',
        '/sdcard/Downloads/categories.csv',
      ];

      print(
          '🔍 Searching for categories.csv in paths: $possiblePaths'); // Debug

      File? csvFile;
      String foundPath = '';

      for (String path in possiblePaths) {
        print('🔍 Checking path: $path'); // Debug
        File testFile = File(path);
        bool exists = await testFile.exists();
        print('📄 File exists at $path: $exists'); // Debug

        if (exists) {
          csvFile = testFile;
          foundPath = path;
          print('✅ Found categories.csv at: $foundPath'); // Debug
          break;
        }
      }

      if (csvFile == null) {
        print('❌ categories.csv not found in any location'); // Debug
        return {
          'success': false,
          'message': 'categories.csv not found in Downloads folder - Skipped',
          'imported': 0,
          'total': 0
        };
      }

      print('📖 Reading file contents...'); // Debug
      String contents = await csvFile.readAsString();
      print('📄 File size: ${contents.length} characters'); // Debug
      print(
          '📄 First 200 chars: ${contents.length > 200 ? contents.substring(0, 200) : contents}'); // Debug

      // Handle different line endings and split properly
      contents = contents.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Check if it's a single line format (like your example) or multi-line
      List<String> lines = contents.split('\n');
      print('📄 Number of lines: ${lines.length}'); // Debug

      List<String> allFields;

      if (lines.length == 1 || (lines.length == 2 && lines[1].trim().isEmpty)) {
        // Single line format - split by commas
        print('📄 Processing as single-line CSV format'); // Debug
        allFields = _parseCsvRow(contents.trim());
      } else {
        // Multi-line format - join all non-empty lines and split by commas
        print('📄 Processing as multi-line CSV format'); // Debug
        String joinedContent =
            lines.where((line) => line.trim().isNotEmpty).join(',');
        allFields = _parseCsvRow(joinedContent);
      }

      print('📊 Total fields parsed: ${allFields.length}'); // Debug
      print('📊 First 10 fields: ${allFields.take(10).toList()}'); // Debug

      // Find CATEGORIES and SUBCATEGORIES indices
      int categoriesIndex = -1;
      int subcategoriesIndex = -1;

      for (int i = 0; i < allFields.length; i++) {
        String field = allFields[i].trim().toUpperCase();
        if (field == 'CATEGORIES') {
          categoriesIndex = i;
          print('✅ Found CATEGORIES at index: $i'); // Debug
        } else if (field == 'SUBCATEGORIES') {
          subcategoriesIndex = i;
          print('✅ Found SUBCATEGORIES at index: $i'); // Debug
        }
      }

      if (categoriesIndex == -1) {
        print('❌ CATEGORIES section not found'); // Debug
        return {
          'success': false,
          'message': 'CATEGORIES section not found in CSV',
          'imported': 0,
          'total': 0
        };
      }

      // Parse Categories
      List<CategoryModel> categories = [];
      int categorySkipped = 0;

      // Find where category data starts (after CATEGORIES header)
      int categoryDataStart = categoriesIndex + 1;

      // Skip empty fields and find the actual header
      while (categoryDataStart < allFields.length &&
          allFields[categoryDataStart].trim().isEmpty) {
        categoryDataStart++;
      }

      // Skip the header row (categoryId,categoryName,status,sortOrder)
      if (categoryDataStart < allFields.length &&
          allFields[categoryDataStart]
              .trim()
              .toLowerCase()
              .contains('categoryid')) {
        categoryDataStart++;
      }

      int categoryDataEnd =
          subcategoriesIndex != -1 ? subcategoriesIndex : allFields.length;

      print(
          '📊 Category data range: $categoryDataStart to $categoryDataEnd'); // Debug

      // Process categories - look for UUID pattern to identify start of data
      for (int i = categoryDataStart; i < categoryDataEnd; i++) {
        String field = allFields[i].trim();

        // Check if this looks like a UUID (category ID)
        if (field.length == 36 && field.contains('-')) {
          if (i + 3 < categoryDataEnd) {
            try {
              String categoryId = field;
              String categoryName = allFields[i + 1].trim();
              String status = allFields[i + 2].trim();
              String sortOrderStr = allFields[i + 3].trim();

              // Skip if categoryName is empty
              if (categoryName.isEmpty) {
                continue;
              }

              CategoryModel category = CategoryModel(
                categoryId: categoryId,
                categoryName: categoryName,
                status: status.isEmpty ? 'active' : status,
                sortOrder: int.tryParse(sortOrderStr) ?? 0,
              );
              categories.add(category);
              print(
                  '✅ Added category: ${category.categoryName} (ID: ${category.categoryId})'); // Debug

              // Skip the next 3 fields as we've processed them
              i += 3;
            } catch (e) {
              print('❌ Error parsing category at index $i: $e');
              categorySkipped++;
            }
          }
        }
      }

      // Parse Subcategories
      List<SubcategoryModel> subcategories = [];
      int subcategorySkipped = 0;

      if (subcategoriesIndex != -1) {
        // Find where subcategory data starts
        int subcategoryDataStart = subcategoriesIndex + 1;

        // Skip empty fields and find the actual header
        while (subcategoryDataStart < allFields.length &&
            allFields[subcategoryDataStart].trim().isEmpty) {
          subcategoryDataStart++;
        }

        // Skip the header row (subcategoryId,subcategoryName,categoryId,status,sortOrder)
        if (subcategoryDataStart < allFields.length &&
            allFields[subcategoryDataStart]
                .trim()
                .toLowerCase()
                .contains('subcategoryid')) {
          subcategoryDataStart++;
        }

        print(
            '📊 Subcategory data range: $subcategoryDataStart to ${allFields.length}'); // Debug

        // Process subcategories - look for UUID pattern
        for (int i = subcategoryDataStart; i < allFields.length; i++) {
          String field = allFields[i].trim();

          // Check if this looks like a UUID (subcategory ID)
          if (field.length == 36 && field.contains('-')) {
            if (i + 4 < allFields.length) {
              try {
                String subcategoryId = field;
                String subcategoryName = allFields[i + 1].trim();
                String categoryId = allFields[i + 2].trim();
                String status = allFields[i + 3].trim();
                String sortOrderStr = allFields[i + 4].trim();

                // Skip if subcategoryName is empty
                if (subcategoryName.isEmpty) {
                  continue;
                }

                SubcategoryModel subcategory = SubcategoryModel(
                  subcategoryId: subcategoryId,
                  subcategoryName: subcategoryName,
                  categoryId: categoryId,
                  status: status.isEmpty ? 'active' : status,
                  sortOrder: int.tryParse(sortOrderStr) ?? 0,
                );
                subcategories.add(subcategory);
                print(
                    '✅ Added subcategory: ${subcategory.subcategoryName} (ID: ${subcategory.subcategoryId})'); // Debug

                // Skip the next 4 fields as we've processed them
                i += 4;
              } catch (e) {
                print('❌ Error parsing subcategory at index $i: $e');
                subcategorySkipped++;
              }
            }
          }
        }
      }

      print(
          '📊 Final counts - Categories: ${categories.length}, Subcategories: ${subcategories.length}'); // Debug

      // Import to database
      Map<String, dynamic> result = await _importCategoriesAndSubcategories(
          categories, subcategories, categorySkipped, subcategorySkipped);
      result['foundPath'] = foundPath;
      return result;
    } catch (e) {
      print('💥 Error importing categories CSV: $e'); // Debug
      return {
        'success': false,
        'message': 'Error reading categories CSV: $e',
        'imported': 0,
        'total': 0
      };
    }
  }

  static Future<Map<String, dynamic>> importMenuFromCsv() async {
    print('🍽️ Starting importMenuFromCsv()'); // Debug

    try {
      // Try multiple possible paths for menu_data.csv
      List<String> possiblePaths = [
        '/storage/emulated/0/Download/menu_data.csv',
        '/storage/emulated/0/Downloads/menu_data.csv',
        '/sdcard/Download/menu_data.csv',
        '/sdcard/Downloads/menu_data.csv',
      ];

      print('🔍 Searching for menu_data.csv in paths: $possiblePaths'); // Debug

      File? csvFile;
      String foundPath = '';

      for (String path in possiblePaths) {
        print('🔍 Checking path: $path'); // Debug
        File testFile = File(path);
        bool exists = await testFile.exists();
        print('📄 File exists at $path: $exists'); // Debug

        if (exists) {
          csvFile = testFile;
          foundPath = path;
          print('✅ Found menu_data.csv at: $foundPath'); // Debug
          break;
        }
      }

      if (csvFile == null) {
        print('❌ menu_data.csv not found in any location'); // Debug
        return {
          'success': false,
          'message': 'menu_data.csv not found in Downloads folder - Skipped',
          'imported': 0,
          'total': 0
        };
      }

      String contents = await csvFile.readAsString();
      List<String> lines = contents.split('\n');

      print('📄 Menu file lines: ${lines.length}'); // Debug

      if (lines.length < 3) {
        return {
          'success': false,
          'message': 'Menu CSV file appears to be empty or invalid',
          'imported': 0,
          'total': 0
        };
      }

      List<MenuModel> menuItems = [];
      int skippedRows = 0;

      // Skip first row (MENU) and second row (column headers), start from row 2 (index 2)
      for (int i = 2; i < lines.length; i++) {
        String line = lines[i].trim();
        if (line.isEmpty) continue;

        List<String> row = _parseCsvRow(line);

        // Ensure we have enough columns (at least 12 for all required fields)
        if (row.length < 12) {
          skippedRows++;
          continue;
        }

        try {
          // Map CSV columns to your database structure
          String menuId = row[0].trim();
          String menuName = row[1].trim();
          String menuType = row[2].trim();
          String subMenuType = row[3].trim();
          String price = row[4].trim();
          row[4].trim();
          String description = row[5].trim();
          String availabilityStr = row[6].trim();
          String dishImage = row[7].trim();
          String uuid = row[8].trim();
          String createdAt = row[9].trim();
          String updatedAt = row[10].trim();
          String itemDestination = row[11].trim();

          // Validate required fields
          if (menuId.isEmpty || menuName.isEmpty || price.isEmpty) {
            skippedRows++;
            continue;
          }

          // Parse availability (should be 0 or 1) - Convert to bool
          bool availability = true;
          if (availabilityStr == '0' ||
              availabilityStr.toLowerCase() == 'false') {
            availability = false;
          }

          // Validate price
          double? priceValue = double.tryParse(price);
          if (priceValue == null || priceValue <= 0) {
            skippedRows++;
            continue;
          }

          // Generate new timestamps if empty
          String currentTime = DateTime.now().toIso8601String();
          if (createdAt.isEmpty) createdAt = currentTime;
          if (updatedAt.isEmpty) updatedAt = currentTime;
          if (uuid.isEmpty)
            uuid = DateTime.now().millisecondsSinceEpoch.toString();

          MenuModel menuItem = MenuModel(
            menuId: menuId,
            menuName: menuName,
            menuType: menuType,
            subMenuType: subMenuType,
            price: price,
            description: description,
            availability: availability,
            dishImage: dishImage,
            uuid: uuid,
            createdAt: createdAt,
            updatedAt: updatedAt,
            itemDestination: itemDestination,
          );

          menuItems.add(menuItem);
          print('✅ Added menu item: ${menuItem.menuName}'); // Debug
        } catch (e) {
          print('❌ Error parsing menu row $i: $e');
          skippedRows++;
        }
      }

      print('📊 Total menu items parsed: ${menuItems.length}'); // Debug

      // Import to database
      Map<String, dynamic> result =
          await _importMenuItems(menuItems, skippedRows);
      result['foundPath'] = foundPath;
      return result;
    } catch (e) {
      print('💥 Error importing menu CSV: $e');
      return {
        'success': false,
        'message': 'Error reading menu CSV: $e',
        'imported': 0,
        'total': 0
      };
    }
  }

  static List<String> _parseCsvRow(String row) {
    List<String> result = [];
    bool inQuotes = false;
    String currentField = '';

    for (int i = 0; i < row.length; i++) {
      String char = row[i];

      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(currentField);
        currentField = '';
      } else {
        currentField += char;
      }
    }

    result.add(currentField);
    return result;
  }

  static Future<Map<String, dynamic>> _importCategoriesAndSubcategories(
      List<CategoryModel> categories,
      List<SubcategoryModel> subcategories,
      int categorySkipped,
      int subcategorySkipped) async {
    print('💾 Starting database import...'); // Debug

    try {
      CategoryDatabaseHelper db = CategoryDatabaseHelper.instance;

      int categorySuccessCount = 0;
      int categoryFailedCount = 0;
      int subcategorySuccessCount = 0;
      int subcategoryFailedCount = 0;

      print('💾 Importing ${categories.length} categories...'); // Debug

      // Import categories
      for (CategoryModel category in categories) {
        try {
          await db.insertCategory(category);
          categorySuccessCount++;
          print('✅ Successfully inserted category: ${category.categoryName}');
        } catch (e) {
          print('❌ Failed to insert category ${category.categoryName}: $e');
          categoryFailedCount++;
        }
      }

      print('💾 Importing ${subcategories.length} subcategories...'); // Debug

      // Import subcategories
      for (SubcategoryModel subcategory in subcategories) {
        try {
          await db.insertSubcategory(subcategory);
          subcategorySuccessCount++;
          print(
              '✅ Successfully inserted subcategory: ${subcategory.subcategoryName}');
        } catch (e) {
          print(
              '❌ Failed to insert subcategory ${subcategory.subcategoryName}: $e');
          subcategoryFailedCount++;
        }
      }

      print('📊 Import summary:');
      print(
          '   Categories: $categorySuccessCount success, $categoryFailedCount failed, $categorySkipped skipped');
      print(
          '   Subcategories: $subcategorySuccessCount success, $subcategoryFailedCount failed, $subcategorySkipped skipped');

      return {
        'success': categorySuccessCount > 0 || subcategorySuccessCount > 0,
        'message':
            'Categories: ${categorySuccessCount} imported, ${categoryFailedCount} failed, ${categorySkipped} skipped\nSubcategories: ${subcategorySuccessCount} imported, ${subcategoryFailedCount} failed, ${subcategorySkipped} skipped',
        'categoryImported': categorySuccessCount,
        'subcategoryImported': subcategorySuccessCount,
        'imported': categorySuccessCount + subcategorySuccessCount,
        'total': categories.length + subcategories.length,
        'failed': categoryFailedCount + subcategoryFailedCount,
        'skipped': categorySkipped + subcategorySkipped
      };
    } catch (e) {
      print('💥 Error saving categories to database: $e');
      return {
        'success': false,
        'message': 'Error saving categories to database: $e',
        'categoryImported': 0,
        'subcategoryImported': 0,
        'imported': 0,
        'total': categories.length + subcategories.length
      };
    }
  }

  static Future<Map<String, dynamic>> _importMenuItems(
      List<MenuModel> menuItems, int skippedRows) async {
    print('💾 Starting menu database import...'); // Debug

    try {
      MenuLocalDb db = MenuLocalDb.instance;

      int successCount = 0;
      int failedCount = 0;

      print('💾 Importing ${menuItems.length} menu items...'); // Debug

      for (MenuModel item in menuItems) {
        bool success = await db.insertMenuItem(item);
        if (success) {
          successCount++;
          print('✅ Successfully inserted menu item: ${item.menuName}');
        } else {
          failedCount++;
          print('❌ Failed to insert menu item: ${item.menuName}');
        }
      }

      print(
          '📊 Menu import summary: $successCount success, $failedCount failed, $skippedRows skipped');

      return {
        'success': successCount > 0,
        'message':
            'Imported $successCount items successfully. Failed: $failedCount, Skipped: $skippedRows',
        'imported': successCount,
        'total': menuItems.length,
        'failed': failedCount,
        'skipped': skippedRows
      };
    } catch (e) {
      print('💥 Error saving menu to database: $e');
      return {
        'success': false,
        'message': 'Error saving menu to database: $e',
        'imported': 0,
        'total': menuItems.length
      };
    }
  }

  // Helper method to check permissions
  static Future<bool> checkStoragePermission() async {
    PermissionStatus permission = await Permission.storage.status;
    PermissionStatus managePermission =
        await Permission.manageExternalStorage.status;

    return permission.isGranted || managePermission.isGranted;
  }
}
