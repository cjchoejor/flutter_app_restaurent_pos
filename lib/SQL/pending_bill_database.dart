import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import 'package:pos_system_legphel/models/Bill/bill_summary_model.dart';
import 'package:pos_system_legphel/models/Bill/bill_details_model.dart';

class PendingBillDatabaseHelper {
  static final PendingBillDatabaseHelper instance =
      PendingBillDatabaseHelper._init();
  static Database? _database;

  PendingBillDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('pending_bills.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2, // INCREMENT VERSION
      onCreate: _createDB,
      onUpgrade: _onUpgrade, // ADD UPGRADE HANDLER
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_bill_summaries (
        fnb_bill_no TEXT PRIMARY KEY,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        room_no TEXT,
        reservation_ref_no TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_bill_details (
        id TEXT PRIMARY KEY,
        fnb_bill_no TEXT NOT NULL,
        data TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL,
        retry_count INTEGER DEFAULT 0,
        room_no TEXT,
        reservation_ref_no TEXT,
        FOREIGN KEY (fnb_bill_no) REFERENCES pending_bill_summaries (fnb_bill_no)
      )
    ''');
  }

  // ADD UPGRADE HANDLER
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
          'ALTER TABLE pending_bill_summaries ADD COLUMN room_no TEXT');
      await db.execute(
          'ALTER TABLE pending_bill_summaries ADD COLUMN reservation_ref_no TEXT');
      await db
          .execute('ALTER TABLE pending_bill_details ADD COLUMN room_no TEXT');
      await db.execute(
          'ALTER TABLE pending_bill_details ADD COLUMN reservation_ref_no TEXT');
    }
  }

  Future<void> insertPendingBill(
    BillSummaryModel summary,
    List<BillDetailsModel> details,
  ) async {
    final db = await database;
    final batch = db.batch();

    // Insert summary
    batch.insert('pending_bill_summaries', {
      'fnb_bill_no': summary.fnbBillNo,
      'data': jsonEncode(summary.toJson()),
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'sync_status': 'pending',
      'retry_count': 0,
      'room_no': summary.roomNo, // ADD THIS
      'reservation_ref_no': summary.reservationRefNo, // ADD THIS
    });

    // Insert details
    for (var detail in details) {
      batch.insert('pending_bill_details', {
        'id': detail.id,
        'fnb_bill_no': detail.fnbBillNo,
        'data': jsonEncode(detail.toJson()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'sync_status': 'pending',
        'retry_count': 0,
        'room_no': detail.roomNumber, // ADD THIS
        'reservation_ref_no': detail.reservationRefNo, // ADD THIS
      });
    }

    await batch.commit();
  }

  Future<List<Map<String, dynamic>>> getPendingBills() async {
    final db = await database;
    return await db.query(
      'pending_bill_summaries',
      where: 'sync_status = ?',
      whereArgs: ['pending'],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllBillSummaries() async {
    final db = await database;
    return await db.query(
      'pending_bill_summaries',
      orderBy: 'created_at DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingBillDetails(
      String fnbBillNo) async {
    final db = await database;
    return await db.query(
      'pending_bill_details',
      where: 'fnb_bill_no = ? AND sync_status = ?',
      whereArgs: [fnbBillNo, 'pending'],
    );
  }

  Future<void> updateSyncStatus(String fnbBillNo, String status) async {
    final db = await database;
    final batch = db.batch();

    batch.update(
      'pending_bill_summaries',
      {'sync_status': status},
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );

    batch.update(
      'pending_bill_details',
      {'sync_status': status},
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );

    await batch.commit();
  }

  Future<void> incrementRetryCount(String fnbBillNo) async {
    final db = await database;
    final batch = db.batch();

    batch.rawUpdate(
      'UPDATE pending_bill_summaries SET retry_count = retry_count + 1 WHERE fnb_bill_no = ?',
      [fnbBillNo],
    );

    batch.rawUpdate(
      'UPDATE pending_bill_details SET retry_count = retry_count + 1 WHERE fnb_bill_no = ?',
      [fnbBillNo],
    );

    await batch.commit();
  }

  Future<void> deleteSyncedBill(String fnbBillNo) async {
    final db = await database;
    final batch = db.batch();

    batch.delete(
      'pending_bill_details',
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );

    batch.delete(
      'pending_bill_summaries',
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );

    await batch.commit();
  }

  Future<void> updateBillSummaryData(
    String fnbBillNo,
    BillSummaryModel updatedSummary,
  ) async {
    final db = await database;
    
    await db.update(
      'pending_bill_summaries',
      {
        'data': jsonEncode(updatedSummary.toJson()),
        'sync_status': 'synced', // Mark as synced if successfully updated
      },
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );
  }

  Future<Map<String, dynamic>?> getBillSummaryData(String fnbBillNo) async {
    final db = await database;
    final results = await db.query(
      'pending_bill_summaries',
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
      limit: 1,
    );

    if (results.isEmpty) return null;
    
    final bill = results.first;
    final data = jsonDecode(bill['data'] as String) as Map<String, dynamic>;
    return data;
  }

  Future<void> updatePaymentStatus(
    String fnbBillNo,
    String paymentStatus,
    double amountSettled,
    String paymentMode,
  ) async {
    final db = await database;
    
    // Get current bill data
    final currentData = await getBillSummaryData(fnbBillNo);
    if (currentData == null) {
      throw Exception('Bill not found');
    }

    // Update payment fields in the JSON data
    currentData['payment_status'] = paymentStatus;
    currentData['amount_settled'] = amountSettled;
    currentData['payment_mode'] = paymentMode;
    if (paymentStatus == 'PAID') {
      currentData['amount_remaing'] = 0.0;
    }

    // Update the record
    await db.update(
      'pending_bill_summaries',
      {
        'data': jsonEncode(currentData),
        'sync_status': 'synced',
      },
      where: 'fnb_bill_no = ?',
      whereArgs: [fnbBillNo],
    );

    print('Updated payment status in local database for $fnbBillNo: $paymentStatus');
  }
}
