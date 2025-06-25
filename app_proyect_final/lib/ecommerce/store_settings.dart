// Archivo: store_settings.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'bloque_settings.dart';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';

import '../config.dart';

class StoreSettings extends StatefulWidget {
  const StoreSettings({super.key});

  @override
  State<StoreSettings> createState() => _StoreSettingsState();
}

class _StoreSettingsState extends State<StoreSettings> {
  final picker = ImagePicker();
  bool loading = true;
  bool saving = false;
  bool success = false;
  String? error;
  File? logoFile;
  File? bloqueImagenFile;
  List bloques = [];
  bool mostrarModalBloques = false;
  Map<String, dynamic>? bloqueTemporal;
  int? estiloId;
  bool bloqueGuardado = false;

  Map<String, dynamic> config = {
    'nombre': '',
    'descripcion': '',
    'tema': 'default',
    'color_primario': '#3B82F6',
    'color_secundario': '#1E40AF',
    'color_texto': '#1F2937',
    'color_fondo': '#F3F4F6',
    'publicado': false,
    'logo': null,
    'slug': '',
  };

  Map<String, dynamic> styleConfig = {
    'color_primario': '#3498db',
    'color_secundario': '#2ecc71',
    'color_texto': '#333333',
    'color_fondo': '#ffffff',
    'tipo_fuente': 'Arial',
    'tema': 'claro',
    'vista_producto': 'grid',
    'tema_plantilla': 'clasico',
  };

