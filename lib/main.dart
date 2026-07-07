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
import 'package:excel/excel.dart' hide BorderStyle, Border;
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
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

// =========================================================
// COFRE BLINDADO LOCAL (SQLite para Android/iOS | SharedPreferences para Web)
// =========================================================
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

    // 👇 RELÓGIO AJUSTADO PARA 15 SEGUNDOS
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
        bool falhaNoUploadDaFoto = false; // 👈 Controle local de falha de mídia

        // 🛡️ REGRA 1: ISOLAMENTO CRÍTICO DA FOTO
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
                    .timeout(
                      const Duration(seconds: 15),
                    ); // Timeout para não prender o app

                urlFotoFirebase = await ref.getDownloadURL();
                await arquivoLocal.delete(); // Apaga do telemóvel após subir
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
            falhaNoUploadDaFoto = true; // 👈 Sinaliza que o upload falhou
            ultimoErro = "Falha no upload da foto, enviando apenas texto...";
          }
        }

        // 🛡️ NOVA REGRA DE SEGURANÇA: Se a foto era obrigatória e falhou, impede a subida do texto
        // O 'continue' salta este apartamento preservando-o intacto no SQLite com a foto local,
        // mas deixa a fila continuar enviando as leituras normais sem travar o aplicativo!
        if (dados['tem_foto_anexada'] == true && falhaNoUploadDaFoto) {
          ultimoErro =
              "Apto ${dados['apartamento']}: Aguardando conexão estável para subir imagem de auditoria.";
          continue;
        }

        // Preparação do pacote de texto
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

        // Se a foto subiu com sucesso, anexa a URL, senão guarda sem URL para não perder o texto
        if (urlFotoFirebase != null) {
          pacote['url_foto'] = urlFotoFirebase;
        } else if (dados['tem_foto_anexada'] == true) {
          pacote['erro_sincronizacao_foto'] =
              true; // Marca que o texto foi, mas a foto falhou
        }

        // Envia para o Firestore
        await FirebaseFirestore.instance
            .collection('leituras')
            .doc(idUnicoDoc)
            .set(pacote, SetOptions(merge: true))
            .timeout(const Duration(seconds: 10));

        // 🔥 SÓ REMOVE DO SQLITE SE O TEXTO FOR SALVO COM SUCESSO
        await BancoLocal.remover(idLocal, itemJson);
        sucessoCount++;
      } catch (e) {
        // Se cair aqui, o erro é do Firestore (ex: Regras de segurança ou falta de login)
        debugPrint("❌ Falha fatal no item (Apto ${dados['apartamento']}): $e");
        ultimoErro = "Apto ${dados['apartamento']}: $e";
        if (mounted) setState(() => _isOnline = false);

        // Importante: NÃO damos return aqui! O 'continue' do loop vai tentar enviar o próximo
        // apartamento, garantindo que um erro no apto 101 não trave os outros 29!
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

      // Feedback para o utilizador
      if (sucessoCount > 0) {
        _mostrarToast(
          '✓ $sucessoCount leitura(s) sincronizada(s) com sucesso!',
          Colors.green.shade700,
        );
      }

      // Se houve algum erro na fila, avisa explicitamente o que travou
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
          bottom:
              MediaQuery.of(context).size.height -
              130, // Empurra para o topo do ecrã
          left: 16,
          right: 16,
        ),
        duration: const Duration(
          milliseconds: 3000,
        ), // Tempo suficiente para ler o erro
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
    return Scaffold(
      backgroundColor: _cinzaFundo,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
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
    return Container(
      color: const Color(0xFF0D47A1),
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

enum StatusLeitura { pendente, lendo, lido }

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
  late PageController _pageController;
  String? medidorGlobal;
  int _paginaAtual = 0;

  Map<String, StatusLeitura> statusApartamentos = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    if (widget.medidores.isNotEmpty) {
      medidorGlobal = widget.medidores.first.toString();
    }

    for (var apto in widget.apartamentos) {
      statusApartamentos[apto.toString()] = StatusLeitura.pendente;
    }
    if (widget.apartamentos.isNotEmpty) {
      statusApartamentos[widget.apartamentos.first.toString()] =
          StatusLeitura.lendo;
    }
  }

  void _irParaAnterior() {
    if (_paginaAtual > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _irParaProximo() {
    if (_paginaAtual < widget.apartamentos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void _onLeituraSalva() {
    setState(() {
      statusApartamentos[widget.apartamentos[_paginaAtual].toString()] =
          StatusLeitura.lido;
    });

    if (_paginaAtual < widget.apartamentos.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  void _abrirMenuLista() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Lista de Apartamentos",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.2,
                ),
                itemCount: widget.apartamentos.length,
                itemBuilder: (context, index) {
                  String apto = widget.apartamentos[index].toString();
                  StatusLeitura status =
                      statusApartamentos[apto] ?? StatusLeitura.pendente;

                  Color bgColor;
                  Color textColor = Colors.black87;

                  if (status == StatusLeitura.lido) {
                    bgColor = Colors.green.shade100;
                    textColor = Colors.green.shade900;
                  } else if (status == StatusLeitura.lendo) {
                    bgColor = Colors.amber.shade100;
                    textColor = Colors.amber.shade900;
                  } else {
                    bgColor = Colors.grey.shade200;
                  }

                  return InkWell(
                    onTap: () {
                      _pageController.jumpToPage(index);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: _paginaAtual == index
                            ? Border.all(
                                color: const Color(0xFF0D47A1),
                                width: 2,
                              )
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        apto,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: textColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF0D47A1);
    final total = widget.apartamentos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: azul,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.condominio,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              'Apto ${_paginaAtual + 1} de $total',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: _abrirMenuLista,
            icon: const Icon(
              Icons.grid_view_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: const Text(
              "Lista",
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: LinearProgressIndicator(
            value: total > 0 ? (_paginaAtual + 1) / total : 0,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            minHeight: 3,
          ),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _paginaAtual = index;
            String aptoAtual = widget.apartamentos[index].toString();
            if (statusApartamentos[aptoAtual] == StatusLeitura.pendente) {
              statusApartamentos[aptoAtual] = StatusLeitura.lendo;
            }
          });
        },
        itemCount: widget.apartamentos.length,
        itemBuilder: (context, index) {
          final aptoAtual = widget.apartamentos[index].toString();
          return ApartamentoLeituraPage(
            condominio: widget.condominio,
            apartamento: aptoAtual,
            medidores: widget.medidores,
            medidorSelecionado: medidorGlobal,
            indiceAtual: index,
            totalAptos: total,
            onMedidorAlterado: (novo) => setState(() => medidorGlobal = novo),
            onSalvo: _onLeituraSalva,
            onAnterior: _irParaAnterior,
            onProximo: _irParaProximo,
            isPrimeiro: index == 0,
            isUltimo: index == total - 1,
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
  final int indiceAtual;
  final int totalAptos;
  final Function(String) onMedidorAlterado;

  final VoidCallback onSalvo;
  final VoidCallback onAnterior;
  final VoidCallback onProximo;
  final bool isPrimeiro;
  final bool isUltimo;

  const ApartamentoLeituraPage({
    super.key,
    required this.condominio,
    required this.apartamento,
    required this.medidores,
    required this.medidorSelecionado,
    required this.indiceAtual,
    required this.totalAptos,
    required this.onMedidorAlterado,
    required this.onSalvo,
    required this.onAnterior,
    required this.onProximo,
    required this.isPrimeiro,
    required this.isUltimo,
  });

  @override
  State<ApartamentoLeituraPage> createState() => _ApartamentoLeituraPageState();
}

class _ApartamentoLeituraPageState extends State<ApartamentoLeituraPage>
    with AutomaticKeepAliveClientMixin {
  static const Color _azul = Color(0xFF0D47A1);
  static const Color _laranja = Color(0xFFE65100);

  double? leituraAnterior;
  String referenciaAnterior = '--/----';
  bool carregandoLeitura = true;
  double? leituraAtual;
  double? consumoCalculado;
  bool modoEdicao = false;
  String? idLeituraExistente;
  bool houveTrocaOuCorrecao = false;

  // 👇 VARIÁVEL DE TRAVA DE SEGURANÇA
  bool loteFechado = false;

  final ImagePicker _picker = ImagePicker();
  XFile? fotoComprovante;

  bool salvando = false;
  bool processandoIA = false;

  final TextEditingController _leituraCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.medidores.isNotEmpty) {
      _buscarLeituraAnterior();
      _verificarLoteFechado(); // 👈 Verifica o status do lote ao abrir
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      // 👈 Só levanta o teclado se o lote NÃO estiver fechado
      if (mounted && !loteFechado) _focusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(ApartamentoLeituraPage old) {
    super.didUpdateWidget(old);

    if (old.medidorSelecionado != widget.medidorSelecionado ||
        old.apartamento != widget.apartamento) {
      setState(() {
        leituraAnterior = null;
        referenciaAnterior = '--/----';
        carregandoLeitura = true;
        loteFechado = false; // Reset da trava para garantir validação limpa

        _leituraCtrl.clear();
        leituraAtual = null;
        consumoCalculado = null;
        houveTrocaOuCorrecao = false;
      });
      _buscarLeituraAnterior();
      _verificarLoteFechado(); // 👈 Verifica o lote sempre que muda de apto

      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted && !loteFechado) _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _leituraCtrl.dispose();
    super.dispose();
  }

  // 🔥 NOVA FUNÇÃO: PERGUNTA AO BANCO SE O LOTE FOI ENCERRADO PELA ADMIN
  Future<void> _verificarLoteFechado() async {
    try {
      DateTime agora = DateTime.now();
      String mesAtual = "${agora.month}_${agora.year}";

      // Procura o prédio atual no banco (tenta pelos nomes de campo mais comuns)
      var query = await FirebaseFirestore.instance
          .collection('predios')
          .where('nome_predio', isEqualTo: widget.condominio)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        query = await FirebaseFirestore.instance
            .collection('predios')
            .where('condominio', isEqualTo: widget.condominio)
            .limit(1)
            .get();
      }

      if (query.docs.isNotEmpty) {
        var dados = query.docs.first.data();
        List<dynamic> lotes = dados['lotes_fechados'] ?? [];
        if (mounted) {
          setState(() {
            loteFechado = lotes.contains(mesAtual);
            if (loteFechado) {
              _focusNode
                  .unfocus(); // Se estava aberto, esconde o teclado à força!
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Erro ao verificar trava do lote: $e");
    }
  }

  String _nomeMedidor(String id) {
    if (id == 'agua') return 'Água';
    if (id == 'gas') return 'Gás';
    if (id == 'energia') return 'Luz';
    return id.toUpperCase();
  }

  String _unidadeMedidor(String id) {
    if (id == 'energia') return 'kWh';
    return 'm³';
  }

  Future<void> _buscarLeituraAnterior() async {
    if (widget.medidorSelecionado == null) return;
    setState(() => carregandoLeitura = true);

    try {
      final nomeMedidor = _nomeMedidor(widget.medidorSelecionado!);
      final query = await FirebaseFirestore.instance
          .collection('leituras')
          .where('condominio', isEqualTo: widget.condominio)
          .where('apartamento', isEqualTo: widget.apartamento)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 5));

      if (query.docs.isEmpty) {
        setState(() {
          leituraAnterior = 0.0;
          referenciaAnterior = 'Inicial';
          carregandoLeitura = false;
        });
        return;
      }

      var docs = query.docs.where((doc) {
        final d = doc.data() as Map<String, dynamic>;
        return d['medidor'].toString().contains(nomeMedidor);
      }).toList();

      if (docs.isEmpty) {
        setState(() {
          leituraAnterior = 0.0;
          referenciaAnterior = 'Novo';
          carregandoLeitura = false;
        });
        return;
      }

      docs.sort((a, b) {
        final ta = (a.data() as Map<String, dynamic>)['data_hora'] as Timestamp;
        final tb = (b.data() as Map<String, dynamic>)['data_hora'] as Timestamp;
        return tb.compareTo(ta);
      });

      final recente = docs.first;
      final dadosRecentes = recente.data() as Map<String, dynamic>;
      final dataLeitura = (dadosRecentes['data_hora'] as Timestamp).toDate();
      final hoje = DateTime.now();

      if (dataLeitura.month == hoje.month && dataLeitura.year == hoje.year) {
        setState(() {
          modoEdicao = true;
          idLeituraExistente = recente.id;
          final valorSalvo = (dadosRecentes['leitura_atual'] ?? 0.0).toDouble();
          _leituraCtrl.text = valorSalvo
              .toStringAsFixed(3)
              .replaceAll('.', ',');
          if (docs.length > 1) {
            final anterior = docs.elementAt(1);
            final dataAnt =
                ((anterior.data() as Map<String, dynamic>)['data_hora']
                        as Timestamp)
                    .toDate();
            referenciaAnterior =
                '${dataAnt.month.toString().padLeft(2, '0')}/${dataAnt.year}';
            leituraAnterior =
                ((anterior.data() as Map<String, dynamic>)['leitura_atual'] ??
                        0.0)
                    .toDouble();
          } else {
            leituraAnterior = 0.0;
            referenciaAnterior = 'Inicial';
          }
          carregandoLeitura = false;
        });
        _calcularConsumo(_leituraCtrl.text);
      } else {
        setState(() {
          modoEdicao = false;
          referenciaAnterior =
              '${dataLeitura.month.toString().padLeft(2, '0')}/${dataLeitura.year}';
          leituraAnterior = (dadosRecentes['leitura_atual'] ?? 0.0).toDouble();
          carregandoLeitura = false;
        });
      }
    } catch (_) {
      setState(() {
        leituraAnterior = null;
        referenciaAnterior = 'Offline';
        carregandoLeitura = false;
      });
    }
  }

  void _calcularConsumo(String valor) {
    if (valor.isEmpty) {
      setState(() => consumoCalculado = null);
      return;
    }
    final v = double.tryParse(valor.replaceAll(',', '.'));
    if (v != null) {
      setState(() {
        leituraAtual = v;
        if (leituraAnterior != null) consumoCalculado = v - leituraAnterior!;
      });
    }
  }

  Future<void> _tirarFotoManual() async {
    final foto = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 40,
    );
    if (foto != null) setState(() => fotoComprovante = foto);
  }

  Future<void> _abrirGaleria() async {
    final foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 40,
    );
    if (foto != null) setState(() => fotoComprovante = foto);
  }

  Future<void> _lerComIA() async {
    final fotoOriginal = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (fotoOriginal == null) return;

    final fotoCortada = await ImageCropper().cropImage(
      sourcePath: fotoOriginal.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Foque nos números',
          toolbarColor: _azul,
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
      final bytes = await fotoCortada.readAsBytes();
      final base64Image = base64Encode(bytes);

      if (AppConfig.cloudVisionApiKey.isEmpty) {
        _toast('Chave da API não configurada.', Colors.red);
        return;
      }

      final uri = Uri.parse(
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
        _toast('Erro na API (${response.statusCode}).', Colors.red);
        return;
      }

      final data = jsonDecode(response.body);
      final texto = data['responses']?[0]?['fullTextAnnotation']?['text'] ?? '';
      final numeros = texto.replaceAll(RegExp(r'[^0-9]'), '');
      final medidor = widget.medidorSelecionado?.toLowerCase() ?? '';
      String? resultado;

      if (numeros.isNotEmpty) {
        if (medidor.contains('gas') && numeros.length >= 8) {
          final n = numeros.substring(0, 8);
          resultado = '${n.substring(0, 5)},${n.substring(5)}';
        } else if (medidor.contains('agua')) {
          if (numeros.length >= 7) {
            final n = numeros.substring(0, 7);
            resultado = '${n.substring(0, 4)},${n.substring(4)}';
          } else if (numeros.length == 6) {
            resultado = '${numeros.substring(0, 4)},${numeros.substring(4)}0';
          }
        }
        resultado ??= numeros;
      }

      if (resultado != null) {
        setState(() {
          _leituraCtrl.text = resultado!;
          fotoComprovante = XFile(fotoCortada.path);
        });
        _calcularConsumo(resultado);
        _toast(
          '✅ Leitura capturada! Confirme se está correta.',
          Colors.green.shade700,
        );
      } else {
        _toast(
          '⚠️ Não consegui ler. Tente digitar manualmente.',
          Colors.orange.shade700,
        );
      }
    } catch (e) {
      _toast('Erro: $e', Colors.red);
    } finally {
      setState(() => processandoIA = false);
    }
  }

  void _verificarEGuardar() {
    if (leituraAtual != null &&
        leituraAnterior != null &&
        !houveTrocaOuCorrecao) {
      double limiteConsumoSeguro = 7.0;

      if (consumoCalculado! > limiteConsumoSeguro) {
        if (fotoComprovante == null) {
          String unidadeAtual = _unidadeMedidor(
            widget.medidorSelecionado ?? '',
          );

          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: const [
                  Icon(Icons.camera_alt_rounded, color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Foto Obrigatória',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                'Alerta de Consumo Elevado!\n\n'
                'O consumo calculado (${consumoCalculado!.toStringAsFixed(3).replaceAll('.', ',')} $unidadeAtual) ultrapassou o limite seguro de $limiteConsumoSeguro $unidadeAtual.\n\n'
                'Para evitar erros de digitação e permitir auditoria posterior, tire uma foto do visor do medidor.',
                style: const TextStyle(fontSize: 15),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'CORRIGIR TEXTO',
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _tirarFotoManual();
                  },
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'TIRAR FOTO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      }
    }

    _salvarNaCaixaDeSaida();
  }

  Future<void> _salvarNaCaixaDeSaida() async {
    setState(() => salvando = true);
    try {
      String? caminhoFotoLocal;
      if (fotoComprovante != null && !kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final nome = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
        caminhoFotoLocal = '${dir.path}/$nome';
        await io.File(
          caminhoFotoLocal,
        ).writeAsBytes(await fotoComprovante!.readAsBytes());
      } else if (fotoComprovante != null && kIsWeb) {
        final bytes = await fotoComprovante!.readAsBytes();
        caminhoFotoLocal = 'base64:${base64Encode(bytes)}';
      }

      final leituraLocal = {
        'condominio': widget.condominio,
        'medidor': _nomeMedidor(widget.medidorSelecionado!),
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

      await BancoLocal.salvar(jsonEncode(leituraLocal));

      if (mounted) {
        setState(() {
          salvando = false;
          fotoComprovante = null;
        });
        widget.onSalvo();
      }
    } catch (e) {
      setState(() => salvando = false);
      _toast('Erro ao salvar: $e', Colors.red);
    }
  }

  void _toast(String msg, Color cor) {
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
          bottom: MediaQuery.of(context).size.height - 150,
          left: 16,
          right: 16,
        ),
        duration: const Duration(milliseconds: 1500),
      ),
    );
  }

  void _abrirMenuSecundario() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Opções adicionais',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 16),
            _ItemMenu(
              icon: Icons.document_scanner_rounded,
              cor: _laranja,
              titulo: 'Ler com IA',
              subtitulo: 'Tira foto e tenta ler o medidor automaticamente',
              carregando: processandoIA,
              onTap: () {
                Navigator.pop(context);
                _lerComIA();
              },
            ),
            const SizedBox(height: 8),
            _ItemMenu(
              icon: Icons.photo_library_rounded,
              cor: _azul,
              titulo: 'Escolher da galeria',
              subtitulo: 'Seleciona uma foto já tirada',
              onTap: () {
                Navigator.pop(context);
                _abrirGaleria();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final leituraInvalida =
        leituraAnterior != null &&
        consumoCalculado != null &&
        consumoCalculado! < 0 &&
        !houveTrocaOuCorrecao;

    // 👇 O botão de guardar agora exige que o lote esteja ABERTO
    final podeSalvar =
        _leituraCtrl.text.isNotEmpty && !leituraInvalida && !loteFechado;
    final medidorAtual = widget.medidorSelecionado ?? '';
    final unidade = _unidadeMedidor(medidorAtual);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Column(
                    children: [
                      Text(
                        widget.apartamento,
                        style: const TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A2E),
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'Apartamento',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF90A4AE),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 🛑 AVISO DE LOTE FECHADO
                if (loteFechado)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lote Encerrado.\nA administradora bloqueou o envio ou edição de leituras para este prédio.',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (widget.medidores.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: widget.medidores.map<Widget>((m) {
                        final sel = widget.medidorSelecionado == m;
                        return GestureDetector(
                          onTap: () => widget.onMedidorAlterado(m.toString()),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? _azul : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? _azul : const Color(0xFFCFD8DC),
                                width: 0.8,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: _azul.withOpacity(0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Text(
                              _nomeMedidor(m.toString()),
                              style: TextStyle(
                                color: sel
                                    ? Colors.white
                                    : const Color(0xFF607D8B),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFECEFF1),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.history_rounded,
                        color: Color(0xFFB0BEC5),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Leitura anterior',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF90A4AE),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            referenciaAnterior,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF607D8B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      carregandoLeitura
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF90A4AE),
                              ),
                            )
                          : Text(
                              leituraAnterior == null
                                  ? 'Offline'
                                  : '${leituraAnterior!.toStringAsFixed(3).replaceAll('.', ',')} $unidade',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF546E7A),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: loteFechado
                        ? Colors.grey.shade100
                        : Colors.white, // Muda de cor se fechado
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: leituraInvalida
                          ? Colors.red.shade300
                          : _leituraCtrl.text.isNotEmpty
                          ? _azul.withOpacity(0.4)
                          : const Color(0xFFECEFF1),
                      width: leituraInvalida || _leituraCtrl.text.isNotEmpty
                          ? 1.2
                          : 0.8,
                    ),
                    boxShadow: _leituraCtrl.text.isNotEmpty && !leituraInvalida
                        ? [
                            BoxShadow(
                              color: _azul.withOpacity(0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              color: loteFechado ? Colors.grey : _azul,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Leitura atual',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: loteFechado ? Colors.grey : _azul,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: loteFechado ? null : _abrirMenuSecundario,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF5F6FA),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(
                                      Icons.more_horiz_rounded,
                                      color: Color(0xFF90A4AE),
                                      size: 18,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Mais',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF90A4AE),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextField(
                        controller: _leituraCtrl,
                        focusNode: _focusNode,
                        readOnly: loteFechado, // 👈 IMPEDE DIGITAÇÃO SE FECHADO
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: loteFechado
                              ? Colors.grey
                              : const Color(0xFF1A1A2E),
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '0000,000',
                          hintStyle: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFCFD8DC),
                            letterSpacing: 1,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixText: unidade,
                          suffixStyle: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF90A4AE),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LeituraDecimalFormatter(),
                        ],
                        onChanged: _calcularConsumo,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: consumoCalculado == null
                        ? const Color(0xFFF5F6FA)
                        : leituraInvalida
                        ? Colors.red.shade50
                        : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: consumoCalculado == null
                          ? const Color(0xFFECEFF1)
                          : leituraInvalida
                          ? Colors.red.shade200
                          : Colors.green.shade200,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            consumoCalculado == null
                                ? Icons.calculate_outlined
                                : leituraInvalida
                                ? Icons.trending_down_rounded
                                : Icons.trending_up_rounded,
                            color: consumoCalculado == null
                                ? const Color(0xFFB0BEC5)
                                : leituraInvalida
                                ? Colors.red.shade600
                                : Colors.green.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Consumo apurado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: consumoCalculado == null
                                  ? const Color(0xFFB0BEC5)
                                  : leituraInvalida
                                  ? Colors.red.shade700
                                  : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        consumoCalculado == null
                            ? '-- $unidade'
                            : '${consumoCalculado! >= 0 ? '+' : ''}${consumoCalculado!.toStringAsFixed(3).replaceAll('.', ',')} $unidade',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: consumoCalculado == null
                              ? const Color(0xFFCFD8DC)
                              : leituraInvalida
                              ? Colors.red.shade700
                              : Colors.green.shade700,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                GestureDetector(
                  onTap: (fotoComprovante == null && !loteFechado)
                      ? _tirarFotoManual
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fotoComprovante != null
                            ? Colors.green.shade300
                            : const Color(0xFFECEFF1),
                        width: 0.8,
                      ),
                    ),
                    child: fotoComprovante != null
                        ? Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Foto anexada',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.green,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: loteFechado
                                    ? null
                                    : () => setState(
                                        () => fotoComprovante = null,
                                      ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Color(0xFFB0BEC5),
                                  size: 18,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Icon(
                                Icons.camera_alt_rounded,
                                color: loteFechado
                                    ? Colors.grey.shade300
                                    : const Color(0xFF90A4AE),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Tirar foto (opcional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: loteFechado
                                      ? Colors.grey.shade300
                                      : const Color(0xFF90A4AE),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: loteFechado
                                    ? Colors.grey.shade200
                                    : const Color(0xFFCFD8DC),
                                size: 18,
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 10),

                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: houveTrocaOuCorrecao
                        ? Colors.red.shade50
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: houveTrocaOuCorrecao
                          ? Colors.red.shade200
                          : const Color(0xFFECEFF1),
                      width: 0.8,
                    ),
                  ),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 2,
                    ),
                    title: Text(
                      'Troca de medidor / Correção',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: loteFechado
                            ? Colors.grey
                            : const Color(0xFF37474F),
                      ),
                    ),
                    subtitle: Text(
                      'Permite leitura menor que a anterior',
                      style: TextStyle(
                        fontSize: 12,
                        color: loteFechado
                            ? Colors.grey.shade400
                            : const Color(0xFF90A4AE),
                      ),
                    ),
                    value: houveTrocaOuCorrecao,
                    activeColor: Colors.red.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onChanged: loteFechado
                        ? null
                        : (v) =>
                              setState(() => houveTrocaOuCorrecao = v ?? false),
                  ),
                ),

                if (leituraInvalida)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.red.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: Colors.red.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Leitura menor que a anterior',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB0BEC5),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                SizedBox(
                  width: 55,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: widget.isPrimeiro ? null : widget.onAnterior,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                        color: widget.isPrimeiro ? Colors.grey.shade300 : _azul,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 30,
                      color: widget.isPrimeiro ? Colors.grey.shade400 : _azul,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: podeSalvar
                          ? (salvando ? null : _verificarEGuardar)
                          : null,
                      icon: salvando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              loteFechado ? Icons.lock : Icons.check_rounded,
                              color: loteFechado
                                  ? Colors.grey.shade500
                                  : Colors.white,
                            ),
                      label: Text(
                        loteFechado
                            ? 'MÊS BLOQUEADO'
                            : salvando
                            ? 'A GUARDAR...'
                            : (modoEdicao
                                  ? 'CONFIRMAR CORREÇÃO'
                                  : 'GUARDAR E AVANÇAR'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: loteFechado
                              ? Colors.grey.shade500
                              : Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azul,
                        disabledBackgroundColor: Colors.grey.shade300,
                        elevation: podeSalvar ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                SizedBox(
                  width: 55,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: widget.isUltimo ? null : widget.onProximo,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(
                        color: widget.isUltimo ? Colors.grey.shade300 : _azul,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 30,
                      color: widget.isUltimo ? Colors.grey.shade400 : _azul,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemMenu extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;
  final bool carregando;

  const _ItemMenu({
    required this.icon,
    required this.cor,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: carregando ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: carregando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cor,
                      ),
                    )
                  : Icon(icon, color: cor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF37474F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF90A4AE),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFCFD8DC),
              size: 18,
            ),
          ],
        ),
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
  List<Map<String, dynamic>> filaDeLeituras = [];
  bool sincronizando = false;
  int totalParaSincronizar = 0;

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
    setState(() {
      sincronizando = true;
    });

    int sucessoCount = 0;
    for (var linha in filaDeLeituras) {
      try {
        int idLocal = linha['id'];
        String itemJson = linha['dados'];
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

        await BancoLocal.remover(idLocal, itemJson);
        sucessoCount++;
      } catch (e) {
        debugPrint("Falha ao sincronizar item: $e");
      }
    }

    await _carregarFila();
    setState(() {
      sincronizando = false;
    });
    if (mounted) {
      if (filaDeLeituras.isEmpty) {
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

// ============================================================================
// TELA PRINCIPAL: PAINEL DA ADMINISTRADORA
// ============================================================================
class TelaAdminDashboard extends StatelessWidget {
  final String idAdministradora;
  const TelaAdminDashboard({super.key, required this.idAdministradora});

  void _mostrarAlertaBreve(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Funcionalidade em desenvolvimento para a próxima versão.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // O PAYWALL: Verifica se o cliente paga o plano Premium
  Future<void> _abrirPersonalizacaoPremium(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      var doc = await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(idAdministradora)
          .get();
      bool isPremium =
          (doc.data() as Map<String, dynamic>?)?['plano_premium'] == true;

      if (context.mounted) Navigator.pop(context); // Fecha o loading

      if (isPremium) {
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TelaConfiguracoesMarca(idAdministradora: idAdministradora),
            ),
          );
        }
      } else {
        if (context.mounted) _mostrarUpsellPremium(context);
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
    }
  }

  // A TELA DE UPGRADE (A isca de vendas)
  void _mostrarUpsellPremium(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.star_rounded, color: Colors.amber, size: 30),
            SizedBox(width: 10),
            Text(
              'Recurso Premium',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'A personalização avançada de relatórios (inserção do seu Logótipo e contactos oficiais em PDF) é uma funcionalidade exclusiva do Plano White-Label.\n\n'
          'Destaque a sua marca perante os síndicos e passe uma imagem de topo. Fale com o nosso suporte para fazer o upgrade da sua conta!',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'AGORA NÃO',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              // Aqui pode colocar um link para o WhatsApp no futuro
            },
            icon: const Icon(
              Icons.rocket_launch_rounded,
              color: Colors.white,
              size: 18,
            ),
            label: const Text(
              'FAZER UPGRADE',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color azul = Color(0xFF0D47A1);
    const Color fundo = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Centro de Comando',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: azul,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sair',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const EcraLogin()),
                );
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: azul,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Olá, Administrador!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Visão Geral da Operação',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(
                    top: 85,
                    left: 16,
                    right: 16,
                    bottom: 20,
                  ),
                  child: Row(
                    children: [
                      // KPI: Prédios
                      Expanded(
                        child: _kpiCard(
                          'Prédios',
                          Icons.apartment_rounded,
                          Colors.blue.shade700,
                          FirebaseFirestore.instance
                              .collection('predios')
                              .where(
                                'id_administradora',
                                isEqualTo: idAdministradora,
                              )
                              .snapshots(),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaGerenciarEquipes(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // KPI: Equipe
                      Expanded(
                        child: _kpiCard(
                          'Equipe',
                          Icons.people_alt_rounded,
                          Colors.green.shade700,
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .where(
                                'id_administradora',
                                isEqualTo: idAdministradora,
                              )
                              .where('cargo', isEqualTo: 'leiturista')
                              .snapshots(),
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaListaEquipe(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- BARRA DE PROGRESSO ESPECÍFICA DA ADMINISTRADORA ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FutureBuilder<Map<String, dynamic>>(
                future: () async {
                  int totalApartamentos = 0;
                  int leiturasConcluidas = 0;

                  DateTime agora = DateTime.now();
                  String mesAnoFiltro = "${agora.month}_${agora.year}";

                  // Busca apenas os prédios DESTA administradora
                  var prediosSnapshot = await FirebaseFirestore.instance
                      .collection('predios')
                      .where('id_administradora', isEqualTo: idAdministradora)
                      .get();

                  for (var doc in prediosSnapshot.docs) {
                    var dados = doc.data();
                    if (dados['apartamentos'] != null) {
                      if (dados['apartamentos'] is List) {
                        totalApartamentos +=
                            (dados['apartamentos'] as List).length;
                      } else if (dados['apartamentos'] is num) {
                        totalApartamentos += (dados['apartamentos'] as num)
                            .toInt();
                      }
                    }
                  }

                  // Busca as leituras feitas para ESTA administradora
                  var leiturasSnapshot = await FirebaseFirestore.instance
                      .collection('leituras')
                      .where('id_administradora', isEqualTo: idAdministradora)
                      .get();

                  for (var doc in leiturasSnapshot.docs) {
                    if (doc.id.endsWith(mesAnoFiltro)) {
                      leiturasConcluidas++;
                    }
                  }

                  double progresso = 0.0;
                  if (totalApartamentos > 0) {
                    progresso = leiturasConcluidas / totalApartamentos;
                  }

                  return {
                    'total': totalApartamentos,
                    'concluidas': leiturasConcluidas,
                    'porcentagem': progresso > 1.0 ? 1.0 : progresso,
                  };
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  var dadosOperacao =
                      snapshot.data ??
                      {'total': 0, 'concluidas': 0, 'porcentagem': 0.0};
                  double pctValor = dadosOperacao['porcentagem'] as double;
                  int pctTexto = (pctValor * 100).toInt();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progresso do Consumo Mensal',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              '$pctTexto%',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: pctTexto == 100
                                    ? Colors.green.shade700
                                    : Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: pctValor,
                          backgroundColor: Colors.grey.shade100,
                          color: pctTexto == 100
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dadosOperacao['concluidas']} de ${dadosOperacao['total']} medidores lidos este mês.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // AÇÕES RÁPIDAS
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Operações',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          'Ver Relatórios',
                          'Consumos e PDF',
                          Icons.insert_chart_rounded,
                          Colors.orange.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaRelatoriosBusca(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          'Gerir Roteiros',
                          'Acompanhar Leituras',
                          Icons.assignment_ind_rounded,
                          Colors.purple.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaGerenciarEquipes(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _actionCard(
                          context,
                          'Auditoria',
                          'Revisar Anomalias',
                          Icons.policy_rounded,
                          Colors.red.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaAuditoria(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _actionCard(
                          context,
                          'Fechar Lote',
                          'Bloquear Mês',
                          Icons.lock_rounded,
                          Colors.indigo.shade600,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaFechamentoLote(
                                idAdministradora: idAdministradora,
                              ),
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

          // CADASTROS DO SISTEMA
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cadastros',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.domain_add_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: const Text(
                            'Registar Novo Prédio',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Adicionar condomínio e medidores',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaCadastroPredio(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.person_add_rounded,
                              color: Colors.green.shade700,
                            ),
                          ),
                          title: const Text(
                            'Registar Leiturista',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: const Text(
                            'Criar acesso para a equipe de campo',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.grey,
                          ),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => TelaCadastroLeiturista(
                                idAdministradora: idAdministradora,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // CONFIGURAÇÕES WHITE-LABEL SELF-SERVICE
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Definições da Marca',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.brush_rounded,
                          color: Colors.teal.shade700,
                        ),
                      ),
                      title: const Text(
                        'Personalizar Relatórios',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Upload de logótipo e contactos oficiais',
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.grey,
                      ),
                      onTap: () => _abrirPersonalizacaoPremium(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(
    String titulo,
    IconData icon,
    Color cor,
    Stream<QuerySnapshot> stream,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: cor, size: 28),
                const SizedBox(height: 12),
                StreamBuilder<QuerySnapshot>(
                  stream: stream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Text(
                        '...',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    int count = snapshot.data?.docs.length ?? 0;
                    return Text(
                      count.toString(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 10,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionCard(
    BuildContext context,
    String titulo,
    String subtitulo,
    IconData icon,
    Color cor,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: cor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: cor, size: 24),
                ),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TELA 1: AUDITORIA (Revisão de anomalias com ações reais)
// ============================================================================
class TelaAuditoria extends StatelessWidget {
  final String idAdministradora;
  const TelaAuditoria({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Auditoria de Anomalias',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Procura leituras que tenham foto anexada (alertas de limite ou correção manual)
        stream: FirebaseFirestore.instance
            .collection('leituras')
            .where('id_administradora', isEqualTo: idAdministradora)
            .where('tem_foto_anexada', isEqualTo: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhuma anomalia para revisar. ✅',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Filtramos em memória para tirar da lista os que já foram aprovados pelo gestor
          var docsPendentes = snapshot.data!.docs.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            return dados['status_auditoria'] != 'aprovado';
          }).toList();

          if (docsPendentes.isEmpty) {
            return const Center(
              child: Text(
                'Todas as anomalias foram auditadas! 🎉',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docsPendentes.length,
            itemBuilder: (context, index) {
              var doc = docsPendentes[index];
              var dados = doc.data() as Map<String, dynamic>;

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          // Área da foto
                          GestureDetector(
                            onTap: () {
                              // Futuro: Ao clicar na foto, ela abre em ecrã inteiro
                              if (dados['url_foto'] == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Imagem ainda não sincronizada pelo leiturista.',
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(8),
                                image: dados['url_foto'] != null
                                    ? DecorationImage(
                                        image: NetworkImage(dados['url_foto']),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: dados['url_foto'] == null
                                  ? const Icon(
                                      Icons.hourglass_bottom_rounded,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Dados do apartamento
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${dados['condominio']} - Apto ${dados['apartamento']}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Medidor: ${dados['medidor']}',
                                  style: const TextStyle(color: Colors.grey),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Consumo: ${dados['consumo']?.toStringAsFixed(3)}',
                                    style: TextStyle(
                                      color: Colors.red.shade900,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(),
                      ),
                      // 🔘 BOTÕES DE DECISÃO
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Botão Rejeitar
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              side: BorderSide(color: Colors.red.shade200),
                            ),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text(
                              'REFAZER',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              // Apaga a leitura, forçando o leiturista a refazer
                              await FirebaseFirestore.instance
                                  .collection('leituras')
                                  .doc(doc.id)
                                  .delete();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Leitura rejeitada! O apartamento voltou para a lista de pendentes do leiturista.',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              }
                            },
                          ),
                          // Botão Aprovar
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green.shade600,
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'APROVAR',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () async {
                              // Atualiza o documento adicionando a tag de aprovado
                              await FirebaseFirestore.instance
                                  .collection('leituras')
                                  .doc(doc.id)
                                  .update({'status_auditoria': 'aprovado'});
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Leitura validada e pronta para faturamento!',
                                    ),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// TELA 2: FECHAMENTO DE LOTE (Bloqueia o mês)
// ============================================================================
class TelaFechamentoLote extends StatelessWidget {
  final String idAdministradora;
  const TelaFechamentoLote({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fechamento de Lote',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.indigo.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('predios')
            .where('id_administradora', isEqualTo: idAdministradora)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          if (snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'Nenhum prédio cadastrado ainda.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          // Descobre o mês e ano atual (ex: "7_2026")
          DateTime agora = DateTime.now();
          String mesAtual = "${agora.month}_${agora.year}";

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var predio = snapshot.data!.docs[index];
              var dadosPredio = predio.data() as Map<String, dynamic>? ?? {};

              String nomeDoPredio =
                  dadosPredio['nome_predio'] ?? 'Prédio Sem Nome';

              // Verifica se o mês atual já está na lista de lotes fechados deste prédio
              List<dynamic> lotesFechados = dadosPredio['lotes_fechados'] ?? [];
              bool isLoteFechado = lotesFechados.contains(mesAtual);

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isLoteFechado
                        ? Colors.red.shade200
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isLoteFechado
                          ? Colors.red.shade50
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isLoteFechado ? Icons.lock_rounded : Icons.domain_rounded,
                      color: isLoteFechado
                          ? Colors.red.shade700
                          : Colors.indigo.shade700,
                    ),
                  ),
                  title: Text(
                    nomeDoPredio,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      isLoteFechado
                          ? 'O lote de leitura deste mês já está encerrado.'
                          : 'Bloquear edições de leitura neste mês.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isLoteFechado
                            ? Colors.red.shade600
                            : Colors.grey.shade700,
                        fontWeight: isLoteFechado
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  trailing: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLoteFechado
                          ? Colors.grey.shade300
                          : Colors.indigo.shade600,
                      foregroundColor: isLoteFechado
                          ? Colors.grey.shade600
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: isLoteFechado ? 0 : 2,
                    ),
                    icon: Icon(
                      isLoteFechado ? Icons.lock : Icons.lock_outline_rounded,
                      size: 16,
                    ),
                    label: Text(
                      isLoteFechado ? 'FECHADO' : 'FECHAR',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: isLoteFechado
                        ? null
                        : () async {
                            // 🔥 LÓGICA REAL DE BLOQUEIO NO FIREBASE
                            // Confirmação por segurança para não fechar sem querer
                            bool confirmacao =
                                await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar Fechamento'),
                                    content: Text(
                                      'Tem certeza que deseja fechar o lote de $nomeDoPredio?\n\nOs leituristas não poderão mais enviar ou editar leituras neste mês.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('CANCELAR'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'SIM, FECHAR LOTE',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirmacao) {
                              try {
                                // Adiciona o mês atual à array de lotes fechados no Firebase
                                await FirebaseFirestore.instance
                                    .collection('predios')
                                    .doc(predio.id)
                                    .set({
                                      'lotes_fechados': FieldValue.arrayUnion([
                                        mesAtual,
                                      ]),
                                    }, SetOptions(merge: true));

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Lote bloqueado com sucesso! Nenhuma leitura será alterada.',
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Erro ao bloquear lote: $e',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ============================================================================
// TELA 3: CONFIGURAÇÕES MARCA (MOTOR REAL DE UPLOAD E GRAVAÇÃO)
// ============================================================================

class TelaConfiguracoesMarca extends StatefulWidget {
  final String idAdministradora;
  const TelaConfiguracoesMarca({super.key, required this.idAdministradora});

  @override
  State<TelaConfiguracoesMarca> createState() => _TelaConfiguracoesMarcaState();
}

class _TelaConfiguracoesMarcaState extends State<TelaConfiguracoesMarca> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _whatsCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _urlLogoAtual;
  io.File? _novaImagem;

  @override
  void initState() {
    super.initState();
    _carregarDadosAtuais();
  }

  // Puxa os dados que já existem na nuvem para preencher a tela
  Future<void> _carregarDadosAtuais() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(widget.idAdministradora)
          .get();
      if (doc.exists) {
        var dados = doc.data() as Map<String, dynamic>;
        setState(() {
          _emailCtrl.text = dados['email_suporte'] ?? '';
          _whatsCtrl.text = dados['whatsapp_suporte'] ?? '';
          _urlLogoAtual = dados['url_logo'];
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar marca: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Abre a galeria do telemóvel para escolher a logo
  Future<void> _escolherImagem() async {
    // Requer o pacote image_picker no pubspec.yaml
    /* Descomente este bloco assim que o pacote estiver instalado
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    
    if (pickedFile != null) {
      setState(() {
        _novaImagem = io.File(pickedFile.path);
      });
    }
    */

    // Alerta provisório caso o pacote ainda não esteja ativo
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Pacote image_picker necessário para abrir a galeria!'),
      ),
    );
  }

  // Salva tudo no Firebase
  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);
    try {
      String? urlParaSalvar = _urlLogoAtual;

      // Se o utilizador escolheu uma foto nova, fazemos o upload para o Storage primeiro
      if (_novaImagem != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'logos_administradoras/logo_${widget.idAdministradora}.jpg',
        );
        await ref.putFile(_novaImagem!);
        urlParaSalvar = await ref.getDownloadURL();
      }

      // Atualiza o documento da Administradora com as novas configurações
      await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(widget.idAdministradora)
          .set({
            'email_suporte': _emailCtrl.text.trim(),
            'whatsapp_suporte': _whatsCtrl.text.trim(),
            'url_logo': urlParaSalvar,
          }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configurações de marca salvas com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Personalização Premium',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.teal.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.amber,
                          size: 30,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Plano White-Label. As configurações abaixo aparecerão em todos os PDFs oficiais.',
                            style: TextStyle(color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),

                  const Text(
                    'Logótipo Oficial',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _escolherImagem,
                    child: Container(
                      height: 120,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1.0,
                        ),
                        image: _novaImagem != null
                            ? DecorationImage(
                                image: FileImage(_novaImagem!),
                                fit: BoxFit.contain,
                              )
                            : (_urlLogoAtual != null
                                  ? DecorationImage(
                                      image: NetworkImage(_urlLogoAtual!),
                                      fit: BoxFit.contain,
                                    )
                                  : null),
                      ),
                      child: (_novaImagem == null && _urlLogoAtual == null)
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.upload_file_rounded,
                                  color: Colors.grey,
                                  size: 30,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Enviar imagem',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            )
                          : null,
                    ),
                  ),

                  const SizedBox(height: 30),
                  const Text(
                    'Contactos do Relatório',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail de Suporte',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _whatsCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'WhatsApp de Suporte',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                  ),

                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isSaving ? null : _salvarAlteracoes,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'SALVAR ALTERAÇÕES',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class TelaSuperAdminDashboard extends StatefulWidget {
  const TelaSuperAdminDashboard({super.key});

  @override
  State<TelaSuperAdminDashboard> createState() =>
      _TelaSuperAdminDashboardState();
}

class _TelaSuperAdminDashboardState extends State<TelaSuperAdminDashboard> {
  // 🟢 FUNÇÃO MÁGICA: IMPORTAÇÃO DO EXCEL
  // 🟢 NOVA ESTRATÉGIA: IMPORTAÇÃO POR COPIAR E COLAR (SMART PASTE)
  void _abrirDialogImportacao(String idAdministradora) {
    final TextEditingController _pasteController = TextEditingController();
    bool processando = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.paste_rounded, color: Color(0xFF0D47A1)),
                  SizedBox(width: 10),
                  Text(
                    'Importação Rápida (Smart Paste)',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Copie os dados diretamente do seu Excel e cole na caixa abaixo.\n'
                      'Ordem das colunas: Condomínio | Apto | Medidor',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 15),
                    TextField(
                      controller: _pasteController,
                      maxLines: 8,
                      decoration: InputDecoration(
                        hintText:
                            "Exemplo:\nEdifício Sol\t101\tÁgua\nEdifício Sol\t102\tGás",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    if (processando)
                      const Padding(
                        padding: EdgeInsets.only(top: 15),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: processando ? null : () => Navigator.pop(context),
                  child: const Text(
                    'CANCELAR',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: processando
                      ? null
                      : () async {
                          if (_pasteController.text.trim().isEmpty) return;
                          setStateDialog(() => processando = true);

                          await _processarTextoColado(
                            _pasteController.text,
                            idAdministradora,
                          );

                          if (context.mounted) Navigator.pop(context);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                  ),
                  child: const Text(
                    'IMPORTAR DADOS',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // O Motor que lê o texto colado e injeta no Firebase
  Future<void> _processarTextoColado(
    String textoBruto,
    String idAdministradora,
  ) async {
    try {
      // O Excel separa as linhas por "Enter" (\n) e as colunas por "Tab" (\t)
      List<String> linhas = textoBruto.trim().split('\n');

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int contador = 0;
      int totalImportados = 0;

      for (String linha in linhas) {
        if (linha.trim().isEmpty) continue;

        List<String> colunas = linha.split('\t');

        // Exige pelo menos Condominio e Apartamento (Medidor é bônus)
        if (colunas.length < 2) continue;

        String condominio = colunas[0].trim();
        String apartamento = colunas[1].trim();
        String medidor = colunas.length > 2 && colunas[2].trim().isNotEmpty
            ? colunas[2].trim()
            : 'Água';

        // Evita cabeçalhos colados por acidente
        if (condominio.toLowerCase() == 'condominio' ||
            apartamento.toLowerCase() == 'apartamento')
          continue;

        var docRef = FirebaseFirestore.instance.collection('leituras').doc();
        batch.set(docRef, {
          'id_administradora': idAdministradora,
          'condominio': condominio,
          'apartamento': apartamento,
          'medidor': medidor,
          'leitura_anterior': 0.0,
          'leitura_atual': 0.0,
          'consumo': 0.0,
          'teve_consumo': false,
          'tem_foto_anexada': false,
          'correcao_manual': true,
          'data_hora': FieldValue.serverTimestamp(),
          'importacao_lote': true,
        });

        contador++;
        totalImportados++;

        // Limite do Firebase Batch é 500
        if (contador >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          contador = 0;
        }
      }

      if (contador > 0) {
        await batch.commit();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ $totalImportados medidores importados com sucesso!',
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao processar dados: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  @override
  Widget build(BuildContext context) {
    const Color azulEscuro = Color(0xFF0A192F);
    const Color azul = Color(0xFF0D47A1);
    const Color fundo = Color(0xFFF5F6FA);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Painel Master SaaS',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        backgroundColor: azulEscuro,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
            tooltip: 'Sair do Sistema',
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  // Nota: Assegure-se que EcraLogin está importado no topo do seu ficheiro original
                  MaterialPageRoute(builder: (context) => const EcraLogin()),
                );
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // --- CABEÇALHO E KPIs (SOBREPOSTOS COM STACK) ---
          SliverToBoxAdapter(
            child: Stack(
              children: [
                // 1. Fundo Premium (Fica por trás)
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: azulEscuro,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Olá, MC Prestadora!',
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Gestão de Clientes',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Cartões Flutuantes (KPIs)
                Padding(
                  padding: const EdgeInsets.only(
                    top: 85,
                    left: 16,
                    right: 16,
                    bottom: 20,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _kpiCard(
                          'Empresas',
                          Icons.domain_rounded,
                          azul,
                          FirebaseFirestore.instance
                              .collection('administradoras')
                              .snapshots(),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _kpiCard(
                          'Gestores',
                          Icons.admin_panel_settings_rounded,
                          Colors.amber.shade700,
                          FirebaseFirestore.instance
                              .collection('usuarios')
                              .where('cargo', isEqualTo: 'admin')
                              .snapshots(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- BARRA DE PROGRESSO GLOBAL (OPERAÇÃO TOTAL MC PRESTADORA) ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: FutureBuilder<Map<String, dynamic>>(
                future: () async {
                  int totalApartamentos = 0;
                  int leiturasConcluidas = 0;

                  // Descobre o mês e ano atual
                  DateTime agora = DateTime.now();
                  String mesAnoFiltro = "${agora.month}_${agora.year}";

                  // Busca TODOS os prédios do sistema
                  var prediosSnapshot = await FirebaseFirestore.instance
                      .collection('predios')
                      .get();

                  for (var doc in prediosSnapshot.docs) {
                    var dados = doc.data();
                    if (dados['apartamentos'] != null) {
                      if (dados['apartamentos'] is List) {
                        totalApartamentos +=
                            (dados['apartamentos'] as List).length;
                      } else if (dados['apartamentos'] is num) {
                        totalApartamentos += (dados['apartamentos'] as num)
                            .toInt();
                      }
                    }
                  }

                  // Busca TODAS as leituras do sistema
                  var leiturasSnapshot = await FirebaseFirestore.instance
                      .collection('leituras')
                      .get();

                  for (var doc in leiturasSnapshot.docs) {
                    if (doc.id.endsWith(mesAnoFiltro)) {
                      leiturasConcluidas++;
                    }
                  }

                  double progresso = 0.0;
                  if (totalApartamentos > 0) {
                    progresso = leiturasConcluidas / totalApartamentos;
                  }

                  return {
                    'total': totalApartamentos,
                    'concluidas': leiturasConcluidas,
                    'porcentagem': progresso > 1.0 ? 1.0 : progresso,
                  };
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  }

                  var dadosOperacao =
                      snapshot.data ??
                      {'total': 0, 'concluidas': 0, 'porcentagem': 0.0};
                  double pctValor = dadosOperacao['porcentagem'] as double;
                  int pctTexto = (pctValor * 100).toInt();

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Progresso Global da Operação',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            Text(
                              '$pctTexto%',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(
                          value: pctValor,
                          backgroundColor: Colors.grey.shade200,
                          color: pctTexto == 100
                              ? Colors.green.shade600
                              : Colors.blue.shade600,
                          minHeight: 8,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dadosOperacao['concluidas']} de ${dadosOperacao['total']} medidores lidos neste mês.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // --- AÇÕES RÁPIDAS ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Expansão do Sistema',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          // Nota: Assegure-se que TelaCadastroAdministradora está importada
                          builder: (context) =>
                              const TelaCadastroAdministradora(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [azul, Colors.blue.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: azul.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.domain_add_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Novo Cliente',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                                Text(
                                  'Cadastrar uma nova administradora',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- LISTA DE CLIENTES ---
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 25, 20, 15),
              child: const Text(
                'Clientes Ativos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),
          ),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('administradoras')
                .orderBy('data_cadastro', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_center_rounded,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Nenhum cliente cadastrado.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 0,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    var doc = snapshot.data!.docs[index];
                    var adminData = doc.data() as Map<String, dynamic>;

                    String nome = adminData['nome_empresa'] ?? 'Empresa';
                    String inicial = nome.isNotEmpty
                        ? nome[0].toUpperCase()
                        : 'E';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: const EdgeInsets.fromLTRB(
                              16,
                              16,
                              16,
                              0,
                            ),
                            leading: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: azulEscuro.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  inicial,
                                  style: const TextStyle(
                                    color: azulEscuro,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              nome,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'CNPJ: ${adminData['cnpj'] ?? 'Não informado'}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // BOTÃO DE CRIAR ACESSO ADMIN
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.admin_panel_settings_rounded,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'Criar Acesso',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: azul,
                                      side: BorderSide(
                                        color: azul.withOpacity(0.5),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              TelaCriarAcessoCliente(
                                                idAdministradora: doc.id,
                                                nomeEmpresa: nome,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // BOTÃO ATUALIZADO PARA IMPORTAÇÃO EM MASSA
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.paste_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                    label: const Text(
                                      'Importar em Massa',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green.shade700,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      elevation: 0,
                                    ),
                                    onPressed: () =>
                                        _abrirDialogImportacao(doc.id),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }, childCount: snapshot.data!.docs.length),
                ),
              );
            },
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  // Widget Interno: Cartão de Estatísticas do Super Admin
  Widget _kpiCard(
    String titulo,
    IconData icon,
    Color cor,
    Stream<QuerySnapshot> stream,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cor, size: 28),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Text(
                  '...',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                );
              }
              int count = snapshot.data?.docs.length ?? 0;
              return Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              );
            },
          ),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
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
                                idAdministradora: widget
                                    .idAdministradora, // 👈 ENVIANDO O ID DA EMPRESA
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

class TelaRelatoriosPredio extends StatefulWidget {
  final String condominio;
  final String idAdministradora;

  const TelaRelatoriosPredio({
    super.key,
    required this.condominio,
    required this.idAdministradora,
  });

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
        if (m.contains('água') || m.contains('agua')) {
          tiposEncontrados.add('Agua');
        }
        if (m.contains('gás') || m.contains('gas')) {
          tiposEncontrados.add('Gas');
        }
        if (m.contains('luz') ||
            m.contains('energia') ||
            m.contains('eletricidade')) {
          tiposEncontrados.add('Energia');
        }
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
    // 🛑 FEEDBACK VISUAL IMEDIATO: Informa o usuário no ato do clique
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparando arquivo Excel...'),
          backgroundColor: Color(0xFF0D47A1),
          duration: Duration(seconds: 2),
        ),
      );
    }

    String nomeEmpresa = 'MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA';
    String cnpjEmpresa = 'Não informado';
    String emailEmpresa = 'anderson.mcservicos@gmail.com';
    String telefoneBruto = '(51) 98128-5818';
    String nomeContato = 'Anderson';

    try {
      // 🔍 BUSCA COM TIMEOUT LIMITADO: Não trava a UI caso a rede falhe
      final docAdmin = await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(widget.idAdministradora)
          .get()
          .timeout(const Duration(seconds: 4));

      if (docAdmin.exists && docAdmin.data() != null) {
        final dadosAdmin = docAdmin.data() as Map<String, dynamic>;
        nomeEmpresa = dadosAdmin['nome_empresa'] ?? nomeEmpresa;
        cnpjEmpresa = dadosAdmin['cnpj'] ?? cnpjEmpresa;
        emailEmpresa = dadosAdmin['email'] ?? emailEmpresa;
        telefoneBruto = dadosAdmin['telefone'] ?? telefoneBruto;
        nomeContato = dadosAdmin['nome_contato'] ?? nomeContato;
      }
    } catch (e) {
      debugPrint('SaaS White-Label fallback usado: $e');
    }

    String foneNumeros = telefoneBruto.replaceAll(RegExp(r'[^0-9]'), '');
    if (!foneNumeros.startsWith('55') && foneNumeros.isNotEmpty) {
      foneNumeros = '55' + foneNumeros;
    }
    if (foneNumeros.isEmpty) foneNumeros = '5551981285818';

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
    sheetObject.appendRow([TextCellValue(nomeEmpresa.toUpperCase())]);
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
    CellStyle estiloLinkDireto = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#0000FF'),
      underline: Underline.Single,
    );

    sheetObject.appendRow([
      TextCellValue(
        'Esta leitura foi realizada pelo sistema oficial de medição da empresa $nomeEmpresa.',
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

    sheetObject.appendRow([TextCellValue('CNPJ do Emissor: $cnpjEmpresa')]);
    sheetObject.appendRow([
      TextCellValue('Para contratar serviços ou obter informações de suporte:'),
    ]);

    int linhaEmail = sheetObject.maxRows;
    sheetObject.appendRow([
      FormulaCellValue(
        '=HYPERLINK("mailto:$emailEmpresa", "✉️ E-mail: $emailEmpresa (Clique para enviar)")',
      ),
    ]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linhaEmail),
            )
            .cellStyle =
        estiloLinkDireto;

    int linhaWhats = sheetObject.maxRows;
    sheetObject.appendRow([
      FormulaCellValue(
        '=HYPERLINK("https://wa.me/$foneNumeros", "💬 WhatsApp: $telefoneBruto (Clique para abrir a conversa)")',
      ),
    ]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linhaWhats),
            )
            .cellStyle =
        estiloLinkDireto;

    sheetObject.appendRow([TextCellValue('Responsável: $nomeContato')]);
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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erro ao compartilhar Excel: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _exportarParaPDF(
    BuildContext context,
    List<QueryDocumentSnapshot> leituras,
  ) async {
    // 🛑 FEEDBACK VISUAL IMEDIATO
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gerando Relatório Oficial PDF...'),
          backgroundColor: Color(0xFF0D47A1),
          duration: Duration(seconds: 3),
        ),
      );
    }

    String nomeEmpresa = 'MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA';
    String cnpjEmpresa = 'Não informado';
    String emailEmpresa = 'anderson.mcservicos@gmail.com';
    String telefoneBruto = '(51) 98128-5818';
    String nomeContato = 'Anderson';

    try {
      // 🔍 BUSCA COM TIMEOUT
      final docAdmin = await FirebaseFirestore.instance
          .collection('administradoras')
          .doc(widget.idAdministradora)
          .get()
          .timeout(const Duration(seconds: 4));

      if (docAdmin.exists && docAdmin.data() != null) {
        final dadosAdmin = docAdmin.data() as Map<String, dynamic>;
        nomeEmpresa = dadosAdmin['nome_empresa'] ?? nomeEmpresa;
        cnpjEmpresa = dadosAdmin['cnpj'] ?? cnpjEmpresa;
        emailEmpresa = dadosAdmin['email'] ?? emailEmpresa;
        telefoneBruto = dadosAdmin['telefone'] ?? telefoneBruto;
        nomeContato = dadosAdmin['nome_contato'] ?? nomeContato;
      }
    } catch (e) {
      debugPrint('SaaS White-Label fallback usado: $e');
    }

    String foneNumeros = telefoneBruto.replaceAll(RegExp(r'[^0-9]'), '');
    if (!foneNumeros.startsWith('55') && foneNumeros.isNotEmpty) {
      foneNumeros = '55' + foneNumeros;
    }
    if (foneNumeros.isEmpty) foneNumeros = '5551981285818';

    pw.MemoryImage? logoImage;
    try {
      final ByteData bytes = await rootBundle.load('assets/logo.png');
      logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      debugPrint('Aviso: Logo nativo ausente.');
    }

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
        } catch (e) {
          debugPrint('Foto remota indisponível para o PDF.');
        }
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
                        nomeEmpresa.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        "Relatório Oficial - ${widget.condominio}",
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.Text(
                        "CNPJ: $cnpjEmpresa",
                        style: const pw.TextStyle(
                          fontSize: 9,
                          color: PdfColors.grey700,
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
                    "Esta leitura foi realizada e auditada pelo sistema oficial de medição da empresa $nomeEmpresa.",
                    style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.orange800,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    "Para obter informações de faturamento ou suporte:",
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.UrlLink(
                        destination: 'mailto:$emailEmpresa',
                        child: pw.Text(
                          "E-mail: $emailEmpresa",
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue700,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                      pw.Text("  |  ", style: const pw.TextStyle(fontSize: 9)),
                      pw.UrlLink(
                        destination: 'https://wa.me/$foneNumeros',
                        child: pw.Text(
                          "Suporte WhatsApp: $telefoneBruto",
                          style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.blue700,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Responsável Técnico: $nomeContato",
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

    // 💡 AS VARIÁVEIS DO ARQUIVO AGORA ESTÃO NO ESCOPO CORRETO E SEGURO
    String prefixo = _gerarPrefixoMedidores(leituras);
    DateTime agora = DateTime.now();
    String dataArquivo =
        "${agora.day.toString().padLeft(2, '0')}-${agora.month.toString().padLeft(2, '0')}-${agora.year}";
    String nomeFicheiro =
        '${prefixo}${widget.condominio.replaceAll(' ', '_')}_$dataArquivo.pdf';

    try {
      await Printing.sharePdf(bytes: await pdf.save(), filename: nomeFicheiro);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao compartilhar PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('Nenhuma leitura encontrada.'));
          }

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

          DateTime hoje = DateTime.now();
          var leiturasFiltradas = mapaLeiturasUnicas.values.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            DateTime dataLeitura =
                (dados['data_hora'] as Timestamp? ?? Timestamp.now()).toDate();

            if (dataLeitura.month != hoje.month ||
                dataLeitura.year != hoje.year) {
              return false;
            }

            if (filtroAtual == 'Todos') return true;
            String medidorStr = dados['medidor'].toString().toLowerCase();

            if (filtroAtual == 'Água' &&
                (medidorStr.contains('água') || medidorStr.contains('agua'))) {
              return true;
            }
            if (filtroAtual == 'Gás' &&
                (medidorStr.contains('gás') || medidorStr.contains('gas'))) {
              return true;
            }
            if (filtroAtual == 'Energia' &&
                (medidorStr.contains('luz') ||
                    medidorStr.contains('energia') ||
                    medidorStr.contains('eletricidade'))) {
              return true;
            }

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
                            if (selected) {
                              setState(() {
                                filtroAtual = filtro;
                              });
                            }
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

// ================================================================
// TELA LISTA DA EQUIPE REGISTADA (Acessível via KPI do Dashboard)
// ================================================================
class TelaListaEquipe extends StatelessWidget {
  final String idAdministradora;
  const TelaListaEquipe({super.key, required this.idAdministradora});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text(
          'Equipe Registada',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .where('id_administradora', isEqualTo: idAdministradora)
            .where('cargo', isEqualTo: 'leiturista')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.group_off_rounded,
                    size: 80,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    'Nenhum leiturista na equipa.',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }

          var equipe = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: equipe.length,
            itemBuilder: (context, index) {
              var leiturista = equipe[index].data() as Map<String, dynamic>;
              String nome = leiturista['nome'] ?? 'Sem nome';
              String inicial = nome.isNotEmpty ? nome[0].toUpperCase() : '?';

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.only(bottom: 15),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor: Colors.green.shade100,
                    child: Text(
                      inicial,
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    nome,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Text(leiturista['email'] ?? 'Sem email'),
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                  ),
                ),
              );
            },
          );
        },
      ),
      // Botão Flutuante Rápido para adicionar mais
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green.shade700,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  TelaCadastroLeiturista(idAdministradora: idAdministradora),
            ),
          );
        },
        icon: const Icon(Icons.person_add_rounded, color: Colors.white),
        label: const Text(
          "Novo Leiturista",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
