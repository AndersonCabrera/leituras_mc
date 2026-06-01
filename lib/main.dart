import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:typed_data';
import 'package:excel/excel.dart' hide Border;
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'config/app_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LeiturasMCApp());
}

class LeiturasMCApp extends StatelessWidget {
  const LeiturasMCApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Leituras MC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const EcraLogin(),
    );
  }
}

class LeituraDecimalFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue.copyWith(text: '');
    String numerosLimpos = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (numerosLimpos.isEmpty) return newValue.copyWith(text: '');
    double valor = int.parse(numerosLimpos) / 1000;
    String novoTexto = valor.toStringAsFixed(3).replaceAll('.', ',');
    return TextEditingValue(
      text: novoTexto,
      selection: TextSelection.collapsed(offset: novoTexto.length),
    );
  }
}

class EcraLogin extends StatefulWidget {
  const EcraLogin({super.key});

  @override
  State<EcraLogin> createState() => _EcraLoginState();
}

class _EcraLoginState extends State<EcraLogin> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool carregando = false;
  bool _ocultarSenha = true;

  Future<void> _fazerLogin() async {
    if (emailController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha email e senha!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      carregando = true;
    });
    try {
      UserCredential credencial = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
            email: emailController.text.trim(),
            password: senhaController.text.trim(),
          );
      if (credencial.user != null) {
        DocumentSnapshot fichaUsuario = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(credencial.user!.uid)
            .get();
        if (fichaUsuario.exists) {
          String cargo = fichaUsuario.get('cargo');
          String? idAdmin =
              fichaUsuario.data().toString().contains('id_administradora')
              ? fichaUsuario.get('id_administradora')
              : null;
          if (cargo == 'leiturista' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TelaCondominios(idAdministradora: idAdmin!),
              ),
            );
          } else if (cargo == 'admin' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    TelaAdminDashboard(idAdministradora: idAdmin!),
              ),
            );
          } else if (cargo == 'super_admin' && mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TelaSuperAdminDashboard(),
              ),
            );
          }
        } else {
          await FirebaseAuth.instance.signOut();
          setState(() {
            carregando = false;
          });
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Erro: Usuário sem cadastro de cargo.'),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        carregando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no login: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
    } catch (e) {
      setState(() {
        carregando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao buscar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 20),
              const Text(
                'Leituras MC',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Text(
                'Acesso ao Sistema',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: senhaController,
                obscureText: _ocultarSenha,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _ocultarSenha ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _ocultarSenha = !_ocultarSenha;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: carregando ? null : _fazerLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: carregando
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Entrar',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
//  TELA DE ROTEIROS — REDESIGN UX
//  Substitui completamente a classe TelaCondominios original.
//  Mantém toda a lógica de negócio (sync, fila, Firebase).
// ============================================================

class TelaCondominios extends StatefulWidget {
  final String idAdministradora;
  const TelaCondominios({super.key, required this.idAdministradora});

  @override
  State<TelaCondominios> createState() => _TelaCondominiosState();
}

class _TelaCondominiosState extends State<TelaCondominios>
    with TickerProviderStateMixin {
  // --- Estado de sincronização ---
  Timer? _timerSync;
  bool _sincronizandoAgora = false;
  int _totalPendentes = 0;
  bool _isOnline = true;

  // --- Animações ---
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  // --- Paleta de cores do app ---
  static const Color _azulPrimario = Color(0xFF0D47A1);
  static const Color _azulEscuro = Color(0xFF1A237E);
  static const Color _laranja = Color(0xFFE65100);
  static const Color _cinzaFundo = Color(0xFFF5F6FA);

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
      const Duration(minutes: 1),
      (_) => _sincronizarSilenciosamente(),
    );
  }

  @override
  void dispose() {
    _timerSync?.cancel();
    _fadeCtrl.dispose();
    super.dispose();
  }

  // --- Lê a fila local e atualiza o contador de pendentes ---
  Future<void> _carregarPendentes() async {
    final prefs = await SharedPreferences.getInstance();
    final fila = prefs.getStringList('fila_leituras') ?? [];
    if (mounted) setState(() => _totalPendentes = fila.length);
  }

  // --- Sincronização silenciosa (lógica original preservada) ---
  Future<void> _sincronizarSilenciosamente() async {
    if (_sincronizandoAgora) return;
    final prefs = await SharedPreferences.getInstance();
    List<String> fila = prefs.getStringList('fila_leituras') ?? [];
    if (mounted) setState(() => _totalPendentes = fila.length);
    if (fila.isEmpty) return;

    setState(() => _sincronizandoAgora = true);
    List<String> filaAtualizada = List.from(fila);
    int sucessoCount = 0;

    for (String itemJson in fila) {
      try {
        Map<String, dynamic> dados = jsonDecode(itemJson);
        String? urlFotoFirebase;
        String? caminhoLocal = dados['caminho_foto_local'];

        if (caminhoLocal != null && !caminhoLocal.startsWith('base64:')) {
          io.File arquivoLocal = io.File(caminhoLocal);
          if (await arquivoLocal.exists()) {
            final ref = FirebaseStorage.instance.ref().child(
              'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await ref.putFile(
              arquivoLocal,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            urlFotoFirebase = await ref.getDownloadURL();
            await arquivoLocal.delete();
          }
        } else if (caminhoLocal != null && caminhoLocal.startsWith('base64:')) {
          final Uint8List imageBytes = base64Decode(
            caminhoLocal.replaceAll('base64:', ''),
          );
          final ref = FirebaseStorage.instance.ref().child(
            'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final tarefa = await ref.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          urlFotoFirebase = await tarefa.ref.getDownloadURL();
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
        if (urlFotoFirebase != null) pacote['url_foto'] = urlFotoFirebase;

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacote, SetOptions(merge: true));

        filaAtualizada.remove(itemJson);
        sucessoCount++;
      } catch (e) {
        debugPrint("Falha ao sincronizar: $e");
        if (mounted) setState(() => _isOnline = false);
      }
    }

    await prefs.setStringList('fila_leituras', filaAtualizada);
    if (mounted) {
      setState(() {
        _sincronizandoAgora = false;
        _totalPendentes = filaAtualizada.length;
        if (sucessoCount > 0) _isOnline = true;
      });
      if (sucessoCount > 0) {
        _mostrarToast(
          '✓ $sucessoCount leitura(s) sincronizada(s)!',
          Colors.green.shade700,
        );
      }
    }
  }

  void _mostrarToast(String msg, Color cor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: cor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Calcula progresso do prédio (leituras salvas este mês) ---
  Future<int> _buscarProgresso(
    String nomePredio,
    List<dynamic> apartamentos,
    List<dynamic> medidores,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fila = prefs.getStringList('fila_leituras') ?? [];
      final hoje = DateTime.now();

      // Conta leituras locais (offline) deste mês para este prédio
      int localCount = fila.where((item) {
        final dados = jsonDecode(item) as Map<String, dynamic>;
        if (dados['condominio'] != nomePredio) return false;
        final data = DateTime.parse(dados['data_hora_string']);
        return data.month == hoje.month && data.year == hoje.year;
      }).length;

      // Conta leituras na nuvem (online) deste mês
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
    return Scaffold(
      backgroundColor: _cinzaFundo,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── App Bar colapsável ──────────────────────────────────
            SliverAppBar(
              expandedHeight: 110,
              floating: false,
              pinned: true,
              backgroundColor: _azulPrimario,
              elevation: 0,
              automaticallyImplyLeading: false,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                title: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Text(
                        'Meus roteiros',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () async {
                        await FirebaseAuth.instance.signOut();
                        if (context.mounted) {
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                              builder: (_) => const EcraLogin(),
                            ),
                            (_) => false,
                          );
                        }
                      },
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_azulEscuro, _azulPrimario],
                    ),
                  ),
                ),
              ),
            ),

            // ── Status Bar (conexão + pendentes) ───────────────────
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

            // ── Banner de pendentes (visível apenas quando há itens) ─
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

            // ── Lista de prédios ────────────────────────────────────
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

// ================================================================
//  WIDGET — Status Bar (conexão + sincronização)
// ================================================================
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
    return Container(
      color: const Color(0xFF0D47A1),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          // Pill de conexão
          _Pill(
            icon: isOnline ? Icons.wifi_rounded : Icons.wifi_off_rounded,
            label: isOnline ? 'Online' : 'Offline',
            cor: isOnline ? Colors.green.shade300 : Colors.red.shade300,
            fundo: isOnline
                ? Colors.green.withOpacity(0.15)
                : Colors.red.withOpacity(0.15),
          ),
          const SizedBox(width: 8),

          // Pill de sincronização
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

          // Botão de sync manual
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

// ================================================================
//  WIDGET — Banner de pendentes
// ================================================================
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
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFFFECB3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.cloud_upload_rounded,
              color: Color(0xFFE65100),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF5D4037),
                  ),
                ),
                const SizedBox(height: 2),
                GestureDetector(
                  onTap: onVerDetalhes,
                  child: const Text(
                    'Ver detalhes →',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0D47A1),
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

// ================================================================
//  WIDGET — Cartão de prédio com barra de progresso
// ================================================================
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

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8ECF0), width: 0.8),
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
              // Linha superior: ícone + nome + seta
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.apartment_rounded,
                      color: Color(0xFF0D47A1),
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
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A2E),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        // Chips de medidores
                        Row(
                          children: medidores.map<Widget>((m) {
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Text(
                                '${_icone(m.toString())} ${_nomeMedidor(m.toString())}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF607D8B),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB0BEC5),
                    size: 22,
                  ),
                ],
              ),

              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 14),

              // Barra de progresso
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
                                  ? Colors.green.shade700
                                  : const Color(0xFF607D8B),
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
                                  ? Colors.green.shade700
                                  : const Color(0xFF37474F),
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
                          backgroundColor: const Color(0xFFECEFF1),
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

  String _nomeMedidor(String id) {
    if (id == 'agua') return 'Água';
    if (id == 'gas') return 'Gás';
    if (id == 'energia') return 'Energia';
    return id;
  }
}

