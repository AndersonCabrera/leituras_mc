import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:io' as io;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import '../../services/upload_foto_service.dart';

class TelaFotosPendentes extends StatefulWidget {
  final String idAdministradora;
  const TelaFotosPendentes({super.key, required this.idAdministradora});

  @override
  State<TelaFotosPendentes> createState() => _TelaFotosPendentesState();
}

class _TelaFotosPendentesState extends State<TelaFotosPendentes> {
  Set<String> _retryEmAndamento = {};

  Future<void> _retryFoto(String docId, Map<String, dynamic> dados) async {
    if (_retryEmAndamento.contains(docId)) return;

    setState(() => _retryEmAndamento.add(docId));

    try {
      String? urlFotoFirebase;
      String? fotoKey;
      String? caminhoLocal = dados['caminho_foto_local'];
      String erroMsg = '';

      if (caminhoLocal != null && caminhoLocal.isNotEmpty) {
        const int maxTentativas = 3;
        int tentativa = 0;

while (tentativa < maxTentativas && urlFotoFirebase == null) {
          try {
            // Force token refresh before long upload
            await FirebaseAuth.instance.currentUser?.getIdToken(true);
            if (!caminhoLocal.startsWith('base64:')) {
              io.File arquivoLocal = io.File(caminhoLocal);
              if (await arquivoLocal.exists()) {
                final ref = FirebaseStorage.instance.ref().child(
                  'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
                );
                await ref
                    .putFile(
                      arquivoLocal,
                      SettableMetadata(contentType: 'image/jpeg'),
                    )
                    .timeout(const Duration(seconds: 120));
                urlFotoFirebase = await ref.getDownloadURL();
              } else {
                erroMsg = 'Arquivo local não encontrado no dispositivo';
                break;
              }
            } else {
              final base64Str = caminhoLocal.replaceAll('base64:', '');
              final timestamp = DateTime.now().millisecondsSinceEpoch;
              final fileName = 'foto_$timestamp.jpg';
              debugPrint('🔍 [RETRY] Upload via Vercel: $fileName (${base64Str.length} chars)');
              final resultado = await UploadFotoService.uploadBase64(
                base64: base64Str,
                fileName: fileName,
              );
              urlFotoFirebase = resultado?.downloadUrl;
              fotoKey = resultado?.fileKey;
              debugPrint('✅ [RETRY] Upload OK: $urlFotoFirebase');
            }
          } on FirebaseException catch (e) {
            erroMsg = '[${e.code}] ${e.message}';
            tentativa++;
            if (tentativa < maxTentativas) {
              final delay = Duration(seconds: (pow(2, tentativa) * 3 + Random().nextInt(5)).toInt());
              await Future.delayed(delay);
            }
          } catch (e) {
            erroMsg = e.toString();
            tentativa++;
            if (tentativa < maxTentativas) {
              final delay = Duration(seconds: (pow(2, tentativa) * 3 + Random().nextInt(5)).toInt());
              await Future.delayed(delay);
            }
          }
        }
          } else {
            erroMsg = 'Caminho da foto não disponível (não salva localmente)';
          }

      if (urlFotoFirebase != null) {
        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(docId)
            .update({
          'url_foto': urlFotoFirebase,
          if (fotoKey != null) 'foto_key': fotoKey,
          'erro_sincronizacao_foto': false,
          'mensagem_erro': FieldValue.delete(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Foto reenviada com sucesso: $docId'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(docId)
            .update({
          'erro_sincronizacao_foto': true,
          'mensagem_erro': 'Retry falhou: $erroMsg',
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Falha no reenvio: $erroMsg'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erro: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _retryEmAndamento.remove(docId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fotos Pendentes de Sincronização',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.orange.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leituras')
            .where('id_administradora', isEqualTo: widget.idAdministradora)
            .where('tem_foto_anexada', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma leitura com foto encontrada.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Filtrar: fotos com erro OU sem url_foto (nem foto_key)
          var fotosComProblema = snapshot.data!.docs.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            bool temErro = dados['erro_sincronizacao_foto'] == true;
            bool semUrl = (dados['url_foto'] == null || dados['url_foto'] == '') &&
                (dados['foto_key'] == null || dados['foto_key'] == '');
            return temErro || semUrl;
          }).toList();

          if (fotosComProblema.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 80, color: Colors.green.shade300),
                  const SizedBox(height: 16),
                  const Text(
                    'Todas as fotos estão sincronizadas!',
                    style: TextStyle(fontSize: 18, color: Colors.green),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade50,
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.orange.shade800),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${fotosComProblema.length} foto(s) ainda não sincronizada(s) no servidor.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: fotosComProblema.length,
                  itemBuilder: (context, index) {
                    var doc = fotosComProblema[index];
                    var dados = doc.data() as Map<String, dynamic>;
                    return _cardFoto(doc.id, dados);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _cardFoto(String docId, Map<String, dynamic> dados) {
    String condominio = dados['condominio'] ?? '-';
    String apartamento = dados['apartamento'] ?? '-';
    String medidor = dados['medidor'] ?? '-';
    bool temErro = dados['erro_sincronizacao_foto'] == true;
    String mensagemErro = dados['mensagem_erro'] ?? 'Foto ainda não enviada';
    bool emRetry = _retryEmAndamento.contains(docId);

    DateTime? data;
    if (dados['data_hora'] != null) {
      data = (dados['data_hora'] as Timestamp).toDate();
    }
    String dataStr = data != null
        ? '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}'
        : '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  temErro ? Icons.error_outline : Icons.hourglass_bottom_rounded,
                  color: temErro ? Colors.red.shade700 : Colors.orange.shade700,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '$condominio - Apto $apartamento',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (!emRetry)
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.blue, size: 22),
                    tooltip: 'Tentar reenviar',
                    onPressed: () => _retryFoto(docId, dados),
                  )
                else
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const Divider(height: 16),
            _linha('Medidor', medidor),
            _linha('Data da Leitura', dataStr),
            _linha('ID do Documento', docId, cor: Colors.grey.shade500),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: temErro ? Colors.red.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    temErro ? Icons.error : Icons.info_outline,
                    size: 16,
                    color: temErro ? Colors.red.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mensagemErro,
                      style: TextStyle(
                        fontSize: 12,
                        color: temErro ? Colors.red.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linha(String label, String valor, {Color? cor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontSize: 12, color: cor ?? Colors.black87, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}