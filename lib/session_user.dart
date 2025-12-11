// lib/session_user.dart
import 'package:firebase_auth/firebase_auth.dart';

class SessionUser {
  static String userId = "";
  static String nombre = "Nuevo usuario";
  static String email = "";
  static String ciudad = "Ciudad";
  static String pais = "País";
  static String descripcion = "Aquí puedes agregar una breve descripción sobre ti.";
  static String avatarUrl = "https://i.imgur.com/BoN9kdC.png";

  // Inicializar desde Firebase User
  static void initializeFromFirebase(User user, Map<String, dynamic> userData) {
    userId = user.uid;
    email = user.email ?? "";
    nombre = userData['nombre'] ?? user.displayName ?? "Usuario";
    ciudad = userData['ciudad'] ?? "Ciudad";
    pais = userData['pais'] ?? "País";
    descripcion = userData['descripcion'] ?? "Aquí puedes agregar una breve descripción sobre ti.";
    avatarUrl = userData['avatarUrl'] ?? user.photoURL ?? "https://i.imgur.com/BoN9kdC.png";
  }

  // Actualizar campos del perfil
  static void updateProfile({
    String? nuevoNombre,
    String? nuevaCiudad,
    String? nuevoPais,
    String? nuevaDescripcion,
    String? nuevoAvatarUrl,
  }) {
    if (nuevoNombre != null && nuevoNombre.trim().isNotEmpty) {
      nombre = nuevoNombre.trim();
    }
    if (nuevaCiudad != null && nuevaCiudad.trim().isNotEmpty) {
      ciudad = nuevaCiudad.trim();
    }
    if (nuevoPais != null && nuevoPais.trim().isNotEmpty) {
      pais = nuevoPais.trim();
    }
    if (nuevaDescripcion != null && nuevaDescripcion.trim().isNotEmpty) {
      descripcion = nuevaDescripcion.trim();
    }
    if (nuevoAvatarUrl != null && nuevoAvatarUrl.trim().isNotEmpty) {
      avatarUrl = nuevoAvatarUrl.trim();
    }
  }

  // Obtener nombre del usuario
  static String getNombre() => nombre;

  // Verificar si está autenticado
  static bool isAuthenticated() => userId.isNotEmpty;

  // Resetear sesión
  static void reset() {
    userId = "";
    nombre = "Nuevo usuario";
    email = "";
    ciudad = "Ciudad";
    pais = "País";
    descripcion = "Aquí puedes agregar una breve descripción sobre ti.";
    avatarUrl = "https://i.imgur.com/BoN9kdC.png";
  }
}