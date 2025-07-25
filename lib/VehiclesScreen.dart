import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VehiclesScreen extends StatefulWidget {
  @override
  _VehiclesScreenState createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedType;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _secondaryColor = Color(0xFF00BFA5);
  static const Color _alertColor = Color(0xFFFF7043);
  static const Color _backgroundColor = Color(0xFFF8F9FA);
  static const Color _textColor = Color(0xFF2D3436);

  void _navigateToVehicleDetails(String vehicleId) {
    Navigator.pushNamed(context, '/details', arguments: vehicleId);
  }

  void _editVehicle(String vehicleId) {
    Navigator.pushNamed(context, '/edit', arguments: vehicleId);
  }

  Future<void> _deleteVehicle(String vehicleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Êtes-vous sûr de vouloir supprimer ce véhicule ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await _firestore.collection('vehicles').doc(vehicleId).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Véhicule supprimé avec succès')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  List<QueryDocumentSnapshot> _filterVehicles(List<QueryDocumentSnapshot> vehicles) {
    return vehicles.where((vehicle) {
      final data = vehicle.data() as Map<String, dynamic>;
      final searchLower = _searchQuery.toLowerCase();
      return data['modele'].toString().toLowerCase().contains(searchLower) ||
          data['marque'].toString().toLowerCase().contains(searchLower) ||
          data['numeroImmatriculation'].toString().toLowerCase().contains(searchLower) ||
          data['type'].toString().toLowerCase().contains(searchLower);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text(
          'Liste des véhicules',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: _primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
        onPressed: () => Navigator.pushNamed(context, '/add'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildTypeFilter(),
          Expanded(child: _buildVehicleList()),
        ],
      ),
    );
  }

Widget _buildSearchBar() {
  final Color _primaryColor = const Color(0xFF6C5CE7);

  return Padding(
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
  );
}

  Widget _buildTypeFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilterChip(
            label: const Text('Tous'),
            selected: _selectedType == null,
            selectedColor: _primaryColor.withOpacity(0.2),
            onSelected: (_) => setState(() => _selectedType = null),
          ),
          FilterChip(
            label: const Text('Électrique'),
            selected: _selectedType == 'electrique',
            selectedColor: _secondaryColor.withOpacity(0.2),
            onSelected: (_) => setState(() => _selectedType = 'electrique'),
          ),
          FilterChip(
            label: const Text('Thermique'),
            selected: _selectedType == 'thermique',
            selectedColor: _alertColor.withOpacity(0.2),
            onSelected: (_) => setState(() => _selectedType = 'thermique'),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleList() {
    Query query = _firestore.collection('vehicles');

    if (_selectedType != null) {
      query = query.where('type', isEqualTo: _selectedType);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Erreur : ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(child: Text("Aucun véhicule trouvé"));
        }

        final vehicles = _filterVehicles(snapshot.data!.docs);

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          itemCount: vehicles.length,
          itemBuilder: (context, index) {
            final vehicle = vehicles[index];
            final data = vehicle.data() as Map<String, dynamic>;
            return _buildVehicleCard(vehicle.id, data);
          },
        );
      },
    );
  }

  Widget _buildVehicleCard(String vehicleId, Map<String, dynamic> data) {
    final bool isElectric = data['type'] == 'electrique';
    
    return GestureDetector(
      onTap: () => _navigateToVehicleDetails(vehicleId),
      child: Card(
        color: Colors.white,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        margin: const EdgeInsets.only(bottom: 12),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: Hero(
            tag: vehicleId,
            child: CircleAvatar(
              backgroundColor: isElectric ? _secondaryColor : _alertColor,
              radius: 25,
              child: Icon(
                isElectric ? Icons.electric_car : Icons.local_gas_station,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          title: Text(
            data['modele'] ?? 'Modèle inconnu',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Marque: ${data['marque'] ?? 'Non spécifiée'}'),
              Text('Immatriculation: ${data['numeroImmatriculation'] ?? 'Non disponible'}'),
              Chip(
                label: Text(isElectric ? 'Électrique' : 'Thermique'),
                backgroundColor: isElectric 
                  ? _secondaryColor.withOpacity(0.15)
                  : _alertColor.withOpacity(0.15),
                labelStyle: TextStyle(
                  color: isElectric ? _secondaryColor : _alertColor,
                  fontWeight: FontWeight.bold),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildActionButton(Icons.edit, _primaryColor, 
                () => _editVehicle(vehicleId)),
              SizedBox(width: 8),
              _buildActionButton(Icons.delete, _alertColor, 
                () => _deleteVehicle(vehicleId)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
    );
  }
}