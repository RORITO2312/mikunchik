import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/services.dart';
import '../../session_user.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  LoginScreenState createState() => LoginScreenState();
}

// Clase FakeUser simplificada - NO hereda de User
class FakeUser {
  final String uid;
  final String email;
  final String? displayName;
  final String? photoURL;

  FakeUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoURL,
  });

  factory FakeUser.fromMap({
    required String id,
    required String email,
    String? displayName,
    String? photoURL,
  }) {
    return FakeUser(
      uid: id,
      email: email,
      displayName: displayName,
      photoURL: photoURL,
    );
  }
}

class LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailOrUserController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  Future<void> _login() async {
    final input = _emailOrUserController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      _showSnack('Por favor completa todos los campos');
      return;
    }

    setState(() => _loading = true);

    try {
      // Intentar login con Firebase Auth (email)
      try {
        final UserCredential userCredential =
            await _auth.signInWithEmailAndPassword(
          email: input,
          password: password,
        );

        if (userCredential.user != null) {
          await _handleSuccessfulLogin(userCredential.user!);
          return;
        }
      } on FirebaseAuthException catch (e) {
        // Si falla Firebase Auth, intentar con Firestore
        log('Firebase Auth failed: $e');
        // Continuar con login por Firestore
      }

      // Login con Firestore (backup)
      await _loginWithFirestore(input, password);
    } catch (e) {
      _showSnack('Error: ${e.toString()}');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginWithFirestore(String input, String password) async {
    QuerySnapshot<Map<String, dynamic>> result = await FirebaseFirestore.instance
        .collection('usuarios')
        .where('nombre', isEqualTo: input)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      result = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('email', isEqualTo: input)
          .limit(1)
          .get();
    }

    if (result.docs.isEmpty) {
      _showSnack('Usuario no encontrado');
      return;
    }

    final userData = result.docs.first.data();
    final storedPassword = userData['password'];

    if (password == storedPassword) {
      // Crear FakeUser para SessionUser
      final fakeUser = FakeUser.fromMap(
        id: result.docs.first.id,
        email: userData['email'] ?? '',
        displayName: userData['nombre'] ?? 'Usuario',
        photoURL: userData['avatarUrl'] ?? '',
      );

      await _handleFakeUserLogin(fakeUser);
      _showSnack('Bienvenido, ${userData['nombre']}');
    } else {
      _showSnack('Contraseña incorrecta');
    }
  }

  Future<void> _handleFakeUserLogin(FakeUser fakeUser) async {
    try {
      // Obtener datos del usuario de Firestore
      Map<String, dynamic>? userData;
      
      // Buscar por UID
      final uidQuery = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('uid', isEqualTo: fakeUser.uid)
          .limit(1)
          .get();
      
      if (uidQuery.docs.isNotEmpty) {
        userData = uidQuery.docs.first.data();
      } else {
        // Buscar por email
        final emailQuery = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: fakeUser.email)
            .limit(1)
            .get();
        
        if (emailQuery.docs.isNotEmpty) {
          userData = emailQuery.docs.first.data();
        }
      }

      // Inicializar SessionUser con FakeUser
      SessionUser.userId = fakeUser.uid;
      SessionUser.email = fakeUser.email;
      SessionUser.nombre = fakeUser.displayName ?? 'Usuario';
      SessionUser.avatarUrl = fakeUser.photoURL ?? '';
      
      if (userData != null) {
        SessionUser.ciudad = userData['ciudad'] ?? '';
        SessionUser.pais = userData['pais'] ?? '';
        SessionUser.descripcion = userData['descripcion'] ?? '';
      }

      _navigateToMain();
    } catch (e) {
      log('Error en _handleFakeUserLogin: $e');
      _navigateToMain();
    }
  }

  Future<void> _handleSuccessfulLogin(User user) async {
    try {
      // Obtener datos del usuario de Firestore
      Map<String, dynamic>? userData;
      
      // Buscar por UID primero
      final uidQuery = await FirebaseFirestore.instance
          .collection('usuarios')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();
      
      if (uidQuery.docs.isNotEmpty) {
        userData = uidQuery.docs.first.data();
      } else {
        // Buscar por email
        final emailQuery = await FirebaseFirestore.instance
            .collection('usuarios')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        
        if (emailQuery.docs.isNotEmpty) {
          userData = emailQuery.docs.first.data();
        }
      }

      // Inicializar SessionUser
      SessionUser.initializeFromFirebase(user, userData ?? {});

      _navigateToMain();
    } catch (e) {
      log('Error en _handleSuccessfulLogin: $e');
      // Inicializar con datos mínimos si hay error
      SessionUser.userId = user.uid;
      SessionUser.email = user.email ?? '';
      SessionUser.nombre = user.displayName ?? 'Usuario';
      SessionUser.avatarUrl = user.photoURL ?? SessionUser.avatarUrl;
      
      _navigateToMain();
    }
  }

  // Login con Google
  Future<void> _loginWithGoogle() async {
    try {
      setState(() => _loading = true);

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        _showSnack('Inicio de sesión cancelado');
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        await _handleFirestoreUser(userCredential.user!);
        await _handleSuccessfulLogin(userCredential.user!);
        _showSnack('¡Bienvenido, ${userCredential.user!.displayName}!');
      } else {
        _showSnack('Error: No se pudo obtener información del usuario');
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } on PlatformException catch (e) {
      _showSnack('Error del dispositivo: ${e.message}');
    } catch (e) {
      _showSnack('Algo salió mal. Intenta de nuevo.');
    } finally {
      setState(() => _loading = false);
    }
  }

  // Manejo de usuarios en Firestore para Google Sign-In
  Future<void> _handleFirestoreUser(User user) async {
    try {
      final usersRef = FirebaseFirestore.instance.collection('usuarios');
      
      // Verificar si el usuario ya existe
      final userQuery = await usersRef
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      final userData = {
        'uid': user.uid,
        'email': user.email,
        'nombre': user.displayName ?? 'Usuario Google',
        'avatarUrl': user.photoURL ?? '',
        'ciudad': 'Ciudad',
        'pais': 'País',
        'descripcion': 'Usuario de Google',
        'provider': 'google',
        'fecha_creacion': FieldValue.serverTimestamp(),
        'ultimo_login': FieldValue.serverTimestamp(),
      };

      if (userQuery.docs.isEmpty) {
        // Crear nuevo usuario
        await usersRef.doc(user.uid).set(userData);
      } else {
        // Actualizar usuario existente
        await usersRef.doc(userQuery.docs.first.id).update({
          'ultimo_login': FieldValue.serverTimestamp(),
          'avatarUrl': user.photoURL ?? userQuery.docs.first.data()['avatarUrl'],
          'nombre': user.displayName ?? userQuery.docs.first.data()['nombre'],
          'email': user.email,
        });
      }
    } catch (e) {
      log('Error en handleFirestoreUser: $e');
      // No bloquear el login si hay error en Firestore
    }
  }

  void _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        _showSnack('Ya existe una cuenta con este email. Usa otro método.');
        break;
      case 'invalid-credential':
        _showSnack('Credenciales inválidas o expiradas.');
        break;
      case 'operation-not-allowed':
        _showSnack('Login con Google no habilitado. Contacta soporte.');
        break;
      case 'network-request-failed':
        _showSnack('Error de conexión. Verifica tu internet.');
        break;
      case 'internal-error':
        _showSnack('Error interno del servidor. Intenta más tarde.');
        break;
      case 'user-disabled':
        _showSnack('Esta cuenta ha sido deshabilitada.');
        break;
      case 'user-not-found':
        _showSnack('No se encontró la cuenta.');
        break;
      case 'wrong-password':
        _showSnack('Contraseña incorrecta.');
        break;
      default:
        _showSnack('Error: ${e.message ?? 'Desconocido'}');
    }
  }

  void _navigateToMain() {
    Navigator.pushReplacementNamed(context, '/main');
  }

  void _showSnack(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 80),
              // Logo
              Image.asset(
                'lib/assets/images/logo.png',
                height: 123,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 123,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant_menu,
                        size: 60, color: Colors.grey),
                  );
                },
              ),
              const SizedBox(height: 30),
              const Text(
                "INICIAR SESIÓN",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailOrUserController,
                decoration: const InputDecoration(
                  labelText: "Usuario o correo electrónico",
                  filled: true,
                  fillColor: Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 19),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña",
                  filled: true,
                  fillColor: Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF2A71A),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Ingresar",
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
              const SizedBox(height: 20),
              const Text(
                "O ingresa con",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Center(
                child: GestureDetector(
                  onTap: _loading ? null : _loginWithGoogle,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(50),
                      boxShadow: const [
                        BoxShadow(
                          color: Color.fromRGBO(0, 0, 0, 0.3),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'lib/assets/images/google_icon.png',
                      width: 33,
                      height: 33,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 33,
                          height: 33,
                          color: Colors.grey[300],
                          child: const Icon(Icons.login, color: Colors.grey),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              InkWell(
                onTap: _loading
                    ? null
                    : () => Navigator.pushNamed(context, '/register'),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("¿Aún no tienes una cuenta? "),
                    Text(
                      "Regístrate",
                      style: TextStyle(
                        color: Color(0xFFF2A71A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}