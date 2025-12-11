// lib/screens/publicar_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import '../session_user.dart';

class PublicarScreen extends StatefulWidget {
  const PublicarScreen({super.key});
  @override
  PublicarScreenState createState() => PublicarScreenState();
}

class PublicarScreenState extends State<PublicarScreen> {
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _ingredientesController = TextEditingController();
  final TextEditingController _procedimientoController = TextEditingController();
  final TextEditingController _presupuestoController = TextEditingController();

  File? _selectedImage;
  String? _imageUrl;
  bool _isLoading = false;
  bool _uploadingImage = false;

  String _numPlatos = '1 a 2';
  final List<String> _numPlatosOptions = [
    '1 a 2',
    '2 a 4',
    '4 a 6',
    '6 a 8',
    'Más de 8'
  ];

  // Seleccionar imagen desde galería
  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageUrl = null;
      });
    }
  }

  // Tomar foto con cámara
  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _imageUrl = null;
      });
    }
  }

  // Subir imagen a Firebase Storage
  Future<String?> _uploadImageToStorage(File imageFile) async {
    try {
      setState(() => _uploadingImage = true);

      final String fileName = 'receta_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('recetas_imagenes')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _publicarReceta() async {
    final usuario = SessionUser.isAuthenticated() ? SessionUser.nombre : "Anónimo";

    // Validaciones
    if (_nombreController.text.isEmpty) {
      _showSnack('Ingresa el nombre del plato');
      return;
    }
    if (_ingredientesController.text.isEmpty) {
      _showSnack('Ingresa los ingredientes');
      return;
    }
    if (_procedimientoController.text.isEmpty) {
      _showSnack('Ingresa el procedimiento');
      return;
    }
    if (_presupuestoController.text.isEmpty) {
      _showSnack('Ingresa el presupuesto');
      return;
    }
    if (_selectedImage == null && _imageUrl == null) {
      _showSnack('Selecciona una imagen para la receta');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _imageUrl;

      // Subir imagen si se seleccionó una nueva
      if (_selectedImage != null) {
        finalImageUrl = await _uploadImageToStorage(_selectedImage!);
        if (finalImageUrl == null) {
          throw Exception('Error al subir la imagen');
        }
      }

      // Guardar en Firestore
      await FirebaseFirestore.instance.collection('recetas').add({
        'nombre': _nombreController.text,
        'ingredientes': _ingredientesController.text,
        'procedimiento': _procedimientoController.text,
        'presupuesto': double.tryParse(_presupuestoController.text) ?? 0.0,
        'numeroPlatos': _numPlatos,
        'usuario': usuario,
        'usuarioId': SessionUser.userId,
        'usuarioAvatar': SessionUser.avatarUrl,
        'puntuacion': 0.0,
        'votos': 0,
        'fecha': FieldValue.serverTimestamp(),
        'imagenUrl': finalImageUrl ?? 'https://cdn-icons-png.flaticon.com/512/857/857681.png',
        'likes': [],
      });

      _showSnack('¡Receta publicada con éxito!', isError: false);

      // Limpiar formulario
      _nombreController.clear();
      _ingredientesController.clear();
      _procedimientoController.clear();
      _presupuestoController.clear();
      setState(() {
        _selectedImage = null;
        _imageUrl = null;
        _numPlatos = '1 a 2';
      });
    } catch (e) {
      _showSnack('Error al publicar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {bool isError = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "Comparte tu receta",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField(
              "Nombre del plato",
              "Ej. Lomo Saltado",
              controller: _nombreController,
            ),
            const SizedBox(height: 16),
            const Text("Imagen del plato", style: TextStyle(fontSize: 20)),
            const SizedBox(height: 8),
            
            // Contenedor de imagen
            GestureDetector(
              onTap: _showImagePickerOptions,
              child: Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFBDBDBD), width: 2),
                ),
                child: _uploadingImage
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : _imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _imageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildPlaceholderImage();
                                  },
                                ),
                              )
                            : _buildPlaceholderImage(),
              ),
            ),
            
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _pickImageFromGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Cámara'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              "Ingredientes",
              "Lista los ingredientes necesarios...",
              controller: _ingredientesController,
              maxLines: 5,
            ),
            const SizedBox(height: 16),
            
            _buildTextField(
              "Procedimiento",
              "Describe los pasos para preparar...",
              controller: _procedimientoController,
              maxLines: 8,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    "Presupuesto",
                    "S/.",
                    controller: _presupuestoController,
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Número de platos",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _numPlatos,
                        items: _numPlatosOptions
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _numPlatos = val!),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey[100],
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _publicarReceta,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2A71A),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Publicar Receta",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate,
            size: 60,
            color: Colors.grey[500],
          ),
          const SizedBox(height: 8),
          Text(
            'Toca para agregar una foto',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Desde galería o cámara',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar una foto'),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancelar'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF9E9E9E)),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: maxLines > 1 ? 12 : 14,
            ),
          ),
        ),
      ],
    );
  }
}