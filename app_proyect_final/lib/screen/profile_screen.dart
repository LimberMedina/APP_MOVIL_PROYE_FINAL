import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:ppp_proyect_final/screen/header_screen.dart';

import '../config.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? user;
  Map<String, dynamic>? storeConfig;
  bool loading = true;
  String? error;
  bool showCreateDialog = false;
  int cartCount = 0;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
    checkStore();
    loadCartCount();
  }

  Future<void> fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/users/profile/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          user = jsonDecode(response.body);
        });
      } else if (response.statusCode == 401) {
        prefs.remove('token');
        Navigator.pushReplacementNamed(context, '/login');
      } else {
        setState(() => error = 'Error al cargar el perfil');
      }
    } catch (e) {
      setState(() => error = 'Error de red al cargar el perfil');
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> checkStore() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tiendas/tiendas/config/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          storeConfig = jsonDecode(response.body);
          showCreateDialog = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          storeConfig = null;
          showCreateDialog = true;
        });
      } else {
        setState(() => error = 'Error interno al verificar la tienda');
      }
    } catch (e) {
      setState(() => error = 'Error al conectar con el servidor');
    }
  }

  Future<void> loadCartCount() async {
    final prefs = await SharedPreferences.getInstance();
    final storedCart = prefs.getString('cart');

    if (storedCart != null) {
      final List<dynamic> cart = jsonDecode(storedCart);
      int totalItems = cart.fold<int>(
        0,
        (sum, item) => sum + (item['quantity'] as int),
      );
      setState(() => cartCount = totalItems);
    }
  }

  void handleCardClick(String route) {
    if (user != null) {
      Navigator.pushNamed(context, route, arguments: user);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error != null) {
      return Scaffold(
        body: Center(
          child: Text(error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      appBar: HeaderScreen(title: 'Perfil', showBackButton: false, user: user),
      backgroundColor: Colors.grey[100],
      body: ListView(
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                user?['profile_picture'] != null
                    ? CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(
                        'http://localhost:8000${user!['profile_picture']}',
                      ),
                    )
                    : const CircleAvatar(
                      radius: 50,
                      child: Icon(FontAwesomeIcons.user, size: 40),
                    ),
                const SizedBox(height: 12),
                Text(
                  user?['first_name'] != null
                      ? '${user!['first_name']} ${user!['last_name']}'
                      : user?['username'] ?? 'Usuario',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?['email'] ?? 'No disponible',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Chip(
                  label: Text(user?['role'] ?? 'Usuario'),
                  backgroundColor: Colors.blue[100],
                  labelStyle: const TextStyle(color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Selecciona el tipo de solución que deseas usar',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildCard(
                  icon: FontAwesomeIcons.users,
                  title: "CRM",
                  description:
                      "Gestiona clientes, oportunidades y tareas comerciales desde una sola plataforma.",
                  color: Colors.blue,
                  onTap: () => handleCardClick('/crm'),
                ),
                const SizedBox(height: 20),
                _buildCard(
                  icon: FontAwesomeIcons.store,
                  title: "E-commerce",
                  description:
                      "Administra tu tienda virtual, productos, pagos y envíos de forma automatizada.",
                  color: Colors.green,
                  onTap: () => handleCardClick('/app-ecommerce'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    );
  }
}
