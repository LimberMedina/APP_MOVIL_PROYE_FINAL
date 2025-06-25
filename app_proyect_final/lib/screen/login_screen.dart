import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class LoginScreen extends StatefulWidget {
  final Function(String) setToken;

  const LoginScreen({super.key, required this.setToken});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool showPassword = false;
  bool loading = false;
  bool success = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _clearStorage();
  }

  Future<void> _clearStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    widget.setToken('');
  }

  Future<void> _handleLogin() async {
    setState(() {
      loading = true;
      errorMessage = null;
      success = false;
    });

    final credentials = {
      "username": _usernameController.text,
      "password": _passwordController.text,
    };

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(credentials),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['access'] != null) {
        final token = data['access'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        widget.setToken(token);

        print('Token guardado: $token'); // debug

        if (data['user'] != null) {
          await prefs.setString('user', jsonEncode(data['user']));
        }

        setState(() => success = true);

        // Esperar 2 segundos y redirigir
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.of(
            context,
          ).pushNamedAndRemoveUntil('/profile', (route) => false);
        });
      } else {
        throw data['detail'] ?? 'Error desconocido';
      }
    } catch (error) {
      final message = error.toString().toLowerCase();
      String msg = "Error al iniciar sesión";

      if (message.contains("no active account")) {
        msg = "No existe una cuenta con estas credenciales";
      } else if (message.contains("invalid credentials")) {
        msg = "Usuario o contraseña incorrectos";
      } else if (message.contains("token")) {
        msg = "Error de autenticación";
      } else if (message.contains("failed host lookup")) {
        msg = "No se pudo conectar con el servidor";
      }

      setState(() => errorMessage = msg);
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Bienvenido',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Inicia sesión en tu cuenta',
                        style: TextStyle(color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 24),

                      if (errorMessage != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error, color: Colors.red),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  errorMessage!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        ),

                      TextField(
                        controller: _usernameController,
                        enabled: !loading,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de usuario',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _passwordController,
                        obscureText: !showPassword,
                        enabled: !loading,
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed:
                                () => setState(
                                  () => showPassword = !showPassword,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: loading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child:
                              loading
                                  ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Text('Iniciando sesión...'),
                                    ],
                                  )
                                  : const Text('Ingresar'),
                        ),
                      ),
                      const SizedBox(height: 20),

                      TextButton(
                        onPressed:
                            () => Navigator.pushNamed(
                              context,
                              '/forgot-password',
                            ),
                        child: const Text("¿Olvidaste tu contraseña?"),
                      ),
                      TextButton(
                        onPressed:
                            () => Navigator.pushNamed(context, '/register'),
                        child: const Text("¿No tienes cuenta? Registrarse"),
                      ),
                    ],
                  ),
                ),

                if (success)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(
                            Icons.check_circle,
                            size: 60,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            '¡Inicio de sesión exitoso!',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
