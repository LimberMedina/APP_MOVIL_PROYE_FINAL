// Archivo: lead_detail_modal.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import 'package:html_unescape/html_unescape.dart';

class LeadDetailModal extends StatelessWidget {
  final VoidCallback onClose;

  const LeadDetailModal({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<LeadDetailController>();
    final lead = controller.lead;
    final acciones = controller.getAccionesDisponibles(lead?['estado'] ?? '');

    if (lead == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(12),
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(context, lead),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoCard(context, controller, lead, acciones),
                        const SizedBox(height: 16),
                        _buildSeguimientoCard(lead, acciones, controller),
                        const SizedBox(height: 16),
                        _buildInteractionCard(context, controller),
                        const SizedBox(height: 16),
                        _buildNotasCard(controller),
                        const SizedBox(height: 16),
                        _buildInfoAdicionalCard(lead, controller),
                      ],
                    ),
                  );
                },
              ),
            ),

            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionCard(
    BuildContext context,
    LeadDetailController controller,
  ) {
    final unescape = HtmlUnescape();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    SizedBox(width: 8),
                    Text(
                      'Interacciones',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: controller.toggleFormularioInteraccion,

                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            if (controller.mostrarFormInteraccion)
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Registrar Interacción',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: controller.tipoInteraccion,
                      items: const [
                        DropdownMenuItem(
                          value: 'llamada',
                          child: Text('Llamada'),
                        ),
                        DropdownMenuItem(value: 'email', child: Text('Email')),
                        DropdownMenuItem(
                          value: 'reunion',
                          child: Text('Reunión'),
                        ),
                        DropdownMenuItem(
                          value: 'compra',
                          child: Text('Compra'),
                        ),
                        DropdownMenuItem(value: 'otro', child: Text('Otra')),
                      ],
                      onChanged: (val) {
                        if (val != null) controller.cambiarTipoInteraccion(val);
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Interacción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: controller.descripcionInteraccion,
                      onChanged:
                          (val) => controller.descripcionInteraccion = val,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => controller.cancelarInteraccion(),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed:
                              () => controller.enviarInteraccion(context),
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

            const Text(
              'HISTORIAL DE INTERACCIONES',
              style: TextStyle(
                color: Colors.grey,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 12),

            controller.cargandoInteracciones
                ? const Center(child: CircularProgressIndicator())
                : controller.interacciones.isEmpty
                ? const Text('Sin interacciones registradas.')
                : Column(
                  children:
                      controller.interacciones.map((inter) {
                        final tipo = inter['tipo'] ?? '-';
                        final descripcion = unescape.convert(
                          inter['descripcion'] ?? '',
                        );
                        final fecha = controller.formatDate(
                          inter['fecha'] ?? inter['fecha_creacion'],
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 4,
                                height: 48,
                                color: Colors.blue.shade100,
                                margin: const EdgeInsets.only(right: 12),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          tipo[0].toUpperCase() +
                                              tipo.substring(1),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          fecha,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      descripcion,
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotasCard(LeadDetailController controller) {
    final nota = controller.lead?['notas']?.toString().trim();
    final descripcion = controller.lead?['descripcion']?.toString().trim();
    if ((nota?.isEmpty ?? true) && (descripcion?.isEmpty ?? true))
      return const SizedBox();

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Notas del Lead',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              nota!.isNotEmpty ? nota : (descripcion ?? ''),
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> lead) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue, Colors.blueAccent],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                lead['nombre'] ?? '',
                style: const TextStyle(
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  _estadoBadge(lead['estado']),
                  const SizedBox(width: 6),
                  if (lead['fuente'] != null)
                    _simpleBadge(lead['fuente'], Colors.white.withOpacity(0.2)),
                ],
              ),
            ],
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _estadoBadge(String? estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        estado ?? '-',
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    LeadDetailController controller,
    Map<String, dynamic> lead,
    List acciones,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título
            Row(
              children: const [
                Icon(Icons.person, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Información de Contacto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 24),

            // Email
            _infoRow(
              icon: Icons.email,
              label: 'Email',
              value: lead['email'],
              actions: [
                IconButton(
                  onPressed: () => controller.abrirCorreo(context),
                  icon: const Icon(
                    Icons.email_outlined,
                    size: 20,
                    color: Colors.blue,
                  ),
                  tooltip: 'Correo',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Teléfono
            _infoRow(
              icon: Icons.phone,
              label: 'Teléfono',
              value: lead['telefono'],
              actions: [
                IconButton(
                  onPressed: () => controller.abrirWhatsapp(context),
                  icon: const Icon(Icons.chat, color: Colors.green),
                  tooltip: 'WhatsApp',
                ),
                IconButton(
                  onPressed: () => controller.hacerLlamada(context),
                  icon: const Icon(Icons.call, color: Colors.blue),
                  tooltip: 'Llamar',
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Fuente
            _infoRow(
              icon: Icons.category,
              label: 'Fuente',
              value: lead['fuente'],
            ),
            const SizedBox(height: 12),

            // Valor Estimado
            _infoRow(
              icon: Icons.monetization_on,
              label: 'Valor Estimado',
              value: controller.formatNumber(lead['valor_estimado']),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String? value,
    List<Widget>? actions,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value != null && value.isNotEmpty ? value : 'No especificado',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        if (actions != null) ...[
          const SizedBox(width: 8),
          Row(mainAxisSize: MainAxisSize.min, children: actions),
        ],
      ],
    );
  }

  Widget _simpleBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  Widget _buildSeguimientoCard(
    Map<String, dynamic> lead,
    List acciones,
    LeadDetailController controller,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.assignment, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Seguimiento',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const Divider(height: 20),
            const Text('Estado Actual', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade400,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                lead['estado'] ?? '-',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Próximos Pasos', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            ...acciones.map((acc) {
              final String texto = acc['texto'];
              final String estado = acc['estado'];

              Color bgColor;
              Color textColor;
              IconData icon;

              switch (estado) {
                case 'calificado':
                  bgColor = Colors.yellow.shade100;
                  textColor = Colors.brown;
                  icon = Icons.star;
                  break;
                case 'propuesta':
                  bgColor = Colors.purple.shade100;
                  textColor = Colors.purple;
                  icon = Icons.description;
                  break;
                case 'nuevo':
                  bgColor = Colors.grey.shade200;
                  textColor = Colors.black87;
                  icon = Icons.reply;
                  break;
                default:
                  bgColor = Colors.blue.shade100;
                  textColor = Colors.black;
                  icon = Icons.arrow_forward;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => controller.actualizarEstado(estado, () {}),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: textColor, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              texto,
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: textColor),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoAdicionalCard(
    Map<String, dynamic> lead,
    LeadDetailController controller,
  ) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'INFORMACIÓN ADICIONAL',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // ID del Lead
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ID del Lead',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${lead['id']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                // Fecha creación
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Creado',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      controller.formatDate(lead['fecha_creacion']),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Última actualización
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Última actualización',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  controller.formatDate(lead['ultima_actualizacion']),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final controller = context.watch<LeadDetailController>();
    final estadoActual = controller.lead?['estado'];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Dropdown de estados
          Row(
            children: [
              const Text(
                'Cambiar estado: ',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: estadoActual,
                items:
                    controller.estadosDisponibles.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(entry.value),
                      );
                    }).toList(),
                onChanged: (nuevoEstado) {
                  if (nuevoEstado != null && nuevoEstado != estadoActual) {
                    controller.actualizarEstado(nuevoEstado, () {});
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class LeadDetailController extends ChangeNotifier {
  final int leadId;

  LeadDetailController(this.leadId);

  Map<String, dynamic>? lead;
  List<dynamic> interacciones = [];
  bool loading = true;
  bool cargandoInteracciones = true;
  String tipoInteraccion = 'llamada';
  String descripcionInteraccion = '';
  bool mostrarFormInteraccion = false;

  final Map<String, dynamic> countryCurrencies = {
    'Bolivia': {'code': 'BOB', 'symbol': 'Bs', 'name': 'Boliviano'},
    'Argentina': {'code': 'ARS', 'symbol': '\$', 'name': 'Peso Argentino'},
    'Chile': {'code': 'CLP', 'symbol': '\$', 'name': 'Peso Chileno'},
    'Peru': {'code': 'PEN', 'symbol': 'S/', 'name': 'Sol Peruano'},
    'default': {'code': 'USD', 'symbol': '\$', 'name': 'Dólar'},
  };

  Map<String, dynamic> currency = {
    'code': 'USD',
    'symbol': '\$',
    'name': 'Dólar',
  };

  final Map<String, String> estadosDisponibles = {
    'nuevo': 'Nuevo',
    'contactado': 'Contactado',
    'calificado': 'Calificado',
    'propuesta': 'Propuesta',
    'negociacion': 'Negociación',
    'ganado': 'Ganado',
    'perdido': 'Perdido',
  };

  void cambiarTipoInteraccion(String nuevoTipo) {
    tipoInteraccion = nuevoTipo;
    notifyListeners();
  }

  void cancelarInteraccion() {
    descripcionInteraccion = '';
    tipoInteraccion = 'llamada';
    mostrarFormInteraccion = false;
    notifyListeners();
  }

  void hacerLlamada(BuildContext context) async {
    final telefono = lead?['telefono'];
    if (telefono == null || telefono.toString().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No hay número')));
      return;
    }

    final uri = Uri.parse('tel:$telefono');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      registrarInteraccionAutomatica(
        'llamada',
        'Se realizó una llamada al número $telefono',
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo realizar la llamada')),
      );
    }
  }

  void toggleFormularioInteraccion() {
    mostrarFormInteraccion = !mostrarFormInteraccion;
    notifyListeners();
  }

  Future<void> fetchLeadDetails() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('$baseUrl/leads/$leadId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        lead = json.decode(utf8.decode(res.bodyBytes));

        loading = false;
        notifyListeners();
        await fetchInteracciones(); // importante esperar antes de continuar
      } else {
        loading = false;
        notifyListeners();
      }
    } catch (_) {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> fetchInteracciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.get(
        Uri.parse('$baseUrl/leads/$leadId/interacciones/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (res.statusCode == 200) {
        interacciones = json.decode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {
      // manejo opcional de error
    } finally {
      cargandoInteracciones = false;
      notifyListeners();
    }
  }

  Future<void> enviarInteraccion(BuildContext context) async {
    if (descripcionInteraccion.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ingrese una descripción')));
      return;
    }

    final body = {
      'tipo': tipoInteraccion,
      'descripcion': descripcionInteraccion.trim(),
    };
    if (tipoInteraccion == 'compra' && lead?['valor_estimado'] != null) {
      body['valor'] = lead!['valor_estimado'];
    }

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/leads/$leadId/interacciones/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      if (res.statusCode == 201) {
        final nueva = json.decode(res.body);
        interacciones.insert(0, nueva);
        tipoInteraccion = 'llamada';
        descripcionInteraccion = '';
        mostrarFormInteraccion = false;
        notifyListeners();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Interacción registrada')));
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al registrar interacción')),
      );
    }
  }

  Future<void> registrarInteraccionAutomatica(
    String tipo,
    String descripcion,
  ) async {
    final body = {
      'tipo': tipo,
      'descripcion': descripcion,
      'fecha': DateTime.now().toIso8601String(),
    };
    try {
      await http.post(
        Uri.parse('$baseUrl/leads/$leadId/interacciones/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      await fetchInteracciones();
    } catch (_) {}
  }

  void abrirWhatsapp(BuildContext context) async {
    final telefono = lead?['telefono'];
    final nombre = lead?['nombre'] ?? 'Estimado/a';

    if (telefono == null || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay número de teléfono disponible')),
      );
      return;
    }

    // Limpiar el número de teléfono
    final telefonoLimpio = telefono.replaceAll(RegExp(r'[^\d+]'), '');

    // Formatear para Bolivia si es necesario
    String telefonoFormateado = telefonoLimpio;
    if (!telefonoLimpio.startsWith('591') &&
        !telefonoLimpio.startsWith('+591')) {
      if (telefonoLimpio.length == 8) {
        telefonoFormateado = '591$telefonoLimpio';
      }
    }

    final mensaje = Uri.encodeComponent('Hola $nombre, ¿cómo estás?');

    // Lista de URLs para intentar en orden
    final urls = [
      'https://wa.me/$telefonoFormateado?text=$mensaje',
      'whatsapp://send?phone=$telefonoFormateado&text=$mensaje',
    ];

    bool success = false;

    for (String url in urls) {
      try {
        final uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          success = true;
          break;
        }
      } catch (e) {
        print('Error con $url: $e');
        continue;
      }
    }

    if (success) {
      registrarInteraccionAutomatica(
        'whatsapp',
        'Se envió mensaje por WhatsApp a $telefonoFormateado',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp abierto correctamente')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp no está disponible')),
      );
    }
  }

  void abrirCorreo(BuildContext context) async {
    final email = lead?['email'] ?? lead?['correo'];
    final nombre = lead?['nombre'] ?? 'Estimado/a';

    if (email == null || email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay dirección de correo disponible')),
      );
      return;
    }

    // Validar formato básico de email
    if (!_esEmailValido(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dirección de correo no válida')),
      );
      return;
    }

    final asunto = Uri.encodeComponent('Contacto desde la aplicación');
    final cuerpo = Uri.encodeComponent(
      'Hola $nombre,\n\nEspero que te encuentres bien.\n\n'
      'Me pongo en contacto contigo para...\n\n'
      'Saludos cordiales.',
    );

    // Lista de URLs para intentar en orden
    final urls = [
      'mailto:$email?subject=$asunto&body=$cuerpo',
      'https://mail.google.com/mail/?view=cm&to=$email&su=$asunto&body=$cuerpo',
    ];

    bool success = false;

    for (String url in urls) {
      try {
        final uri = Uri.parse(url);

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          success = true;
          break;
        }
      } catch (e) {
        print('Error con $url: $e');
        continue;
      }
    }

    if (success) {
      registrarInteraccionAutomatica(
        'email',
        'Se abrió correo electrónico para $email',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aplicación de correo abierta')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el correo electrónico')),
      );
    }
  }

  // Método auxiliar para validar email
  bool _esEmailValido(String email) {
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(email);
  }

  List<Map<String, dynamic>> getAccionesDisponibles(String estado) {
    final acciones = {
      'nuevo': [
        {'estado': 'contactado', 'texto': 'Marcar como Contactado'},
        {'estado': 'calificado', 'texto': 'Calificar Lead'},
        {'estado': 'perdido', 'texto': 'Marcar como Perdido'},
      ],
      'contactado': [
        {'estado': 'calificado', 'texto': 'Calificar Lead'},
        {'estado': 'propuesta', 'texto': 'Enviar Propuesta'},
        {'estado': 'nuevo', 'texto': 'Volver a Nuevo'},
      ],
      'calificado': [
        {'estado': 'propuesta', 'texto': 'Enviar Propuesta'},
        {'estado': 'contactado', 'texto': 'Volver a Contactado'},
      ],
      'propuesta': [
        {'estado': 'negociacion', 'texto': 'Iniciar Negociación'},
        {'estado': 'calificado', 'texto': 'Volver a Calificado'},
      ],
      'negociacion': [
        {'estado': 'ganado', 'texto': 'Marcar como Ganado'},
        {'estado': 'propuesta', 'texto': 'Volver a Propuesta'},
      ],
      'ganado': [
        {'estado': 'nuevo', 'texto': 'Crear Oportunidad'},
        {'estado': 'perdido', 'texto': 'Marcar como Perdido'},
      ],
      'perdido': [
        {'estado': 'nuevo', 'texto': 'Reactivar Lead'},
        {'estado': 'contactado', 'texto': 'Volver a Contactado'},
      ],
    };
    return acciones[estado] ?? [];
  }

  String formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    final date = DateTime.parse(dateString);
    return DateFormat('dd MMM yyyy, HH:mm', 'es_ES').format(date);
  }

  String formatNumber(dynamic value) {
    final locale =
        {
          'BOB': 'es-BO',
          'ARS': 'es-AR',
          'CLP': 'es-CL',
          'PEN': 'es-PE',
          'USD': 'en-US',
        }[currency['code']] ??
        'en-US';

    final number =
        value is String
            ? double.tryParse(
                  value
                      .replaceAll(RegExp(r'[^0-9.,-]'), '')
                      .replaceAll(',', '.'),
                ) ??
                0
            : (value is num ? value : 0);

    return NumberFormat.currency(locale: locale, symbol: '').format(number);
  }

  void actualizarEstado(String nuevoEstado, VoidCallback onSuccess) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final res = await http.patch(
        Uri.parse('$baseUrl/leads/$leadId/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'estado': nuevoEstado}),
      );

      if (res.statusCode == 200) {
        lead = {...?lead, 'estado': nuevoEstado};
        notifyListeners();
        onSuccess();
      } else {
        debugPrint('Error actualizando estado: ${res.body}');
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }
}
