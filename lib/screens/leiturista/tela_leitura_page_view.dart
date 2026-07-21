import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import '../../services/banco_local.dart';
import '../../core/formatters.dart';
// Note que importei do path correto. Será criado depois caso não exista.
import '../../config/app_config.dart';

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
        if (mounted) {
          setState(() {
            loteFechado = lotes.contains(mesAtual);
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

  Future<void> _lerComIA() async {
    final fotoOriginal = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    if (fotoOriginal == null) return;
    setState(() => processandoIA = true);

    try {
      final bytes = await fotoOriginal.readAsBytes();
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
          fotoComprovante = fotoOriginal;
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
      double limiteConsumoSeguro = 1.0;
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
                    color: loteFechado ? Colors.grey.shade100 : Colors.white,
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
                        readOnly: loteFechado,
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
                          hintStyle: const TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCFD8DC),
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
