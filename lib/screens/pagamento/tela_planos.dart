import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/plano.dart';
import '../../services/mercadopago_service.dart';
import 'tela_pix_pagamento.dart';
import 'tela_status_assinatura.dart';

class TelaPlanos extends StatefulWidget {
  final String idAdministradora;
  final String emailAdmin;
  final String nomeEmpresa;
  final String planoAtual;

  const TelaPlanos({
    super.key,
    required this.idAdministradora,
    required this.emailAdmin,
    required this.nomeEmpresa,
    required this.planoAtual,
  });

  @override
  State<TelaPlanos> createState() => _TelaPlanosState();
}

class _TelaPlanosState extends State<TelaPlanos> {
  bool _carregando = false;

  Future<void> _assinar(Plano plano) async {
    setState(() => _carregando = true);

    try {
      final result = await MercadoPagoService.criarAssinatura(
        idAdministradora: widget.idAdministradora,
        plano: plano.id,
        emailAdmin: widget.emailAdmin,
        nomeEmpresa: widget.nomeEmpresa,
      );

      if (result.containsKey('erro')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro: ${result['erro']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TelaPixPagamento(
              idAdministradora: widget.idAdministradora,
              qrCodeBase64: result['qr_code_base64'] as String? ?? '',
              qrCodeTexto: result['qr_code'] as String? ?? '',
              ticketUrl: result['ticket_url'] as String? ?? '',
              valor: (result['valor'] as num?)?.toDouble() ?? 0,
              faturaId: result['id_fatura'] as int? ?? 0,
            ),
          ),
        );
      }
    } finally {
      setState(() => _carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color corCartao = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color corTexto = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0D47A1),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 10),
          Text(
            'Escolha o plano ideal para sua administradora',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: corTexto),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Pagamento via PIX. Cancele quando quiser.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ...Plano.planos
              .where((p) => !p.isGratis)
              .map((plano) => _PlanoCard(
                    plano: plano,
                    isAtual: widget.planoAtual == plano.id,
                    isDark: isDark,
                    corCartao: corCartao,
                    corTexto: corTexto,
                    carregando: _carregando,
                    onAssinar: () => _assinar(plano),
                  )),
        ],
      ),
    );
  }
}

class _PlanoCard extends StatelessWidget {
  final Plano plano;
  final bool isAtual;
  final bool isDark;
  final Color corCartao;
  final Color corTexto;
  final bool carregando;
  final VoidCallback onAssinar;

  const _PlanoCard({
    required this.plano,
    required this.isAtual,
    required this.isDark,
    required this.corCartao,
    required this.corTexto,
    required this.carregando,
    required this.onAssinar,
  });

  @override
  Widget build(BuildContext context) {
    final isPremium = plano.id == 'premium';
    final isSuperPremium = plano.id == 'super_premium';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: corCartao,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSuperPremium
              ? Colors.amber.shade400
              : isPremium
                  ? Colors.blue.shade300
                  : Colors.grey.shade300,
          width: isSuperPremium ? 2 : 1,
        ),
        boxShadow: [
          if (isSuperPremium)
            BoxShadow(
              color: Colors.amber.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        children: [
          if (isSuperPremium)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade600, Colors.orange.shade700],
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
              ),
              child: const Text(
                'MAIS POPULAR',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 2,
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  isSuperPremium ? Icons.diamond_rounded : Icons.star_rounded,
                  size: 48,
                  color: isSuperPremium ? Colors.amber : Colors.blue,
                ),
                const SizedBox(height: 12),
                Text(
                  plano.nome,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: corTexto,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'R\$${plano.precoReal.toStringAsFixed(0).replaceAll('.', ',')}',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: isSuperPremium ? Colors.amber.shade700 : Colors.blue.shade700,
                  ),
                ),
                Text(
                  '/mês',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 20),
                _beneficio(Icons.apartment, plano.limiteCondominiosTexto),
                _beneficio(Icons.people, plano.limiteLeituristasTexto),
                _beneficio(
                  Icons.description,
                  plano.relatoriosPersonalizados
                      ? 'Relatórios PDF e Excel'
                      : 'Apenas relatórios básicos',
                  destaque: plano.relatoriosPersonalizados,
                ),
                _beneficio(
                  Icons.brush,
                  plano.marcaPropria ? 'Marca própria nos relatórios' : 'Marca MC nos relatórios',
                  destaque: plano.marcaPropria,
                ),
                _beneficio(Icons.support_agent, 'Suporte prioritário'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: isAtual
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('PLANO ATUAL'),
                        )
                      : ElevatedButton(
                          onPressed: carregando ? null : onAssinar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSuperPremium
                                ? Colors.amber.shade700
                                : Colors.blue.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: isSuperPremium ? 4 : 0,
                          ),
                          child: carregando
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  isSuperPremium ? 'ASSINAR SUPER PREMIUM' : 'ASSINAR ${plano.nome.toUpperCase()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _beneficio(IconData icon, String texto, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: destaque ? Colors.green : Colors.grey),
          const SizedBox(width: 10),
          Text(
            texto,
            style: TextStyle(
              fontSize: 14,
              color: destaque ? Colors.green.shade600 : Colors.grey.shade600,
              fontWeight: destaque ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
