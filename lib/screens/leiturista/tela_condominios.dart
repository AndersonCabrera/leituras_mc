import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import '../../services/banco_local.dart';
import 'tela_sincronizacao.dart';
import 'tela_leitura_page_view.dart';
import '../auth/tela_login.dart';
import '../../core/theme.dart'; // 💡 IMPORTAÇÃO DO TEMA

class TelaCondominios extends StatefulWidget {
  final String idAdministradora;
  const TelaCondominios({super.key, required this.idAdministradora});

  @override
  State<TelaCondominios> createState() => _TelaCondominiosState();
}

class _TelaCondominiosState extends State<TelaCondominios>
    with TickerProviderStateMixin {
  Timer? _timerSync;
  bool _sincronizandoAgora = false;
  int _totalPendentes = 0;
  bool _isOnline = true;

  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  static const Color _azulPrimario = Color(0xFF0D47A1);
  static const Color _azulEscuro = Color(0xFF1A237E);

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();

    _carregarPendentes();
    _sincronizarSilenciosamente();

    _timerSync = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sincronizarSilenciosamente(),
    );
  }

  @override
  void dispose() {
    _timerSync?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarPendentes() async {
    final fila = await BancoLocal.lerFila();
    if (mounted) setState(() => _totalPendentes = fila.length);
  }

  Future<void> _sincronizarSilenciosamente() async {
    if (_sincronizandoAgora) return;

    final fila = await BancoLocal.lerFila();
    if (mounted) setState(() => _totalPendentes = fila.length);
    if (fila.isEmpty) return;

    setState(() => _sincronizandoAgora = true);
    int sucessoCount = 0;
    String? ultimoErro;

    for (var linha in fila) {
      int idLocal = linha['id'];
      String itemJson = linha['dados'];
      Map<String, dynamic> dados = jsonDecode(itemJson);

      try {
        String? urlFotoFirebase;
        String? caminhoLocal = dados['caminho_foto_local'];
        bool falhaNoUploadDaFoto = false;

        if (caminhoLocal != null) {
          try {
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
                    .timeout(const Duration(seconds: 15));

                urlFotoFirebase = await ref.getDownloadURL();
                await arquivoLocal.delete();
              }
            } else {
              final Uint8List imageBytes = base64Decode(
                caminhoLocal.replaceAll('base64:', ''),
              );
              final ref = FirebaseStorage.instance.ref().child(
                'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
              );
              final tarefa = await ref
                  .putData(
                    imageBytes,
                    SettableMetadata(contentType: 'image/jpeg'),
                  )
                  .timeout(const Duration(seconds: 15));

              urlFotoFirebase = await tarefa.ref.getDownloadURL();
            }
          } catch (fotoError) {
            debugPrint(
              "⚠️ Falha ao subir foto (Apto ${dados['apartamento']}): $fotoError",
            );
            falhaNoUploadDaFoto = true;
            ultimoErro = "Falha no upload da foto, enviando apenas texto...";
          }
        }

        if (dados['tem_foto_anexada'] == true && falhaNoUploadDaFoto) {
          ultimoErro =
              "Apto ${dados['apartamento']}: Aguardando conexão estável para subir imagem de auditoria.";
          continue;
        }

        DateTime dataLeitura = DateTime.parse(dados['data_hora_string']);
        String mesAno = "${dataLeitura.month}_${dataLeitura.year}";
        String idUnicoDoc =
            "${dados['condominio']}_${dados['apartamento']}_${dados['medidor']}_$mesAno"
                .replaceAll(' ', '_')
                .toLowerCase();

        Map<String, dynamic> pacote = {
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
          pacote['url_foto'] = urlFotoFirebase;
        } else if (dados['tem_foto_anexada'] == true) {
          pacote['erro_sincronizacao_foto'] = true;
        }

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacote, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));

        await BancoLocal.remover(idLocal, itemJson);
        sucessoCount++;
      } catch (e) {
        debugPrint("❌ Falha fatal no item (Apto ${dados['apartamento']}): $e");
        ultimoErro = "Apto ${dados['apartamento']}: $e";
        if (mounted) setState(() => _isOnline = false);
        continue;
      }
    }

    final novaFila = await BancoLocal.lerFila();
    if (mounted) {
      setState(() {
        _sincronizandoAgora = false;
        _totalPendentes = novaFila.length;
        if (sucessoCount > 0) _isOnline = true;
      });

      if (sucessoCount > 0) {
        _mostrarToast(
          '✓ $sucessoCount leitura(s) sincronizada(s) com sucesso!',
          Colors.green.shade700,
        );
      }

      if (ultimoErro != null && sucessoCount == 0) {
        _mostrarToast(
          '⚠️ Sincronização travada: $ultimoErro',
          Colors.red.shade900,
        );
      }
    }
  }

  void _mostrarToast(String msg, Color cor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        dismissDirection: DismissDirection.up,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 130,
          left: 16,
          right: 16,
        ),
        duration: const Duration(milliseconds: 3000),
      ),
    );
  }

  Future<int> _buscarProgresso(
    String nomePredio,
    List<dynamic> apartamentos,
    List<dynamic> medidores,
  ) async {
    try {
      final fila = await BancoLocal.lerFila();
      final hoje = DateTime.now();

      int localCount = fila.where((item) {
        final dados = jsonDecode(item['dados']) as Map<String, dynamic>;
        if (dados['condominio'] != nomePredio) return false;
        final data = DateTime.parse(dados['data_hora_string']);
        return data.month == hoje.month && data.year == hoje.year;
      }).length;

      final query = await FirebaseFirestore.instance
          .collection('leituras')
          .where('condominio', isEqualTo: nomePredio)
          .get(const GetOptions(source: Source.cache))
          .timeout(const Duration(seconds: 3));

      int nuvemCount = query.docs.where((doc) {
        final dados = doc.data();
        final ts = dados['data_hora'] as Timestamp?;
        if (ts == null) return false;
        final data = ts.toDate();
        return data.month == hoje.month && data.year == hoje.year;
      }).length;

      return (localCount + nuvemCount).clamp(
        0,
        apartamentos.length * medidores.length,
      );
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color appBarColor = isDark ? Colors.blueGrey.shade900 : _azulPrimario;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              floating: false,
              pinned: true,
              backgroundColor: appBarColor,
              elevation: 0,
              automaticallyImplyLeading: false,
              actions: [
                const BotaoTrocaTema(corIcone: Colors.white), // 💡 BOTÃO AQUI!
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const EcraLogin()),
                        (_) => false,
                      );
                    }
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: const Text(
                  'Meus roteiros',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        isDark ? Colors.black87 : _azulEscuro,
                        appBarColor,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _StatusBar(
                isOnline: _isOnline,
                sincronizando: _sincronizandoAgora,
                pendentes: _totalPendentes,
                onSincronizar: _sincronizarSilenciosamente,
                onVerPendentes: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TelaSincronizacao()),
                ).then((_) => _carregarPendentes()),
              ),
            ),
            if (_totalPendentes > 0)
              SliverToBoxAdapter(
                child: _BannerPendentes(
                  total: _totalPendentes,
                  sincronizando: _sincronizandoAgora,
                  onSincronizar: _sincronizarSilenciosamente,
                  onVerDetalhes: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TelaSincronizacao(),
                    ),
                  ).then((_) => _carregarPendentes()),
                ),
              ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('predios')
                  .where(
                    'id_administradora',
                    isEqualTo: widget.idAdministradora,
                  )
                  .where(
                    'leituristas_permitidos',
                    arrayContains: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: _azulPrimario,
                        strokeWidth: 2,
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SliverFillRemaining(child: _EstadoVazio());
                }

                final predios = snapshot.data!.docs;

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final predio = predios[index];
                      final dados = predio.data() as Map<String, dynamic>;
                      final medidores = (dados['tipos_medicao'] as List?) ?? [];
                      final apartamentos =
                          (dados['apartamentos'] as List?) ?? [];
                      final nome = dados['nome_predio'] as String? ?? '';

                      return _CartaoPredio(
                        nome: nome,
                        medidores: medidores,
                        apartamentos: apartamentos,
                        totalUnidades: apartamentos.length * medidores.length,
                        progressoFuture: _buscarProgresso(
                          nome,
                          apartamentos,
                          medidores,
                        ),
                        onTap: () {
                          if (apartamentos.isEmpty || medidores.isEmpty) {
                            _mostrarToast(
                              'Prédio sem apartamentos ou medidores.',
                              Colors.orange.shade700,
                            );
                            return;
                          }
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaLeituraPageView(
                                condominio: nome,
                                medidores: medidores,
                                apartamentos: apartamentos,
                              ),
                            ),
                          ).then((_) {
                            _carregarPendentes();
                            _sincronizarSilenciosamente();
                          });
                        },
                      );
                    }, childCount: predios.length),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  final bool isOnline;
  final bool sincronizando;
  final int pendentes;
  final VoidCallback onSincronizar;
  final VoidCallback onVerPendentes;

  const _StatusBar({
    required this.isOnline,
    required this.sincronizando,
    required this.pendentes,
    required this.onSincronizar,
    required this.onVerPendentes,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.blueGrey.shade900 : const Color(0xFF0D47A1),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          _Pill(
            icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            label: isOnline ? 'Online' : 'Offline',
            cor: isOnline ? Colors.green.shade300 : Colors.red.shade300,
            fundo: isOnline
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
          ),
          const SizedBox(width: 8),
          if (sincronizando)
            _Pill(
              icon: Icons.sync_rounded,
              label: 'Sincronizando...',
              cor: Colors.white70,
              fundo: Colors.white.withOpacity(0.1),
              animating: true,
            )
          else if (pendentes > 0)
            GestureDetector(
              onTap: onVerPendentes,
              child: _Pill(
                icon: Icons.cloud_upload_rounded,
                label: '$pendentes pendente${pendentes > 1 ? 's' : ''}',
                cor: const Color(0xFFFFCC80),
                fundo: Colors.orange.withOpacity(0.2),
              ),
            )
          else
            _Pill(
              icon: Icons.cloud_done_rounded,
              label: 'Tudo sincronizado',
              cor: Colors.green.shade300,
              fundo: Colors.green.withOpacity(0.15),
            ),
          const Spacer(),
          if (!sincronizando && pendentes > 0)
            GestureDetector(
              onTap: onSincronizar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Enviar agora',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color cor;
  final Color fundo;
  final bool animating;

  const _Pill({
    required this.icon,
    required this.label,
    required this.cor,
    required this.fundo,
    this.animating = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: fundo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: cor, size: 13),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerPendentes extends StatelessWidget {
  final int total;
  final bool sincronizando;
  final VoidCallback onSincronizar;
  final VoidCallback onVerDetalhes;

  const _BannerPendentes({
    required this.total,
    required this.sincronizando,
    required this.onSincronizar,
    required this.onVerDetalhes,
  });

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.orange.shade900.withOpacity(0.3)
            : const Color(0xFFFFF8E1),
        border: Border.all(
          color: isDark ? Colors.orange.shade800 : const Color(0xFFFFE082),
          width: 0.8,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? Colors.orange.shade800 : const Color(0xFFFFECB3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.cloud_upload_rounded,
              color: isDark ? Colors.white : const Color(0xFFE65100),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$total leitura${total > 1 ? 's' : ''} aguardando envio',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onVerDetalhes,
                  child: Text(
                    'Ver detalhes →',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.blue.shade300
                          : const Color(0xFF0D47A1),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          sincronizando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE65100),
                  ),
                )
              : GestureDetector(
                  onTap: onSincronizar,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D47A1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Enviar',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _CartaoPredio extends StatelessWidget {
  final String nome;
  final List<dynamic> medidores;
  final List<dynamic> apartamentos;
  final int totalUnidades;
  final Future<int> progressoFuture;
  final VoidCallback onTap;

  const _CartaoPredio({
    required this.nome,
    required this.medidores,
    required this.apartamentos,
    required this.totalUnidades,
    required this.progressoFuture,
    required this.onTap,
  });

  String _icone(String id) {
    if (id == 'agua') return '💧';
    if (id == 'gas') return '🔥';
    if (id == 'energia') return '⚡';
    return '📊';
  }

  String _nomeMedidor(String id) {
    if (id == 'agua') return 'Água';
    if (id == 'gas') return 'Gás';
    if (id == 'energia') return 'Energia';
    return id;
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : const Color(0xFFE8ECF0),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.shade900.withOpacity(0.4)
                          : const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.apartment_rounded,
                      color: isDark
                          ? Colors.blue.shade300
                          : const Color(0xFF0D47A1),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: medidores.map<Widget>((m) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${_icone(m.toString())} ${_nomeMedidor(m.toString())}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : const Color(0xFF607D8B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: isDark
                        ? Colors.grey.shade600
                        : const Color(0xFFB0BEC5),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: isDark ? Colors.grey.shade800 : const Color(0xFFF0F0F0),
              ),
              const SizedBox(height: 14),
              FutureBuilder<int>(
                future: progressoFuture,
                builder: (context, snap) {
                  final feitas = snap.data ?? 0;
                  final total = totalUnidades == 0 ? 1 : totalUnidades;
                  final progresso = (feitas / total).clamp(0.0, 1.0);
                  final completo = feitas >= total && total > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            completo ? 'Concluído ✓' : 'Progresso',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: completo
                                  ? Colors.green.shade600
                                  : (isDark
                                        ? Colors.grey.shade400
                                        : const Color(0xFF607D8B)),
                            ),
                          ),
                          Text(
                            snap.connectionState == ConnectionState.waiting
                                ? '...'
                                : '$feitas / $totalUnidades leituras',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: completo
                                  ? Colors.green.shade600
                                  : (isDark
                                        ? Colors.white
                                        : const Color(0xFF37474F)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: snap.connectionState == ConnectionState.waiting
                              ? null
                              : progresso,
                          minHeight: 5,
                          backgroundColor: isDark
                              ? Colors.grey.shade800
                              : const Color(0xFFECEFF1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            completo
                                ? Colors.green.shade600
                                : const Color(0xFF0D47A1),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.shade900.withOpacity(0.2)
                    : const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.assignment_outlined,
                size: 40,
                color: isDark ? Colors.blue.shade300 : const Color(0xFF90CAF9),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Nenhum roteiro liberado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Aguarde o administrador\nvincular você a um prédio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : const Color(0xFF90A4AE),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
