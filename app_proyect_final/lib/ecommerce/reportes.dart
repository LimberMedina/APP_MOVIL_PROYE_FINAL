import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart';
import 'package:fl_chart/fl_chart.dart';

import '../config.dart';

class ReportesScreen extends StatefulWidget {
  final String slug;
  const ReportesScreen({super.key, required this.slug});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  bool loading = true;
  String? error;
  bool noData = false;
  Map<String, dynamic>? storeConfig;
  Map<String, dynamic>? userInfo;
  List<dynamic> pedidos = [];
  List<String> metodosPago = [];

  Map<String, String> filtros = {
    'fechaInicio': DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 30))),
    'fechaFin': DateFormat('yyyy-MM-dd').format(DateTime.now()),
    'estado': 'todos',
    'metodoPago': 'todos',
  };

  double totalVentas = 0;
  Map<String, int> pedidosPorEstado = {};
  Map<String, double> ventasPorMetodoPago = {};
  List<Map<String, dynamic>> productosMasVendidos = [];

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() {
      loading = true;
      error = null;
      noData = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        setState(() => error = 'Token no encontrado.');
        return;
      }

      final storeRes = await http.get(
        Uri.parse('$baseUrl/tiendas/tiendas/config/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (storeRes.statusCode == 200) {
        storeConfig = jsonDecode(storeRes.body);
      }

      final userRes = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (userRes.statusCode == 200) {
        userInfo = jsonDecode(userRes.body);
      }

      final pedidosRes = await http.get(
        Uri.parse('$baseUrl/pedidos-publicos/por_tienda/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (pedidosRes.statusCode != 200) {
        setState(() => error = 'Error al obtener pedidos');
        return;
      }

      final pedidosRaw = jsonDecode(pedidosRes.body);
      pedidos = List<Map<String, dynamic>>.from(pedidosRaw);
      if (pedidos.isEmpty) {
        setState(() => noData = true);
        return;
      }

      metodosPago =
          pedidos
              .map((p) => p['metodo_pago']?.toString() ?? '')
              .where((m) => m.isNotEmpty)
              .toSet()
              .toList();

      final inicio = DateTime.parse(filtros['fechaInicio']!);
      final fin = DateTime.parse(
        filtros['fechaFin']!,
      ).add(const Duration(hours: 23, minutes: 59));

      final pedidosFiltrados =
          pedidos.where((p) {
            final fecha =
                DateTime.tryParse(p['fecha'] ?? p['fecha_creacion'] ?? '') ??
                DateTime.now();
            final estadoOk =
                filtros['estado'] == 'todos' ||
                p['estado'] == filtros['estado'];
            final metodoOk =
                filtros['metodoPago'] == 'todos' ||
                p['metodo_pago'] == filtros['metodoPago'];
            return fecha.isAfter(inicio.subtract(const Duration(days: 1))) &&
                fecha.isBefore(fin) &&
                estadoOk &&
                metodoOk;
          }).toList();

      totalVentas = pedidosFiltrados.fold(
        0.0,
        (acc, p) => acc + (double.tryParse(p['total'].toString()) ?? 0),
      );

      pedidosPorEstado = {};
      ventasPorMetodoPago = {};
      Map<String, Map<String, dynamic>> productos = {};

      for (var p in pedidosFiltrados) {
        final estado = p['estado'] ?? 'sin_estado';
        pedidosPorEstado[estado] = (pedidosPorEstado[estado] ?? 0) + 1;

        final metodo = p['metodo_pago'] ?? 'sin_metodo';
        final total = double.tryParse(p['total'].toString()) ?? 0;
        ventasPorMetodoPago[metodo] =
            (ventasPorMetodoPago[metodo] ?? 0) + total;

        final detalles = List<Map<String, dynamic>>.from(p['detalles'] ?? []);
        for (var d in detalles) {
          final nombre = d['nombre_producto'] ?? 'Producto';
          final cantidad = int.tryParse(d['cantidad'].toString()) ?? 0;
          final subtotal = double.tryParse(d['subtotal'].toString()) ?? 0;
          if (!productos.containsKey(nombre)) {
            productos[nombre] = {'nombre': nombre, 'cantidad': 0, 'total': 0.0};
          }
          productos[nombre]!['cantidad'] += cantidad;
          productos[nombre]!['total'] += subtotal;
        }
      }

      productosMasVendidos =
          productos.values.toList()
            ..sort((a, b) => b['cantidad'].compareTo(a['cantidad']));

      setState(() => loading = false);
    } catch (e) {
      setState(() {
        error = 'Error: $e';
        loading = false;
      });
    }
  }

  void exportarPDF() async {
    final pdf = pw.Document();
    final fechaAhora = DateTime.now();

    pdf.addPage(
      pw.MultiPage(
        build:
            (context) => [
              pw.Text('Reporte de Ventas', style: pw.TextStyle(fontSize: 20)),
              if (storeConfig != null)
                pw.Text(
                  'Tienda: ${storeConfig!['nombre']}',
                  style: pw.TextStyle(fontSize: 12),
                ),
              if (userInfo != null)
                pw.Text(
                  'Generado por: ${userInfo!['first_name']} ${userInfo!['last_name']}',
                  style: pw.TextStyle(fontSize: 12),
                ),
              pw.Text(
                'Fecha: ${DateFormat('dd/MM/yyyy HH:mm').format(fechaAhora)}',
              ),
              pw.SizedBox(height: 20),
              pw.Text('Resumen', style: pw.TextStyle(fontSize: 16)),
              pw.Table.fromTextArray(
                context: context,
                data: [
                  ['Métrica', 'Valor'],
                  ['Total Ventas', 'Bs. ${totalVentas.toStringAsFixed(2)}'],
                  [
                    'Total Pedidos',
                    pedidosPorEstado.values.fold(0, (a, b) => a + b),
                  ],
                  [
                    'Productos Vendidos',
                    productosMasVendidos.fold(
                      0,
                      (a, b) => a + (b['cantidad'] as int),
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Productos Más Vendidos',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.Table.fromTextArray(
                context: context,
                data: [
                  ['Producto', 'Cantidad', 'Total'],
                  ...productosMasVendidos.map(
                    (p) => [
                      p['nombre'],
                      '${p['cantidad']}',
                      'Bs. ${p['total'].toStringAsFixed(2)}',
                    ],
                  ),
                ],
              ),
            ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  void exportarExcel() async {
    final excel = Excel.createExcel();
    final resumen = excel['Resumen'];
    resumen.appendRow(['Métrica', 'Valor']);
    resumen.appendRow([
      'Total Ventas',
      'Bs. ${totalVentas.toStringAsFixed(2)}',
    ]);
    resumen.appendRow([
      'Total Pedidos',
      pedidosPorEstado.values.fold(0, (a, b) => a + b),
    ]);
    resumen.appendRow([
      'Productos Vendidos',
      productosMasVendidos.fold(0, (a, b) => a + (b['cantidad'] as int)),
    ]);

    final productos = excel['Productos Más Vendidos'];
    productos.appendRow(['Producto', 'Cantidad', 'Total']);
    for (var p in productosMasVendidos) {
      productos.appendRow([
        p['nombre'],
        p['cantidad'],
        'Bs. ${p['total'].toStringAsFixed(2)}',
      ]);
    }

    final fileBytes = excel.save();
    final path = '/storage/emulated/0/Download/reporte_ventas.xlsx';
    final file = File(path);
    await file.writeAsBytes(fileBytes!);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Excel guardado en Descargas.')),
    );
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

    return Scaffold(
      appBar: AppBar(title: const Text('Reporte de Ventas')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            const Text(
              'Filtros',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Desde'),
                    readOnly: true,
                    controller: TextEditingController(
                      text: filtros['fechaInicio'],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(filtros['fechaInicio']!),
                        firstDate: DateTime(2022),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          filtros['fechaInicio'] = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                        fetchData();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'Hasta'),
                    readOnly: true,
                    controller: TextEditingController(
                      text: filtros['fechaFin'],
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(filtros['fechaFin']!),
                        firstDate: DateTime(2022),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        setState(() {
                          filtros['fechaFin'] = DateFormat(
                            'yyyy-MM-dd',
                          ).format(picked);
                        });
                        fetchData();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: filtros['estado'],
              decoration: const InputDecoration(labelText: 'Estado del Pedido'),
              items:
                  [
                        'todos',
                        'pendiente',
                        'pagado',
                        'enviado',
                        'entregado',
                        'cancelado',
                      ]
                      .map(
                        (estado) => DropdownMenuItem(
                          value: estado,
                          child: Text(estado),
                        ),
                      )
                      .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => filtros['estado'] = val);
                  fetchData();
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: filtros['metodoPago'],
              decoration: const InputDecoration(labelText: 'Método de Pago'),
              items:
                  ['todos', ...metodosPago]
                      .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                      .toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => filtros['metodoPago'] = val);
                  fetchData();
                }
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Total Ventas: Bs. ${totalVentas.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Exportar PDF'),
              onPressed: exportarPDF,
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.grid_on),
              label: const Text('Exportar Excel'),
              onPressed: exportarExcel,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildResumenCard(
                  color: Colors.blue.shade100,
                  icon: Icons.attach_money,
                  label: 'Total Ventas',
                  value: 'Bs. ${totalVentas.toStringAsFixed(2)}',
                ),
                _buildResumenCard(
                  color: Colors.green.shade100,
                  icon: Icons.shopping_cart,
                  label: 'Total Pedidos',
                  value: '${pedidosPorEstado.values.fold(0, (a, b) => a + b)}',
                ),
                _buildResumenCard(
                  color: Colors.purple.shade100,
                  icon: Icons.inventory_2,
                  label: 'Productos Vendidos',
                  value:
                      '${productosMasVendidos.fold(0, (a, b) => a + (b['cantidad'] as int))}',
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              'Pedidos por Estado',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Container(
              height: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 6),
                ],
              ),
              child:
                  pedidosPorEstado.isEmpty
                      ? const Center(child: Text('No hay datos para mostrar'))
                      : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          barGroups:
                              pedidosPorEstado.entries
                                  .toList()
                                  .asMap()
                                  .entries
                                  .map((entry) {
                                    int i = entry.key;
                                    String estado = entry.value.key;
                                    int cantidad = entry.value.value;
                                    debugPrint(
                                      'Estado: $estado, cantidad: $cantidad',
                                    );

                                    return BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: cantidad.toDouble(),
                                          width: 18,
                                          color: Colors.blueAccent,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ],
                                    );
                                  })
                                  .toList(),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 28,
                                getTitlesWidget: (value, meta) {
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 4,
                                    child: Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: Colors.black,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: false,
                              ), // desactiva derecha
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: false,
                              ), // opcional
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final estado =
                                      pedidosPorEstado.keys.toList()[value
                                          .toInt()];
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    space: 8,
                                    child: Text(
                                      estado,
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          gridData: FlGridData(show: false),
                        ),
                      ),
            ),
            const SizedBox(height: 30),
            Text(
              'Productos Más Vendidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            productosMasVendidos.isEmpty
                ? const Text('No hay productos vendidos.')
                : Column(
                  children:
                      productosMasVendidos.map((producto) {
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: const Icon(
                              Icons.shopping_bag,
                              color: Colors.blue,
                            ),
                            title: Text(producto['nombre']),
                            subtitle: Text(
                              '${producto['cantidad']} unidades vendidas',
                            ),
                            trailing: Text(
                              'Bs. ${producto['total'].toStringAsFixed(2)}',
                            ),
                          ),
                        );
                      }).toList(),
                ),
            const SizedBox(height: 30),
            Text(
              'Ventas por Método de Pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ventasPorMetodoPago.isEmpty
                ? const Text('No hay datos de métodos de pago.')
                : GridView.count(
                  crossAxisCount:
                      MediaQuery.of(context).size.width > 600 ? 3 : 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children:
                      ventasPorMetodoPago.entries.map((entry) {
                        final metodo = entry.key;
                        final total = entry.value;

                        return Card(
                          color: Colors.orange.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.payment,
                                  size: 32,
                                  color: Colors.orange,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  metodo[0].toUpperCase() + metodo.substring(1),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Bs. ${total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                ),
          ],
        ),
      ),
    );
  }

  Widget _buildResumenCard({
    required Color color,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.black54),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(value, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
