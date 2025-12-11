// lib/screens/buscar_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BuscarScreen extends StatefulWidget {
  const BuscarScreen({super.key});
  @override
  BuscarScreenState createState() => BuscarScreenState();
}

class BuscarScreenState extends State<BuscarScreen> {
  final String apiKey = '93xCGh1BltRSsjR3kMiQQDxzrRGYFhapghxg6ESi';
  final TextEditingController _alimentoController = TextEditingController();
  Map<String, dynamic>? _nutricionData;
  bool _buscando = false;
  String _error = '';

  // Función para buscar información nutricional
  Future<void> _buscarNutricion() async {
    if (_alimentoController.text.isEmpty) return;

    setState(() {
      _buscando = true;
      _error = '';
      _nutricionData = null;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$apiKey&query=${Uri.encodeQueryComponent(_alimentoController.text)}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['foods'] != null && data['foods'].isNotEmpty) {
          setState(() {
            _nutricionData = data['foods'][0];
          });
        } else {
          setState(() {
            _error =
                'No se encontró información para "${_alimentoController.text}"';
          });
        }
      } else {
        setState(() {
          _error = 'Error en la búsqueda. Intenta nuevamente.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error de conexión: $e';
      });
    } finally {
      setState(() {
        _buscando = false;
      });
    }
  }

  // Función para extraer nutrientes específicos
  String _obtenerNutriente(String nombreNutriente) {
    if (_nutricionData?['foodNutrients'] == null) return 'No disponible';

    for (var nutriente in _nutricionData!['foodNutrients']) {
      if (nutriente['nutrientName'] == nombreNutriente) {
        return '${nutriente['value']?.toStringAsFixed(1) ?? '0'} ${nutriente['unitName'] ?? ''}';
      }
    }
    return 'No disponible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFFF2A71A),
        title: const Text("Buscar Recetas"),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Búsqueda de recetas (existente)
              TextField(
                decoration: InputDecoration(
                  hintText: "Busca tu receta aquí",
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // NUEVA SECCIÓN: Búsqueda de valor nutricional
              _buildSeccionNutricion(),

              const SizedBox(height: 24),

              // Categorías con iconos de Flutter
              GridView.count(
                crossAxisCount: 4,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildCategoryItem("Desayuno", Icons.breakfast_dining),
                  _buildCategoryItem("Snack", Icons.fastfood),
                  _buildCategoryItem("Almuerzo", Icons.lunch_dining),
                  _buildCategoryItem("Cena", Icons.dinner_dining),
                  _buildCategoryItem("Refrigerios", Icons.icecream),
                  _buildCategoryItem("Postres", Icons.cake),
                  _buildCategoryItem("Bebidas", Icons.local_cafe),
                  _buildCategoryItem("Ver más...", Icons.more_horiz),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Nueva sección para búsqueda nutricional
  Widget _buildSeccionNutricion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "🔍 Valor Nutricional",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          "Busca el valor nutricional de cualquier alimento:",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),

        // Campo de búsqueda nutricional
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _alimentoController,
                decoration: InputDecoration(
                  hintText: "Ej: manzana, arroz, pollo...",
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _buscarNutricion(),
              ),
            ),
            const SizedBox(width: 8),
            _buscando
                ? const CircularProgressIndicator()
                : IconButton(
                    icon: const Icon(Icons.search, color: Color(0xFFF2A71A)),
                    onPressed: _buscarNutricion,
                  ),
          ],
        ),

        const SizedBox(height: 16),

        // Mostrar resultados o errores
        if (_error.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error, style: const TextStyle(color: Colors.red)),
          ),

        if (_nutricionData != null) _buildResultadoNutricion(),
      ],
    );
  }

  // Widget para mostrar los resultados nutricionales
  Widget _buildResultadoNutricion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _nutricionData!['description'] ?? 'Alimento',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoNutricional('🔥 Calorías', _obtenerNutriente('Energy')),
          _buildInfoNutricional('💪 Proteína', _obtenerNutriente('Protein')),
          _buildInfoNutricional('🌾 Carbohidratos',
              _obtenerNutriente('Carbohydrate, by difference')),
          _buildInfoNutricional(
              '🥑 Grasas', _obtenerNutriente('Total lipid (fat)')),
          _buildInfoNutricional(
              '🍬 Azúcares', _obtenerNutriente('Sugars, total including NLEA')),
          _buildInfoNutricional(
              '🌿 Fibra', _obtenerNutriente('Fiber, total dietary')),
        ],
      ),
    );
  }

  Widget _buildInfoNutricional(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(titulo, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(valor, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // Categorías con iconos de Flutter
  Widget _buildCategoryItem(String title, IconData icon) {
    return InkWell(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[200]!,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.black),
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}