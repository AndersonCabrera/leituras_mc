import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';
import 'dart:math';
import '../../services/banco_local.dart';

class TelaSincronizacao extends StatefulWidget {
  final String idAdministradora;
  const TelaSincronizacao({super.key, required this.idAdministradora});

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
        // Lock atômico no SQLite: evita que a sync silenciosa processe o
        // mesmo item ao mesmo tempo. Se outro processo já o reivindicou, pula.
        if (!await BancoLocal.reivindicar(idLocal)) continue;
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
            String ultimoErro = '';
            while (tentativas < maxTentativas && urlFotoFirebase == null) {
              try {
                // Force token refresh before long upload
                await FirebaseAuth.instance.currentUser?.getIdToken(true);
                final ref = FirebaseStorage.instance.ref().child(
                  'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await ref.putFile(
                  arquivoLocal,
                  SettableMetadata(contentType: 'image/jpeg'),
                ).timeout(const Duration(seconds: 120));
                urlFotoFirebase = await ref.getDownloadURL();
                await arquivoLocal.delete();
              } on FirebaseException catch (e) {
                ultimoErro = '[${e.code}] ${e.message}';
                tentativas++;
                debugPrint("Falha no upload da foto (tentativa $tentativas/$maxTentativas): $ultimoErro");
                if (tentativas < maxTentativas) {
                  final delay = Duration(seconds: (pow(2, tentativas) * 3 + Random().nextInt(5)).toInt());
                  await Future.delayed(delay);
                }
              } catch (e) {
                ultimoErro = e.toString();
                tentativas++;
                debugPrint("Falha no upload da foto (tentativa $tentativas/$maxTentativas): $ultimoErro");
                if (tentativas < maxTentativas) {
                  final delay = Duration(seconds: (pow(2, tentativas) * 3 + Random().nextInt(5)).toInt());
                  await Future.delayed(delay);
                }
              }
            }
            if (urlFotoFirebase == null) {
              dados['_erro_upload_foto'] = 'Todas as $maxTentativas tentativas falharam: $ultimoErro';
            }
          } else {
            debugPrint("Arquivo de foto não encontrado: $caminhoLocal");
            dados['_erro_upload_foto'] = 'Arquivo local não encontrado (pode ter sido deletado pelo SO)';
          }
} else if (caminhoLocal != null && caminhoLocal.startsWith('base64:')) {
          int tentativas = 0;
          const int maxTentativas = 3;
          String ultimoErro = '';

          // Verificar auth state antes de tentar
          final user = FirebaseAuth.instance.currentUser;
          debugPrint('🔍 [SYNC] User: ${user?.uid}, Email: ${user?.email}');
          if (user == null) {
            debugPrint('🔴 [SYNC] ERRO: Usuário não autenticado!');
            dados['_erro_upload_foto'] = 'Usuário não autenticado';
          } else {
            while (tentativas < maxTentativas && urlFotoFirebase == null) {
              try {
                // Force token refresh before long upload
                debugPrint('🔍 [SYNC] Refreshing auth token...');
                final token = await user.getIdToken(true);
                debugPrint('🔍 [SYNC] Token refreshed: ${token != null ? "OK" : "NULL"}');

                final base64Str = caminhoLocal.replaceAll('base64:', '');
                debugPrint('🔍 [SYNC] Base64 length: ${base64Str.length}');
                final Uint8List imageBytes = base64Decode(base64Str);
                debugPrint('🔍 [SYNC] Decoded bytes length: ${imageBytes.length} (${(imageBytes.length / 1024).toStringAsFixed(1)} KB)');

                if (imageBytes.length > 10 * 1024 * 1024) {
                  throw Exception('Imagem muito grande: ${imageBytes.length} bytes (max 10MB)');
                }

                final timestamp = DateTime.now().millisecondsSinceEpoch;
                final fileName = 'foto_$timestamp.jpg';
                debugPrint('🔍 [SYNC] Uploading file: $fileName');
                final ref = FirebaseStorage.instance.ref().child('comprovantes/$fileName');
                debugPrint('🔍 [SYNC] Ref path: ${ref.fullPath}');
                debugPrint('🔍 [SYNC] Starting putData...');
                final tarefa = await ref.putData(
                  imageBytes,
                  SettableMetadata(contentType: 'image/jpeg'),
                ).timeout(const Duration(seconds: 120));
                debugPrint('🔍 [SYNC] Upload complete, state: ${tarefa.state}, getting download URL...');
                urlFotoFirebase = await tarefa.ref.getDownloadURL();
                debugPrint('🔍 [SYNC] Download URL: $urlFotoFirebase');
              } on FirebaseException catch (e) {
                ultimoErro = '[${e.code}] ${e.message}';
                tentativas++;
                debugPrint("🔴 [SYNC] FirebaseException (base64, tentativa $tentativas/$maxTentativas): $ultimoErro");
                if (tentativas < maxTentativas) {
                  final delay = Duration(seconds: (pow(2, tentativas) * 3 + Random().nextInt(5)).toInt());
                  await Future.delayed(delay);
                }
              } catch (e) {
                ultimoErro = e.toString();
                tentativas++;
                debugPrint("🔴 [SYNC] Generic Exception (base64, tentativa $tentativas/$maxTentativas): $ultimoErro");
                if (tentativas < maxTentativas) {
                  final delay = Duration(seconds: (pow(2, tentativas) * 3 + Random().nextInt(5)).toInt());
                  await Future.delayed(delay);
                }
              }
            }
          }
          if (urlFotoFirebase == null) {
            dados['_erro_upload_foto'] = 'Todas as $maxTentativas tentativas falharam (base64): $ultimoErro';
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
          'id_administradora': widget.idAdministradora,
          'status_auditoria': 'pendente',
        };

        if (urlFotoFirebase != null) {
          pacoteParaNuvem['url_foto'] = urlFotoFirebase;
        } else if (dados['tem_foto_anexada'] == true) {
          pacoteParaNuvem['erro_sincronizacao_foto'] = true;
          pacoteParaNuvem['mensagem_erro'] = dados['_erro_upload_foto'] ?? 'Foto nao sincronizada - reenvio pendente';
        }

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacoteParaNuvem, SetOptions(merge: true))
            .timeout(const Duration(seconds: 30));

        // Só remover da fila se: (não tem foto) OU (foto enviada com sucesso)
        bool fotoEnviada = urlFotoFirebase != null;
        bool temFotoAnexada = dados['tem_foto_anexada'] == true;
        bool deveRemover = !temFotoAnexada || fotoEnviada;

        if (deveRemover) {
          await BancoLocal.remover(idLocal, itemJson);
          sucessoCount++;
        } else {
          debugPrint("Foto não enviada - mantendo item na fila para retry");
          await BancoLocal.liberar(idLocal);
          falhaCount++;
        }
      } catch (e) {
        debugPrint("Falha ao sincronizar item: $e");
        if (linha['id'] != null) {
          await BancoLocal.liberar(linha['id'] as int);
        }
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
