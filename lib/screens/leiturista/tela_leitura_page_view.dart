import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../../services/banco_local.dart';
import '../../core/formatters.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Lista de Apartamentos",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
            ),
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
                  Color textColor = isDark ? Colors.white : Colors.black87;

                  // Lógica de Cores Inteligentes (Dark/Light Mode)
                  if (status == StatusLeitura.lido) {
                    bgColor = isDark
                        ? Colors.green.shade900.withOpacity(0.4)
                        : Colors.green.shade100;
                    textColor = isDark
                        ? Colors.green.shade300
                        : Colors.green.shade900;
                  } else if (status == StatusLeitura.lendo) {
                    bgColor = isDark
                        ? Colors.amber.shade900.withOpacity(0.4)
                        : Colors.amber.shade100;
                    textColor = isDark
                        ? Colors.amber.shade300
                        : Colors.amber.shade900;
                  } else {
                    bgColor = isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200;
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
                                color: isDark
                                    ? Colors.blue.shade300
                                    : const Color(0xFF0D47A1),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final azul = isDark ? Colors.blueGrey.shade900 : const Color(0xFF0D47A1);
    final total = widget.apartamentos.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

  double? leituraAnterior;
  String referenciaAnterior = '--/----';
  bool carregandoLeitura = true;
  double? leituraAtual;
  double? consumoCalculado;
  bool modoEdicao = false;
  String? idLeituraExistente;
  bool houveTrocaOuCorrecao = false;
  bool loteFechado = false;
  double limiteConsumoCustomizado = 1.0;

  final ImagePicker _picker = ImagePicker();
  XFile? fotoComprovante;
  bool salvando = false;

  final TextEditingController _leituraCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    if (widget.medidores.isNotEmpty) {
      _buscarLeituraAnterior();
      _verificarLoteFechado();
    }
    Future.delayed(const Duration(milliseconds: 300), () {
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
        loteFechado = false;
        _leituraCtrl.clear();
        leituraAtual = null;
        consumoCalculado = null;
        houveTrocaOuCorrecao = false;
      });
      _buscarLeituraAnterior();
      _verificarLoteFechado();
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

  Future<void> _verificarLoteFechado() async {
    try {
      DateTime agora = DateTime.now();
      String mesAtual = "${agora.month}_${agora.year}";
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

        double limite = 1.0;
        if (dados.containsKey('limite_consumo_alerta')) {
          limite = (dados['limite_consumo_alerta'] as num).toDouble();
        }

        if (mounted) {
          setState(() {
            loteFechado = lotes.contains(mesAtual);
            limiteConsumoCustomizado = limite;
            if (loteFechado) _focusNode.unfocus();
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
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (foto != null) setState(() => fotoComprovante = foto);
  }

  Future<void> _abrirGaleria() async {
    final foto = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (foto != null) setState(() => fotoComprovante = foto);
  }

  void _verificarEGuardar() {
    if (leituraAtual != null &&
        leituraAnterior != null &&
        !houveTrocaOuCorrecao) {
      double limiteConsumoSeguro = limiteConsumoCustomizado;

      if (consumoCalculado! >= limiteConsumoSeguro) {
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
                'Alerta de Consumo!\n\n'
                'O consumo calculado (${consumoCalculado!.toStringAsFixed(3).replaceAll('.', ',')} $unidadeAtual) atingiu ou ultrapassou a marca de $limiteConsumoSeguro $unidadeAtual.\n\n'
                'Tire uma foto do visor do medidor para comprovar a leitura ao síndico.',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                color: isDark ? Colors.grey.shade700 : const Color(0xFFCFD8DC),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Opções adicionais',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF37474F),
              ),
            ),
            const SizedBox(height: 16),
            _ItemMenu(
              icon: Icons.photo_library_rounded,
              cor: isDark ? Colors.blue.shade300 : _azul,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Variáveis de Cor Inteligentes
    final corCartao = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final corBorda = isDark ? Colors.grey.shade800 : const Color(0xFFECEFF1);
    final corTextoForte = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final corTextoFraco = isDark
        ? Colors.grey.shade400
        : const Color(0xFF90A4AE);
    final corDestaque = isDark ? Colors.blue.shade300 : _azul;
    final corFundoInput = isDark
        ? const Color(0xFF2A2A2A)
        : const Color(0xFFF5F6FA);

    final leituraInvalida =
        leituraAnterior != null &&
        consumoCalculado != null &&
        consumoCalculado! < 0 &&
        !houveTrocaOuCorrecao;
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
                        style: TextStyle(
                          fontSize: 52,
                          fontWeight: FontWeight.w700,
                          color: corTextoForte,
                          letterSpacing: -1,
                          height: 1,
                        ),
                      ),
                      Text(
                        'Apartamento',
                        style: TextStyle(
                          fontSize: 13,
                          color: corTextoFraco,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                if (loteFechado)
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.red.shade900.withOpacity(0.3)
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.red.shade800
                            : Colors.red.shade200,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: isDark
                              ? Colors.red.shade400
                              : Colors.red.shade700,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Lote Encerrado.\nA administradora bloqueou o envio ou edição de leituras para este prédio.',
                            style: TextStyle(
                              color: isDark
                                  ? Colors.red.shade200
                                  : Colors.red.shade900,
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
                              color: sel ? corDestaque : corCartao,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? corDestaque : corBorda,
                                width: 0.8,
                              ),
                              boxShadow: sel
                                  ? [
                                      BoxShadow(
                                        color: corDestaque.withOpacity(0.2),
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
                                    ? (isDark ? Colors.black : Colors.white)
                                    : corTextoFraco,
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
                    color: corCartao,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: corBorda, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: isDark
                            ? Colors.grey.shade600
                            : const Color(0xFFB0BEC5),
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Leitura anterior',
                            style: TextStyle(
                              fontSize: 12,
                              color: corTextoFraco,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            referenciaAnterior,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : const Color(0xFF607D8B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      carregandoLeitura
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: corTextoFraco,
                              ),
                            )
                          : Text(
                              leituraAnterior == null
                                  ? 'Offline'
                                  : '${leituraAnterior!.toStringAsFixed(3).replaceAll('.', ',')} $unidade',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade200
                                    : const Color(0xFF546E7A),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: loteFechado
                        ? (isDark ? Colors.grey.shade900 : Colors.grey.shade100)
                        : corCartao,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: leituraInvalida
                          ? (isDark ? Colors.red.shade800 : Colors.red.shade300)
                          : _leituraCtrl.text.isNotEmpty
                          ? corDestaque.withOpacity(0.4)
                          : corBorda,
                      width: leituraInvalida || _leituraCtrl.text.isNotEmpty
                          ? 1.2
                          : 0.8,
                    ),
                    boxShadow: _leituraCtrl.text.isNotEmpty && !leituraInvalida
                        ? [
                            BoxShadow(
                              color: corDestaque.withOpacity(
                                isDark ? 0.3 : 0.08,
                              ),
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
                              color: loteFechado ? Colors.grey : corDestaque,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Leitura atual',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: loteFechado ? Colors.grey : corDestaque,
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
                                  color: corFundoInput,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.more_horiz_rounded,
                                      color: corTextoFraco,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Mais',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: corTextoFraco,
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
                        readOnly: loteFechado,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          color: loteFechado ? Colors.grey : corTextoForte,
                          letterSpacing: 1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        decoration: InputDecoration(
                          hintText: '0000,000',
                          hintStyle: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.grey.shade800
                                : const Color(0xFFCFD8DC),
                            letterSpacing: 1,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          suffixText: unidade,
                          suffixStyle: TextStyle(
                            fontSize: 16,
                            color: corTextoFraco,
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
                        ? corFundoInput
                        : leituraInvalida
                        ? (isDark
                              ? Colors.red.shade900.withOpacity(0.2)
                              : Colors.red.shade50)
                        : (isDark
                              ? Colors.green.shade900.withOpacity(0.2)
                              : Colors.green.shade50),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: consumoCalculado == null
                          ? corBorda
                          : leituraInvalida
                          ? (isDark ? Colors.red.shade800 : Colors.red.shade200)
                          : (isDark
                                ? Colors.green.shade800
                                : Colors.green.shade200),
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
                                ? (isDark
                                      ? Colors.grey.shade600
                                      : const Color(0xFFB0BEC5))
                                : leituraInvalida
                                ? (isDark
                                      ? Colors.red.shade400
                                      : Colors.red.shade600)
                                : (isDark
                                      ? Colors.green.shade400
                                      : Colors.green.shade600),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Consumo apurado',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: consumoCalculado == null
                                  ? (isDark
                                        ? Colors.grey.shade600
                                        : const Color(0xFFB0BEC5))
                                  : leituraInvalida
                                  ? (isDark
                                        ? Colors.red.shade400
                                        : Colors.red.shade700)
                                  : (isDark
                                        ? Colors.green.shade400
                                        : Colors.green.shade700),
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
                              ? (isDark
                                    ? Colors.grey.shade700
                                    : const Color(0xFFCFD8DC))
                              : leituraInvalida
                              ? (isDark
                                    ? Colors.red.shade400
                                    : Colors.red.shade700)
                              : (isDark
                                    ? Colors.green.shade400
                                    : Colors.green.shade700),
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
                      color: corCartao,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: fotoComprovante != null
                            ? (isDark
                                  ? Colors.green.shade600
                                  : Colors.green.shade300)
                            : corBorda,
                        width: 0.8,
                      ),
                    ),
                    child: fotoComprovante != null
                        ? Row(
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: isDark
                                    ? Colors.green.shade400
                                    : Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Foto anexada',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDark
                                        ? Colors.green.shade400
                                        : Colors.green,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: loteFechado
                                    ? null
                                    : () => setState(
                                        () => fotoComprovante = null,
                                      ),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: isDark
                                      ? Colors.grey.shade600
                                      : const Color(0xFFB0BEC5),
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
                                    ? Colors.grey.shade600
                                    : corTextoFraco,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Tirar foto (opcional)',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: loteFechado
                                      ? Colors.grey.shade600
                                      : corTextoFraco,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: loteFechado
                                    ? Colors.grey.shade800
                                    : (isDark
                                          ? Colors.grey.shade700
                                          : const Color(0xFFCFD8DC)),
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
                        ? (isDark
                              ? Colors.red.shade900.withOpacity(0.2)
                              : Colors.red.shade50)
                        : corCartao,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: houveTrocaOuCorrecao
                          ? (isDark ? Colors.red.shade800 : Colors.red.shade200)
                          : corBorda,
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
                            : (isDark
                                  ? Colors.grey.shade200
                                  : const Color(0xFF37474F)),
                      ),
                    ),
                    subtitle: Text(
                      'Permite leitura menor que a anterior',
                      style: TextStyle(
                        fontSize: 12,
                        color: loteFechado
                            ? Colors.grey.shade600
                            : corTextoFraco,
                      ),
                    ),
                    value: houveTrocaOuCorrecao,
                    activeColor: isDark
                        ? Colors.red.shade500
                        : Colors.red.shade700,
                    checkColor: isDark ? Colors.black : Colors.white,
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
                        color: isDark
                            ? Colors.red.shade900.withOpacity(0.2)
                            : Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? Colors.red.shade800
                              : Colors.red.shade200,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            color: isDark
                                ? Colors.red.shade400
                                : Colors.red.shade700,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Leitura menor que a anterior',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.red.shade400
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'MC PRESTADORA DE SERVIÇOS CONDOMINIAIS LTDA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? Colors.grey.shade700
                          : const Color(0xFFB0BEC5),
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
            color: corCartao,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
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
                        color: widget.isPrimeiro
                            ? (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300)
                            : corDestaque,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 30,
                      color: widget.isPrimeiro
                          ? (isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade400)
                          : corDestaque,
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
                                  : (isDark ? Colors.black : Colors.white),
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
                              : (isDark ? Colors.black : Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: corDestaque,
                        disabledBackgroundColor: isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300,
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
                        color: widget.isUltimo
                            ? (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade300)
                            : corDestaque,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 30,
                      color: widget.isUltimo
                          ? (isDark
                                ? Colors.grey.shade700
                                : Colors.grey.shade400)
                          : corDestaque,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: carregando ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F6FA),
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
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF37474F),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.grey.shade400
                          : const Color(0xFF90A4AE),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDark ? Colors.grey.shade600 : const Color(0xFFCFD8DC),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