// ================================================================
//  WIDGET — Estado vazio
// ================================================================
class _EstadoVazio extends StatelessWidget {
  const _EstadoVazio();

  @override
  Widget build(BuildContext context) {
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
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.assignment_outlined,
                size: 40,
                color: Color(0xFF90CAF9),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Nenhum roteiro liberado',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Aguarde o administrador\nvincular você a um prédio.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF90A4AE),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TelaLeituraPageView extends StatefulWidget {
  final String condominio;
  final List<dynamic> medidores;
  final List<dynamic> apartamentos;

  const TelaLeituraPageView({
    super.key,
    required this.condominio,
    required this.medidores,
    required this.apartamentos,
  });

  @override
  State<TelaLeituraPageView> createState() => _TelaLeituraPageViewState();
}

class _TelaLeituraPageViewState extends State<TelaLeituraPageView> {
  final PageController _pageController = PageController();
  String? medidorGlobal;

  @override
  void initState() {
    super.initState();
    if (widget.medidores.isNotEmpty)
      medidorGlobal = widget.medidores.first.toString();
  }

  void _avancarParaProximoApto() {
    if (_pageController.page != null &&
        _pageController.page! < widget.apartamentos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.condominio,
          style: const TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.apartamentos.length,
        itemBuilder: (context, index) {
          String aptoAtual = widget.apartamentos[index].toString();
          return ApartamentoLeituraPage(
            condominio: widget.condominio,
            apartamento: aptoAtual,
            medidores: widget.medidores,
            medidorSelecionado: medidorGlobal,
            onMedidorAlterado: (novoMedidor) {
              setState(() {
                medidorGlobal = novoMedidor;
              });
            },
            onSalvo: _avancarParaProximoApto,
          );
        },
      ),
    );
  }
}

class ApartamentoLeituraPage extends StatefulWidget {
  final String condominio;
  final String apartamento;
  final List<dynamic> medidores;
  final String? medidorSelecionado;
  final Function(String) onMedidorAlterado;
  final VoidCallback onSalvo;

  const ApartamentoLeituraPage({
    super.key,
    required this.condominio,
    required this.apartamento,
    required this.medidores,
    required this.medidorSelecionado,
    required this.onMedidorAlterado,
    required this.onSalvo,
  });

  @override
  State<ApartamentoLeituraPage> createState() => _ApartamentoLeituraPageState();
}

