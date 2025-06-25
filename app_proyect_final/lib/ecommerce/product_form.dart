import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProductForm extends StatefulWidget {
  final Map<String, dynamic>? editingProduct;
  final VoidCallback? onProductAdded;
  final VoidCallback? onCancel;

  const ProductForm({
    super.key,
    this.editingProduct,
    this.onProductAdded,
    this.onCancel,
  });

  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final _formKey = GlobalKey<FormState>();
  List<dynamic> categories = [];
  bool showNewCategoryForm = false;
  String newCategory = '';
  String? error;
  String? success;

  TextEditingController nombreCtrl = TextEditingController();
  TextEditingController descripcionCtrl = TextEditingController();
  TextEditingController precioCtrl = TextEditingController();
  TextEditingController stockCtrl = TextEditingController();
  String? selectedCategory;
  File? imageFile;
  String? imageUrl;

  @override
  void initState() {
    super.initState();
    fetchCategories();

    if (widget.editingProduct != null) {
      final p = widget.editingProduct!;
      nombreCtrl.text = p['nombre'] ?? '';
      descripcionCtrl.text = p['descripcion'] ?? '';
      precioCtrl.text = p['precio'].toString();
      stockCtrl.text = p['stock'].toString();
      selectedCategory = p['categoria']?.toString();

      if (p['imagen'] != null) {
        imageUrl =
            p['imagen'].toString().startsWith('http')
                ? p['imagen']
                : '$baseUrl${p['imagen']}';
      }
    }
  }

  Future<void> fetchCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/tiendas/categorias/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          categories = jsonDecode(response.body);
        });
      } else {
        setState(
          () => error = 'Error al cargar categorías: ${response.statusCode}',
        );
      }
    } catch (e) {
      setState(() => error = 'Error al conectar con el servidor');
    }
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final uri =
        widget.editingProduct != null
            ? Uri.parse(
              '$baseUrl/tiendas/productos/${widget.editingProduct!['id']}/',
            )
            : Uri.parse('$baseUrl/tiendas/productos/');

    var request = http.MultipartRequest(
      widget.editingProduct != null ? 'PUT' : 'POST',
      uri,
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    request.fields['nombre'] = nombreCtrl.text;
    request.fields['descripcion'] = descripcionCtrl.text;
    request.fields['precio'] = precioCtrl.text;
    request.fields['stock'] = stockCtrl.text;

    if (selectedCategory != null) {
      request.fields['categoria'] = selectedCategory!;
    }

    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath('imagen', imageFile!.path),
      );
    }

    try {
      final response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        setState(() {
          success =
              widget.editingProduct != null
                  ? 'Producto actualizado'
                  : 'Producto agregado';
          error = null;
        });
        widget.onProductAdded?.call();
      } else {
        setState(() => error = 'Error al guardar el producto');
      }
    } catch (e) {
      setState(() => error = 'Fallo al conectar con el servidor');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.editingProduct != null
                  ? 'Editar Producto'
                  : 'Agregar Nuevo Producto',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(error!, style: const TextStyle(color: Colors.red)),
            ],
            if (success != null) ...[
              const SizedBox(height: 8),
              Text(success!, style: const TextStyle(color: Colors.green)),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: nombreCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del Producto',
              ),
              validator:
                  (value) => value!.isEmpty ? 'Este campo es requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descripcionCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: precioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Precio'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: stockCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Stock'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedCategory,
              hint: const Text('Seleccionar categoría'),
              onChanged: (val) => setState(() => selectedCategory = val),
              items:
                  categories.map((c) {
                    return DropdownMenuItem(
                      value: c['id'].toString(),
                      child: Text(c['nombre']),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickImage,
              icon: const Icon(Icons.image),
              label: const Text('Seleccionar Imagen'),
            ),

            const SizedBox(height: 8),

            if (imageFile != null) ...[
              Image.file(
                imageFile!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ] else if (imageUrl != null) ...[
              Image.network(
                imageUrl!,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ] else ...[
              Container(
                width: 100,
                height: 100,
                color: Colors.grey[200],
                child: const Center(child: Text('Sin imagen')),
              ),
            ],

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: widget.onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: submitForm,
                  child: Text(
                    widget.editingProduct != null ? 'Actualizar' : 'Agregar',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
