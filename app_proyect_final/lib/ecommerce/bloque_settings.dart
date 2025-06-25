import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../config.dart';

class BloqueSettings extends StatefulWidget {
  const BloqueSettings({super.key});

  @override
  State<BloqueSettings> createState() => _BloqueSettingsState();
}

class _BloqueSettingsState extends State<BloqueSettings> {
  List<dynamic> bloques = [];
  Map<String, dynamic> bloqueEditado = {};
  bool loading = true;
  bool mostrarModalEliminar = false;
  int? bloqueAEliminar;
  String? mensaje;
  int? editandoId;
  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    fetchBloques();
  }

  Future<void> fetchBloques() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final res = await http.get(
      Uri.parse('$baseUrl/store-style/bloques/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      setState(() {
        bloques = jsonDecode(res.body);
        loading = false;
      });
    }
  }

  void handleEdit(Map<String, dynamic> bloque) {
    setState(() {
      editandoId = bloque['id'];
      bloqueEditado = {...bloque};
    });
  }

  Future<void> handleUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    String? imagenUrl = bloqueEditado['imagen'];

    if (imagenUrl is File) {
      final file = imagenUrl as File; // <- cast explícito
      final uploadReq = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/store-style/upload-imagen/'),
      );
      uploadReq.headers['Authorization'] = 'Bearer $token';
      uploadReq.files.add(await http.MultipartFile.fromPath('file', file.path));
      final uploadRes = await uploadReq.send();
      final uploadBody = await uploadRes.stream.bytesToString();
      imagenUrl = jsonDecode(uploadBody)['url'];
    }

    final res = await http.patch(
      Uri.parse('$baseUrl/store-style/bloques/${bloqueEditado['id']}/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'tipo': bloqueEditado['tipo'],
        'titulo': bloqueEditado['titulo'],
        'descripcion': bloqueEditado['descripcion'],
        'imagen': imagenUrl,
      }),
    );

    if (res.statusCode == 200) {
      setState(() {
        final idx = bloques.indexWhere((b) => b['id'] == bloqueEditado['id']);
        if (idx != -1) bloques[idx] = {...bloqueEditado, 'imagen': imagenUrl};
        editandoId = null;
        bloqueEditado = {};
        mensaje = 'Bloque actualizado correctamente';
      });
      Future.delayed(
        const Duration(seconds: 3),
        () => setState(() => mensaje = null),
      );
    }
  }

  void handleDeleteClick(int id) {
    setState(() {
      bloqueAEliminar = id;
      mostrarModalEliminar = true;
    });
  }

  Future<void> handleDeleteConfirm() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    await http.delete(
      Uri.parse('$baseUrl/store-style/bloques/$bloqueAEliminar/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    setState(() {
      bloques.removeWhere((b) => b['id'] == bloqueAEliminar);
      mostrarModalEliminar = false;
      mensaje = 'Bloque eliminado correctamente';
    });
    Future.delayed(
      const Duration(seconds: 3),
      () => setState(() => mensaje = null),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(FontAwesomeIcons.cube, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Bloques de Bienvenida",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (mensaje != null)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  border: Border.all(color: Colors.green.shade200),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      FontAwesomeIcons.checkCircle,
                      color: Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mensaje!,
                        style: const TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            Column(
              children:
                  bloques.map((bloque) {
                    final esEditando = editandoId == bloque['id'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.topRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () => handleEdit(bloque),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed:
                                      () => handleDeleteClick(bloque['id']),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (esEditando && bloqueEditado['imagen'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child:
                                  bloqueEditado['imagen'] is File
                                      ? Image.file(
                                        bloqueEditado['imagen'],
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      )
                                      : Image.network(
                                        bloqueEditado['imagen']
                                                .toString()
                                                .startsWith('http')
                                            ? bloqueEditado['imagen']
                                            : '$mediaUrl${bloqueEditado['imagen']}',
                                        height: 120,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                            )
                          else if (bloque['imagen'] != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                bloque['imagen'].toString().startsWith('http')
                                    ? bloque['imagen']
                                    : '$mediaUrl${bloque['imagen']}',
                                height: 120,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              height: 120,
                              color: Colors.grey[100],
                              child: const Center(
                                child: Icon(
                                  Icons.image,
                                  size: 40,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          const SizedBox(height: 8),
                          if (esEditando)
                            Column(
                              children: [
                                DropdownButtonFormField<String>(
                                  value: bloqueEditado['tipo'],
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'apilado',
                                      child: Text('Apilado'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'en_linea',
                                      child: Text('En línea'),
                                    ),
                                  ],
                                  onChanged:
                                      (val) => setState(
                                        () => bloqueEditado['tipo'] = val,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: bloqueEditado['titulo'],
                                  onChanged:
                                      (val) => bloqueEditado['titulo'] = val,
                                  decoration: const InputDecoration(
                                    labelText: 'Título',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: bloqueEditado['descripcion'],
                                  onChanged:
                                      (val) =>
                                          bloqueEditado['descripcion'] = val,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                    labelText: 'Descripción',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final picked = await picker.pickImage(
                                      source: ImageSource.gallery,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        bloqueEditado['imagen'] = File(
                                          picked.path,
                                        );
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.upload_file),
                                  label: const Text('Cambiar imagen'),
                                ),
                                const SizedBox(height: 8),
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    ElevatedButton(
                                      onPressed: handleUpdate,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      child: const Text(
                                        'Actualizar',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton(
                                      onPressed: () {
                                        setState(() {
                                          editandoId = null;
                                          bloqueEditado = {};
                                        });
                                      },
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(
                                          color: Colors.grey,
                                        ),
                                      ),
                                      child: const Text('Cancelar'),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else ...[
                            Text(
                              bloque['titulo'] ?? '(Sin título)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              bloque['descripcion'] ?? '(Sin descripción)',
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Chip(
                              label: Text(
                                bloque['tipo'] ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.blue,
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
            ),
            if (mostrarModalEliminar)
              AlertDialog(
                title: const Text('¿Eliminar bloque?'),
                content: const Text('Esta acción no se puede deshacer.'),
                actions: [
                  TextButton(
                    onPressed:
                        () => setState(() => mostrarModalEliminar = false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: handleDeleteConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    child: const Text('Sí, eliminar'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
