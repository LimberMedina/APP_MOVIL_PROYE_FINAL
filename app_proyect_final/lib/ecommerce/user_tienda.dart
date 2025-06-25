import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class UserTiendaScreen extends StatefulWidget {
  final int storeId;
  final VoidCallback onUserCreated;

  const UserTiendaScreen({
    super.key,
    required this.storeId,
    required this.onUserCreated,
  });

  @override
  State<UserTiendaScreen> createState() => _UserTiendaScreenState();
}

class _UserTiendaScreenState extends State<UserTiendaScreen> {
  final _formKey = GlobalKey<FormState>();
  bool loading = false;
  String? error;

  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  String selectedRole = 'stock';
  final List<String> roles = ['stock', 'crm', 'marketing', 'vendedor'];

  Future<void> handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/users/crear-usuario-interno/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'username': usernameController.text,
          'email': emailController.text,
          'password': passwordController.text,
          'role': selectedRole,
          'tienda': widget.storeId,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        widget.onUserCreated();
        Navigator.of(context).pop();
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          error = data['detail'] ?? 'Error al crear usuario';
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error de red al crear usuario';
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Agregar Usuario Interno',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            TextFormField(
              controller: usernameController,
              decoration: const InputDecoration(labelText: 'Nombre de usuario'),
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo electrónico',
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            TextFormField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              obscureText: true,
              validator: (value) => value!.isEmpty ? 'Campo requerido' : null,
            ),
            DropdownButtonFormField<String>(
              value: selectedRole,
              items:
                  roles.map((role) {
                    return DropdownMenuItem(
                      value: role,
                      child: Text(role[0].toUpperCase() + role.substring(1)),
                    );
                  }).toList(),
              onChanged: (value) => setState(() => selectedRole = value!),
              decoration: const InputDecoration(labelText: 'Rol'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: loading ? null : handleSubmit,
                  child: Text(loading ? 'Guardando...' : 'Crear Usuario'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
