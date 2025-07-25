import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_user_screen.dart';
import 'edit_user_screen.dart';

class UserManagementScreen extends StatefulWidget {
  @override
  _UserManagementScreenState createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
 
  final TextEditingController _searchController = TextEditingController();
  final  Color _primaryColor = Color(0xFF6C5CE7);
  String _searchQuery = '';

  List<QueryDocumentSnapshot> _filterUsers(List<QueryDocumentSnapshot> users) {
    if (_searchQuery.isEmpty) return users;
    return users.where((user) {
      final data = user.data() as Map<String, dynamic>;
      return data['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          data['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          data['role'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Gestion des utilisateurs", style: TextStyle(color: Colors.white)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
               colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
     body: DefaultTabController(
  length: 2,
  child: Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            suffixIcon: IconButton(
              icon: Icon(Icons.clear, color: _primaryColor),
              onPressed: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ),
          onChanged: (value) => setState(() => _searchQuery = value),
        ),
      ),
      TabBar(
        labelColor: _primaryColor,
        unselectedLabelColor: Colors.grey,
        indicatorColor: _primaryColor,
        tabs: const [
          Tab(text: 'Chauffeurs'),
          Tab(text: 'Responsables'),
        ],
      ),
      Expanded(
        child: TabBarView(
          children: [
            _buildUserList(role: 'Chauffeur'),
            _buildUserList(role: 'Responsable de parc'),
          ],
        ),
      ),
    ],
  ),
),

      floatingActionButton: FloatingActionButton(
        backgroundColor:_primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddUserScreen())),
      ),
    );
  }
  Widget _buildUserList({required String role}) {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: role)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return _buildLoading();

      var users = _filterUsers(snapshot.data!.docs);
      if (users.isEmpty) return _buildEmptyState();

      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        itemBuilder: (context, index) {
          var user = users[index];
          return _buildUserCard(user, context);
        },
      );
    },
  );
}



  Widget _buildUserCard(DocumentSnapshot user, BuildContext context) {
    final isDriver = user['role'] == 'Chauffeur';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withOpacity(0.1),
          child: Icon(Icons.person, color: _primaryColor),
        ),
        title: Text(
          user['name'],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${user['email']}  |  ${user['role']}",
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            if (isDriver) _buildDriverStatus(user['email']),
          ],
        ),
        // Ajout de l'icône de modification ici
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton Modifier
            IconButton(
              icon: Icon(Icons.edit, color: _primaryColor),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditUserScreen(userId: user.id),
                ),
              ),
            ),
            // Bouton Supprimer
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () => _deleteUser(user.id, context),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildDriverStatus(String email) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('missions')
          .where('driver', isEqualTo: email)
          .where('status', whereIn: ['En cours', 'En attente'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final isAvailable = snapshot.data!.docs.isEmpty;
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.circle, 
                  color: isAvailable ? Colors.green : Colors.red, 
                  size: 12),
              const SizedBox(width: 6),
              Text(
                isAvailable ? 'Disponible' : 'En mission',
                style: TextStyle(
                  color: isAvailable ? Colors.green : Colors.red,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteUser(String userId, BuildContext context) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Utilisateur supprimé")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.toString()}")),
      );
    }
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
    );
  }
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text('Aucun utilisateur trouvé', style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}