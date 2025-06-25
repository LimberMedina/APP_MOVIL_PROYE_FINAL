import 'package:flutter/material.dart';

class CrmScreen extends StatelessWidget {
  const CrmScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('CRM')),
      body: const Center(child: Text('Pantalla CRM')),
    );
  }
}
