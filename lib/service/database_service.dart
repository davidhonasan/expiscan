import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:expiscan/constants/constants.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DatabaseEntry {
  int? id;
  String name;
  String picturePath;

  DatabaseEntry({this.id, required this.name, required this.picturePath});

  Map<String, dynamic> toMap() {
    return {columnId: id, columnName: name, columnPicturePath: picturePath};
  }

  @override
  String toString() {
    return json.encode(this.toMap());
  }

  fromMap(Map<String, dynamic> map) {
    this.id = map[columnId];
    this.name = map[columnName];
    this.picturePath = map[columnPicturePath];
  }
}

class Food extends DatabaseEntry {
  DateTime expiryDate;
  int isBestBefore;
  String note;
  int pantryId;

  Food(
      {id,
      name,
      picturePath,
      required this.expiryDate,
      required this.isBestBefore,
      required this.note,
      required this.pantryId})
      : super(id: id, name: name, picturePath: picturePath);

  @override
  Map<String, dynamic> toMap() {
    return {
      columnId: id,
      columnName: name,
      columnPicturePath: picturePath,
      columnExpiryDate: expiryDate.millisecondsSinceEpoch,
      columnIsBestBefore: isBestBefore,
      columnNote: note,
      columnPantryId: pantryId
    };
  }

  @override
  fromMap(Map<String, dynamic> map) {
    this.id = map[columnId];
    this.name = map[columnName];
    this.picturePath = map[columnPicturePath];
    this.expiryDate =
        DateTime.fromMillisecondsSinceEpoch(map[columnExpiryDate]);
    this.isBestBefore = map[columnIsBestBefore];
    this.note = map[columnNote];
    this.pantryId = map[columnPantryId];
  }
}

class Pantry extends DatabaseEntry {
  Pantry({id, name, picturePath})
      : super(id: id, name: name, picturePath: picturePath);

  @override
  Map<String, dynamic> toMap() {
    return {columnId: id, columnName: name, columnPicturePath: picturePath};
  }

  @override
  fromMap(Map<String, dynamic> map) {
    this.id = map[columnId];
    this.name = map[columnName];
    this.picturePath = map[columnPicturePath];
  }
}

class ExpiscanDB {
// Initialize DB (create (if don't exist) and open it)
  static Future<Database> initDB() async {
    // Open the database and store the reference.
    return openDatabase(
      // Set the path to the database. Note: Using the `join` function from the
      // `path` package is best practice to ensure the path is correctly
      // constructed for each platform.
      p.join(await getDatabasesPath(), 'expiscan.db'),
      onConfigure: (db) async {
        db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Run the CREATE TABLE statement on the database.
        var batch = db.batch();

        batch.execute(
          'CREATE TABLE $pantryTableName($columnId INTEGER PRIMARY KEY, $columnName TEXT, $columnPicturePath TEXT)',
        );
        batch.execute(
          'CREATE TABLE $foodTableName($columnId INTEGER PRIMARY KEY, $columnName TEXT, $columnPicturePath TEXT, $columnExpiryDate NUMERIC, $columnIsBestBefore NUMERIC, $columnNote TEXT, $columnPantryId INTEGER, FOREIGN KEY ($columnPantryId) REFERENCES $pantryTableName ($columnId))',
        );
        batch.insert(pantryTableName,
            Pantry(id: 1, name: 'Your Pantry', picturePath: '').toMap());

        await batch.commit();
      },
      // Set the version. This executes the onCreate function and provides a
      // path to perform database upgrades and downgrades.
      version: 1,
    );
  }

  static Future<int> addEntry(String table, DatabaseEntry entry) async {
    // Insert the Dog into the correct table. You might also specify the
    // `conflictAlgorithm` to use in case the same dog is inserted twice.
    //
    // In this case, replace any previous data.

    if (entry.picturePath.isNotEmpty) {
      entry.picturePath = await addPicture(entry.picturePath);
    }

    final Database db = await initDB();
    return await db.insert(
      table,
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<dynamic>> getEntries(String table, [int? id]) async {
    final Database db = await initDB();
    late List<Map<String, dynamic>> maps;

    if (id == null) {
      maps = await db.query(table);
    } else {
      maps =
          await db.query(table, where: '$columnPantryId = ?', whereArgs: [id]);
    }

    if (table == 'Food') {
      return List.generate(maps.length, (i) {
        return Food(
            id: maps[i][columnId],
            name: maps[i][columnName],
            picturePath: maps[i][columnPicturePath],
            expiryDate:
                DateTime.fromMillisecondsSinceEpoch(maps[i][columnExpiryDate]),
            isBestBefore: maps[i][columnIsBestBefore],
            note: maps[i][columnNote],
            pantryId: maps[i][columnPantryId]);
      });
    } else {
      return List.generate(maps.length, (i) {
        return Pantry(
            id: maps[i][columnId],
            name: maps[i][columnName],
            picturePath: maps[i][columnPicturePath]);
      });
    }
  }

  static Future<dynamic> getEntryFromId(String tableName, int id) async {
    final Database db = await initDB();

    // Get the first one from entry
    final Map<String, dynamic> map =
        (await db.query(tableName, where: '$columnId = ?', whereArgs: [id]))
            .first;

    if (tableName == 'Food') {
      return Food(
          id: map[columnId],
          name: map[columnName],
          picturePath: map[columnPicturePath],
          expiryDate:
              DateTime.fromMillisecondsSinceEpoch(map[columnExpiryDate]),
          isBestBefore: map[columnIsBestBefore],
          note: map[columnNote],
          pantryId: map[columnPantryId]);
    } else {
      return Pantry(
          id: map[columnId],
          name: map[columnName],
          picturePath: map[columnPicturePath]);
    }
  }

  static Future<int> deleteEntry(String table, DatabaseEntry entry) async {
    await deletePicture(entry.picturePath);

    final Database db = await initDB();

    return await db
        .delete(table, where: '$columnId = ?', whereArgs: [entry.id]);
  }

  static Future<int> updateEntry(String table, DatabaseEntry entry) async {
    final oldPicturePath = (await getEntryFromId(table, entry.id!)).picturePath;
    final tmpPicturePath = entry.picturePath;

    if (oldPicturePath != tmpPicturePath) {
      await deletePicture(oldPicturePath);

      if (entry.picturePath.isNotEmpty) {
        entry.picturePath = await addPicture(tmpPicturePath);
      }
    }

    final Database db = await initDB();

    return await db.update(table, entry.toMap(),
        where: '$columnId = ?', whereArgs: [entry.id]);
  }

  static Future<String> addPicture(String entryPicPath) async {
    if (entryPicPath.contains(RegExp(r'^(https?)'))) return entryPicPath;
    final String path = (await getApplicationDocumentsDirectory()).path;
    final String fileName = p.basename(entryPicPath);
    final String movedImagePath =
        (await File(entryPicPath).copy('$path/$fileName')).path;

    return movedImagePath;
  }

  static Future<void> deletePicture(String entryPicPath) async {
    if (entryPicPath.isNotEmpty) {
      try {
        if (await File(entryPicPath).exists())
          await File(entryPicPath).delete();
      } catch (e) {}
    }
  }
}

String? checkEmpty(String? value) {
  if (value == null || value.isEmpty || value.trim() == '') {
    return 'This field is required.';
  }
  return null;
}

// Future<void> printDogs() async {
//   print('printing dogs');
//   final doggolist = await getPantryList();
//   print(json.encode(doggolist[0].toMap()));
//   print(doggolist[0].name);
//   print(doggolist.toString());
//   print('done');
// }
