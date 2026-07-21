import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide BorderStyle, Border;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:io' as io;
import 'package:flutter/services.dart' show ByteData, rootBundle;

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
                                idAdministradora: widget.idAdministradora,
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
    if (!foneNumeros.startsWith('55') && foneNumeros.isNotEmpty)
      foneNumeros = '55$foneNumeros';
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
      'Correção Manual',
      'Status Auditoria',
      'Evidência Visual (Foto)',
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
      bool correcao = dados['correcao_manual'] ?? false;
      String auditoria =
          dados['status_auditoria'] ??
          (dados['tem_foto_anexada'] == true ? 'Aguardando Revisão' : 'Normal');

      sheetObject.appendRow([
        TextCellValue(dataFormatada),
        TextCellValue(apto),
        TextCellValue(medidor),
        DoubleCellValue(ant),
        DoubleCellValue(atual),
        DoubleCellValue(cons),
        TextCellValue(correcao ? 'Sim' : 'Não'),
        TextCellValue(auditoria),
        TextCellValue(linkFoto.isEmpty ? 'Não exigida' : linkFoto),
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
          CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex),
        );
        celulaLink.value = FormulaCellValue(
          '=HYPERLINK("$linkFoto", "VER FOTO DE EVIDÊNCIA")',
        );
        celulaLink.cellStyle = CellStyle(
          fontColorHex: ExcelColor.fromHexString('#0000FF'),
          underline: Underline.Single,
          bold: true,
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
        'Esta leitura foi realizada e auditada pelo sistema oficial de medição da empresa $nomeEmpresa.',
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
        '=HYPERLINK("mailto:$emailEmpresa", "✉️ E-mail: $emailEmpresa")',
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
        '=HYPERLINK("https://wa.me/$foneNumeros", "💬 WhatsApp: $telefoneBruto")',
      ),
    ]);
    sheetObject
            .cell(
              CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: linhaWhats),
            )
            .cellStyle =
        estiloLinkDireto;

    sheetObject.appendRow([TextCellValue('Responsável Técnico: $nomeContato')]);
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
                content: Text('Erro ao compartilhar Excel: $e'),
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
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Construindo Laudo Técnico em PDF...'),
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
    String? urlLogoFirebase;

    try {
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
        urlLogoFirebase = dadosAdmin['url_logo'];
      }
    } catch (e) {
      debugPrint('Fallback White-Label: $e');
    }

    String foneNumeros = telefoneBruto.replaceAll(RegExp(r'[^0-9]'), '');
    if (!foneNumeros.startsWith('55') && foneNumeros.isNotEmpty)
      foneNumeros = '55$foneNumeros';

    pw.ImageProvider? logoImage;
    if (urlLogoFirebase != null && urlLogoFirebase.isNotEmpty) {
      try {
        logoImage = await networkImage(urlLogoFirebase);
      } catch (e) {
        debugPrint('Erro ao carregar logo do Firebase no PDF: $e');
      }
    } else {
      try {
        final ByteData bytes = await rootBundle.load('assets/logo.png');
        logoImage = pw.MemoryImage(bytes.buffer.asUint8List());
      } catch (e) {
        debugPrint('Sem logo nativa.');
      }
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
          debugPrint('Foto de auditoria indisponível.');
        }
      }

      bool isAprovado = dados['status_auditoria'] == 'aprovado';
      bool temFoto = dados['tem_foto_anexada'] == true;

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
                      'Apto: ${dados['apartamento'] ?? '-'}',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 5),
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
                      'Consumo: ${dados['consumo']?.toStringAsFixed(3) ?? '-'}',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.red700,
                      ),
                    ),
                    if (temFoto) ...[
                      pw.SizedBox(height: 5),
                      pw.Text(
                        isAprovado
                            ? '✓ Leitura Auditada e Aprovada'
                            : '⚠️ Aguardando Auditoria',
                        style: pw.TextStyle(
                          color: isAprovado
                              ? PdfColors.green700
                              : PdfColors.orange700,
                          fontWeight: pw.FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
                    'Sem Evidência',
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
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue800,
                        ),
                      ),
                      pw.Text(
                        "Relatório de leitura: ${widget.condominio}",
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
                    pw.Container(
                      height: 60,
                      width: 120,
                      alignment: pw.Alignment.centerRight,
                      child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                    ),
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
                    "Leitura realizada e auditada pela $nomeEmpresa.",
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

    String prefixo = _gerarPrefixoMedidores(leituras);
    DateTime agora = DateTime.now();
    String dataArquivo =
        "${agora.day.toString().padLeft(2, '0')}-${agora.month.toString().padLeft(2, '0')}-${agora.year}";
    String nomeFicheiro =
        '${prefixo}${widget.condominio.replaceAll(' ', '_')}_$dataArquivo.pdf';

    try {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: nomeFicheiro,
      );
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao imprimir PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
            if (!mapaLeiturasUnicas.containsKey(chaveUnica))
              mapaLeiturasUnicas[chaveUnica] = doc;
          }

          DateTime hoje = DateTime.now();
          var leiturasFiltradas = mapaLeiturasUnicas.values.where((doc) {
            var dados = doc.data() as Map<String, dynamic>;
            DateTime dataLeitura =
                (dados['data_hora'] as Timestamp? ?? Timestamp.now()).toDate();
            if (dataLeitura.month != hoje.month ||
                dataLeitura.year != hoje.year)
              return false;
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
                            if (selected) setState(() => filtroAtual = filtro);
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
