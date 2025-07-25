import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BrandManagementScreen extends StatefulWidget {
  const BrandManagementScreen({Key? key}) : super(key: key);

  @override
  _BrandManagementScreenState createState() => _BrandManagementScreenState();
}

class _BrandManagementScreenState extends State<BrandManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00BFA5);
  final Color _backgroundColor = const Color(0xFFF3F4F6);
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String _selectedType = 'thermique';
  String _searchQuery = '';
  String _currentBrandId = '';

  List<QueryDocumentSnapshot> _filterBrands(List<QueryDocumentSnapshot> brands, String query) {
    if (query.isEmpty) return brands;
    return brands.where((brand) {
      final data = brand.data() as Map<String, dynamic>;
      return data['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
          data['type'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Gestion des Marques', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showBrandForm(context),
        backgroundColor: _primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, size: 28),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Rechercher une marque...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('brands').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: _primaryColor));
                }
                final filtered = _filterBrands(snapshot.data!.docs, _searchQuery);
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildBrandCard(filtered[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandCard(DocumentSnapshot brand) {
    final data = brand.data() as Map<String, dynamic>;
    final bool isThermal = data['type'] == 'thermique';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isThermal ? _primaryColor.withOpacity(0.1) : _secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isThermal ? Icons.local_gas_station : Icons.electric_car,
            color: isThermal ? _primaryColor : _secondaryColor,
          ),
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(
          data['type'] == 'thermique' ? 'Véhicule thermique' : 'Véhicule électrique',
          style: const TextStyle(color: Colors.grey),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.edit, color: _primaryColor),
              onPressed: () => _showBrandForm(context, brand),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red[300]),
              onPressed: () => _deleteBrand(brand.id),
            ),
          ],
        ),
      ),
    );
  }

  void _showBrandForm(BuildContext context, [DocumentSnapshot? brand]) {
    if (brand != null) {
      _nameController.text = brand['name'];
      _selectedType = brand['type'];
      _currentBrandId = brand.id;
    } else {
      _nameController.clear();
      _currentBrandId = '';
      _selectedType = 'thermique';
    }

    showModalBottomSheet(
      isScrollControlled: true,
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      brand != null ? 'Modifier la marque' : 'Ajouter une marque',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nom de la marque',
                        prefixIcon: Icon(Icons.drive_eta, color: _primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (value) => value == null || value.isEmpty ? 'Ce champ est requis' : null,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField(
                      value: _selectedType,
                      items: ['thermique', 'electrique'].map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(type == 'thermique' ? 'Thermique' : 'Électrique'),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => _selectedType = value.toString()),
                      decoration: InputDecoration(
                        labelText: 'Type de véhicule',
                        prefixIcon: Icon(Icons.settings_input_component, color: _primaryColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _handleSubmit(brand != null),
                      child: Text(
                        brand != null ? 'Mettre à jour' : 'Ajouter',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleSubmit(bool isUpdate) async {
    if (_formKey.currentState!.validate()) {
      try {
        final brandData = {
          'name': _nameController.text,
          'type': _selectedType,
          'timestamp': FieldValue.serverTimestamp()
        };

        if (isUpdate) {
          await _firestore.collection('brands').doc(_currentBrandId).update(brandData);
        } else {
          await _firestore.collection('brands').add(brandData);
        }

        Navigator.pop(context);
        _nameController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteBrand(String brandId) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette marque ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: TextStyle(color: _primaryColor)),
          ),
          TextButton(
            onPressed: () async {
              await _firestore.collection('brands').doc(brandId).delete();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}
