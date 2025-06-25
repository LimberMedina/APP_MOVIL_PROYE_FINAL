import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screen/login_screen.dart';
import 'screen/profile_screen.dart';
import 'crm/crm.dart';
import 'ecommerce/ecommerce.dart';
import 'ecommerce/profile_user.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); // Necesario para async antes de runApp
  await initializeDateFormatting(
    'es_ES',
    null,
  ); // Carga datos de localización para español
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String token = '';

  @override
  void initState() {
    super.initState();
    _loadToken();
  }

  Future<void> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    final storedToken = prefs.getString('token');
    setState(() {
      token = storedToken ?? '';
    });
  }

  void setToken(String newToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
    setState(() {
      token = newToken;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CRM-Ecommerce App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      initialRoute: token.isNotEmpty ? '/profile' : '/login',
      routes: {
        '/login': (context) => LoginScreen(setToken: setToken),
        '/profile': (context) => const ProfileScreen(),
        '/crm': (context) => const CRM(),

        '/app-ecommerce': (context) {
          final user =
              ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
          return EcommerceScreen(user: user);
        },
        '/user-profile': (context) => const ProfileUserScreen(), // ✅ NUEVA RUTA
      },
    );
  }
}
