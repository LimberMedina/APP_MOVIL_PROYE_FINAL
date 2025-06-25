// ecommerce.dart
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config.dart';
import '../screen/header_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'render_stats.dart';
import 'orders.dart';
import 'pagos.dart';
import 'store_settings.dart';
import 'product_form.dart';
import 'reportes.dart';
import 'user_tienda.dart';

class TabItem {
  final String label;
  final String value;
  final IconData icon;

  TabItem({required this.label, required this.value, required this.icon});
}

class EcommerceScreen extends StatefulWidget {
  final Map<String, dynamic> user;

  const EcommerceScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<EcommerceScreen> createState() => _EcommerceScreenState();
}

class _EcommerceScreenState extends State<EcommerceScreen> {
  List<dynamic> products = [];
  List<dynamic> categories = [];
  int cartItemsCount = 0;
  bool loading = true;
  String? error;
  dynamic selectedCategory;
  Map<String, dynamic> storeConfig = {};
  bool showCreateDialog = false;
  bool showNewCategoryForm = false;
  String newCategory = '';
  String? categoryError;
  String? categorySuccess;
  String activeTab = 'products';
  dynamic editingProduct;
  bool showAddProduct = false;
  bool showCreateUserDialog = false;

  Map<String, dynamic> stats = {
    'totalProducts': 0,
    'totalOrders': 0,
    'totalRevenue': 0.0,
    'lowStock': 0,
  };

  @override
  void initState() {
    super.initState();
    fetchInitialData();
  }

