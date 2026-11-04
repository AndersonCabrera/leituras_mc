import 'dart:developer';
import 'upload_foto_service.dart';

class _CacheUrl {
  final String url;
  final DateTime validoAte;

  const _CacheUrl(this.url, this.validoAte);
}

/// Resolve a URL de exibição de uma foto de leitura.
///
/// - Se o documento tem `foto_key` (upload via B2), usa a URL assinada
///   enquanto ela ainda estiver válida; perto do vencimento (ou expirada),
///   gera uma URL nova sob demanda (válida por 7 dias).
/// - Cache em memória por 5 dias evita chamadas repetidas na mesma sessão.
/// - Sem `foto_key`, usa `url_foto` direto (Firebase Storage / legado).
class FotoUrlService {
  static final Map<String, _CacheUrl> _cache = {};
  static const Duration _validadeCache = Duration(days: 5);
  static const Duration _margemRenovacao = Duration(hours: 24);

  static Future<String?> resolver(Map<String, dynamic> dados) async {
    String fileKey = (dados['foto_key'] ?? '').toString().trim();
    final urlSalva = (dados['url_foto'] ?? '').toString();

    // Documentos antigos (antes do campo foto_key): extrai a chave da URL do B2
    if (fileKey.isEmpty && urlSalva.isNotEmpty) {
      fileKey = _extrairKeyDeUrl(urlSalva);
    }

    if (fileKey.isEmpty) {
      return urlSalva.isEmpty ? null : urlSalva;
    }

    final agora = DateTime.now();

    // 1) Cache em memória da sessão
    final cacheado = _cache[fileKey];
    if (cacheado != null && agora.isBefore(cacheado.validoAte)) {
      return cacheado.url;
    }

    // 2) URL salva no documento ainda é utilizável? (evita chamada ao servidor)
    if (urlSalva.isNotEmpty && _aindaValida(urlSalva, agora)) {
      _cache[fileKey] = _CacheUrl(urlSalva, agora.add(_validadeCache));
      return urlSalva;
    }

    // 3) Gera URL nova no servidor
    try {
      final url = await UploadFotoService.buscarUrlFoto(fileKey);
      if (url != null && url.isNotEmpty) {
        _cache[fileKey] = _CacheUrl(url, agora.add(_validadeCache));
        return url;
      }
    } catch (e) {
      log('🔴 [FOTO RESOLVER] $e');
    }

    // 4) Fallback: tenta a URL antiga mesmo perto do vencimento
    return urlSalva.isEmpty ? null : urlSalva;
  }

  /// Resolve várias fotos com concorrência limitada (para relatórios).
  static Future<List<String?>> resolverEmLote(
    List<Map<String, dynamic>> lista, {
    int paralelismo = 8,
  }) async {
    final resultados = List<String?>.filled(lista.length, null);
    var proximo = 0;

    Future<void> trabalhador() async {
      while (true) {
        final i = proximo++;
        if (i >= lista.length) return;
        resultados[i] = await resolver(lista[i]);
      }
    }

    await Future.wait(
      List.generate(
        paralelismo < lista.length ? paralelismo : lista.length,
        (_) => trabalhador(),
      ),
    );
    return resultados;
  }

  /// Indica se o documento tem foto disponível (chave B2 ou URL salva).
  static bool temFoto(Map<String, dynamic> dados) {
    final fileKey = (dados['foto_key'] ?? '').toString().trim();
    if (fileKey.isNotEmpty) return true;
    final url = dados['url_foto'];
    return url != null && url.toString().isNotEmpty;
  }

  /// Verifica se uma URL assinada S3/B2 continua válida por mais de
  /// [_margemRenovacao]. URLs sem parâmetros de assinatura (ex.: Firebase
  /// Storage) são consideradas permanentes.
  static bool _aindaValida(String url, DateTime agora) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final dataStr = uri.queryParameters['X-Amz-Date'];
    final expiraStr = uri.queryParameters['X-Amz-Expires'];

    // URL não assinada (Firebase Storage etc.) -> não expira
    if (dataStr == null || expiraStr == null) return true;

    final expiraSegundos = int.tryParse(expiraStr);
    final inicio = _parseAmzDate(dataStr);
    if (expiraSegundos == null || inicio == null) return false;

    final validoAte = inicio.add(Duration(seconds: expiraSegundos));
    return agora.toUtc().isBefore(validoAte.subtract(_margemRenovacao));
  }

  /// Extrai a chave do objeto B2 de uma URL assinada salva (formatos
  /// path-style e virtual-hosted). Retorna string vazia se não for B2.
  static String _extrairKeyDeUrl(String url) {
    final idx = url.indexOf('comprovantes/');
    if (idx < 0) return '';
    final chave = url.substring(idx).split('?').first;
    return RegExp(r'^comprovantes/[A-Za-z0-9._-]+\.jpg$').hasMatch(chave)
        ? chave
        : '';
  }

  /// Converte o formato de data do S3 (ex.: 20261103T120000Z) em DateTime.
  static DateTime? _parseAmzDate(String s) {
    if (s.length < 16) return null;
    try {
      return DateTime.utc(
        int.parse(s.substring(0, 4)),
        int.parse(s.substring(4, 6)),
        int.parse(s.substring(6, 8)),
        int.parse(s.substring(9, 11)),
        int.parse(s.substring(11, 13)),
        int.parse(s.substring(13, 15)),
      );
    } catch (_) {
      return null;
    }
  }
}
