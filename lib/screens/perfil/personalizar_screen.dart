import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../session_user.dart';

class PersonalizarPerfilScreen extends StatefulWidget {
  const PersonalizarPerfilScreen({super.key});

  @override
  State<PersonalizarPerfilScreen> createState() =>
      _PersonalizarPerfilScreenState();
}

class _PersonalizarPerfilScreenState extends State<PersonalizarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String nombre = '';
  String ciudad = '';
  String pais = '';
  String descripcion = '';
  File? _selectedImage;
  bool _isLoading = false;
  bool _uploadingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (!SessionUser.isAuthenticated()) return;
    
    setState(() => _isLoading = true);

    try {
      // Cargar datos de SessionUser
      setState(() {
        nombre = SessionUser.nombre;
        ciudad = SessionUser.ciudad;
        pais = SessionUser.pais;
        descripcion = SessionUser.descripcion;
      });
    } catch (e) {
      _showSnack('Error al cargar perfil: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) return null;

    try {
      setState(() => _uploadingImage = true);

      final String fileName = 'perfil_${SessionUser.userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('perfiles')
          .child(fileName);

      final UploadTask uploadTask = storageRef.putFile(_selectedImage!);
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      return downloadUrl;
    } catch (e) {
      return null;
    } finally {
      setState(() => _uploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    if (!SessionUser.isAuthenticated()) {
      _showSnack('No hay usuario autenticado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? avatarUrl;

      // Subir imagen si se seleccionó una nueva
      if (_selectedImage != null) {
        avatarUrl = await _uploadProfileImage();
        if (avatarUrl == null) {
          throw Exception('Error al subir la imagen');
        }
      }

      // Actualizar en Firestore
      await _firestore.collection('usuarios').doc(SessionUser.userId).set({
        'uid': SessionUser.userId,
        'nombre': nombre,
        'email': SessionUser.email,
        'ciudad': ciudad,
        'pais': pais,
        'descripcion': descripcion,
        'avatarUrl': avatarUrl ?? SessionUser.avatarUrl,
        'ultimaActualizacion': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Actualizar SessionUser
      SessionUser.updateProfile(
        nuevoNombre: nombre,
        nuevaCiudad: ciudad,
        nuevoPais: pais,
        nuevaDescripcion: descripcion,
        nuevoAvatarUrl: avatarUrl,
      );

      // Actualizar displayName en Firebase Auth
      final user = _auth.currentUser;
      if (user != null && nombre.isNotEmpty) {
        await user.updateDisplayName(nombre);
      }

      _showSnack('Perfil guardado correctamente', isError: false);
      
      // Esperar un momento antes de regresar
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      _showSnack('Error: $e');
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
        title: const Text("Editar Perfil"),
        backgroundColor: const Color(0xFFF2A71A),
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading && nombre.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const SizedBox(height: 10),
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.orange[300],
                            backgroundImage: _selectedImage != null
                                ? FileImage(_selectedImage!) as ImageProvider
                                : SessionUser.avatarUrl.isNotEmpty
                                    ? NetworkImage(SessionUser.avatarUrl)
                                    : const AssetImage(
                                            'lib/assets/images/default_avatar.png')
                                        as ImageProvider,
                            child: _uploadingImage
                                ? const CircularProgressIndicator(
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2A71A),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: IconButton(
                                icon: const Icon(Icons.edit, size: 20),
                                color: Colors.white,
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      initialValue: nombre,
                      decoration: const InputDecoration(
                        labelText: 'Nombre',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (val) =>
                          val == null || val.isEmpty ? 'Ingresa tu nombre' : null,
                      onSaved: (val) => nombre = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: ciudad,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city),
                      ),
                      onSaved: (val) => ciudad = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: pais,
                      decoration: const InputDecoration(
                        labelText: 'País',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.flag),
                      ),
                      onSaved: (val) => pais = val ?? '',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: descripcion,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                      onSaved: (val) => descripcion = val ?? '',
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF2A71A),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Guardar Cambios',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}