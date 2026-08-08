import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import '../../services/banco_local.dart';

class TelaSincronizacao extends StatefulWidget {
  const TelaSincronizacao({super.key});

  @override
  State<TelaSincronizacao> createState() => _TelaSincronizacaoState();
}

class _TelaSincronizacaoState extends State<TelaSincronizacao> {
  List<Map<String, dynamic>> filaDeLeituras = [];
  bool sincronizando = false;
  int totalParaSincronizar = 0;
  int _currentIndex = 0;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  Future<void> _carregarFila() async {
    final fila = await BancoLocal.lerFila();
    setState(() {
      filaDeLeituras = fila;
      totalParaSincronizar = filaDeLeituras.length;
    });
  }

  Future<void> _enviarParaNuvem() async {
    if (filaDeLeituras.isEmpty) return;

    final itensParaEnviar = List<Map<String, dynamic>>.from(filaDeLeituras);

    setState(() {
      sincronizando = true;
      _currentIndex = 0;
    });

    int sucessoCount = 0;
    int falhaCount = 0;

    for (var linha in itensParaEnviar) {
      if (!mounted) return;

      try {
        int idLocal = linha['id'];
        String itemJson = linha['dados'];
        Map<String, dynamic> dados = jsonDecode(itemJson);
        String? urlFotoFirebase;
        String? caminhoLocal = dados['caminho_foto_local'];
        bool temFoto = caminhoLocal != null && caminhoLocal.isNotEmpty;

        setState(() {
          _currentIndex++;
          _statusMessage = temFoto 
              ? 'Enviando $_currentIndex de ${itensParaEnviar.length} (com foto)...'
              : 'Enviando $_currentIndex de ${itensParaEnviar.length}...';
        });

        if (caminhoLocal != null && !caminhoLocal.startsWith('base64:')) {
          io.File arquivoLocal = io.File(caminhoLocal);
          if (await arquivoLocal.exists()) {
            int tentativas = 0;
            const int maxTentativas = 3;
            while (tentativas < maxTentativas && urlFotoFirebase == null) {
              try {
                final ref = FirebaseStorage.instance.ref().child(
                  'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await ref.putFile(
                  arquivoLocal,
                  SettableMetadata(contentType: 'image/jpeg'),
                ).timeout(const Duration(seconds: 60));
                urlFotoFirebase = await ref.getDownloadURL();
                await arquivoLocal.delete();
              } catch (e) {
                tentativas++;
                debugPrint("Falha no upload da foto (tentativa $tentativas/$maxTentativas): $e");
                if (tentativas < maxTentativas) {
                  await Future.delayed(Duration(seconds: tentativas * 2));
                }
              }
            }
          } else {
            debugPrint("Arquivo de foto não encontrado: $caminhoLocal");
          }
        } else if (caminhoLocal != null && caminhoLocal.startsWith('base64:')) {
          int tentativas = 0;
          const int maxTentativas = 3;
          while (tentativas < maxTentativas && urlFotoFirebase == null) {
            try {
              final Uint8List imageBytes = base64Decode(
                caminhoLocal.replaceAll('base64:', ''),
              );
              final ref = FirebaseStorage.instance.ref().child(
                'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
              final tarefa = await ref.putData(
                imageBytes,
                SettableMetadata(contentType: 'image/jpeg'),
              ).timeout(const Duration(seconds: 60));
              urlFotoFirebase = await tarefa.ref.getDownloadURL();
            } catch (e) {
              tentativas++;
              debugPrint("Falha no upload da foto (base64, tentativa $tentativas/$maxTentativas): $e");
              if (tentativas < maxTentativas) {
                await Future.delayed(Duration(seconds: tentativas * 2));
              }
            }
          }
        }

        DateTime dataLeitura;
        try {
          dataLeitura = DateTime.parse(dados['data_hora_string']);
        } catch (_) {
          dataLeitura = DateTime.now();
        }

        String mesAno = "${dataLeitura.month}_${dataLeitura.year}";
        String idUnicoDoc =
            "${dados['condominio']}_${dados['apartamento']}_${dados['medidor']}_$mesAno"
                .replaceAll(' ', '_')
                .toLowerCase();

        Map<String, dynamic> pacoteParaNuvem = {
          'condominio': dados['condominio'],
          'apartamento': dados['apartamento'] ?? 'Geral',
          'medidor': dados['medidor'],
          'leitura_anterior': dados['leitura_anterior'],
          'leitura_atual': dados['leitura_atual'],
          'consumo': dados['consumo'],
          'teve_consumo': dados['teve_consumo'],
          'tem_foto_anexada': dados['tem_foto_anexada'],
          'correcao_manual': dados['correcao_manual'] ?? false,
          'data_hora': Timestamp.fromDate(dataLeitura),
        };

        if (urlFotoFirebase != null) {
          pacoteParaNuvem['url_foto'] = urlFotoFirebase;
        }

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacoteParaNuvem, SetOptions(merge: true));

        await BancoLocal.remover(idLocal, itemJson);
        sucessoCount++;
      } catch (e) {
        debugPrint("Falha ao sincronizar item: $e");
        falhaCount++;
      }
    }

    await _carregarFila();
    if (mounted) {
      setState(() {
        sincronizando = false;
      });

      if (filaDeLeituras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Concluído! $sucessoCount leitura(s) enviada(s) com sucesso.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$sucessoCount enviada(s), $falhaCount falharam. '
              '${filaDeLeituras.length} na fila.',
            ),
            backgroundColor: falhaCount > 0 ? Colors.orange : Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sincronização',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                totalParaSincronizar == 0
                    ? Icons.cloud_done
                    : Icons.cloud_upload,
                size: 100,
                color: totalParaSincronizar == 0
                    ? Colors.green
                    : Colors.blue.shade800,
              ),
              const SizedBox(height: 20),
              Text(
                totalParaSincronizar == 0
                    ? 'Tudo Sincronizado!'
                    : 'Leituras Pendentes',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Tem $totalParaSincronizar leituras prontas para enviar.',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              if (sincronizando) ...[
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    children: [
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: totalParaSincronizar > 0
                            ? _currentIndex / totalParaSincronizar
                            : 0,
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ],
                  ),
                ),
              ] else if (totalParaSincronizar > 0)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.sync, color: Colors.white),
                    label: Text(
                      'Sincronizar $totalParaSincronizar Leitura(s)',
                      style: const TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade800,
                    ),
                    onPressed: _enviarParaNuvem,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
