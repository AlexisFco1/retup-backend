import 'package:flutter/material.dart';
import '../widgets/custom_bottom_navigation_bar.dart';

class RachasScreen extends StatefulWidget {
  const RachasScreen({Key? key}) : super(key: key);

  @override
  State<RachasScreen> createState() => _RachasScreenState();
}

class _RachasScreenState extends State<RachasScreen> {
  int _currentNavIndex = 2; // Rachas es el índice 2

  void _onNavTap(int index) {
    setState(() {
      _currentNavIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/social');
        break;
      case 2:
        // Ya estamos en Rachas
        break;
      case 3:
        Navigator.pushReplacementNamed(context, '/practicalo');
        break;
      case 4:
        Navigator.pushReplacementNamed(context, '/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rachas'),
        centerTitle: true,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Pantalla Rachas - En construcción'),
      ),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
      ),
    );
  }
}
