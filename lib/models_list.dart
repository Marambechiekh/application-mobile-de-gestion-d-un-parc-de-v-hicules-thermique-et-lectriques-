import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModelsListScreen extends StatefulWidget {
  @override
  _ModelsListScreenState createState() => _ModelsListScreenState();
}

class _ModelsListScreenState extends State<ModelsListScreen> {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _secondaryColor = Color(0xFFFF7043);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<QueryDocumentSnapshot> _filterModels(List<QueryDocumentSnapshot> models, String query) {
    if (query.isEmpty) return models;
    return models.where((model) {
      final data = model.data() as Map<String, dynamic>;
      return data['nom'].toString().toLowerCase().contains(query.toLowerCase()) ||
          data['type'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modèles de Véhicules', 
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _primaryColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => Navigator.pushNamed(context, '/addModel'),
      ),
      body: Column(
  children: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(Icons.search, color: _primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.clear, color: _primaryColor),
                  )
                : null,
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Colors.grey.shade600),
            border: InputBorder.none,
          ),
        ),
      ),
    ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('modeles')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _buildLoading();
                final filtered = _filterModels(snapshot.data!.docs, _searchQuery);
                if (filtered.isEmpty) return _buildEmptyState();
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => 
                      _buildModelCard(context, filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelCard(BuildContext context, DocumentSnapshot model) {
    final data = model.data() as Map<String, dynamic>;
    final isElectric = data['type'] == 'electrique';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(data['nom'],
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _primaryColor)),
                ),
                Chip(
                  label: Text(isElectric ? 'ÉLECTRIQUE' : 'THERMIQUE',
                      style: TextStyle(
                          fontSize: 12,
                          color: isElectric ? Colors.white : Colors.black87)),
                  backgroundColor: isElectric ? _secondaryColor : Colors.grey[300],
                  shape: StadiumBorder(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isElectric ? Icons.electric_bolt : Icons.local_gas_station,
                  color: isElectric ? _secondaryColor : Colors.grey[600],
                ),
                const SizedBox(width: 8),
                if (data.containsKey('autonomie'))
                  _buildDetailChip(
                      Icons.battery_charging_full,
                      '${data['autonomie']} km',
                      _secondaryColor),
                if (data.containsKey('consommation'))
                  _buildDetailChip(
                      Icons.speed,
                      '${data['consommation']} L/100km',
                      Colors.grey[600]!),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: Icon(Icons.edit, color: _primaryColor),
                  style: IconButton.styleFrom(
                      backgroundColor: _primaryColor.withOpacity(0.1)),
                  onPressed: () => Navigator.pushNamed(
                      context, '/editModel', arguments: model),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red),
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.1)),
                  onPressed: () => _confirmDelete(context, model.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailChip(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Chip(
        labelPadding: const EdgeInsets.symmetric(horizontal: 6),
        backgroundColor: color.withOpacity(0.1),
        shape: StadiumBorder(),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(text, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
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
          Icon(Icons.electric_car, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text('Aucun modèle enregistré',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce modèle ?'),
        actions: [
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.pop(context)),
          TextButton(
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
            onPressed: () {
              FirebaseFirestore.instance.collection('modeles').doc(id).delete();
              Navigator.pop(context);
            }),
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