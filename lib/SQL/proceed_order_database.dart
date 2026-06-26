import 'package:pos_system_legphel/models/Menu%20Model/proceed_order_model.dart';
import 'package:pos_system_legphel/debug/agent_debug_log.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ProceedOrderDatabaseHelper {
  static final ProceedOrderDatabaseHelper instance =
      ProceedOrderDatabaseHelper._init();
  static Database? _database;

  ProceedOrderDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;

    // to retriever the old data from the data you can use this
    // but might need to change the model as it has lesser data
    // _database = await _initDB('ProceedOrdersFromAPINew.db');
    _database =
        await _initDB('ProceedOrderDataBase01.db'); // KEEP ORIGINAL NAME
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    final db = await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
    // #region agent log
    try {
      final uv = await db.rawQuery('PRAGMA user_version');
      List<dynamic> colNames = [];
      try {
        final ti = await db.rawQuery('PRAGMA table_info(proceed_orders)');
        colNames = ti.map((e) => e['name']).toList();
      } catch (_) {}
      await agentDebugLog(
        location: 'proceed_order_database.dart:_initDB',
        message: 'proceed DB after open',
        hypothesisId: 'B',
        data: {
          'absolutePath': path,
          'user_version': uv.isNotEmpty ? uv.first['user_version'] : null,
          'pragma_proceed_orders_columns': colNames,
        },
      );
    } catch (_) {}
    // #endregion
    return db;
  }

  // SQLite Table for Proceed Orders
  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE proceed_orders (
        holdOrderId TEXT PRIMARY KEY,
        tableNumber TEXT,
        customerName TEXT,
        phoneNumber TEXT,
        orderNumber TEXT, 
        restaurantBranchName TEXT,
        orderDateTime TEXT,
        menuItems TEXT,
        totalAmount REAL,
        roomNumber TEXT,
        reservationRefNo TEXT,
        paymentStatus TEXT,
        paymentMode TEXT
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // #region agent log
    await agentDebugLog(
      location: 'proceed_order_database.dart:_onUpgrade',
      message: 'onUpgrade invoked',
      hypothesisId: 'B',
      data: {'oldVersion': oldVersion, 'newVersion': newVersion},
    );
    // #endregion
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE proceed_orders ADD COLUMN roomNumber TEXT');
      await db.execute(
          'ALTER TABLE proceed_orders ADD COLUMN reservationRefNo TEXT');
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE proceed_orders ADD COLUMN paymentStatus TEXT');
      await db.execute('ALTER TABLE proceed_orders ADD COLUMN paymentMode TEXT');
    }
  }

  // Insert a Proceed Order
  Future<int> insertProceedOrder(ProceedOrderModel proceedOrder) async {
    final db = await instance.database;
    Map<String, dynamic> proceedOrderMap = proceedOrder.toMap();
    // #region agent log
    await agentDebugLog(
      location: 'proceed_order_database.dart:insertProceedOrder',
      message: 'insert map keys',
      hypothesisId: 'D',
      data: {
        'mapKeys': proceedOrderMap.keys.toList(),
        'hasPaymentStatus': proceedOrderMap.containsKey('paymentStatus'),
        'paymentStatus': proceedOrderMap['paymentStatus']?.toString() ?? '',
        'paymentMode': proceedOrderMap['paymentMode']?.toString() ?? '',
      },
    );
    // #endregion
    return await db.insert('proceed_orders', proceedOrderMap);
  }

  // Fetch all Proceed Orders
  Future<List<ProceedOrderModel>> fetchProceedOrders() async {
    final db = await instance.database;
    final result =
        await db.query('proceed_orders', orderBy: 'orderDateTime ASC');

    return result.map((map) {
      return ProceedOrderModel.fromMap(map);
    }).toList();
  }

  // Update a Proceed Order
  Future<int> updateProceedOrder(ProceedOrderModel proceedOrder) async {
    final db = await instance.database;

    if (proceedOrder.holdOrderId.isEmpty) {
      return 0;
    }

    final existingOrder = await db.query(
      'proceed_orders',
      where: 'holdOrderId = ?',
      whereArgs: [proceedOrder.holdOrderId],
    );

    if (existingOrder.isEmpty) {
      return 0;
    }

    int result = await db.update(
      'proceed_orders',
      proceedOrder.toMap(),
      where: 'holdOrderId = ?',
      whereArgs: [proceedOrder.holdOrderId],
    );
    return result;
  }

  // Delete a Proceed Order
  Future<int> deleteProceedOrder(String holdOrderId) async {
    final db = await instance.database;
    return await db.delete('proceed_orders',
        where: 'holdOrderId = ?', whereArgs: [holdOrderId]);
  }

  /// Updates payment fields only (e.g. after Pay Now on Order History).
  Future<int> updatePaymentFields(
    String holdOrderId,
    String paymentStatus,
    String paymentMode,
  ) async {
    final db = await instance.database;
    return await db.update(
      'proceed_orders',
      {
        'paymentStatus': paymentStatus,
        'paymentMode': paymentMode,
      },
      where: 'holdOrderId = ?',
      whereArgs: [holdOrderId],
    );
  }
}
