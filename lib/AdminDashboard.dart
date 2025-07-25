import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isAdmin = false;

  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00BFA5);
  final Color _alertColor = const Color(0xFFFF7043);
  final Color _backgroundColor = const Color(0xFFF8F9FA);

  final List<Widget> _screens = [
    const DashboardContent(),
    const UserManagementPlaceholder(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        _redirectToLogin();
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data()?['role'] == 'admin') {
        setState(() {
          _isAdmin = true;
          _isLoading = false;
        });
      } else {
        _redirectToHome();
      }
    } catch (e) {
      _redirectToError();
    }
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/login');
    });
  }

  void _redirectToHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/home');
    });
  }

  void _redirectToError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/error');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: _backgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isAdmin) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Tableau de Bord Admin',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      selectedItemColor: _primaryColor,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: true,
      onTap: (index) => setState(() => _currentIndex = index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Utilisateurs',
        ),
      ],
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques Administrateur',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3436))),
          const SizedBox(height: 25),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 15,
            crossAxisSpacing: 15,
            childAspectRatio: 1.2,
            children: [
              _StatCard(
                title: 'Total Utilisateurs',
                icon: Icons.people_alt,
                color: const Color(0xFF6C5CE7),
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
              ),
              _StatCard(
                title: 'Chauffeurs',
                icon: Icons.directions_car,
                color: const Color(0xFF00BFA5),
                stream: FirebaseFirestore.instance.collection('users')
                  .where('role', isEqualTo: 'Chauffeur').snapshots(),
              ),
              _StatCard(
                title: 'Responsables',
                icon: Icons.engineering,
                color: const Color(0xFFFF7043),
                stream: FirebaseFirestore.instance.collection('users')
                  .where('role', isEqualTo: 'Responsable de parc').snapshots(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Stream<QuerySnapshot> stream;

  const _StatCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.stream,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (context, snapshot) {
        final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        
        return Container(
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 15),
              Text(count.toString(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color)),
              const SizedBox(height: 5),
              Text(title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }
}

class UserManagementPlaceholder extends StatelessWidget {
  const UserManagementPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Gestion des Utilisateurs',
          style: TextStyle(fontSize: 24)),
    );
  }
}