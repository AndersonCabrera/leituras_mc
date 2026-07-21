import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class BancoLocal {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    if (kIsWeb) throw Exception("Sqflite não roda na Web.");
    String caminho = p.join(await getDatabasesPath(), 'fila_leituras_mc.db');
    _db = await openDatabase(
      caminho,
      version: 1,
      onCreate: (banco, versao) async {
        await banco.execute(
          'CREATE TABLE fila (id INTEGER PRIMARY KEY AUTOINCREMENT, dados TEXT)',
        );
      },
    );
    return _db!;
  }

  static Future<void> salvar(String jsonStr) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final fila = prefs.getStringList('fila_leituras') ?? [];
      fila.add(jsonStr);
      await prefs.setStringList('fila_leituras', fila);
    } else {
      final banco = await db;
      await banco.insert('fila', {'dados': jsonStr});
    }
  }

  static Future<List<Map<String, dynamic>>> lerFila() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final fila = prefs.getStringList('fila_leituras') ?? [];
      return List.generate(fila.length, (i) => {'id': i, 'dados': fila[i]});
    } else {
      final banco = await db;
      return await banco.query('fila', orderBy: 'id ASC');
    }
  }

  static Future<void> remover(int id, String dadosJson) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      List<String> fila = prefs.getStringList('fila_leituras') ?? [];
      fila.remove(dadosJson);
      await prefs.setStringList('fila_leituras', fila);
    } else {
      final banco = await db;
      await banco.delete('fila', where: 'id = ?', whereArgs: [id]);
    }
  }
}
