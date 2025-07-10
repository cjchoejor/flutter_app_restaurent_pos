import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:pos_system_legphel/models/others/room_no_model.dart';

class RoomDatabaseHelper {
  static final RoomDatabaseHelper instance = RoomDatabaseHelper._init();
  static Database? _database;

  RoomDatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('rooms.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE rooms (
        roomNumber TEXT PRIMARY KEY,
        roomType TEXT
      )
    ''');
  }

  // Insert a new room
  Future<void> insertRoom(RoomNoModel room) async {
    final db = await instance.database;
    await db.insert(
      'rooms',
      room.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Fetch all rooms
  Future<List<RoomNoModel>> fetchRooms() async {
    final db = await instance.database;
    final maps = await db.query('rooms');

    return List.generate(maps.length, (i) {
      return RoomNoModel.fromMap(maps[i]);
    });
  }

  // Update a room
  Future<void> updateRoom(RoomNoModel room) async {
    final db = await instance.database;
    await db.update(
      'rooms',
      room.toMap(),
      where: 'roomNumber = ?',
      whereArgs: [room.roomNumber],
    );
  }

  // Delete a room
  Future<void> deleteRoom(String roomNumber) async {
    final db = await instance.database;
    await db.delete(
      'rooms',
      where: 'roomNumber = ?',
      whereArgs: [roomNumber],
    );
  }

  // Close the database
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
