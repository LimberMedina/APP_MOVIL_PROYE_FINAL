import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LeadDetailScreen extends StatefulWidget {
  final int leadId;
  const LeadDetailScreen({super.key, required this.leadId});

  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  Map<String, dynamic>? lead;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchLeadDetails();
  }

  Future<void> fetchLeadDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/leads/${widget.leadId}/'),
        headers: {'Authorization': 'Token $token'},
      );
      if (response.statusCode != 200) {
        showDialog(
          context: context,
          builder:
              (_) => AlertDialog(
                title: Text('Error'),
                content: Text('No se pudo obtener los detalles del lead'),
              ),
        );
      } else {
        setState(() => loading = false);
      }
    } catch (e) {
      print('Error: $e');
      setState(() => loading = false);
    }
  }

  Widget estadoBadge(String estado) {
    final colores = {
      'nuevo': Colors.blue,
      'contactado': Colors.lightBlue,
      'calificado': Colors.orange,
      'propuesta': Colors.purple,
      'negociacion': Colors.grey,
      'ganado': Colors.green,
      'perdido': Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colores[estado] ?? Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget fuenteBadge(String fuente) {
    final colores = {'tienda_publica': Colors.blue, 'ecommerce': Colors.green};

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colores[fuente] ?? Colors.grey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        fuente.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (lead == null) {
      return const Scaffold(body: Center(child: Text('Lead no encontrado')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Detalles del Lead')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Información Principal
            cardSection('Información del Lead', [
              _infoRow(FontAwesomeIcons.user, 'Nombre', lead!['nombre']),
              _infoRow(FontAwesomeIcons.envelope, 'Email', lead!['email']),
              _infoRow(null, 'Estado', estadoBadge(lead!['estado'])),
              _infoRow(null, 'Valor Estimado', '\$${lead!['valor_estimado']}'),
              _infoRow(null, 'Probabilidad', '${lead!['probabilidad']}%'),
              _infoRow(null, 'Fuente', fuenteBadge(lead!['fuente'] ?? 'otro')),
            ]),

            const SizedBox(height: 16),

            // Métricas de Compra
            cardSection('Métricas de Compras', [
              _infoRow(
                FontAwesomeIcons.shoppingCart,
                'Total Compras',
                lead!['total_compras'].toString(),
              ),
              _infoRow(
                FontAwesomeIcons.moneyBillWave,
                'Valor Total',
                '\$${lead!['valor_total_compras']}',
              ),
              _infoRow(
                null,
                'Frecuencia',
                '${lead!['frecuencia_compra']} días',
              ),
              _infoRow(
                null,
                'Última Compra',
                DateFormat(
                  'dd/MM/yyyy',
                ).format(DateTime.parse(lead!['ultima_compra'])),
              ),
            ]),

            const SizedBox(height: 16),

            // Historial
            if (lead!['interacciones'] != null) ...[
              cardSection(
                'Historial de Interacciones',
                List<Widget>.from(
                  lead!['interacciones'].map(
                    (i) => ListTile(
                      title: Text(
                        i['tipo'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(i['descripcion']),
                      trailing: Text(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format(DateTime.parse(i['fecha'])),
                        style: const TextStyle(fontSize: 12),
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Notas
            if (lead!['notas'] != null && lead!['notas'].toString().isNotEmpty)
              cardSection('Notas', [
                Text(
                  lead!['notas'],
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ]),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData? icon, String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) Icon(icon, size: 16, color: Colors.grey),
          if (icon != null) const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 4),
          value is Widget ? value : Expanded(child: Text(value.toString())),
        ],
      ),
    );
  }

  Widget cardSection(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}
