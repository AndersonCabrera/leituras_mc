import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/mercadopago_service.dart';
import 'tela_status_assinatura.dart';

class TelaPixPagamento extends StatefulWidget {
  final String idAdministradora;
  final String qrCodeBase64;
  final String qrCodeTexto;
  final String ticketUrl;
  final double valor;
  final int faturaId;

  const TelaPixPagamento({
    super.key,
    required this.idAdministradora,
    required this.qrCodeBase64,
    required this.qrCodeTexto,
    required this.ticketUrl,
    required this.valor,
    required this.faturaId,
  });

  @override
  State<TelaPixPagamento> createState() => _TelaPixPagamentoState();
}

class _TelaPixPagamentoState extends State<TelaPixPagamento> {
  Timer? _pollTimer;
  bool _pago = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _verificarPagamento());
  }

  Future<void> _verificarPagamento() async {
    final status = await MercadoPagoService.verificarStatus(
      idAdministradora: widget.idAdministradora,
    );
    if (status['status_assinatura'] == 'active' && mounted) {
      _pollTimer?.cancel();
      setState(() => _pago = true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TelaStatusAssinatura(
            idAdministradora: widget.idAdministradora,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  ImageProvider? _decodificarQr() {
    try {
      final bytes = base64Decode(widget.qrCodeBase64);
      return MemoryImage(Uint8List.fromList(bytes));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrImage = _decodificarQr();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pagamento PIX', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.pix, size: 64, color: Colors.blue.shade700),
            const SizedBox(height: 16),
            Text(
              'R\$ ${widget.valor.toStringAsFixed(2).replaceAll('.', ',')}',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Escaneie o QR Code abaixo para pagar',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: qrImage != null
                  ? Image(image: qrImage, width: 250, height: 250)
                  : Container(
                      width: 250,
                      height: 250,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('QR Code indisponível')),
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: widget.qrCodeTexto));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código PIX copiado!')),
                  );
                },
                icon: const Icon(Icons.copy, color: Colors.white),
                label: const Text(
                  'COPIAR CÓDIGO PIX',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            if (widget.ticketUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.open_in_new, color: Colors.white),
                  label: const Text(
                    'ABRIR PAGAMENTO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Text(
                  'Aguardando confirmação...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
