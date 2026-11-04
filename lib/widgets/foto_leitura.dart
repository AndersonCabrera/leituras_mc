import 'package:flutter/material.dart';
import '../services/foto_url_service.dart';

/// Miniatura quadrada da foto da leitura (resolve URL sob demanda).
class FotoLeituraThumbnail extends StatelessWidget {
  final Map<String, dynamic> dados;
  final double size;
  final VoidCallback? onTap;

  const FotoLeituraThumbnail({
    super.key,
    required this.dados,
    this.size = 90,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.antiAlias,
        child: FotoLeituraImagem(dados: dados, fit: BoxFit.cover),
      ),
    );
  }
}

/// Exibe a imagem da leitura resolvendo a URL sob demanda.
/// Mostra indicador de carregamento e ícone de erro caso falhe.
class FotoLeituraImagem extends StatelessWidget {
  final Map<String, dynamic> dados;
  final BoxFit fit;

  const FotoLeituraImagem({
    super.key,
    required this.dados,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: FotoUrlService.resolver(dados),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final url = snapshot.data;
        if (url == null) {
          return const Icon(Icons.hourglass_bottom_rounded, color: Colors.grey);
        }
        return Image.network(
          url,
          fit: fit,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image_rounded, color: Colors.grey),
        );
      },
    );
  }
}
