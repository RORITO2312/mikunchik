// lib/screens/main_handler.dart

import 'package:flutter/material.dart';
import '../screens/principal_screen.dart';
import '../screens/buscar_screen.dart';
import '../screens/publicar_screen.dart';
import '../screens/feed_screen.dart';
import '../screens/perfil/perfil_screen.dart';

class MainHandler extends StatefulWidget {
  const MainHandler({super.key});

  @override
  State<MainHandler> createState() => _MainHandlerState();
}

class _MainHandlerState extends State<MainHandler> {
  int _selectedIndex = 0;

  static const List<Widget> _widgetOptions = <Widget>[
    PrincipalScreen(),
    BuscarScreen(),
    PublicarScreen(),
    FeedScreen(),
    PerfilScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Principal'),
          BottomNavigationBarItem(
              icon: Icon(Icons.search_outlined),
              activeIcon: Icon(Icons.search),
              label: 'Buscar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Publicar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.rss_feed_outlined),
              activeIcon: Icon(Icons.rss_feed),
              label: 'Feed'),
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person),
              label: 'Perfil'),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFFF2A71A),
        unselectedItemColor: Colors.grey.shade600,
        onTap: _onItemTapped,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
