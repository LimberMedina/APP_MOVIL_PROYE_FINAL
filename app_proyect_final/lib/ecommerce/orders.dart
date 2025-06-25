// orders.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({Key? key}) : super(key: key);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<dynamic> pedidos = [];
  bool loading = true;
  String? error;
  String filtroEstado = 'todos';
  String busqueda = '';
  int? pedidoExpandido;

  @override
  void initState() {
    super.initState();
    fetchPedidos();
  }

  Future<void> fetchPedidos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final response = await http.get(
        Uri.parse('$baseUrl/pedidos-publicos/por_tienda/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          pedidos = data;
          loading = false;
        });
      } else {
        throw Exception('Error al obtener pedidos');
      }
    } catch (e) {
      setState(() {
        error = 'Error al cargar los pedidos';
        loading = false;
      });
    }
  }

  Future<void> actualizarEstadoPedido(int id, String nuevoEstado) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await http.post(
        Uri.parse('$baseUrl/pedidos-publicos/$id/actualizar_estado/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'estado': nuevoEstado}),
      );
      fetchPedidos();
    } catch (e) {
      setState(() => error = 'Error al actualizar el estado del pedido');
    }
  }

  Future<void> agregarCodigoSeguimiento(int id, String codigo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      await http.post(
        Uri.parse('$baseUrl/tiendas/pedidos/$id/agregar_codigo_seguimiento/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'codigo_seguimiento': codigo}),
      );
      fetchPedidos();
    } catch (e) {
      setState(() => error = 'Error al agregar el código de seguimiento');
    }
  }

  Color getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.yellow.shade100;
      case 'confirmado':
        return Colors.blue.shade100;
      case 'en_proceso':
        return Colors.purple.shade100;
      case 'enviado':
        return Colors.indigo.shade100;
      case 'entregado':
        return Colors.green.shade100;
      case 'cancelado':
        return Colors.red.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Icon getEstadoIcon(String estado) {
    switch (estado) {
      case 'pendiente':
        return const Icon(
          FontAwesomeIcons.exclamationTriangle,
          color: Colors.yellow,
        );
      case 'confirmado':
        return const Icon(FontAwesomeIcons.box, color: Colors.blue);
      case 'en_proceso':
        return const Icon(FontAwesomeIcons.box, color: Colors.purple);
      case 'enviado':
        return const Icon(FontAwesomeIcons.truck, color: Colors.indigo);
      case 'entregado':
        return const Icon(FontAwesomeIcons.check, color: Colors.green);
      case 'cancelado':
        return const Icon(FontAwesomeIcons.times, color: Colors.red);
      default:
        return const Icon(FontAwesomeIcons.box);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    final pedidosFiltrados =
        pedidos.where((pedido) {
          final coincideEstado =
              filtroEstado == 'todos' || pedido['estado'] == filtroEstado;
          final coincideBusqueda =
              pedido['id'].toString().contains(busqueda) ||
              pedido['cliente_nombre'].toLowerCase().contains(
                busqueda.toLowerCase(),
              ) ||
              (pedido['codigo_seguimiento']?.toLowerCase().contains(
                    busqueda.toLowerCase(),
                  ) ??
                  false);
          return coincideEstado && coincideBusqueda;
        }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gestión de Pedidos',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (val) => setState(() => busqueda = val),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(FontAwesomeIcons.search),
                    hintText: 'Buscar por ID, cliente o código...',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: filtroEstado,
                onChanged: (val) => setState(() => filtroEstado = val!),
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(
                    value: 'pendiente',
                    child: Text('Pendiente'),
                  ),
                  DropdownMenuItem(
                    value: 'confirmado',
                    child: Text('Confirmado'),
                  ),
                  DropdownMenuItem(
                    value: 'en_proceso',
                    child: Text('En Proceso'),
                  ),
                  DropdownMenuItem(value: 'enviado', child: Text('Enviado')),
                  DropdownMenuItem(
                    value: 'entregado',
                    child: Text('Entregado'),
                  ),
                  DropdownMenuItem(
                    value: 'cancelado',
                    child: Text('Cancelado'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (pedidosFiltrados.isEmpty)
            const Center(child: Text('No se encontraron pedidos'))
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: pedidosFiltrados.length,
              itemBuilder: (context, index) {
                final pedido = pedidosFiltrados[index];
                final expandido = pedidoExpandido == pedido['id'];
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap:
                        () => setState(
                          () =>
                              pedidoExpandido = expandido ? null : pedido['id'],
                        ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  getEstadoIcon(pedido['estado']),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Pedido #${pedido['id']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Bs. ${pedido['total']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Cliente: ${pedido['cliente_nombre'] ?? ''}'),

                          Text(
                            'Fecha: ${(pedido['fecha_creacion'] ?? '').toString().substring(0, 10)}',
                          ),

                          Text(
                            'Método: ${pedido['metodo_pago_display'] ?? ''}',
                          ),

                          if (expandido) ...[
                            const Divider(height: 24),

                            Text(
                              'Dirección: ${pedido['direccion_entrega'] ?? ''}',
                            ),

                            Text('Teléfono: ${pedido['telefono'] ?? ''}'),

                            if (pedido['codigo_seguimiento'] != null)
                              Text('Código: ${pedido['codigo_seguimiento']}'),

                            const SizedBox(height: 12),

                            Column(
                              children:
                                  (pedido['detalles'] as List<dynamic>).map((
                                    detalle,
                                  ) {
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading:
                                          detalle['producto_imagen'] != null
                                              ? Image.network(
                                                '$baseUrl${detalle['producto_imagen']}',
                                                width: 40,
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => const Icon(
                                                      FontAwesomeIcons.box,
                                                    ),
                                              )
                                              : const Icon(
                                                FontAwesomeIcons.box,
                                              ),
                                      title: Text(
                                        detalle['producto_nombre'] ?? '',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        '${detalle['cantidad'] ?? 0} x Bs. ${detalle['precio_unitario'] ?? 0}',
                                      ),
                                      trailing: Text(
                                        'Bs. ${detalle['subtotal'] ?? 0}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                            ),

                            const SizedBox(height: 12),

                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                DropdownButton<String>(
                                  value: pedido['estado'],
                                  onChanged: (value) {
                                    if (value != null) {
                                      actualizarEstadoPedido(
                                        pedido['id'],
                                        value,
                                      );
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'pendiente',
                                      child: Text('Pendiente'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'confirmado',
                                      child: Text('Confirmado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'en_proceso',
                                      child: Text('En Proceso'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'enviado',
                                      child: Text('Enviado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'entregado',
                                      child: Text('Entregado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'cancelado',
                                      child: Text('Cancelado'),
                                    ),
                                  ],
                                ),

                                if (pedido['codigo_seguimiento'] == null)
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      final controller =
                                          TextEditingController();
                                      await showDialog(
                                        context: context,
                                        builder:
                                            (_) => AlertDialog(
                                              title: const Text(
                                                'Agregar Código de Seguimiento',
                                              ),
                                              content: TextField(
                                                controller: controller,
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed:
                                                      () => Navigator.pop(
                                                        context,
                                                      ),
                                                  child: const Text('Cancelar'),
                                                ),
                                                ElevatedButton(
                                                  onPressed: () {
                                                    agregarCodigoSeguimiento(
                                                      pedido['id'],
                                                      controller.text,
                                                    );
                                                    Navigator.pop(context);
                                                  },
                                                  child: const Text('Guardar'),
                                                ),
                                              ],
                                            ),
                                      );
                                    },
                                    icon: const Icon(FontAwesomeIcons.barcode),
                                    label: const Text('Agregar Código'),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
