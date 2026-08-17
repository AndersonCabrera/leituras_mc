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
      version: 2,
      onCreate: (banco, versao) async {
        await banco.execute(
          'CREATE TABLE fila ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'dados TEXT, '
          'em_processamento INTEGER DEFAULT 0, '
          'processado_em INTEGER'
          ')',
        );
      },
      onUpgrade: (banco, versaoAntiga, versaoNova) async {
        if (versaoAntiga < 2) {
          await banco.execute(
            'ALTER TABLE fila ADD COLUMN em_processamento INTEGER DEFAULT 0',
          );
          await banco.execute(
            'ALTER TABLE fila ADD COLUMN processado_em INTEGER',
          );
        }
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
      final agora = DateTime.now().millisecondsSinceEpoch;
      final limiteStale = agora - 10 * 60 * 1000;
      return await banco.query(
        'fila',
        where: 'em_processamento = 0 OR processado_em IS NULL OR processado_em < ?',
        whereArgs: [limiteStale],
        orderBy: 'id ASC',
      );
    }
  }

  /// Reivindica (atomico) um item para processamento. Retorna true se o item
  /// foi bloqueado por esta chamada (evita que sync manual e silenciosa
  /// processem o mesmo item em paralelo).
  static Future<bool> reivindicar(int id) async {
    if (kIsWeb) return true;
    final banco = await db;
    final agora = DateTime.now().millisecondsSinceEpoch;
    final result = await banco.rawUpdate(
      'UPDATE fila SET em_processamento = 1, processado_em = ? '
      'WHERE id = ? AND (em_processamento = 0 OR processado_em IS NULL OR processado_em < ?)',
      [agora, id, agora - 10 * 60 * 1000],
    );
    return result > 0;
  }

  /// Libera um item previamente reivindicado (falha: mantém na fila p/ retry).
  static Future<void> liberar(int id) async {
    if (kIsWeb) return;
    final banco = await db;
    await banco.rawUpdate(
      'UPDATE fila SET em_processamento = 0 WHERE id = ?',
      [id],
    );
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