  Future<void> fetchStats() async {
    final role = widget.user['role'];
    final statsData = await loadStats(
      role: role,
      totalProducts: products.length,
    );
    setState(() => stats = statsData);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  Future<void> fetchInitialData() async {
    if (widget.user.isEmpty) return;

    final role = widget.user['role'];

    if (role == 'cliente' || role == 'stock') {
      await fetchProducts();
      await fetchCategories();
      await fetchCartItemsCount();
    }

    await checkStore();
    setState(() => loading = false);
    await fetchStats();
  }

  Future<void> checkStore() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/tiendas/tiendas/config/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() {
          storeConfig = json.decode(response.body);
          showCreateDialog = false;
        });
      } else if (response.statusCode == 404) {
        setState(() => showCreateDialog = true);
      } else {
        setState(() => error = 'Error al verificar la tienda');
      }
    } catch (e) {
      setState(() => error = 'Error al verificar la tienda');
    }
  }

  Future<void> fetchProducts({int? categoryId}) async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/tiendas/productos/'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final filtered =
            categoryId != null
                ? data.where((p) => p['categoria'] == categoryId).toList()
                : data;
        setState(() {
          products = filtered;
          stats['totalProducts'] = filtered.length;
        });
      } else {
        setState(() => error = 'Error al cargar los productos');
      }
    } catch (e) {
      setState(() => error = 'Error al cargar los productos');
    }
  }

  void handleEditProduct(dynamic product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            contentPadding: const EdgeInsets.all(16),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.9,
              child: SingleChildScrollView(
                child: ProductForm(
                  editingProduct: product,
                  onProductAdded: () {
                    Navigator.of(context).pop(); // Cierra modal
                    fetchProducts(); // Refresca
                  },
                  onCancel: () => Navigator.of(context).pop(),
                ),
              ),
            ),
          ),
    );
  }

  void handleDeleteProduct(int productId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text('¿Eliminar producto?'),
            content: const Text(
              '¿Estás seguro de que deseas eliminar este producto? Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.of(context).pop(); // Cierra el modal
                  await deleteProduct(productId);
                },
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
            ],
          ),
    );
  }

  Future<void> deleteProduct(int id) async {
    final token = await getToken();
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/tiendas/productos/$id/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 204) {
        setState(() {
          products.removeWhere((p) => p['id'] == id);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el producto')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ocurrió un error: $e')));
    }
  }

  Future<void> fetchCategories() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/tiendas/categorias/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        setState(() => categories = json.decode(response.body));
      } else {
        setState(() => error = 'Error al cargar las categorías');
      }
    } catch (e) {
      setState(() => error = 'Error al cargar las categorías');
    }
  }

  Future<void> fetchCartItemsCount() async {
    try {
      final token = await getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/products/cart/'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() => cartItemsCount = data.length);
      }
    } catch (e) {
      print('Error al cargar el carrito: $e');
    }
  }

  Future<void> handleAddCategory() async {
    setState(() {
      categoryError = null;
      categorySuccess = null;
    });
    if (newCategory.trim().isEmpty) {
      setState(() => categoryError = 'El nombre de la categoría es requerido');
      return;
    }
    try {
      final token = await getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/tiendas/categorias/'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'nombre': newCategory.trim()}),
      );
      if (response.statusCode == 201) {
        final newCat = json.decode(response.body);
        setState(() {
          categories.add(newCat);
          newCategory = '';
          showNewCategoryForm = false;
          categorySuccess = 'Categoría agregada exitosamente';
        });
        Future.delayed(const Duration(seconds: 3), () {
          setState(() => categorySuccess = null);
        });
      } else {
        final data = json.decode(response.body);
        setState(
          () =>
              categoryError =
                  data['nombre']?[0] ?? 'Error al agregar la categoría',
        );
        Future.delayed(const Duration(seconds: 3), () {
          setState(() => categoryError = null);
        });
      }
    } catch (e) {
      setState(() => categoryError = 'Error al agregar la categoría');
      Future.delayed(const Duration(seconds: 3), () {
        setState(() => categoryError = null);
      });
    }
  }

  bool isAllowedTo(String section) {
    final role = widget.user['role'];
    final permissions = {
      'cliente': ['products', 'orders', 'payments', 'settings', 'stats'],
      'vendedor': ['orders', 'payments', 'stats'],
      'stock': ['products', 'categories', 'stats'],
    };
    return permissions[role]?.contains(section) ?? false;
  }

  final List<TabItem> tabs = [
    TabItem(label: 'Productos', value: 'products', icon: FontAwesomeIcons.box),
    TabItem(
      label: 'Pedidos',
      value: 'orders',
      icon: FontAwesomeIcons.shoppingCart,
    ),
    TabItem(
      label: 'Pagos',
      value: 'payments',
      icon: FontAwesomeIcons.creditCard,
    ),
    TabItem(
      label: 'Configuración',
      value: 'settings',
      icon: FontAwesomeIcons.cog,
    ),
  ];

  Widget buildTabs() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        children:
            tabs.where((tab) => isAllowedTo(tab.value)).map((tab) {
              final isSelected = activeTab == tab.value;
              return ElevatedButton.icon(
                icon: Icon(tab.icon, size: 16),
                label: Text(tab.label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected ? Colors.blue : Colors.grey[200],
                  foregroundColor: isSelected ? Colors.white : Colors.black,
                ),
                onPressed: () => setState(() => activeTab = tab.value),
              );
            }).toList(),
      ),
    );
  }

  Widget buildCategoryFilter() {
    final role = widget.user['role'];
    if (role != 'cliente' && role != 'stock') return SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(FontAwesomeIcons.filter, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Filtrar por categoría',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                icon: const Icon(FontAwesomeIcons.plus),
                label: const Text('Nueva Categoría'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                onPressed: () => setState(() => showNewCategoryForm = true),
              ),
            ],
          ),

          if (showNewCategoryForm)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Text(
                  'Agregar Nueva Categoría',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (categoryError != null)
                  Text(
                    categoryError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (categorySuccess != null)
                  Text(
                    categorySuccess!,
                    style: const TextStyle(color: Colors.green),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: TextEditingController(text: newCategory),
                        onChanged: (val) => newCategory = val,
                        decoration: const InputDecoration(
                          hintText: 'Nombre de categoría',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: handleAddCategory,
                      icon: const Icon(FontAwesomeIcons.plus),
                      label: const Text('Agregar'),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed:
                          () => setState(() {
                            showNewCategoryForm = false;
                            newCategory = '';
                            categoryError = null;
                          }),
                      icon: const Icon(FontAwesomeIcons.times),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selectedCategory == null ? Colors.blue : Colors.grey[300],
                  foregroundColor:
                      selectedCategory == null ? Colors.white : Colors.black,
                ),
                onPressed: () {
                  setState(() => selectedCategory = null);
                  fetchProducts();
                },
                child: const Text('Todas'),
              ),
              ...categories.map(
                (cat) => ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        selectedCategory == cat['id']
                            ? Colors.blue
                            : Colors.grey[300],
                    foregroundColor:
                        selectedCategory == cat['id']
                            ? Colors.white
                            : Colors.black,
                  ),
                  onPressed: () {
                    setState(() => selectedCategory = cat['id']);
                    fetchProducts(categoryId: cat['id']); // ← con categoría
                  },
                  child: Text(cat['nombre']),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildContent() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null)
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildStats(
            role: widget.user['role'],
            stats: stats,
            onTabSelect: (tab) => setState(() => activeTab = tab),
          ),

          if (activeTab == 'products') ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gestión de Productos y Usuarios',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (isAllowedTo('products'))
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  content: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
                                    child: SingleChildScrollView(
                                      child: ProductForm(
                                        editingProduct: null,
                                        onProductAdded: () {
                                          Navigator.of(context).pop();
                                        },
                                        onCancel:
                                            () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar Producto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),

                    if (widget.user['role'] == 'cliente') ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          final slug = storeConfig['slug'] ?? '';
                          if (slug.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ReportesScreen(slug: slug),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se encontró la tienda para mostrar los reportes.',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(FontAwesomeIcons.chartLine),
                        label: const Text('Reportes de Ventas'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.all(16),
                                  content: SizedBox(
                                    width:
                                        MediaQuery.of(context).size.width * 0.8,
                                    child: SingleChildScrollView(
                                      child: UserTiendaScreen(
                                        storeId: storeConfig['id'],
                                        onUserCreated: () {
                                          Navigator.of(
                                            context,
                                          ).pop(); // Cierra el modal al crear
                                          // Puedes refrescar algo si es necesario
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                          );
                        },
                        icon: const Icon(FontAwesomeIcons.plus),
                        label: const Text('Agregar Usuario'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),
            buildCategoryFilter(),
            const SizedBox(height: 16),
            products.isEmpty
                ? Column(
                  children: const [
                    Icon(
                      FontAwesomeIcons.boxOpen,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 12),
                    Text('No hay productos disponibles en esta categoría'),
                  ],
                )
                : Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children:
                      products.map((product) {
                        final imageUrl =
                            product['imagen'] != null
                                ? product['imagen'].toString().startsWith(
                                      'http',
                                    )
                                    ? product['imagen']
                                    : '$baseUrl${product['imagen']}'
                                : null;

                        return Container(
                          width: 280,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(color: Colors.black12, blurRadius: 4),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Stack(
                                children: [
                                  imageUrl != null
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          height: 120,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Container(
                                        height: 120,
                                        decoration: BoxDecoration(
                                          color: Colors.blue[50],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: const Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              FaIcon(
                                                FontAwesomeIcons.boxOpen,
                                                size: 36,
                                                color: Colors.blue,
                                              ),
                                              SizedBox(height: 4),
                                              Text(
                                                'Sin imagen',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.blueGrey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Row(
                                      children: [
                                        IconButton(
                                          onPressed:
                                              () => handleEditProduct(product),
                                          icon: const FaIcon(
                                            FontAwesomeIcons.edit,
                                            color: Colors.blue,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed:
                                              () => handleDeleteProduct(
                                                product['id'],
                                              ),
                                          icon: const FaIcon(
                                            FontAwesomeIcons.trash,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                product['nombre'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                product['descripcion'] ?? '',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              if (product['categoria_nombre'] != null)
                                Text(
                                  'Categoría: ${product['categoria_nombre']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Bs. ${product['precio']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Stock: ${product['stock']}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
          ] else if (activeTab == 'orders') ...[
            Container(
              height: MediaQuery.of(context).size.height * 0.75,
              child: const OrdersScreen(),
            ),
          ] else if (activeTab == 'payments') ...[
            Container(
              height: MediaQuery.of(context).size.height * 0.75,
              child: const PagosScreen(),
            ),
          ] else if (activeTab == 'settings') ...[
            Container(
              height: MediaQuery.of(context).size.height * 0.75,
              child: const StoreSettings(),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: HeaderScreen(user: widget.user),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        child: Column(children: [buildTabs(), buildContent()]),
      ),
    );
  }
}
