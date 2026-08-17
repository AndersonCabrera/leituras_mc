import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TelaDebugDados extends StatefulWidget {
  final String idAdministradora;
  const TelaDebugDados({super.key, required this.idAdministradora});

  @override
  State<TelaDebugDados> createState() => _TelaDebugDadosState();
}

class _TelaDebugDadosState extends State<TelaDebugDados> {
  bool _mostrarJson = false;
  String _filtro = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug - Dados Firestore', style: TextStyle(color: Colors.white, fontSize: 16)),
        backgroundColor: Colors.grey.shade900,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_mostrarJson ? Icons.list : Icons.code, color: Colors.white),
            tooltip: _mostrarJson ? 'Modo Lista' : 'Modo JSON',
            onPressed: () => setState(() => _mostrarJson = !_mostrarJson),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey.shade100,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Filtrar por nome...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('predios')
                  .where('id_administradora', isEqualTo: widget.idAdministradora)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Nenhum prédio encontrado.'));
                }

                var docs = snapshot.data!.docs.where((doc) {
                  if (_filtro.isEmpty) return true;
                  var dados = doc.data() as Map<String, dynamic>;
                  var nome = (dados['nome_predio'] ?? dados['nome'] ?? '').toString().toLowerCase();
                  return nome.contains(_filtro);
                }).toList();

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var dados = doc.data() as Map<String, dynamic>;

                    if (_mostrarJson) {
                      return _cardJson(doc.id, dados);
                    }
                    return _cardResumo(doc.id, dados);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardResumo(String docId, Map<String, dynamic> dados) {
    String nome = dados['nome_predio'] ?? dados['nome'] ?? 'Sem nome';
    String endereco = dados['endereco'] ?? 'Sem endereço';

    List apartamentos = dados['apartamentos'] ?? [];
    List leituristas = dados['leituristas_permitidos'] ?? [];
    List lotesFechados = dados['lotes_fechados'] ?? [];
    List tiposMedicao = dados['tipos_medicao'] ?? [];

    bool temAgua = dados['tem_medidor_agua'] ?? false;
    bool temGas = dados['tem_medidor_gas'] ?? false;
    bool temElec = dados['tem_medidor_eletricidade'] ?? false;

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
                Icon(Icons.apartment, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nome,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(endereco, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
            const Divider(height: 20),
            _linha('ID Firestore', docId, Colors.grey.shade500),
            _linha('Admin ID', dados['id_administradora'] ?? dados['admin_id'] ?? '-', Colors.grey.shade500),
            _linha('Apartamentos (${apartamentos.length})',
                apartamentos.length <= 10
                    ? apartamentos.join(', ')
                    : '${apartamentos.take(10).join(', ')}... (+${apartamentos.length - 10})',
                Colors.blue.shade700),
            _linha('Leituristas (${leituristas.length})', dados['leiturista_nome'] ?? '-', Colors.green.shade700),
            _linha('Medidores', _formatarMedidores(temAgua, temGas, temElec, tiposMedicao), Colors.orange.shade700),
            _linha('Limite Consumo', '${dados['limite_consumo_alerta'] ?? 1.0}', Colors.purple.shade700),
            if (lotesFechados.isNotEmpty)
              _linha('Lotes Fechados', lotesFechados.join(', '), Colors.red.shade700),
            if (dados['data_cadastro'] != null)
              _linha('Data Cadastro', _formatarData(dados['data_cadastro']), Colors.grey.shade500),
          ],
        ),
      ),
    );
  }

  Widget _cardJson(String docId, Map<String, dynamic> dados) {
    String nome = dados['nome_predio'] ?? dados['nome'] ?? 'Sem nome';
    String jsonStr = _mapToJson(dados, 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ExpansionTile(
        title: Text(nome, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('ID: $docId', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  Widget _linha(String label, String valor, Color corValor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(
              valor,
              style: TextStyle(fontSize: 12, color: corValor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarMedidores(bool agua, bool gas, bool elec, List tipos) {
    List<String> m = [];
    if (tipos.isNotEmpty) {
      m.addAll(tipos.map((e) => e.toString()));
    } else {
      if (agua) m.add('Água');
      if (gas) m.add('Gás');
      if (elec) m.add('Luz');
    }
    return m.isEmpty ? '-' : m.join(', ');
  }

  String _formatarData(dynamic ts) {
    if (ts is Timestamp) {
      var d = ts.toDate();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }
    return ts?.toString() ?? '-';
  }

  String _mapToJson(Map<String, dynamic> map, int indent) {
    String prefix = '  ' * indent;
    String childPrefix = '  ' * (indent + 1);
    StringBuffer sb = StringBuffer('$prefix{\n');
    map.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        sb.write('$childPrefix"$key": ${_mapToJson(value, indent + 1)},\n');
      } else if (value is List) {
        sb.write('$childPrefix"$key": ${value.map((e) => '"$e"').toList()},\n');
      } else if (value is Timestamp) {
        sb.write('$childPrefix"$key": "${_formatarData(value)}",\n');
      } else if (value is FieldValue) {
        sb.write('$childPrefix"$key": "FieldValue(serverTimestamp)",\n');
      } else {
        sb.write('$childPrefix"$key": "$value",\n');
      }
    });
    sb.write('$prefix}');
    return sb.toString();
  }
}
