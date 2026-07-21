import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io' as io;

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

  // Correção de Fuga de Memória (Memory Leak) apontada no relatório
  @override
  void dispose() {
    _emailCtrl.dispose();
    _whatsCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _escolherImagem() async {
    // Agora o pacote image_picker está funcional
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (pickedFile != null) {
      setState(() {
        _novaImagem = io.File(pickedFile.path);
      });
    }
  }

  Future<void> _salvarAlteracoes() async {
    setState(() => _isSaving = true);
    try {
      String? urlParaSalvar = _urlLogoAtual;

      if (_novaImagem != null) {
        final ref = FirebaseStorage.instance.ref().child(
          'logos_administradoras/logo_${widget.idAdministradora}.jpg',
        );
        await ref.putFile(_novaImagem!);
        urlParaSalvar = await ref.getDownloadURL();
      }

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
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