class _ApartamentoLeituraPageState extends State<ApartamentoLeituraPage>
    with AutomaticKeepAliveClientMixin {
  double? leituraAnterior;
  String referenciaAnterior = '--/----';
  bool carregandoLeitura = true;
  double? leituraAtual;
  double? consumoCalculado;
  final ImagePicker _picker = ImagePicker();
  XFile? fotoComprovante;
  bool salvando = false;
  bool modoEdicao = false;

  // Variáveis da IA e da Chave Mestra
  bool processandoIA = false;
  bool houveTrocaOuCorrecao = false;

  String? idLeituraExistente;
  final TextEditingController leituraAtualController = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.medidores.isNotEmpty) _buscarLeituraAnterior();
  }

  @override
  void didUpdateWidget(ApartamentoLeituraPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.medidorSelecionado != widget.medidorSelecionado) {
      leituraAtualController.clear();
      consumoCalculado = null;
      fotoComprovante = null;
      leituraAnterior = null;
      referenciaAnterior = '--/----';
      modoEdicao = false;
      houveTrocaOuCorrecao = false; // Reseta a chave mestra ao mudar de medidor
      _buscarLeituraAnterior();
    }
  }

  @override
  void dispose() {
    leituraAtualController.dispose();
    super.dispose();
  }

  String _nomeMedidorBonito(String id) {
    if (id == 'agua') return 'Água';
    if (id == 'gas') return 'Gás';
    if (id == 'energia') return 'Luz';
    return id.toUpperCase();
  }

  Future<void> _buscarLeituraAnterior() async {
    if (widget.medidorSelecionado == null) return;
    setState(() {
      carregandoLeitura = true;
    });

    try {
      String nomeMedidor = _nomeMedidorBonito(widget.medidorSelecionado!);
      final query = await FirebaseFirestore.instance
          .collection('leituras')
          .where('condominio', isEqualTo: widget.condominio)
          .where('apartamento', isEqualTo: widget.apartamento)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (query.docs.isNotEmpty) {
        var documentos = query.docs.where((doc) {
          var dados = doc.data() as Map<String, dynamic>;
          return dados['medidor'].toString().contains(nomeMedidor);
        }).toList();

        if (documentos.isEmpty) {
          setState(() {
            leituraAnterior = 0.0;
            referenciaAnterior = 'Novo';
            carregandoLeitura = false;
          });
          return;
        }

        documentos.sort((a, b) {
          Timestamp dataA =
              (a.data() as Map<String, dynamic>)['data_hora'] as Timestamp;
          Timestamp dataB =
              (b.data() as Map<String, dynamic>)['data_hora'] as Timestamp;
          return dataB.compareTo(dataA);
        });

        var docMaisRecente = documentos.first;
        var dadosMaisRecentes = docMaisRecente.data() as Map<String, dynamic>;
        DateTime dataDaLeitura = (dadosMaisRecentes['data_hora'] as Timestamp)
            .toDate();
        DateTime hoje = DateTime.now();

        if (dataDaLeitura.month == hoje.month &&
            dataDaLeitura.year == hoje.year) {
          setState(() {
            modoEdicao = true;
            idLeituraExistente = docMaisRecente.id;
            double valorSalvo = (dadosMaisRecentes['leitura_atual'] ?? 0.0)
                .toDouble();
            leituraAtualController.text = valorSalvo
                .toStringAsFixed(3)
                .replaceAll('.', ',');
            if (documentos.length > 1) {
              var docMesPassado = documentos.elementAt(1);
              DateTime dataAnt =
                  ((docMesPassado.data() as Map<String, dynamic>)['data_hora']
                          as Timestamp)
                      .toDate();
              referenciaAnterior =
                  '${dataAnt.month.toString().padLeft(2, '0')}/${dataAnt.year}';
              leituraAnterior =
                  ((docMesPassado.data()
                              as Map<String, dynamic>)['leitura_atual'] ??
                          0.0)
                      .toDouble();
            } else {
              leituraAnterior = 0.0;
              referenciaAnterior = 'Inicial';
            }
            carregandoLeitura = false;
          });
          _calcularConsumo(leituraAtualController.text);
        } else {
          setState(() {
            modoEdicao = false;
            referenciaAnterior =
                '${dataDaLeitura.month.toString().padLeft(2, '0')}/${dataDaLeitura.year}';
            leituraAnterior = (dadosMaisRecentes['leitura_atual'] ?? 0.0)
                .toDouble();
            carregandoLeitura = false;
          });
        }
      } else {
        setState(() {
          leituraAnterior = 0.0;
          referenciaAnterior = 'Inicial';
          carregandoLeitura = false;
        });
      }
    } catch (e) {
      setState(() {
        leituraAnterior = null;
        referenciaAnterior = 'Offline';
        carregandoLeitura = false;
      });
    }
  }

  void _calcularConsumo(String valorDigitado) {
    if (valorDigitado.isEmpty) {
      setState(() {
        consumoCalculado = null;
      });
      return;
    }
    double? valorConvertido = double.tryParse(
      valorDigitado.replaceAll(',', '.'),
    );
    if (valorConvertido != null) {
      setState(() {
        leituraAtual = valorConvertido;
        if (leituraAnterior != null)
          consumoCalculado = valorConvertido - leituraAnterior!;
      });
    }
  }

  Future<void> _tirarFoto() async {
    final XFile? fotoTirada = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 30,
    );
    if (fotoTirada != null)
      setState(() {
        fotoComprovante = fotoTirada;
      });
  }

  // Importe este novo pacote no topo do ficheiro, se ainda não estiver lá:
  // import 'package:image/image.dart' as img;

  // Cole sua chave aqui (idealmente virá de uma variável de ambiente)
  final uri = Uri.parse(
    'https://vision.googleapis.com/v1/images:annotate?key=${AppConfig.cloudVisionApiKey}',
  );

  Future<void> _tirarFotoELerComIA() async {
    final XFile? fotoOriginal = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (AppConfig.cloudVisionApiKey.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chave da API não configurada. Contate o suporte.'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (fotoOriginal == null) return;

    // Recorte opcional — mantém a UX que você já tinha
    CroppedFile? fotoCortada = await ImageCropper().cropImage(
      sourcePath: fotoOriginal.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Foque apenas nos números',
          toolbarColor: const Color(0xFF0D47A1),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio7x5,
          lockAspectRatio: false,
          hideBottomControls: true,
        ),
      ],
    );

    if (fotoCortada == null) return;

    setState(() => processandoIA = true);

    try {
      // 1. Lê a imagem e converte para base64
      final Uint8List imageBytes = await fotoCortada.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // 2. Chama a Cloud Vision API
      final uri = Uri.parse(
        // CORRETO — usa a classe AppConfig:
        'https://vision.googleapis.com/v1/images:annotate?key=${AppConfig.cloudVisionApiKey}',
      );

      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1},
              ],
              'imageContext': {
                'languageHints': ['pt', 'en'],
              },
            },
          ],
        }),
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Erro Vision API: ${response.statusCode} — ${response.body}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro na API (${response.statusCode}). Tente novamente.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 3. Extrai o texto retornado
      final Map<String, dynamic> data = jsonDecode(response.body);
      final String textoCompleto =
          data['responses']?[0]?['fullTextAnnotation']?['text'] ?? '';

      debugPrint('Cloud Vision retornou: $textoCompleto');

      // 4. Limpa e interpreta os números
      final String apenasNumeros = textoCompleto.replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );

      String? resultadoIA;
      String medidorAtual = widget.medidorSelecionado?.toLowerCase() ?? '';

      if (apenasNumeros.isNotEmpty) {
        if (medidorAtual.contains('gas')) {
          // Gás: espera 8 dígitos — 5 inteiros + 3 decimais
          if (apenasNumeros.length >= 8) {
            final n = apenasNumeros.substring(0, 8);
            resultadoIA = '${n.substring(0, 5)},${n.substring(5)}';
          } else if (apenasNumeros.length >= 5) {
            // Fallback: pega o que tem e completa com zeros
            final inteiros = apenasNumeros.substring(
              0,
              apenasNumeros.length > 5 ? 5 : apenasNumeros.length,
            );
            resultadoIA = '${inteiros.padLeft(5, '0')},000';
          }
        } else if (medidorAtual.contains('agua')) {
          // Água: espera 7 dígitos — 4 inteiros + 3 decimais
          if (apenasNumeros.length >= 7) {
            final n = apenasNumeros.substring(0, 7);
            resultadoIA = '${n.substring(0, 4)},${n.substring(4)}';
          } else if (apenasNumeros.length == 6) {
            resultadoIA =
                '${apenasNumeros.substring(0, 4)},${apenasNumeros.substring(4)}0';
          } else if (apenasNumeros.length >= 4) {
            final inteiros = apenasNumeros.substring(0, 4);
            resultadoIA = '$inteiros,000';
          }
        } else {
          // Energia ou genérico: pega os primeiros 8 dígitos
          if (apenasNumeros.length >= 6) {
            final n = apenasNumeros.substring(
              0,
              apenasNumeros.length > 8 ? 8 : apenasNumeros.length,
            );
            final meio = (n.length - 3).clamp(1, n.length);
            resultadoIA =
                '${n.substring(0, meio)},${n.substring(meio).padRight(3, '0')}';
          }
        }

        // Fallback final: mostra o que veio para o leiturista corrigir
        resultadoIA ??= apenasNumeros;
      }

      if (resultadoIA != null && resultadoIA.isNotEmpty) {
        setState(() {
          leituraAtualController.text = resultadoIA!;
          fotoComprovante = XFile(fotoCortada.path);
        });
        _calcularConsumo(resultadoIA!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Leitura capturada! Confirme se está correta.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '⚠️ Não consegui ler os números. Tente aproximar mais ou digitar manualmente.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Erro no processamento da imagem: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro inesperado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => processandoIA = false);
    }
  }

  Future<void> _abrirGaleria() async {
    final XFile? fotoEscolhida = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 30,
    );
    if (fotoEscolhida != null)
      setState(() {
        fotoComprovante = fotoEscolhida;
      });
  }

  Future<void> _salvarDadosNaCaixaDeSaida() async {
    setState(() {
      salvando = true;
    });
    try {
      String? caminhoFotoLocal;
      if (fotoComprovante != null && !kIsWeb) {
        final diretorio = await getApplicationDocumentsDirectory();
        final nomeArquivo = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
        caminhoFotoLocal = '${diretorio.path}/$nomeArquivo';
        final arquivoFisico = io.File(caminhoFotoLocal);
        await arquivoFisico.writeAsBytes(await fotoComprovante!.readAsBytes());
      } else if (fotoComprovante != null && kIsWeb) {
        final bytes = await fotoComprovante!.readAsBytes();
        caminhoFotoLocal = 'base64:' + base64Encode(bytes);
      }

      Map<String, dynamic> leituraLocal = {
        'condominio': widget.condominio,
        'medidor': _nomeMedidorBonito(widget.medidorSelecionado!),
        'apartamento': widget.apartamento,
        'leitura_anterior': leituraAnterior,
        'leitura_atual': leituraAtual,
        'consumo': consumoCalculado,
        'teve_consumo': (consumoCalculado != null && consumoCalculado! > 0),
        'tem_foto_anexada': (fotoComprovante != null),
        'correcao_manual': houveTrocaOuCorrecao,
        'data_hora_string': DateTime.now().toIso8601String(),
        'caminho_foto_local': caminhoFotoLocal,
        'modo_edicao': modoEdicao,
        'id_leitura_existente': idLeituraExistente,
      };

      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> fila = prefs.getStringList('fila_leituras') ?? [];
      fila.add(jsonEncode(leituraLocal));
      await prefs.setStringList('fila_leituras', fila);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Salvo! Avançando...'),
            backgroundColor: Color(0xFF0D47A1),
            duration: Duration(seconds: 1),
          ),
        );
        setState(() {
          salvando = false;
          fotoComprovante = null;
        });
        widget.onSalvo();
      }
    } catch (erro) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar no celular: $erro'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // 👇 A mágica acontece aqui: A leitura só é inválida se for menor E a chave mestra não estiver marcada.
    bool leituraInvalida =
        (leituraAnterior != null &&
        consumoCalculado != null &&
        consumoCalculado! < 0 &&
        !houveTrocaOuCorrecao);

    bool podeSalvar =
        leituraAtualController.text.isNotEmpty && !leituraInvalida;
    const Color mcDeepBlue = Color(0xFF0D47A1);
    const Color mcOrange = Color(0xFFE65100);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.medidores.map((m) {
                  bool isSelected = widget.medidorSelecionado == m;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: ChoiceChip(
                      label: Text(
                        _nomeMedidorBonito(m.toString()),
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.blueGrey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: mcDeepBlue,
                      backgroundColor: Colors.white,
                      onSelected: (selected) {
                        if (selected) widget.onMedidorAlterado(m.toString());
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              Text(
                widget.apartamento,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward, color: Colors.black87),
                onPressed: widget.onSalvo,
              ),
            ],
          ),
          const SizedBox(height: 15),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Leitura Anterior',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: mcDeepBlue,
                fontSize: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 20,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Referência',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        referenciaAnterior,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leitura',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      const SizedBox(height: 5),
                      carregandoLeitura
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              leituraAnterior == null
                                  ? 'Offline'
                                  : leituraAnterior!
                                        .toStringAsFixed(3)
                                        .replaceAll('.', ','),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          InputDecorator(
            decoration: InputDecoration(
              labelText: 'Leitura Atual',
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                color: mcDeepBlue,
                fontSize: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 20,
              ),
            ),
            child: Column(
              children: [
                TextField(
                  controller: leituraAtualController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Digite a Leitura',
                    labelStyle: const TextStyle(fontSize: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.blue.shade50,
                    prefixIcon: const Icon(Icons.speed, color: mcDeepBlue),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LeituraDecimalFormatter(),
                  ],
                  onChanged: _calcularConsumo,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Consumo Apurado',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            consumoCalculado == null
                                ? '0,000'
                                : consumoCalculado!
                                      .toStringAsFixed(3)
                                      .replaceAll('.', ','),
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color:
                                  (consumoCalculado != null &&
                                      consumoCalculado! < 0)
                                  ? Colors.red
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: fotoComprovante != null
                      ? Column(
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: 40,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Foto Anexada (Apto ${widget.apartamento})',
                              style: const TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  setState(() => fotoComprovante = null),
                              child: const Text(
                                'Remover Foto',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            InkWell(
                              onTap: processandoIA ? null : _tirarFotoELerComIA,
                              child: Column(
                                children: [
                                  processandoIA
                                      ? const SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CircularProgressIndicator(
                                            color: mcOrange,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.document_scanner,
                                          color: mcOrange,
                                          size: 30,
                                        ),
                                  const SizedBox(height: 5),
                                  Text(
                                    processandoIA ? 'A ler...' : 'Ler com IA',
                                    style: const TextStyle(
                                      color: mcOrange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _tirarFoto,
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    color: mcDeepBlue,
                                    size: 30,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Câmera (Manual)',
                                    style: TextStyle(color: mcDeepBlue),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              onTap: _abrirGaleria,
                              child: const Column(
                                children: [
                                  Icon(
                                    Icons.photo_library,
                                    color: mcDeepBlue,
                                    size: 30,
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    'Galeria',
                                    style: TextStyle(color: mcDeepBlue),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          if (leituraInvalida)
            const Padding(
              padding: EdgeInsets.only(top: 10),
              child: Center(
                child: Text(
                  '❌ Leitura inválida (Menor que a anterior)!',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 👇 CHAVE MESTRA: CAIXA DE SELEÇÃO DE CORREÇÃO
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: houveTrocaOuCorrecao
                  ? Colors.red.shade50
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: houveTrocaOuCorrecao ? Colors.red : Colors.grey.shade300,
              ),
            ),
            child: CheckboxListTile(
              title: const Text(
                'Troca de Medidor / Correção de Erro',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: const Text(
                'Permite guardar leituras menores que a anterior (Reset do relógio).',
              ),
              value: houveTrocaOuCorrecao,
              activeColor: Colors.red.shade700,
              onChanged: (bool? valor) {
                setState(() {
                  houveTrocaOuCorrecao = valor ?? false;
                });
              },
            ),
          ),

          const SizedBox(height: 15),
          if (podeSalvar)
            salvando
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mcOrange,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _tirarFotoELerComIA,
                          child: const Icon(
                            Icons.document_scanner,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mcDeepBlue,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: _salvarDadosNaCaixaDeSaida,
                          child: Text(
                            modoEdicao
                                ? 'GUARDAR CORREÇÃO'
                                : 'GUARDAR E AVANÇAR',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class TelaSincronizacao extends StatefulWidget {
  const TelaSincronizacao({super.key});

  @override
  State<TelaSincronizacao> createState() => _TelaSincronizacaoState();
}

class _TelaSincronizacaoState extends State<TelaSincronizacao> {
  List<String> filaDeLeituras = [];
  bool sincronizando = false;
  int totalParaSincronizar = 0;

  @override
  void initState() {
    super.initState();
    _carregarFila();
  }

  Future<void> _carregarFila() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      filaDeLeituras = prefs.getStringList('fila_leituras') ?? [];
      totalParaSincronizar = filaDeLeituras.length;
    });
  }

  Future<void> _enviarParaNuvem() async {
    if (filaDeLeituras.isEmpty) return;
    setState(() {
      sincronizando = true;
    });
    List<String> filaAtualizada = List.from(filaDeLeituras);

    for (String itemJson in filaDeLeituras) {
      try {
        Map<String, dynamic> dados = jsonDecode(itemJson);
        String? urlFotoFirebase;
        String? caminhoLocal = dados['caminho_foto_local'];

        if (caminhoLocal != null && !caminhoLocal.startsWith('base64:')) {
          io.File arquivoLocal = io.File(caminhoLocal);
          if (await arquivoLocal.exists()) {
            final ref = FirebaseStorage.instance.ref().child(
              'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
            );
            await ref.putFile(
              arquivoLocal,
              SettableMetadata(contentType: 'image/jpeg'),
            );
            urlFotoFirebase = await ref.getDownloadURL();
            await arquivoLocal.delete();
          }
        } else if (caminhoLocal != null && caminhoLocal.startsWith('base64:')) {
          final Uint8List imageBytes = base64Decode(
            caminhoLocal.replaceAll('base64:', ''),
          );
          final ref = FirebaseStorage.instance.ref().child(
            'comprovantes/foto_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          final tarefa = await ref.putData(
            imageBytes,
            SettableMetadata(contentType: 'image/jpeg'),
          );
          urlFotoFirebase = await tarefa.ref.getDownloadURL();
        }

        DateTime dataLeitura = DateTime.parse(dados['data_hora_string']);
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

        if (urlFotoFirebase != null)
          pacoteParaNuvem['url_foto'] = urlFotoFirebase;

        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacoteParaNuvem, SetOptions(merge: true));
        filaAtualizada.remove(itemJson);
      } catch (e) {
        debugPrint("Falha ao sincronizar item: $e");
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fila_leituras', filaAtualizada);
    _carregarFila();
    setState(() {
      sincronizando = false;
    });
    if (mounted) {
      if (filaAtualizada.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tudo enviado para a nuvem com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Algumas leituras falharam. Verifique a sua internet.',
            ),
            backgroundColor: Colors.orange,
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
              if (totalParaSincronizar > 0)
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: sincronizando
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.sync, color: Colors.white),
                          label: const Text(
                            'Sincronizar Agora',
                            style: TextStyle(fontSize: 18, color: Colors.white),
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

class TelaAdminDashboard extends StatelessWidget {
  final String idAdministradora;
  const TelaAdminDashboard({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Painel de Controlo - Administradora',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair do Sistema',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EcraLogin()),
                );
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.domain, size: 100, color: Colors.blueGrey),
              const SizedBox(height: 20),
              const Text(
                'Bem-vindo ao Centro de Comando',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              Wrap(
                spacing: 30,
                runSpacing: 30,
                alignment: WrapAlignment.center,
                children: [
                  _botaoCard(
                    context,
                    'Registar Prédio',
                    Icons.domain_add,
                    Colors.blue.shade700,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaCadastroPredio(
                          idAdministradora: idAdministradora,
                        ),
                      ),
                    ),
                  ),
                  _botaoCard(
                    context,
                    'Registar Leiturista',
                    Icons.person_add,
                    Colors.green.shade700,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaCadastroLeiturista(
                          idAdministradora: idAdministradora,
                        ),
                      ),
                    ),
                  ),
                  _botaoCard(
                    context,
                    'Ver Relatórios',
                    Icons.insert_chart,
                    Colors.orange.shade700,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaRelatoriosBusca(
                          idAdministradora: idAdministradora,
                        ),
                      ),
                    ),
                  ),
                  _botaoCard(
                    context,
                    'Gerir Roteiros',
                    Icons.assignment_ind,
                    Colors.purple.shade700,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TelaGerenciarEquipes(
                          idAdministradora: idAdministradora,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botaoCard(
    BuildContext context,
    String titulo,
    IconData icone,
    Color cor,
    VoidCallback acao,
  ) {
    return InkWell(
      onTap: acao,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: cor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: cor, width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icone, size: 50, color: cor),
            const SizedBox(height: 15),
            Text(
              titulo,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: cor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class TelaSuperAdminDashboard extends StatelessWidget {
  const TelaSuperAdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MC Prestadora - Painel Master SaaS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair do Sistema',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EcraLogin()),
                );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.amber.shade700,
        icon: const Icon(Icons.domain_add, color: Colors.white),
        label: const Text(
          'Novo Cliente (Administradora)',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const TelaCadastroAdministradora(),
            ),
          );
        },
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(30),
            width: double.infinity,
            color: Colors.grey.shade200,
            child: const Column(
              children: [
                Icon(
                  Icons.admin_panel_settings,
                  size: 80,
                  color: Colors.black87,
                ),
                SizedBox(height: 10),
                Text(
                  'Gestão de Clientes',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Administre as empresas que utilizam o seu sistema.',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('administradoras')
                  .orderBy('data_cadastro', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum cliente cadastrado ainda. Comece a vender!',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    var adminData = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(20),
                        leading: CircleAvatar(
                          backgroundColor: Colors.black87,
                          radius: 30,
                          child: Text(
                            adminData['nome_empresa'].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          adminData['nome_empresa'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'CNPJ: ${adminData['cnpj'] ?? 'Não informado'}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        trailing: ElevatedButton.icon(
                          icon: const Icon(
                            Icons.person_add,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Criar Acesso Admin',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade800,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => TelaCriarAcessoCliente(
                                  idAdministradora: doc.id,
                                  nomeEmpresa: adminData['nome_empresa'],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TelaCadastroAdministradora extends StatefulWidget {
  const TelaCadastroAdministradora({super.key});

  @override
  State<TelaCadastroAdministradora> createState() =>
      _TelaCadastroAdministradoraState();
}

class _TelaCadastroAdministradoraState
    extends State<TelaCadastroAdministradora> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController cnpjController = TextEditingController();
  bool salvando = false;

  Future<void> _salvarCliente() async {
    if (nomeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O nome da empresa é obrigatório!')),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      await FirebaseFirestore.instance.collection('administradoras').add({
        'nome_empresa': nomeController.text.trim(),
        'cnpj': cnpjController.text.trim(),
        'data_cadastro': FieldValue.serverTimestamp(),
        'status': 'ativo',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cliente cadastrado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Cliente'),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Dados da Administradora',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Empresa',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: cnpjController,
                decoration: const InputDecoration(
                  labelText: 'CNPJ (Opcional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Salvar Empresa',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                        ),
                        onPressed: _salvarCliente,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaCriarAcessoCliente extends StatefulWidget {
  final String idAdministradora;
  final String nomeEmpresa;
  const TelaCriarAcessoCliente({
    super.key,
    required this.idAdministradora,
    required this.nomeEmpresa,
  });

  @override
  State<TelaCriarAcessoCliente> createState() => _TelaCriarAcessoClienteState();
}

class _TelaCriarAcessoClienteState extends State<TelaCriarAcessoCliente> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool salvando = false;

  Future<void> _salvarAcesso() async {
    if (nomeController.text.isEmpty ||
        emailController.text.isEmpty ||
        senhaController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos! Senha mínima de 6 caracteres.',
          ),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      FirebaseApp appFantasma = await Firebase.initializeApp(
        name: 'appFantasma_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      UserCredential credencial =
          await FirebaseAuth.instanceFor(
            app: appFantasma,
          ).createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: senhaController.text.trim(),
          );
      await appFantasma.delete();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credencial.user!.uid)
          .set({
            'nome': nomeController.text.trim(),
            'email': emailController.text.trim(),
            'cargo': 'admin',
            'id_administradora': widget.idAdministradora,
            'data_cadastro': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Acesso criado! Envie este email e senha para o seu cliente.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar acesso: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Acesso: ${widget.nomeEmpresa}'),
        backgroundColor: Colors.black87,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Criar Login do Cliente',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Com este acesso, ele terá o próprio painel e não verá os dados de outras empresas.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Gestor (Ex: João Silva)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email de Acesso',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Senha Inicial',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          'Criar e Liberar Acesso',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                        ),
                        onPressed: _salvarAcesso,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaRelatoriosBusca extends StatefulWidget {
  final String idAdministradora;
  const TelaRelatoriosBusca({super.key, required this.idAdministradora});

  @override
  State<TelaRelatoriosBusca> createState() => _TelaRelatoriosBuscaState();
}

class _TelaRelatoriosBuscaState extends State<TelaRelatoriosBusca> {
  String queryBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Relatórios - Selecione o Prédio',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Procurar Prédio',
                hintText: 'Digite o nome do condomínio...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.blueGrey.shade50,
              ),
              onChanged: (valor) {
                setState(() {
                  queryBusca = valor.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('predios')
                  .where(
                    'id_administradora',
                    isEqualTo: widget.idAdministradora,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('Nenhum prédio registado.'));

                var prediosFiltrados = snapshot.data!.docs.where((doc) {
                  var nomePredio =
                      (doc.data() as Map<String, dynamic>)['nome_predio']
                          .toString()
                          .toLowerCase();
                  return nomePredio.contains(queryBusca);
                }).toList();

                if (prediosFiltrados.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum condomínio encontrado com esse nome.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: prediosFiltrados.map((doc) {
                    var predio = doc.data() as Map<String, dynamic>;
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: const Icon(
                          Icons.analytics,
                          size: 40,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          predio['nome_predio'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          predio['endereco'] ?? 'Sem endereço',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.blueGrey,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TelaRelatoriosPredio(
                                condominio: predio['nome_predio'],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================
// --- TELA WEB E MOBILE: RELATÓRIO DO PRÉDIO (APENAS MÊS ATUAL e COM FILTROS) ---
// =========================================================
class TelaRelatoriosPredio extends StatefulWidget {
  final String condominio;
  const TelaRelatoriosPredio({super.key, required this.condominio});

  @override
  State<TelaRelatoriosPredio> createState() => _TelaRelatoriosPredioState();
}

class _TelaRelatoriosPredioState extends State<TelaRelatoriosPredio> {
  String filtroAtual = 'Todos';

  String _gerarPrefixoMedidores(List<QueryDocumentSnapshot> leituras) {
    Set<String> tiposEncontrados = {};
    for (var doc in leituras) {
      var dados = doc.data() as Map<String, dynamic>;
      if (dados['medidor'] != null) {
        String m = dados['medidor'].toString().toLowerCase();
        if (m.contains('água') || m.contains('agua'))
          tiposEncontrados.add('Agua');
        if (m.contains('gás') || m.contains('gas')) tiposEncontrados.add('Gas');
        if (m.contains('luz') ||
            m.contains('energia') ||
            m.contains('eletricidade'))
          tiposEncontrados.add('Energia');
      }
    }
    if (tiposEncontrados.isEmpty) return 'Leitura_Geral';
    List<String> listaOrdenada = tiposEncontrados.toList()..sort();
    return 'Leitura_${listaOrdenada.join('_')}_';
  }

  Future<void> _exportarParaExcel(
    BuildContext context,
    List<QueryDocumentSnapshot> leituras,
  ) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel['Relatorio'];
    excel.setDefaultSheet('Relatorio');

    DateTime agora = DateTime.now();
    String dataEmissao =
        "${agora.day.toString().padLeft(2, '0')}/${agora.month.toString().padLeft(2, '0')}/${agora.year}";

    CellStyle estiloEmpresa = CellStyle(
      bold: true,
      fontSize: 16,
      fontColorHex: ExcelColor.fromHexString('#0D47A1'),
    );
    sheetObject.appendRow([
      TextCellValue('MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA'),
    ]);
    sheetObject
            .cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0))
            .cellStyle =
        estiloEmpresa;
    sheetObject.appendRow([
      TextCellValue('Relatório de Consumo: ${widget.condominio}'),
    ]);
    sheetObject.appendRow([TextCellValue('Gerado em: $dataEmissao')]);
    sheetObject.appendRow([TextCellValue('')]);

    CellStyle estiloCabecalho = CellStyle(
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      fontColorHex: ExcelColor.fromHexString('#ffffff'),
      backgroundColorHex: ExcelColor.fromHexString('#2c3e50'),
    );
    CellStyle estiloNumero = CellStyle(
      numberFormat: NumFormat.custom(formatCode: '0.000'),
    );

    List<String> cabecalho = [
      'Data/Hora',
      'Apartamento',
      'Medidor',
      'L. Anterior',
      'L. Atual',
      'Consumo',
      'Link da Foto',
    ];
    sheetObject.appendRow(
      cabecalho.map((titulo) => TextCellValue(titulo)).toList(),
    );

    for (int i = 0; i < cabecalho.length; i++) {
      sheetObject
              .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4))
              .cellStyle =
          estiloCabecalho;
    }

    for (int i = 0; i < leituras.length; i++) {
      var dados = leituras[i].data() as Map<String, dynamic>;
      int rowIndex = i + 5;

      String dataFormatada = 'Sem data';
      if (dados['data_hora'] != null) {
        DateTime data = (dados['data_hora'] as Timestamp).toDate();
        dataFormatada =
            '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
      }

      String apto = dados['apartamento']?.toString() ?? 'Geral';
      String medidor = dados['medidor'] ?? '-';
      double ant = (dados['leitura_anterior'] ?? 0).toDouble();
      double atual = (dados['leitura_atual'] ?? 0).toDouble();
      double cons = (dados['consumo'] ?? 0).toDouble();
      String linkFoto = dados['url_foto'] ?? '';

      sheetObject.appendRow([
        TextCellValue(dataFormatada),
        TextCellValue(apto),
        TextCellValue(medidor),
        DoubleCellValue(ant),
        DoubleCellValue(atual),
        DoubleCellValue(cons),
        TextCellValue(linkFoto.isEmpty ? 'Sem foto' : linkFoto),
      ]);

      sheetObject
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
              )
              .cellStyle =
          estiloNumero;
      sheetObject
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex),
              )
              .cellStyle =
          estiloNumero;
      sheetObject
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex),
              )
              .cellStyle =
          estiloNumero;

      if (linkFoto.isNotEmpty) {
        var celulaLink = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex),
        );
        celulaLink.value = FormulaCellValue(
          '=HYPERLINK("$linkFoto", "VER FOTO")',
        );
        celulaLink.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#0000FF'),
          underline: Underline.Single,
        );
      }
    }

    sheetObject.appendRow([TextCellValue('')]);
    sheetObject.appendRow([TextCellValue('---')]);
    CellStyle estiloPublicidade = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#E65100'),
    );
    CellStyle estiloContato = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0D47A1'),
    );

    sheetObject.appendRow([
      TextCellValue(
        'Esta leitura foi realizada pelo aplicativo oficial da MC Prestadora.',
      ),
    ]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: sheetObject.maxRows - 1,
              ),
            )
            .cellStyle =
        estiloPublicidade;
    sheetObject.appendRow([
      TextCellValue('Para contratar nossos serviços ou obter informações:'),
    ]);
    sheetObject.appendRow([
      TextCellValue(
        'E-mail: anderson.mcservicos@gmail.com  |  Telefone/WhatsApp: (51) 98128-5818',
      ),
    ]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: sheetObject.maxRows - 1,
              ),
            )
            .cellStyle =
        estiloContato;
    sheetObject.appendRow([TextCellValue('Falar com Anderson')]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: sheetObject.maxRows - 1,
              ),
            )
            .cellStyle =
        estiloContato;

    String prefixo = _gerarPrefixoMedidores(leituras);
    String dataArquivo =
        "${agora.day.toString().padLeft(2, '0')}-${agora.month.toString().padLeft(2, '0')}-${agora.year}";
    String nomeFicheiro =
        '${prefixo}${widget.condominio.replaceAll(' ', '_')}_$dataArquivo.xlsx';

    var fileBytes = excel.save();

    if (fileBytes != null) {
      if (kIsWeb) {
        final blob = html.Blob([
          fileBytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download", nomeFicheiro)
          ..click();
        html.Url.revokeObjectUrl(url);
      } else {
        try {
          final diretorio = await getTemporaryDirectory();
          final caminhoArquivo = '${diretorio.path}/$nomeFicheiro';
          final arquivo = io.File(caminhoArquivo);
          await arquivo.writeAsBytes(fileBytes);
          await Share.shareXFiles([
            XFile(caminhoArquivo),
          ], text: 'Relatório Excel - ${widget.condominio}');
        } catch (e) {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro no celular: $e'),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    }
  }

  Future<void> _exportarParaPDF(
    BuildContext context,
    List<QueryDocumentSnapshot> leituras,
  ) async {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando Relatório Oficial...'),
          backgroundColor: Color(0xFF0D47A1),
          duration: Duration(seconds: 3),
        ),
      );

    pw.MemoryImage? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {}

    final pdf = pw.Document();
    List<pw.Widget> listaDeLeituras = [];

    for (var doc in leituras) {
      var dados = doc.data() as Map<String, dynamic>;
      String dataStr = '-';
      if (dados['data_hora'] != null) {
        DateTime data = (dados['data_hora'] as Timestamp).toDate();
        dataStr =
            '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} às ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
      }

      pw.ImageProvider? imagemPdf;
      if (dados['url_foto'] != null &&
          dados['url_foto'].toString().isNotEmpty) {
        try {
          imagemPdf = await networkImage(dados['url_foto']);
        } catch (e) {}
      }

      listaDeLeituras.add(
        pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 15),
          padding: const pw.EdgeInsets.all(15),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey400, width: 1),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Apto / Porta: ${dados['apartamento'] ?? '-'}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text('Medidor: ${dados['medidor'] ?? '-'}'),
                    pw.Text('Data da Leitura: $dataStr'),
                    pw.Text(
                      'Leitura Anterior: ${dados['leitura_anterior']?.toStringAsFixed(3) ?? '-'}',
                    ),
                    pw.Text(
                      'Leitura Atual: ${dados['leitura_atual']?.toStringAsFixed(3) ?? '-'}',
                    ),
                    pw.SizedBox(height: 5),
                    pw.Text(
                      'Consumo Apurado: ${dados['consumo']?.toStringAsFixed(3) ?? '-'}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 15),
              if (imagemPdf != null)
                pw.Container(
                  width: 120,
                  height: 120,
                  child: pw.Image(imagemPdf, fit: pw.BoxFit.cover),
                )
              else
                pw.Container(
                  width: 120,
                  height: 120,
                  alignment: pw.Alignment.center,
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Text(
                    'Sem foto',
                    style: const pw.TextStyle(color: PdfColors.grey600),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(30),
        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Página ${context.pageNumber} de ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          );
        },
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "MC PRESTADORA DE SERVIÇOS",
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        "Relatório Oficial - ${widget.condominio}",
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                    ],
                  ),
                  if (logoImage != null)
                    pw.Container(height: 50, child: pw.Image(logoImage)),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            ...listaDeLeituras,
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey400),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey100),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    "Esta leitura foi realizada pelo aplicativo oficial da MC Prestadora.",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Para contratar nossos serviços ou obter informações:",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        "E-mail: anderson.mcservicos@gmail.com",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text("  |  ", style: const pw.TextStyle(fontSize: 9)),
                      pw.Text(
                        "Telefone/WhatsApp: (51) 98128-5818",
                        style: pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.blue700,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    "Falar com Anderson",
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    String prefixo = _gerarPrefixoMedidores(leituras);
    DateTime agora = DateTime.now();
    String dataArquivo =
        "${agora.day.toString().padLeft(2, '0')}-${agora.month.toString().padLeft(2, '0')}-${agora.year}";
    String nomeFicheiro =
        '${prefixo}${widget.condominio.replaceAll(' ', '_')}_$dataArquivo.pdf';

    await Printing.sharePdf(bytes: await pdf.save(), filename: nomeFicheiro);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Relatório: ${widget.condominio}',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('leituras')
            .where('condominio', isEqualTo: widget.condominio)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
            return const Center(child: Text('Nenhuma leitura encontrada.'));

          var leiturasBrutas = snapshot.data!.docs;

          leiturasBrutas.sort((a, b) {
            Timestamp dataA =
                (a.data() as Map<String, dynamic>)['data_hora'] as Timestamp? ??
                Timestamp.now();
            Timestamp dataB =
                (b.data() as Map<String, dynamic>)['data_hora'] as Timestamp? ??
                Timestamp.now();
            return dataB.compareTo(dataA);
          });

          Map<String, QueryDocumentSnapshot> mapaLeiturasUnicas = {};
          for (var doc in leiturasBrutas) {
            var dados = doc.data() as Map<String, dynamic>;
            String apto = dados['apartamento']?.toString() ?? 'Geral';
            String medidor = dados['medidor']?.toString() ?? '-';
            DateTime data =
                (dados['data_hora'] as Timestamp?)?.toDate() ?? DateTime.now();
            String chaveUnica = '${apto}_${medidor}_${data.month}_${data.year}';

            if (!mapaLeiturasUnicas.containsKey(chaveUnica)) {
              mapaLeiturasUnicas[chaveUnica] = doc;
            }
          }

          // 👇 BARREIRA DE TEMPO: FILTRAR PARA DEIXAR PASSAR APENAS O MÊS ATUAL
          DateTime hoje = DateTime.now();
          var leiturasFiltradas = mapaLeiturasUnicas.values.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            DateTime dataLeitura =
                (dados['data_hora'] as Timestamp? ?? Timestamp.now()).toDate();

            // Se a leitura NÃO for deste mês ou deste ano, descarta imediatamente
            if (dataLeitura.month != hoje.month ||
                dataLeitura.year != hoje.year) {
              return false;
            }

            if (filtroAtual == 'Todos') return true;
            String medidorStr = dados['medidor'].toString().toLowerCase();

            if (filtroAtual == 'Água' &&
                (medidorStr.contains('água') || medidorStr.contains('agua')))
              return true;
            if (filtroAtual == 'Gás' &&
                (medidorStr.contains('gás') || medidorStr.contains('gas')))
              return true;
            if (filtroAtual == 'Energia' &&
                (medidorStr.contains('luz') ||
                    medidorStr.contains('energia') ||
                    medidorStr.contains('eletricidade')))
              return true;

            return false;
          }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Todos', 'Água', 'Gás', 'Energia'].map((
                      String filtro,
                    ) {
                      bool isSelected = filtroAtual == filtro;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: ChoiceChip(
                          label: Text(
                            filtro,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: const Color(0xFF0D47A1),
                          backgroundColor: Colors.blueGrey.shade50,
                          onSelected: (bool selected) {
                            if (selected)
                              setState(() {
                                filtroAtual = filtro;
                              });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 15,
                ),
                color: Colors.blueGrey.shade50,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Text(
                      'Total: ${leiturasFiltradas.length} leituras deste mês',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Laudo (PDF)',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                          ),
                          onPressed: () =>
                              _exportarParaPDF(context, leiturasFiltradas),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.table_view,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Exportar Excel',
                            style: TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                          onPressed: () =>
                              _exportarParaExcel(context, leiturasFiltradas),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Data')),
                        DataColumn(label: Text('Apto')),
                        DataColumn(label: Text('Medidor')),
                        DataColumn(label: Text('L. Atual')),
                        DataColumn(label: Text('Consumo')),
                        DataColumn(label: Text('Foto')),
                      ],
                      rows: leiturasFiltradas.map((doc) {
                        var dados = doc.data() as Map<String, dynamic>;
                        String dataStr = 'Sem data';
                        if (dados['data_hora'] != null) {
                          DateTime data = (dados['data_hora'] as Timestamp)
                              .toDate();
                          dataStr = '${data.day}/${data.month}/${data.year}';
                        }
                        return DataRow(
                          cells: [
                            DataCell(Text(dataStr)),
                            DataCell(
                              Text(dados['apartamento']?.toString() ?? '-'),
                            ),
                            DataCell(Text(dados['medidor'] ?? '-')),
                            DataCell(
                              Text(
                                dados['leitura_atual']?.toStringAsFixed(3) ??
                                    '-',
                              ),
                            ),
                            DataCell(
                              Text(
                                dados['consumo']?.toStringAsFixed(3) ?? '-',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            DataCell(
                              dados['url_foto'] != null
                                  ? const Icon(Icons.image, color: Colors.blue)
                                  : const Text('-'),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class TelaGerenciarEquipes extends StatefulWidget {
  final String idAdministradora;
  const TelaGerenciarEquipes({super.key, required this.idAdministradora});

  @override
  State<TelaGerenciarEquipes> createState() => _TelaGerenciarEquipesState();
}

class _TelaGerenciarEquipesState extends State<TelaGerenciarEquipes> {
  String queryBusca = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gerir Prédios e Equipas',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Procurar Prédio',
                hintText: 'Digite o nome do condomínio...',
                prefixIcon: const Icon(Icons.search, color: Colors.blueGrey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                filled: true,
                fillColor: Colors.blueGrey.shade50,
              ),
              onChanged: (valor) {
                setState(() {
                  queryBusca = valor.toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('predios')
                  .where(
                    'id_administradora',
                    isEqualTo: widget.idAdministradora,
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                  return const Center(child: Text('Nenhum prédio registado.'));

                var prediosFiltrados = snapshot.data!.docs.where((doc) {
                  var nomePredio =
                      (doc.data() as Map<String, dynamic>)['nome_predio']
                          .toString()
                          .toLowerCase();
                  return nomePredio.contains(queryBusca);
                }).toList();

                if (prediosFiltrados.isEmpty)
                  return const Center(
                    child: Text(
                      'Nenhum condomínio encontrado com esse nome.',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: prediosFiltrados.map((doc) {
                    var predio = doc.data() as Map<String, dynamic>;
                    List permitidos =
                        predio.containsKey('leituristas_permitidos')
                        ? predio['leituristas_permitidos']
                        : [];

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 15),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: const Icon(
                          Icons.apartment,
                          size: 40,
                          color: Colors.blueGrey,
                        ),
                        title: Text(
                          predio['nome_predio'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        subtitle: Text(
                          '${permitidos.length}/3 Leituristas vinculados',
                          style: TextStyle(
                            color: permitidos.length == 3
                                ? Colors.orange
                                : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Editar Dados do Prédio',
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TelaEditarPredio(
                                      idPredio: doc.id,
                                      dadosPredio: predio,
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(
                                Icons.people,
                                color: Colors.white,
                              ),
                              label: const Text(
                                'Equipa',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade700,
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => TelaDetalhesPredio(
                                    idPredio: doc.id,
                                    nomePredio: predio['nome_predio'],
                                    idAdministradora: widget.idAdministradora,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TelaCadastroPredio extends StatefulWidget {
  final String idAdministradora;
  const TelaCadastroPredio({super.key, required this.idAdministradora});

  @override
  State<TelaCadastroPredio> createState() => _TelaCadastroPredioState();
}

class _TelaCadastroPredioState extends State<TelaCadastroPredio> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();
  final TextEditingController apartamentosController = TextEditingController();
  bool medeAgua = false, medeGas = false, medeEnergia = false, salvando = false;

  Future<void> _salvarPredio() async {
    if (nomeController.text.isEmpty || apartamentosController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha o nome e os apartamentos!')),
      );
      return;
    }
    if (!medeAgua && !medeGas && !medeEnergia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione pelo menos um tipo de medição!'),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      List<String> tiposMedicao = [];
      if (medeAgua) tiposMedicao.add('agua');
      if (medeGas) tiposMedicao.add('gas');
      if (medeEnergia) tiposMedicao.add('energia');

      List<String> listaApartamentos = apartamentosController.text
          .split(',')
          .map((apto) => apto.trim())
          .where((apto) => apto.isNotEmpty)
          .toList();

      final dadosDoPredio = {
        'nome_predio': nomeController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'id_administradora': widget.idAdministradora,
        'tipos_medicao': tiposMedicao,
        'apartamentos': listaApartamentos,
        'data_cadastro': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('predios').add(dadosDoPredio);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prédio registado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Prédio'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(30),
          child: ListView(
            children: [
              const Text(
                'Dados do Condomínio',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Prédio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: apartamentosController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Apartamentos (Separe por vírgula)',
                  hintText: 'Ex: 101, 102, 103, 201...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Serviços Medidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Água (m³)'),
                secondary: const Icon(Icons.water_drop, color: Colors.blue),
                value: medeAgua,
                onChanged: (bool? valor) {
                  setState(() {
                    medeAgua = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Gás (m³)'),
                secondary: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                value: medeGas,
                onChanged: (bool? valor) {
                  setState(() {
                    medeGas = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Energia Elétrica (kWh)'),
                secondary: const Icon(Icons.bolt, color: Colors.yellowAccent),
                value: medeEnergia,
                onChanged: (bool? valor) {
                  setState(() {
                    medeEnergia = valor!;
                  });
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Guardar no Sistema',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        onPressed: _salvarPredio,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaEditarPredio extends StatefulWidget {
  final String idPredio;
  final Map<String, dynamic> dadosPredio;
  const TelaEditarPredio({
    super.key,
    required this.idPredio,
    required this.dadosPredio,
  });

  @override
  State<TelaEditarPredio> createState() => _TelaEditarPredioState();
}

class _TelaEditarPredioState extends State<TelaEditarPredio> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController enderecoController = TextEditingController();
  final TextEditingController apartamentosController = TextEditingController();
  bool medeAgua = false, medeGas = false, medeEnergia = false, salvando = false;

  @override
  void initState() {
    super.initState();
    nomeController.text = widget.dadosPredio['nome_predio'] ?? '';
    enderecoController.text = widget.dadosPredio['endereco'] ?? '';
    List<dynamic> medidores = widget.dadosPredio['tipos_medicao'] ?? [];
    medeAgua = medidores.contains('agua');
    medeGas = medidores.contains('gas');
    medeEnergia = medidores.contains('energia');
    if (widget.dadosPredio.containsKey('apartamentos')) {
      List<dynamic> aptos = widget.dadosPredio['apartamentos'];
      apartamentosController.text = aptos.join(', ');
    }
  }

  Future<void> _atualizarPredio() async {
    if (nomeController.text.isEmpty || apartamentosController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha os campos obrigatórios!')),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      List<String> tiposMedicao = [];
      if (medeAgua) tiposMedicao.add('agua');
      if (medeGas) tiposMedicao.add('gas');
      if (medeEnergia) tiposMedicao.add('energia');
      List<String> listaApartamentos = apartamentosController.text
          .split(',')
          .map((apto) => apto.trim())
          .where((apto) => apto.isNotEmpty)
          .toList();
      final dadosAtualizados = {
        'nome_predio': nomeController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'tipos_medicao': tiposMedicao,
        'apartamentos': listaApartamentos,
      };

      await FirebaseFirestore.instance
          .collection('predios')
          .doc(widget.idPredio)
          .update(dadosAtualizados);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prédio atualizado!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao atualizar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Prédio'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(30),
          child: ListView(
            children: [
              const Text(
                'Dados do Condomínio',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(
                  labelText: 'Nome do Prédio',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: enderecoController,
                decoration: const InputDecoration(
                  labelText: 'Endereço',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: apartamentosController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Apartamentos (Separe por vírgula)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'Serviços Medidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Água (m³)'),
                secondary: const Icon(Icons.water_drop, color: Colors.blue),
                value: medeAgua,
                onChanged: (bool? valor) {
                  setState(() {
                    medeAgua = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Gás (m³)'),
                secondary: const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                ),
                value: medeGas,
                onChanged: (bool? valor) {
                  setState(() {
                    medeGas = valor!;
                  });
                },
              ),
              CheckboxListTile(
                title: const Text('Energia Elétrica (kWh)'),
                secondary: const Icon(Icons.bolt, color: Colors.yellowAccent),
                value: medeEnergia,
                onChanged: (bool? valor) {
                  setState(() {
                    medeEnergia = valor!;
                  });
                },
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 50,
                child: salvando
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton.icon(
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text(
                          'Guardar Alterações',
                          style: TextStyle(fontSize: 18, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                        ),
                        onPressed: _atualizarPredio,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TelaDetalhesPredio extends StatefulWidget {
  final String idPredio;
  final String nomePredio;
  final String idAdministradora;
  const TelaDetalhesPredio({
    super.key,
    required this.idPredio,
    required this.nomePredio,
    required this.idAdministradora,
  });

  @override
  State<TelaDetalhesPredio> createState() => _TelaDetalhesPredioState();
}

class _TelaDetalhesPredioState extends State<TelaDetalhesPredio> {
  List<DocumentSnapshot> todosLeituristas = [];
  String? leituristaSelecionado;

  @override
  void initState() {
    super.initState();
    _buscarLeituristasDaEmpresa();
  }

  Future<void> _buscarLeituristasDaEmpresa() async {
    var query = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('id_administradora', isEqualTo: widget.idAdministradora)
        .where('cargo', isEqualTo: 'leiturista')
        .get();
    setState(() {
      todosLeituristas = query.docs;
    });
  }

  Future<void> _adicionarLeiturista(List atuais) async {
    if (leituristaSelecionado == null) return;
    if (atuais.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Limite máximo de 3 leituristas atingido!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (atuais.contains(leituristaSelecionado)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este funcionário já está neste roteiro!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    List novaLista = List.from(atuais)..add(leituristaSelecionado);
    await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.idPredio)
        .update({'leituristas_permitidos': novaLista});
    setState(() {
      leituristaSelecionado = null;
    });
  }

  Future<void> _removerLeiturista(List atuais, String uidRemover) async {
    List novaLista = List.from(atuais)..remove(uidRemover);
    await FirebaseFirestore.instance
        .collection('predios')
        .doc(widget.idPredio)
        .update({'leituristas_permitidos': novaLista});
  }

  String _pegarNomeDoUid(String uid) {
    try {
      return todosLeituristas.firstWhere((doc) => doc.id == uid)['nome'];
    } catch (e) {
      return 'A carregar...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Equipa: ${widget.nomePredio}'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .doc(widget.idPredio)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var predio = snapshot.data!.data() as Map<String, dynamic>;
          List permitidos = predio.containsKey('leituristas_permitidos')
              ? predio['leituristas_permitidos']
              : [];

          return Center(
            child: SingleChildScrollView(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 600),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Equipa do Roteiro (Máximo: 3)',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...permitidos.map((uid) {
                      return Card(
                        color: Colors.green.shade50,
                        child: ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(
                            _pegarNomeDoUid(uid),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.person_remove,
                              color: Colors.red,
                            ),
                            tooltip: 'Remover',
                            onPressed: () =>
                                _removerLeiturista(permitidos, uid),
                          ),
                        ),
                      );
                    }).toList(),
                    if (permitidos.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(10),
                        child: Text(
                          'Nenhum funcionário vinculado.',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ),
                    const SizedBox(height: 40),
                    const Divider(),
                    const SizedBox(height: 20),
                    if (permitidos.length < 3) ...[
                      const Text(
                        'Vincular novo funcionário:',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                labelText: 'Selecione',
                              ),
                              value: leituristaSelecionado,
                              items: todosLeituristas.map((doc) {
                                return DropdownMenuItem<String>(
                                  value: doc.id,
                                  child: Text(doc['nome']),
                                );
                              }).toList(),
                              onChanged: (valor) {
                                setState(() {
                                  leituristaSelecionado = valor;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 55,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.add, color: Colors.white),
                              label: const Text(
                                'Vincular',
                                style: TextStyle(color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                              ),
                              onPressed: () => _adicionarLeiturista(permitidos),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange, size: 30),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Limite atingido para este condomínio.',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class TelaCadastroLeiturista extends StatefulWidget {
  final String idAdministradora;
  const TelaCadastroLeiturista({super.key, required this.idAdministradora});

  @override
  State<TelaCadastroLeiturista> createState() => _TelaCadastroLeituristaState();
}

class _TelaCadastroLeituristaState extends State<TelaCadastroLeiturista> {
  final TextEditingController nomeController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();
  bool salvando = false;

  Future<void> _salvarFuncionario() async {
    if (nomeController.text.isEmpty ||
        emailController.text.isEmpty ||
        senhaController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Preencha todos os campos! A senha deve ter no mínimo 6 letras/números.',
          ),
        ),
      );
      return;
    }
    setState(() {
      salvando = true;
    });

    try {
      FirebaseApp appFantasma = await Firebase.initializeApp(
        name: 'appFantasma_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      UserCredential credencial =
          await FirebaseAuth.instanceFor(
            app: appFantasma,
          ).createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: senhaController.text.trim(),
          );
      await appFantasma.delete();

      await FirebaseFirestore.instance
          .collection('usuarios')
          .doc(credencial.user!.uid)
          .set({
            'nome': nomeController.text.trim(),
            'email': emailController.text.trim(),
            'cargo': 'leiturista',
            'id_administradora': widget.idAdministradora,
            'data_cadastro': FieldValue.serverTimestamp(),
          });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Funcionário registado e pronto para trabalhar!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro no acesso: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
    } catch (e) {
      setState(() {
        salvando = false;
      });
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Novo Leiturista'),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dados do Funcionário',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Utilizará este email e senha para aceder à aplicação móvel.',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome Completo',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email de Acesso',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Senha (mínimo 6 caracteres)',
                    prefixIcon: Icon(Icons.lock),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: salvando
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text(
                            'Criar Acesso',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                          ),
                          onPressed: _salvarFuncionario,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
