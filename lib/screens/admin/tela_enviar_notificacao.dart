import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TelaEnviarNotificacao extends StatefulWidget {
  final String idAdministradora;
  const TelaEnviarNotificacao({super.key, required this.idAdministradora});

  @override
  State<TelaEnviarNotificacao> createState() => _TelaEnviarNotificacaoState();
}

class _TelaEnviarNotificacaoState extends State<TelaEnviarNotificacao> {
  final TextEditingController _tituloCtrl = TextEditingController();
  final TextEditingController _mensagemCtrl = TextEditingController();
  bool _enviando = false;

  List<Map<String, dynamic>> _leituristas = [];
  String _leituristaSelecionado = 'todos';

  // ✅ LINK DA VERCEL CONFIGURADO PERFEITAMENTE
  final String _vercelApiUrl = "https://leituras-mc.vercel.app/api/notificar";

  @override
  void initState() {
    super.initState();
    _carregarEquipe();
  }

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensagemCtrl.dispose();
    super.dispose();
  }

  Future<void> _carregarEquipe() async {
    try {
      var snap = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('id_administradora', isEqualTo: widget.idAdministradora)
          .where('cargo', isEqualTo: 'leiturista')
          .get();

      if (mounted) {
        setState(() {
          _leituristas = snap.docs.map((d) {
            var data = d.data();
            data['id'] = d.id;
            return data;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint("Erro ao carregar equipe: $e");
    }
  }

  Future<void> _enviar() async {
    if (_tituloCtrl.text.trim().isEmpty || _mensagemCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha título e mensagem!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);

    try {
      // 1. Grava no banco apenas para o histórico (Auditoria)
      await FirebaseFirestore.instance.collection('notificacoes_enviadas').add({
        'id_administradora': widget.idAdministradora,
        'destinatario_id': _leituristaSelecionado == 'todos'
            ? null
            : _leituristaSelecionado,
        'destinatario_tipo': _leituristaSelecionado == 'todos'
            ? 'equipe_inteira'
            : 'individual',
        'titulo': _tituloCtrl.text.trim(),
        'mensagem': _mensagemCtrl.text.trim(),
        'data_criacao': FieldValue.serverTimestamp(),
      });

      // 2. Avisa a Vercel para fazer o disparo pros telemóveis!
      final resposta = await http.post(
        Uri.parse(_vercelApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'titulo': _tituloCtrl.text.trim(),
          'mensagem': _mensagemCtrl.text.trim(),
          'destinatario_id': _leituristaSelecionado,
        }),
      );

      if (mounted) {
        if (resposta.statusCode == 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Aviso disparado com sucesso pelos servidores da Vercel!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          // Exibe o erro se a Vercel reclamar de algo
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erro na Vercel: ${resposta.statusCode} - ${resposta.body}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Falha de conexão: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enviar Aviso Push',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.blue.shade900.withOpacity(0.3)
                    : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_active,
                    color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'A mensagem será processada pelo nosso servidor gratuito (Vercel) e aparecerá imediatamente no telemóvel da equipa.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.blue.shade100
                            : Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            Text(
              'Para quem é o aviso?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _leituristaSelecionado,
                  isExpanded: true,
                  dropdownColor: isDark
                      ? const Color(0xFF2A2A2A)
                      : Colors.white,
                  items: [
                    const DropdownMenuItem(
                      value: 'todos',
                      child: Text('📣 Todos os Leituristas'),
                    ),
                    ..._leituristas.map(
                      (l) => DropdownMenuItem(
                        value: l['id'],
                        child: Text('👤 ${l['nome'] ?? 'Sem nome'}'),
                      ),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _leituristaSelecionado = val!),
                ),
              ),
            ),

            const SizedBox(height: 25),
            Text(
              'Conteúdo da Mensagem',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _tituloCtrl,
              decoration: const InputDecoration(
                labelText: 'Título Curto (Ex: Novo Prédio)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _mensagemCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Mensagem detalhada...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                ),
                icon: _enviando
                    ? const SizedBox()
                    : const Icon(Icons.rocket_launch, color: Colors.white),
                label: _enviando
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'DISPARAR VIA VERCEL',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                onPressed: _enviando ? null : _enviar,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
