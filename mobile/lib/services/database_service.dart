import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/schedule.dart';

/// Thin SQLite wrapper for schedule persistence.
///
/// Call [init] once at app startup (before using any other methods).
class DatabaseService {
  static const _dbName = 'ocen.db';
  static const _version = 1;
  static const _table = 'schedules';

  Database? _db;

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  Future<void> init() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);

    _db = await openDatabase(
      path,
      version: _version,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id          TEXT PRIMARY KEY,
            title       TEXT NOT NULL,
            start_time  TEXT NOT NULL,
            end_time    TEXT NOT NULL,
            location    TEXT NOT NULL DEFAULT '',
            notes       TEXT,
            is_work     INTEGER NOT NULL DEFAULT 0,
            needs_travel INTEGER NOT NULL DEFAULT 0,
            travel_mode TEXT,
            travel_minutes INTEGER
          )
        ''');
      },
    );
  }

  Database get _database {
    assert(_db != null, 'DatabaseService.init() must be called first');
    return _db!;
  }

  // ─── Read ────────────────────────────────────────────────────────────────────

  Future<List<Schedule>> getAllSchedules() async {
    final rows = await _database.query(_table, orderBy: 'start_time ASC');
    return rows.map(_fromRow).toList();
  }

  // ─── Write ───────────────────────────────────────────────────────────────────

  Future<void> insertSchedule(Schedule s) async {
    await _database.insert(
      _table,
      _toRow(s),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAll(List<Schedule> schedules) async {
    final batch = _database.batch();
    for (final s in schedules) {
      batch.insert(_table, _toRow(s),
          conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteSchedule(String id) async {
    await _database.delete(_table, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSchedule(Schedule s) async {
    await _database.update(
      _table,
      _toRow(s),
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  Map<String, dynamic> _toRow(Schedule s) => {
        'id': s.id,
        'title': s.title,
        'start_time': s.startTime.toIso8601String(),
        'end_time': s.endTime.toIso8601String(),
        'location': s.location,
        'notes': s.notes,
        'is_work': s.isWork ? 1 : 0,
        'needs_travel': s.needsTravel ? 1 : 0,
        'travel_mode': s.travelMode,
        'travel_minutes': s.travelMinutes,
      };

  Schedule _fromRow(Map<String, dynamic> row) => Schedule(
        id: row['id'] as String,
        title: row['title'] as String,
        startTime: DateTime.parse(row['start_time'] as String),
        endTime: DateTime.parse(row['end_time'] as String),
        location: (row['location'] as String?) ?? '',
        notes: row['notes'] as String?,
        isWork: (row['is_work'] as int) == 1,
        needsTravel: (row['needs_travel'] as int) == 1,
        travelMode: row['travel_mode'] as String?,
        travelMinutes: row['travel_minutes'] as int?,
      );
}
