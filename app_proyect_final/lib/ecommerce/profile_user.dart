// Archivo: profile_user.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class ProfileUserScreen extends StatefulWidget {
  const ProfileUserScreen({super.key});

  @override
  State<ProfileUserScreen> createState() => _ProfileUserScreenState();
}

class _ProfileUserScreenState extends State<ProfileUserScreen> {
  bool loading = true;
  bool editMode = false;
  bool showPasswordForm = false;
  String? error;
  String? passwordError;
  String? passwordSuccess;
  File? profileImage;
  String? previewImage;
  Map<String, dynamic> user = {};
  final picker = ImagePicker();

  Map<String, String> formData = {
    'first_name': '',
    'last_name': '',
    'email': '',
    'preferred_language': 'es',
    'bio': '',
    'birth_date': '',
    'address': '',
    'city': '',
    'postal_code': '',
    'phone': '',
    'country': '',
  };

  Map<String, String> passwordData = {
    'current_password': '',
    'new_password': '',
    'confirm_password': '',
  };

  final List<Map<String, String>> languages = [
    {'code': 'es', 'name': 'Español'},
    {'code': 'en', 'name': 'English'},
    {'code': 'fr', 'name': 'Français'},
    {'code': 'de', 'name': 'Deutsch'},
  ];

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final response = await http.get(
      Uri.parse('$baseUrl/users/profile/'),

      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      setState(() {
        user = data;
        for (var key in formData.keys) {
          formData[key] = data[key]?.toString() ?? '';
        }
        previewImage =
            data['profile_picture'] != null
                ? '$baseUrl${data['profile_picture']}'
                : null;
        loading = false;
      });
    } else {
      setState(() {
        error = 'Error al cargar el perfil';
        loading = false;
      });
    }
  }

  Future<void> updateProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final request = http.MultipartRequest(
      'PUT',
      Uri.parse('$baseUrl/users/profile/update/'),
    );
    request.headers['Authorization'] = 'Bearer $token';

    formData.forEach((key, value) {
      request.fields[key] = value;
    });

    if (profileImage != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_picture',
          profileImage!.path,
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      fetchUserProfile();
      setState(() {
        editMode = false;
      });
    } else {
      setState(() => error = 'Error al actualizar el perfil');
    }
  }

  Future<void> changePassword() async {
    setState(() {
      passwordError = null;
      passwordSuccess = null;
    });

    if (passwordData['new_password'] != passwordData['confirm_password']) {
      setState(() => passwordError = 'Las contraseñas nuevas no coinciden');
      return;
    }

    if ((passwordData['new_password']?.length ?? 0) < 8) {
      setState(() => passwordError = 'Debe tener al menos 8 caracteres');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final response = await http.put(
      Uri.parse('$baseUrl/users/profile/password/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'current_password': passwordData['current_password'],
        'new_password': passwordData['new_password'],
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        passwordSuccess = 'Contraseña actualizada exitosamente';
        showPasswordForm = false;
        passwordData = {
          'current_password': '',
          'new_password': '',
          'confirm_password': '',
        };
      });
    } else {
      setState(() => passwordError = 'Error al cambiar la contraseña');
    }
  }

  Future<void> pickImage() async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        profileImage = File(picked.path);
        previewImage = picked.path;
      });
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
      appBar: AppBar(title: const Text('Mi Perfil')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: editMode ? pickImage : null,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      previewImage != null
                          ? FileImage(File(previewImage!)) as ImageProvider
                          : null,
                  child:
                      previewImage == null
                          ? const Icon(Icons.person, size: 60)
                          : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...formData.keys.map(
              (key) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: TextFormField(
                  initialValue: formData[key],
                  decoration: InputDecoration(
                    labelText: key.replaceAll('_', ' ').toUpperCase(),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged:
                      editMode
                          ? (val) => setState(() => formData[key] = val)
                          : null,
                  readOnly: !editMode || key == 'email',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: () => setState(() => editMode = !editMode),
                  child: Text(editMode ? 'Cancelar' : 'Editar'),
                ),
                if (editMode)
                  ElevatedButton(
                    onPressed: updateProfile,
                    child: const Text('Guardar Cambios'),
                  ),
              ],
            ),
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cambiar Contraseña',
                  style: TextStyle(fontSize: 18),
                ),
                ElevatedButton(
                  onPressed:
                      () =>
                          setState(() => showPasswordForm = !showPasswordForm),
                  child: Text(showPasswordForm ? 'Cancelar' : 'Cambiar'),
                ),
              ],
            ),
            if (showPasswordForm) ...[
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Contraseña Actual',
                ),
                obscureText: true,
                onChanged: (val) => passwordData['current_password'] = val,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nueva Contraseña',
                ),
                obscureText: true,
                onChanged: (val) => passwordData['new_password'] = val,
              ),
              const SizedBox(height: 8),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Confirmar Contraseña',
                ),
                obscureText: true,
                onChanged: (val) => passwordData['confirm_password'] = val,
              ),
              const SizedBox(height: 8),
              if (passwordError != null)
                Text(passwordError!, style: const TextStyle(color: Colors.red)),
              if (passwordSuccess != null)
                Text(
                  passwordSuccess!,
                  style: const TextStyle(color: Colors.green),
                ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: changePassword,
                  child: const Text('Guardar Contraseña'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
