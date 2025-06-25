import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  List<dynamic> paymentMethods = [];
  bool loading = true;
  Map<String, dynamic>? editingMethod;

  final formKey = GlobalKey<FormState>();
  Map<String, dynamic> formData = {
    'name': '',
    'payment_type': '',
    'is_active': true,
    'credentials': {},
    'instructions': '',
  };

  @override
  void initState() {
    super.initState();
    fetchMethods();
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchMethods() async {
    try {
      final token = await getToken();
      final res = await http.get(
        Uri.parse('$baseUrl/payments/methods/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200) {
        setState(() {
          paymentMethods = jsonDecode(res.body);
          loading = false;
        });
      } else {
        throw Exception('Error al cargar métodos');
      }
    } catch (e) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar métodos de pago')),
      );
    }
  }

  Future<void> saveMethod() async {
    if (!formKey.currentState!.validate()) return;
    try {
      final token = await getToken();
      final url =
          editingMethod != null
              ? '$baseUrl/payments/methods/${editingMethod!['id']}/'
              : '$baseUrl/payments/methods/';
      final method = editingMethod != null ? 'PATCH' : 'POST';
      final req =
          http.Request(method, Uri.parse(url))
            ..headers['Authorization'] = 'Bearer $token'
            ..headers['Content-Type'] = 'application/json'
            ..body = jsonEncode(formData);

      final streamed = await req.send();
      final body = await streamed.stream.bytesToString();
      print(body);

      if (streamed.statusCode == 200 || streamed.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editingMethod != null ? 'Método actualizado' : 'Método agregado',
            ),
          ),
        );
        editingMethod = null;
        formData = {
          'name': '',
          'payment_type': '',
          'is_active': true,
          'credentials': {},
          'instructions': '',
        };
        fetchMethods();
      } else {
        throw Exception('Error al guardar');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al guardar método de cobro')),
      );
    }
  }

  Widget _buildFormModal() {
    return AlertDialog(
      title: Text(
        editingMethod != null
            ? 'Editar Método de Cobro'
            : 'Agregar Método de Cobro',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                initialValue: formData['name'],
                onChanged: (val) => formData['name'] = val,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Método',
                ),
                validator:
                    (val) => val == null || val.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value:
                    formData['payment_type'].isNotEmpty
                        ? formData['payment_type']
                        : null,
                onChanged: (val) {
                  setState(() {
                    formData['payment_type'] = val!;
                    formData['credentials'] = {};
                  });
                },

                decoration: const InputDecoration(labelText: 'Tipo de Pago'),
                items: const [
                  DropdownMenuItem(value: 'paypal', child: Text('PayPal')),
                  DropdownMenuItem(value: 'stripe', child: Text('Stripe')),
                  DropdownMenuItem(
                    value: 'credit_card',
                    child: Text('Tarjeta de Crédito'),
                  ),
                  DropdownMenuItem(
                    value: 'debit_card',
                    child: Text('Tarjeta de Débito'),
                  ),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('Transferencia Bancaria'),
                  ),
                  DropdownMenuItem(value: 'cash', child: Text('Efectivo')),
                  DropdownMenuItem(
                    value: 'crypto',
                    child: Text('Criptomonedas'),
                  ),
                ],
              ),
              if (formData['payment_type'] == 'paypal') ...[
                TextFormField(
                  initialValue: formData['credentials']?['client_id'] ?? '',
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['client_id'] = val,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'PayPal Client ID',
                  ),
                ),
                TextFormField(
                  initialValue: formData['credentials']?['client_secret'] ?? '',
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['client_secret'] = val,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'PayPal Client Secret',
                  ),
                  obscureText: true,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: formData['credentials']?['sandbox'] ?? true,
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['sandbox'] = val,
                      ),
                  title: const Text('Usar modo Sandbox (pruebas)'),
                ),
              ],
              if (formData['payment_type'] == 'stripe') ...[
                TextFormField(
                  initialValue: formData['credentials']?['public_key'] ?? '',
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['public_key'] = val,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'Stripe Public Key',
                  ),
                ),
                TextFormField(
                  initialValue: formData['credentials']?['secret_key'] ?? '',
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['secret_key'] = val,
                      ),
                  decoration: const InputDecoration(
                    labelText: 'Stripe Secret Key',
                  ),
                  obscureText: true,
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: formData['credentials']?['test_mode'] ?? true,
                  onChanged:
                      (val) => setState(
                        () => formData['credentials']['test_mode'] = val,
                      ),
                  title: const Text('Usar modo de prueba'),
                ),
              ],
              TextFormField(
                initialValue: formData['instructions'],
                onChanged: (val) => formData['instructions'] = val,
                decoration: const InputDecoration(
                  labelText: 'Instrucciones para el Cliente',
                ),
                maxLines: 3,
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: formData['is_active'] ?? true,
                onChanged: (val) => setState(() => formData['is_active'] = val),
                title: const Text('Activar este método de cobro'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () async {
            await saveMethod();
            Navigator.pop(context);
          },
          child: Text(editingMethod != null ? 'Actualizar' : 'Guardar'),
        ),
      ],
    );
  }

  Future<void> deleteMethod(int id) async {
    try {
      final token = await getToken();
      final res = await http.delete(
        Uri.parse('$baseUrl/payments/methods/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 204) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Método eliminado')));
        fetchMethods();
      } else {
        throw Exception();
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error al eliminar')));
    }
  }

  Icon getIcon(String type) {
    switch (type) {
      case 'credit_card':
        return const Icon(FontAwesomeIcons.creditCard, color: Colors.blue);
      case 'debit_card':
        return const Icon(FontAwesomeIcons.moneyBill, color: Colors.green);
      case 'bank_transfer':
        return const Icon(FontAwesomeIcons.exchangeAlt, color: Colors.purple);
      case 'cash':
        return const Icon(FontAwesomeIcons.moneyBillWave, color: Colors.yellow);
      case 'crypto':
        return const Icon(FontAwesomeIcons.bitcoin, color: Colors.orange);
      case 'paypal':
        return const Icon(FontAwesomeIcons.paypal, color: Colors.blue);
      case 'stripe':
        return const Icon(FontAwesomeIcons.stripe, color: Colors.purple);
      default:
        return const Icon(FontAwesomeIcons.creditCard, color: Colors.grey);
    }
  }

  String getName(String type) {
    const types = {
      'credit_card': 'Tarjeta de Crédito',
      'debit_card': 'Tarjeta de Débito',
      'bank_transfer': 'Transferencia Bancaria',
      'cash': 'Efectivo',
      'crypto': 'Criptomonedas',
      'paypal': 'PayPal',
      'stripe': 'Stripe',
    };
    return types[type] ?? type;
  }

  void confirmDelete(int id) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('¿Eliminar método de pago?'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este método? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await deleteMethod(id);
                },
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Métodos de Cobro',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Configura los métodos de pago que aceptarás en tu tienda',
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        editingMethod = null;
                        formData = {
                          'name': '',
                          'payment_type': '',
                          'is_active': true,
                          'credentials': {},
                          'instructions': '',
                        };
                      });
                      showDialog(
                        context: context,
                        builder:
                            (_) => StatefulBuilder(
                              builder: (context, setModalState) {
                                return AlertDialog(
                                  title: const Text('Agregar Método de Cobro'),
                                  content: SingleChildScrollView(
                                    child: Form(
                                      key: formKey,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          TextFormField(
                                            decoration: const InputDecoration(
                                              labelText: 'Nombre del Método',
                                            ),
                                            onChanged:
                                                (val) => formData['name'] = val,
                                          ),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            value:
                                                formData['payment_type']
                                                        .isNotEmpty
                                                    ? formData['payment_type']
                                                    : null,
                                            decoration: const InputDecoration(
                                              labelText: 'Tipo de Pago',
                                            ),
                                            onChanged: (val) {
                                              setState(() {
                                                formData['payment_type'] = val!;
                                                formData['credentials'] = {};
                                              });
                                              setModalState(() {});
                                            },
                                            items: const [
                                              DropdownMenuItem(
                                                value: 'paypal',
                                                child: Text('PayPal'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'stripe',
                                                child: Text('Stripe'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'credit_card',
                                                child: Text(
                                                  'Tarjeta de Crédito',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'debit_card',
                                                child: Text(
                                                  'Tarjeta de Débito',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'bank_transfer',
                                                child: Text(
                                                  'Transferencia Bancaria',
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'cash',
                                                child: Text('Efectivo'),
                                              ),
                                              DropdownMenuItem(
                                                value: 'crypto',
                                                child: Text('Criptomonedas'),
                                              ),
                                            ],
                                          ),
                                          if (formData['payment_type'] ==
                                              'paypal') ...[
                                            TextFormField(
                                              decoration: const InputDecoration(
                                                labelText: 'PayPal Client ID',
                                              ),
                                              onChanged:
                                                  (val) =>
                                                      formData['credentials']['client_id'] =
                                                          val,
                                            ),
                                            TextFormField(
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'PayPal Client Secret',
                                              ),
                                              obscureText: true,
                                              onChanged:
                                                  (val) =>
                                                      formData['credentials']['client_secret'] =
                                                          val,
                                            ),
                                            CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              value:
                                                  formData['credentials']['sandbox'] ??
                                                  true,
                                              onChanged:
                                                  (val) => setState(
                                                    () =>
                                                        formData['credentials']['sandbox'] =
                                                            val,
                                                  ),
                                              title: const Text(
                                                'Usar modo Sandbox (pruebas)',
                                              ),
                                            ),
                                          ],
                                          if (formData['payment_type'] ==
                                              'stripe') ...[
                                            TextFormField(
                                              decoration: const InputDecoration(
                                                labelText: 'Stripe Public Key',
                                              ),
                                              onChanged:
                                                  (val) =>
                                                      formData['credentials']['public_key'] =
                                                          val,
                                            ),
                                            TextFormField(
                                              decoration: const InputDecoration(
                                                labelText: 'Stripe Secret Key',
                                              ),
                                              obscureText: true,
                                              onChanged:
                                                  (val) =>
                                                      formData['credentials']['secret_key'] =
                                                          val,
                                            ),
                                            CheckboxListTile(
                                              contentPadding: EdgeInsets.zero,
                                              value:
                                                  formData['credentials']['test_mode'] ??
                                                  true,
                                              onChanged:
                                                  (val) => setState(
                                                    () =>
                                                        formData['credentials']['test_mode'] =
                                                            val,
                                                  ),
                                              title: const Text(
                                                'Usar modo de prueba',
                                              ),
                                            ),
                                          ],
                                          TextFormField(
                                            decoration: const InputDecoration(
                                              labelText: 'Instrucciones',
                                            ),
                                            onChanged:
                                                (val) =>
                                                    formData['instructions'] =
                                                        val,
                                          ),
                                          CheckboxListTile(
                                            contentPadding: EdgeInsets.zero,
                                            value:
                                                formData['is_active'] ?? true,
                                            onChanged:
                                                (val) => setState(
                                                  () =>
                                                      formData['is_active'] =
                                                          val,
                                                ),
                                            title: const Text(
                                              'Activar este método de cobro',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancelar'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        await saveMethod();
                                        Navigator.pop(context);
                                      },
                                      child: const Text('Guardar'),
                                    ),
                                  ],
                                );
                              },
                            ),
                      );
                    },
                    icon: const Icon(FontAwesomeIcons.plus),
                    label: const Text('Agregar Método de Cobro'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  itemCount: paymentMethods.length,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 400,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.3,
                  ),

                  itemBuilder: (context, index) {
                    final method = paymentMethods[index];
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  getIcon(method['payment_type']),
                                  const SizedBox(width: 8),
                                  Text(
                                    method['name'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    onPressed: () {
                                      setState(() {
                                        editingMethod = method;
                                        formData = {
                                          'name': method['name'],
                                          'payment_type':
                                              method['payment_type'],
                                          'is_active': method['is_active'],
                                          'credentials':
                                              method['credentials'] ?? {},
                                          'instructions':
                                              method['instructions'] ?? '',
                                        };
                                      });
                                      showDialog(
                                        context: context,
                                        builder: (_) => _buildFormModal(),
                                      );
                                    },
                                    icon: const Icon(
                                      FontAwesomeIcons.edit,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed:
                                        () => confirmDelete(method['id']),

                                    icon: const Icon(
                                      FontAwesomeIcons.trash,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Tipo: ${getName(method['payment_type'])}'),
                          if ((method['instructions'] ?? '')
                              .toString()
                              .isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    FontAwesomeIcons.infoCircle,
                                    color: Colors.blue,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      method['instructions'],
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      method['is_active']
                                          ? Colors.green.shade100
                                          : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  method['is_active'] ? 'Activo' : 'Inactivo',
                                  style: TextStyle(
                                    color:
                                        method['is_active']
                                            ? Colors.green
                                            : Colors.red,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              if ((method['credentials']?['sandbox'] ??
                                      false) ||
                                  (method['credentials']?['test_mode'] ??
                                      false))
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Modo Prueba',
                                    style: TextStyle(
                                      color: Colors.orange,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
  }
}
