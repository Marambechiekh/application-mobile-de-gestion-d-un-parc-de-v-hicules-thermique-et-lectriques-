import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _primaryColor = Color(0xFF6C5CE7);
const Color _secondaryColor = Color(0xFFE70013);

class PartsManagementScreen extends StatefulWidget {
  const PartsManagementScreen({super.key});

  @override
  State<PartsManagementScreen> createState() => _PartsManagementScreenState();
}

class _PartsManagementScreenState extends State<PartsManagementScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late TabController _tabController;
  String? _selectedVehicleType;
  String? _editingId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gestion des Pièces',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: _primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.electric_car)),
            Tab(icon: Icon(Icons.local_gas_station)),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                filled: true,
                hintText: 'Rechercher une pièce...',
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPartsList('electrique'),
                _buildPartsList('thermique'),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: _showBottomSheet,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPartsList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('repair_parts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final filtered = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['vehicle_type'] == type &&
              data['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final doc = filtered[index];
            return _buildPartCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildPartCard(String id, Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          data['vehicle_type'] == 'electrique'
              ? Icons.bolt
              : Icons.settings,
          color: _primaryColor,
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: _primaryColor),
              onPressed: () => _showBottomSheet(id: id, data: data),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: _secondaryColor),
              onPressed: () => _deletePart(id),
            ),
          ],
        ),
      ),
    );
  }

 void _showBottomSheet({String? id, Map<String, dynamic>? data}) {
  if (data != null) {
    _nameController.text = data['name'];
    _selectedVehicleType = data['vehicle_type'];
    _editingId = id;
  } else {
    _nameController.clear();
    _selectedVehicleType = null;
    _editingId = null;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Wrap(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de la pièce',
                prefixIcon: Icon(Icons.construction, color: _primaryColor),
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Le nom est requis' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedVehicleType,
              items: ['electrique', 'thermique']
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.capitalize()),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedVehicleType = value),
              decoration: const InputDecoration(
                labelText: 'Type de véhicule',
                prefixIcon: Icon(Icons.directions_car, color: _primaryColor),
              ),
              validator: (value) =>
                  value == null ? 'Veuillez choisir un type' : null,
            ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white, // Texte en blanc
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _savePart,
                child: const Text(
                  'Enregistrer',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}


  Future<void> _savePart() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text.trim(),
      'vehicle_type': _selectedVehicleType,
      'created_at': FieldValue.serverTimestamp(),
    };

    if (_editingId == null) {
      await _firestore.collection('repair_parts').add(data);
    } else {
      await _firestore.collection('repair_parts').doc(_editingId).update(data);
    }

    Navigator.pop(context);
  }

  Future<void> _deletePart(String id) async {
    await _firestore.collection('repair_parts').doc(id).delete();
  }
}

extension StringExtension on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
