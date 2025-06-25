import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'lead_detail_modal.dart';

import '../config.dart';

class CRM extends StatefulWidget {
  const CRM({super.key});

  @override
  State<CRM> createState() => _CRMState();
}

class _CRMState extends State<CRM> {
  List<dynamic> leads = [];
  Map<String, dynamic>? userProfile;
  Map<String, dynamic> metricas = {
    'total_leads': 0,
    'valor_total_pipeline': 0,
    'valor_total_compras': 0,
    'promedio_compras': 0,
    'leads_por_estado': {},
  };

  Map<String, dynamic> formData = {
    'nombre': '',
    'email': '',
    'telefono': '',
    'notas': '',
    'valor_estimado': '',
    'probabilidad': 0,
    'fuente': 'manual',
  };

  String error = '';
  String selectedStatus = 'todos';
  String searchTerm = '';
  int currentPage = 0;
  final int itemsPerPage = 10;

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

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {'Authorization': 'Bearer $token'}, // <-- corregido aquí
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          userProfile = data;
          if (data['country'] != null &&
              countryCurrencies.containsKey(data['country'])) {
            currency = countryCurrencies[data['country']];
          }
        });
        fetchLeads();
        fetchMetricas();
      } else {
        setState(() => error = 'No se pudo cargar la información del usuario');
      }
    } catch (e) {
      setState(() => error = 'Error al conectar con el servidor');
    }
  }

  Future<void> fetchLeads() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/leads/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => leads = data);
      } else {
        setState(() => error = 'Error al obtener los leads');
      }
    } catch (e) {
      setState(() => error = 'Error al conectar con el servidor');
    }
  }

  Future<void> fetchMetricas() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/leads/metricas/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => metricas = data);
      }
    } catch (e) {
      print('Error al obtener métricas: \$e');
    }
  }

  Future<void> _handleCreateLeadSubmit() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (userProfile == null) {
      setState(() => error = 'No se pudo identificar el usuario');
      return;
    }

    final leadData = {
      'nombre': formData['nombre'],
      'email': formData['email'],
      'telefono': formData['telefono'].isEmpty ? null : formData['telefono'],
      'notas': formData['notas'].isEmpty ? null : formData['notas'],
      'valor_estimado': double.tryParse(formData['valor_estimado']) ?? 0,
      'probabilidad': formData['probabilidad'],
      'estado': 'nuevo',
      'usuario': userProfile!['id'],
      'tienda': userProfile!['tienda']?['id'],
      'fuente': formData['fuente'],

      'total_compras': 0,
      'valor_total_compras': 0,
      'frecuencia_compra': 0,
    };

    try {
      final res = await http.post(
        Uri.parse('$baseUrl/leads/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(leadData),
      );

      if (res.statusCode == 201) {
        Navigator.pop(context); // cerrar modal
        await fetchLeads(); // recargar leads
        await fetchMetricas();
      } else {
        setState(() => error = 'Error al crear lead');
      }
    } catch (e) {
      setState(() => error = 'Error de red');
    }
  }

  List<dynamic> get filteredLeads {
    return leads.where((lead) {
      final nombre = lead['nombre']?.toLowerCase() ?? '';
      final email = lead['email']?.toLowerCase() ?? '';
      final matchesSearch =
          searchTerm.isEmpty ||
          nombre.contains(searchTerm.toLowerCase()) ||
          email.contains(searchTerm.toLowerCase());
      final matchesStatus =
          selectedStatus == 'todos' || lead['estado'] == selectedStatus;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  List<dynamic> get paginatedLeads {
    final startIndex = currentPage * itemsPerPage;
    return filteredLeads.skip(startIndex).take(itemsPerPage).toList();
  }

  void handlePageChange(int page) {
    setState(() => currentPage = page);
  }

  void _showCreateLeadModal(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Nuevo Lead'),
            content: StatefulBuilder(
              builder: (context, setModalState) {
                return SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInputField(
                        'Nombre',
                        formData['nombre'],
                        (v) => setModalState(() => formData['nombre'] = v),
                      ),
                      _buildInputField(
                        'Email',
                        formData['email'],
                        (v) => setModalState(() => formData['email'] = v),
                        keyboard: TextInputType.emailAddress,
                      ),
                      _buildInputField(
                        'Teléfono',
                        formData['telefono'],
                        (v) => setModalState(() => formData['telefono'] = v),
                        keyboard: TextInputType.phone,
                      ),
                      _buildInputField(
                        'Valor Estimado',
                        formData['valor_estimado'],
                        (v) =>
                            setModalState(() => formData['valor_estimado'] = v),
                        keyboard: TextInputType.number,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: DropdownButtonFormField<String>(
                          value: formData['fuente'],
                          decoration: const InputDecoration(
                            labelText: 'Fuente',
                            border: OutlineInputBorder(),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'manual',
                              child: Text('Manual'),
                            ),
                            DropdownMenuItem(
                              value: 'tienda_publica',
                              child: Text('Tienda Pública'),
                            ),
                            DropdownMenuItem(
                              value: 'ecommerce',
                              child: Text('E-commerce'),
                            ),
                            DropdownMenuItem(
                              value: 'redes_sociales',
                              child: Text('Redes Sociales'),
                            ),
                            DropdownMenuItem(
                              value: 'recomendacion',
                              child: Text('Recomendación'),
                            ),
                            DropdownMenuItem(
                              value: 'otro',
                              child: Text('Otro'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() => formData['fuente'] = value);
                            }
                          },
                        ),
                      ),

                      _buildProbabilidadSlider(setModalState),
                      _buildInputField(
                        'Notas',
                        formData['notas'],
                        (v) => setModalState(() => formData['notas'] = v),
                        maxLines: 3,
                      ),
                    ],
                  ),
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: _handleCreateLeadSubmit,
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  Widget _buildInputField(
    String label,
    String value,
    Function(String) onChanged, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        keyboardType: keyboard,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged,
        controller: TextEditingController.fromValue(
          TextEditingValue(
            text: value,
            selection: TextSelection.collapsed(offset: value.length),
          ),
        ),
      ),
    );
  }

  Widget _buildProbabilidadSlider(Function setModalState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        const Text('Probabilidad de cierre'),
        Slider(
          value: (formData['probabilidad'] as num).toDouble(),
          min: 0,
          max: 100,
          divisions: 100,
          label: '${formData['probabilidad']}%',
          onChanged: (val) {
            setModalState(() {
              formData['probabilidad'] = val.round();
            });
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Encabezado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CRM',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Moneda: ${currency['name']} (${currency['symbol']}) • Tenant ID: ${userProfile?['tenant_id'] ?? '-'}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filtros con diseño responsivo
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 250,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Buscar por nombre o email...',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        searchTerm = value;
                        currentPage = 0;
                      });
                    },
                  ),
                ),
                DropdownButton<String>(
                  value: selectedStatus,
                  items:
                      [
                        'todos',
                        'nuevo',
                        'contactado',
                        'calificado',
                        'propuesta',
                        'negociacion',
                        'ganado',
                        'perdido',
                      ].map((e) {
                        return DropdownMenuItem(
                          value: e,
                          child: Text(e.toUpperCase()),
                        );
                      }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedStatus = value;
                        currentPage = 0;
                      });
                    }
                  },
                ),
                ElevatedButton(
                  onPressed: () => _showCreateLeadModal(context),
                  child: const Text('Crear Nuevo Lead'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Métricas
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildMetricCard(
                  FontAwesomeIcons.users,
                  'Total Leads',
                  metricas['total_leads'].toString(),
                ),
                _buildMetricCard(
                  FontAwesomeIcons.chartLine,
                  'Pipeline',
                  '${currency['symbol']} ${metricas['valor_total_pipeline']}',
                ),
                _buildMetricCard(
                  FontAwesomeIcons.moneyBillWave,
                  'Ventas Totales',
                  '${currency['symbol']} ${metricas['valor_total_compras']}',
                ),
                _buildMetricCard(
                  FontAwesomeIcons.shoppingCart,
                  'Prom. Compras',
                  '${currency['symbol']} ${metricas['promedio_compras'].toStringAsFixed(2)}',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tabla
            const Text(
              'Leads',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                headingRowHeight: 40,
                dataRowHeight: 48,
                columns: const [
                  DataColumn(
                    label: Text('Nombre', style: TextStyle(fontSize: 13)),
                  ),
                  DataColumn(
                    label: Text('Email', style: TextStyle(fontSize: 13)),
                  ),
                  DataColumn(
                    label: Text('Estado', style: TextStyle(fontSize: 13)),
                  ),
                  DataColumn(
                    label: Text(
                      'Valor Estimado',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Total Compras',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'Última Actualización',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                  DataColumn(
                    label: Text('Acciones', style: TextStyle(fontSize: 13)),
                  ),
                ],
                rows:
                    paginatedLeads.map((lead) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              lead['nombre'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              lead['email'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              lead['estado']?.toUpperCase() ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${currency['symbol']} ${lead['valor_estimado'] ?? '0'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${currency['symbol']} ${lead['valor_total_compras'] ?? '0'}',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              lead['ultima_actualizacion']?.substring(0, 10) ??
                                  '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            TextButton(
                              onPressed: () {
                                final leadId = lead['id'];
                                showDialog(
                                  context: context,
                                  builder:
                                      (_) => ChangeNotifierProvider(
                                        create:
                                            (_) =>
                                                LeadDetailController(leadId)
                                                  ..fetchLeadDetails(),
                                        child: LeadDetailModal(
                                          onClose:
                                              () => Navigator.of(context).pop(),
                                        ),
                                      ),
                                );
                              },
                              child: const Text(
                                'Ver Detalles',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard(IconData icon, String title, String value) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
