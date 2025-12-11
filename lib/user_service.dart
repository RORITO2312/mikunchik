// lib/user_service.dart
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Registrar un nuevo usuario
  Future<bool> registerUser(
      String nombre, String email, String password) async {
    try {
      final usuariosRef = _firestore.collection('usuarios');

      // Verificar si ya existe el correo
      final existingUser =
          await usuariosRef.where('email', isEqualTo: email).get();
      if (existingUser.docs.isNotEmpty) {
        return false; // correo ya registrado
      }

      // Registrar nuevo usuario
      await usuariosRef.add({
        'nombre': nombre,
        'email': email,
        'password': password,
        'fechaRegistro': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      log('Error al registrar usuario: $e');
      return false;
    }
  }
}