  final tituloBloqueController = TextEditingController();
  final descripcionBloqueController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchConfig();
  }

  Future<void> fetchConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final headers = {'Authorization': 'Bearer $token'};

      final tiendaRes = await http.get(
        Uri.parse('$baseUrl/tiendas/tiendas/config/'),
        headers: headers,
      );
      final estiloRes = await http.get(
        Uri.parse('$baseUrl/store-style/mi-estilo/'),
        headers: headers,
      );
      final bloquesRes = await http.get(
        Uri.parse('$baseUrl/store-style/bloques/'),
        headers: headers,
      );

      if (tiendaRes.statusCode == 200 && estiloRes.statusCode == 200) {
        final tiendaData = jsonDecode(tiendaRes.body);
        final estiloData = jsonDecode(estiloRes.body);
        final bloquesData = jsonDecode(bloquesRes.body);

        setState(() {
          config = {...config, ...tiendaData};
          styleConfig = {...styleConfig, ...estiloData};
          estiloId = estiloData['id'];
          bloques = bloquesData;
          loading = false;
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      setState(() {
        error = 'Error al cargar la configuración de la tienda';
        loading = false;
      });
    }
  }

  Future<void> handleLogoChange() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        logoFile = File(pickedFile.path);
      });
    }
  }

  Future<String?> subirImagen(File imagen, String token) async {
    final uploadReq = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/store-style/upload-imagen/'),
    );
    uploadReq.headers['Authorization'] = 'Bearer $token';
    uploadReq.files.add(await http.MultipartFile.fromPath('file', imagen.path));

    final uploadRes = await uploadReq.send();
    final body = await uploadRes.stream.bytesToString();

    if (uploadRes.statusCode == 200 || uploadRes.statusCode == 201) {
      final json = jsonDecode(body);
      return json['url'];
    }
    return null;
  }

  Future<void> saveBloqueTemporal() async {
    if (bloqueTemporal == null) {
      print("⚠️ bloqueTemporal es null, no se enviará");
      return;
    }

    final titulo = bloqueTemporal!['titulo']?.toString().trim();
    final descripcion = bloqueTemporal!['descripcion']?.toString().trim();
    final imagen = bloqueTemporal!['imagen'];

    final estaVacio =
        (titulo?.isEmpty ?? true) &&
        (descripcion?.isEmpty ?? true) &&
        imagen == null;

    if (estaVacio) {
      print("⚠️ Formulario de bloque vacío, no se enviará");
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        print("❌ Token no disponible");
        return;
      }

      String? imagenUrl;

      if (imagen is File) {
        final subida = await subirImagen(imagen, token);
        if (subida != null) {
          imagenUrl = subida;
        } else {
          print("❌ Error subiendo imagen");
        }
      } else if (imagen is String) {
        imagenUrl = imagen;
      }

      print("📦 estiloId = $estiloId");

      final bloqueData = {
        'tipo': bloqueTemporal!['tipo'] ?? 'apilado',
        'titulo': titulo ?? 'Sin título',
        'descripcion': descripcion ?? '',
        'imagen': imagenUrl,
        'style': estiloId,
      };

      print("📤 Enviando bloque: $bloqueData");

      final res = await http.post(
        Uri.parse('$baseUrl/store-style/bloques/'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bloqueData),
      );

      print("✅ Status: ${res.statusCode}");
      print("🔁 Body: ${res.body}");

      if (res.statusCode == 201) {
        final newBloque = jsonDecode(res.body);
        setState(() {
          bloques.add(newBloque);
          bloqueTemporal = null;
          tituloBloqueController.clear();
          descripcionBloqueController.clear();
          bloqueGuardado = true;
        });

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => bloqueGuardado = false);
          }
        });
      } else {
        print("❌ Error al crear bloque: ${res.body}");
      }
    } catch (e) {
      print("❌ Excepción al guardar bloque temporal: $e");
    }
  }

  Future<void> saveStyleConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    await http.patch(
      Uri.parse('$baseUrl/store-style/mi-estilo/'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(styleConfig),
    );
  }

  Future<void> saveConfig() async {
    setState(() {
      saving = true;
      error = null;
      success = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      final request = http.MultipartRequest(
        'PATCH',
        Uri.parse('$baseUrl/tiendas/tiendas/config/'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      config.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty && key != 'logo') {
          request.fields[key] = value.toString();
        }
      });

      if (logoFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('logo', logoFile!.path),
        );
      }

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode == 200) {
        // Validar si el bloque temporal tiene contenido útil
        if (bloqueTemporal != null) {
          final titulo = bloqueTemporal!['titulo']?.toString().trim();
          final descripcion = bloqueTemporal!['descripcion']?.toString().trim();
          final imagen = bloqueTemporal!['imagen'];

          final tieneContenido =
              (titulo?.isNotEmpty ?? false) ||
              (descripcion?.isNotEmpty ?? false) ||
              imagen != null;

          if (tieneContenido && estiloId != null) {
            print("✅ Guardando bloque temporal desde saveConfig()");
            await saveBloqueTemporal();
          } else {
            print(
              "⚠️ Bloque temporal no tiene contenido válido o falta estiloId",
            );
          }
        }

        await saveStyleConfig();
        setState(() => success = true);
        await fetchConfig();

        Future.delayed(
          const Duration(seconds: 3),
          () => setState(() => success = false),
        );
      } else {
        throw Exception("Falló guardar configuración");
      }
    } catch (e) {
      setState(() => error = 'Error al guardar la configuración');
      print("❌ Error en saveConfig(): $e");
    } finally {
      setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración de la Tienda')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (error != null)
              _alertBox(
                error!,
                Colors.red,
                FontAwesomeIcons.triangleExclamation,
              ),
            if (success)
              _alertBox(
                'Configuración guardada exitosamente',
                Colors.green,
                FontAwesomeIcons.check,
              ),

            if (bloqueGuardado)
              _alertBox(
                'Bloque guardado exitosamente',
                Colors.green,
                FontAwesomeIcons.check,
              ),

            _sectionTitle('Información Básica', FontAwesomeIcons.store),
            _textField('Nombre de la Tienda', 'nombre'),
            _textField('Descripción', 'descripcion', multiline: true),

            _sectionTitle('Logo y Publicación', FontAwesomeIcons.image),
            _logoPicker(),
            const SizedBox(height: 8),
            _publicacionControl(),

            _sectionTitle('Colores y Estilos', FontAwesomeIcons.palette),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _colorPickerVisual('Color Primario', 'color_primario'),
                const SizedBox(height: 16),
                _colorPickerVisual('Color Secundario', 'color_secundario'),
                const SizedBox(height: 16),
                _colorPickerVisual('Color de Texto', 'color_texto'),
                const SizedBox(height: 16),
                _colorPickerVisual('Color de Fondo', 'color_fondo'),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              "Tipo de Fuente",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: styleConfig['tipo_fuente'],
              onChanged:
                  (value) => setState(() => styleConfig['tipo_fuente'] = value),
              items:
                  ['Arial', 'Roboto', 'Poppins', 'Montserrat', 'Lato']
                      .map(
                        (font) =>
                            DropdownMenuItem(value: font, child: Text(font)),
                      )
                      .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 24),
            const Text(
              "Tema Visual",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: styleConfig['tema'],
              onChanged: (value) => setState(() => styleConfig['tema'] = value),
              items:
                  ['claro', 'oscuro']
                      .map(
                        (tema) => DropdownMenuItem(
                          value: tema,
                          child: Text(
                            tema[0].toUpperCase() + tema.substring(1),
                          ),
                        ),
                      )
                      .toList(),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 24),
            const Text(
              "Vista de Productos",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildVistaCard(
                  "grid",
                  Icons.grid_view,
                  styleConfig['vista_producto'],
                ),
                _buildVistaCard(
                  "list",
                  Icons.view_list,
                  styleConfig['vista_producto'],
                ),
                _buildVistaCard(
                  "detallada",
                  Icons.view_comfy_alt,
                  styleConfig['vista_producto'],
                ),
                _buildVistaCard(
                  "masonry",
                  Icons.dashboard_customize,
                  styleConfig['vista_producto'],
                ),
              ],
            ),

            const SizedBox(height: 32),
            const Text(
              "Personalización de Bloques de Bienvenida",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),
            const Text(
              "Tema de Plantilla",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: styleConfig['tema_plantilla'] ?? 'clasico',
              onChanged:
                  (value) =>
                      setState(() => styleConfig['tema_plantilla'] = value),
              items: const [
                DropdownMenuItem(value: 'clasico', child: Text('Clásico')),
                DropdownMenuItem(value: 'urbano', child: Text('Urbano')),
                DropdownMenuItem(
                  value: 'corporativo',
                  child: Text('Corporativo'),
                ),
              ],
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(top: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bloques de Bienvenida",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            bloqueTemporal = {
                              'tipo': 'apilado',
                              'titulo': '',
                              'descripcion': '',
                              'imagen': null,
                            };
                            tituloBloqueController.text = '';
                            descripcionBloqueController.text = '';
                          });
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          bloqueTemporal != null ? 'Cancelar' : '+ Agregar',
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => Dialog(
                                  insetPadding: const EdgeInsets.all(24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: SizedBox(
                                    width: 800,
                                    height: 600,
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: BloqueSettings(),
                                        ),
                                        Positioned(
                                          right: 0,
                                          top: 0,
                                          child: IconButton(
                                            icon: const Icon(Icons.close),
                                            onPressed:
                                                () =>
                                                    Navigator.of(context).pop(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                          );
                        },
                        child: const Text("Ver todos"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (bloqueTemporal != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Tipo de Bloque"),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: bloqueTemporal!['tipo'],
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
                          onChanged: (val) {
                            setState(() => bloqueTemporal!['tipo'] = val);
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Título"),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: tituloBloqueController,
                          onChanged: (val) => bloqueTemporal!['titulo'] = val,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Descripción"),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: descripcionBloqueController,
                          onChanged:
                              (val) => bloqueTemporal!['descripcion'] = val,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text("Imagen del Bloque"),
                        const SizedBox(height: 6),
                        ElevatedButton(
                          onPressed: () async {
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (picked != null) {
                              setState(() {
                                bloqueTemporal!['imagen'] = File(picked.path);
                              });
                            }
                          },
                          child: const Text("Seleccionar imagen"),
                        ),
                        const SizedBox(height: 12),
                        if (bloqueTemporal!['imagen'] != null && !kIsWeb)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              bloqueTemporal!['imagen'],
                              width: 128,
                              height: 128,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Center(
              child: ElevatedButton.icon(
                onPressed: saving ? null : saveConfig,
                icon:
                    saving
                        ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                        : const Icon(FontAwesomeIcons.floppyDisk),
                label: Text(saving ? 'Guardando...' : 'Guardar Cambios'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorPickerVisual(String label, String key) {
    Color currentColor = Color(
      int.parse(styleConfig[key].replaceFirst('#', '0xff')),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => _showColorDialog(key),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: currentColor,
                        border: Border.all(color: Colors.black26),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      initialValue: styleConfig[key],
                      onChanged: (value) => styleConfig[key] = value,
                      decoration: const InputDecoration(
                        labelText: "Hex",
                        border: OutlineInputBorder(),
                        isDense: true, // reduce altura
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showColorDialog(String key) {
    Color pickerColor = Color(
      int.parse(styleConfig[key].replaceFirst('#', '0xff')),
    );

    showDialog(
      context: context,
      builder: (_) {
        final screenSize = MediaQuery.of(context).size;
        return AlertDialog(
          title: const Text('Selecciona un color'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenSize.height * 0.6,
              maxWidth: screenSize.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: pickerColor,
                onColorChanged: (color) {
                  setState(() {
                    styleConfig[key] =
                        '#${color.value.toRadixString(16).substring(2)}';
                  });
                },
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVistaCard(String tipo, IconData icono, String seleccionActual) {
    final bool seleccionado = tipo == seleccionActual;
    return GestureDetector(
      onTap: () => setState(() => styleConfig['vista_producto'] = tipo),
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: seleccionado ? Colors.blue : Colors.grey,
            width: seleccionado ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: seleccionado ? Colors.blue[50] : Colors.white,
          boxShadow:
              seleccionado
                  ? [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ]
                  : [],
        ),
        child: Column(
          children: [
            Icon(icono, size: 48, color: Colors.grey[600]),
            const SizedBox(height: 12),
            Text(
              "Vista ${tipo[0].toUpperCase()}${tipo.substring(1)}",
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _alertBox(String text, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          FaIcon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          FaIcon(icon, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _textField(String label, String key, {bool multiline = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: config[key]),
        onChanged: (val) => config[key] = val,
        maxLines: multiline ? null : 1,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _logoPicker() {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child:
              logoFile != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(logoFile!, fit: BoxFit.cover),
                  )
                  : config['logo'] != null
                  ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      config['logo'].toString().startsWith('http')
                          ? config['logo'] // ya viene con http://
                          : '$baseUrl/${config['logo']}'.replaceFirst(
                            '/api/',
                            '/',
                          ),
                      fit: BoxFit.cover,
                    ),
                  )
                  : const Icon(Icons.store, size: 32, color: Colors.grey),
        ),
        ElevatedButton(
          onPressed: handleLogoChange,
          child: const Text('Cambiar Logo'),
        ),
      ],
    );
  }

  Widget _publicacionControl() {
    final publicado = config['publicado'] == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: publicado ? Colors.green[100] : Colors.yellow[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                publicado ? 'Publicada' : 'No Publicada',
                style: TextStyle(
                  color: publicado ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: publicado ? Colors.red : Colors.green,
              ),
              onPressed: () => setState(() => config['publicado'] = !publicado),
              child: Text(publicado ? 'Despublicar' : 'Publicar'),
            ),
          ],
        ),
        if (publicado)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Tu tienda es visible públicamente en: /tienda-publica/${config['slug']}',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
      ],
    );
  }
}
