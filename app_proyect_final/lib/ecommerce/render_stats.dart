import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

Widget buildStats({
  required String role,
  required Map<String, dynamic> stats,
  required Function(String) onTabSelect,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        if (role == 'cliente' || role == 'stock')
          _statCard(
            title: 'Total Productos',
            value: '${stats['totalProducts']}',
            icon: FontAwesomeIcons.box,
            iconColor: Colors.blue,
          ),
        if (role == 'cliente' || role == 'vendedor')
          GestureDetector(
            onTap: () => onTabSelect('orders'),
            child: _statCard(
              title: 'Pedidos Totales',
              value: '${stats['totalOrders']}',
              icon: FontAwesomeIcons.shoppingCart,
              iconColor: Colors.green,
            ),
          ),
        if (role == 'cliente' || role == 'vendedor')
          _statCard(
            title: 'Ingresos Totales',
            value: 'Bs. ${stats['totalRevenue']}',
            icon: FontAwesomeIcons.chartLine,
            iconColor: Colors.purple,
          ),
        if (role == 'cliente' || role == 'stock')
          _statCard(
            title: 'Stock Bajo',
            value: '${stats['lowStock']}',
            icon: FontAwesomeIcons.trash,
            iconColor: Colors.red,
          ),
      ],
    ),
  );
}

Widget _statCard({
  required String title,
  required String value,
  required IconData icon,
  required Color iconColor,
}) {
  return Container(
    width: 200,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Icon(icon, color: iconColor, size: 28),
      ],
    ),
  );
}

/// Carga las estadísticas generales según el rol y productos ya obtenidos
Future<Map<String, dynamic>> loadStats({
  required String role,
  required int totalProducts,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('token');

  final headers = {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final Map<String, dynamic> stats = {
    'totalProducts': totalProducts,
    'totalOrders': 0,
    'totalRevenue': 0.0,
    'lowStock': 0,
  };

  try {
    if (role == 'cliente' || role == 'vendedor') {
      final pedidosRes = await http.get(
        Uri.parse('$baseUrl/pedidos-publicos/por_tienda/'),
        headers: headers,
      );
      if (pedidosRes.statusCode == 200) {
        final pedidos = jsonDecode(pedidosRes.body);
        stats['totalOrders'] = pedidos.length;

        double total = 0.0;
        for (var pedido in pedidos) {
          final val = double.tryParse(pedido['total'].toString());
          if (val != null) total += val;
        }
        stats['totalRevenue'] = total;
      }
    }

    if (role == 'cliente' || role == 'stock') {
      final lowStockRes = await http.get(
        Uri.parse('$baseUrl/tiendas/productos/low-stock/'),
        headers: headers,
      );
      if (lowStockRes.statusCode == 200) {
        final lowStock = jsonDecode(lowStockRes.body);
        stats['lowStock'] = lowStock.length;
      }
    }
  } catch (e) {
    print('❌ Error al cargar estadísticas: $e');
  }

  return stats;
}
