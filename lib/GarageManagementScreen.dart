import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class GarageManagementScreen extends StatelessWidget {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _secondaryColor = Color(0xFFFF7043);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion des Garages',
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
      body: GarageList(),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () => _showGarageForm(context),
      ),
    );
  }
   void _showGarageForm(BuildContext context, {DocumentSnapshot? garageDoc}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: GarageFormScreen(garageDoc: garageDoc),
      ),
    );
  }
}

class GarageList extends StatefulWidget {
  @override
  _GarageListState createState() => _GarageListState();
}

class _GarageListState extends State<GarageList> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Color _primaryColor = Color(0xFF6C5CE7);
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('garages').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _buildLoading();
              
              final filteredDocs = _filterGarages(snapshot.data!.docs);
              
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) =>
                    _buildGarageCard(context, filteredDocs[index]),
              );
            },
          ),
        ),
      ],
    );
  }
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Rechercher un garage...',
          prefixIcon: Icon(Icons.search, color: _primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[200],
        ),
        onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
      ),
    );
  }
    List<DocumentSnapshot> _filterGarages(List<DocumentSnapshot> docs) {
    if (_searchQuery.isEmpty) return docs;
    
    return docs.where((doc) {
      final garage = doc.data() as Map<String, dynamic>;
      return garage['name'].toString().toLowerCase().contains(_searchQuery) ||
          garage['address'].toString().toLowerCase().contains(_searchQuery) ||
          garage['contact'].toString().toLowerCase().contains(_searchQuery) ||
          (garage['services'] as List).any((service) =>
              service.toString().toLowerCase().contains(_searchQuery));
    }).toList();
  }

  Widget _buildGarageCard(BuildContext context, DocumentSnapshot doc) {
    final garage = doc.data() as Map<String, dynamic>;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(garage['name'], 
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _primaryColor)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: _primaryColor),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => GarageFormScreen(garageDoc: doc),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteGarage(doc.id),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow(Icons.location_on, garage['address'] ?? 'N/A'),
            _buildInfoRow(Icons.phone, garage['contact'] ?? 'N/A'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: (garage['services'] as List<dynamic>?)
                  ?.map((service) => Chip(
                        label: Text(service.toString(),
                            style: const TextStyle(fontSize: 12)),
                        backgroundColor: _primaryColor.withOpacity(0.1),
                        shape: StadiumBorder(),
                      ))
                  .toList() ??
                  [Text('Aucun service disponible')],
            ),
            const SizedBox(height: 12),
            Row(
              children: List.generate(5, (index) => Icon(
                index < (garage['rating'] ?? 0) 
                    ? Icons.star 
                    : Icons.star_border,
                color: Colors.amber,
                size: 20,
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
    );
  }

  Future<void> _deleteGarage(String id) async {
    await _firestore.collection('garages').doc(id).delete();
  }
}

class GarageFormScreen extends StatefulWidget {
  final DocumentSnapshot? garageDoc;

  const GarageFormScreen({this.garageDoc});

  @override
  _GarageFormScreenState createState() => _GarageFormScreenState();
}

class _GarageFormScreenState extends State<GarageFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final List<String> _availableServices = ['Mécanique', 'Carrosserie', 'Électrique', 'Pneumatique'];
  final Set<String> _selectedServices = {};
  int _rating = 3;
  static const Color _primaryColor = Color(0xFF6C5CE7);

  @override
  void initState() {
    super.initState();
    if (widget.garageDoc != null) _loadExistingData();
  }

  void _loadExistingData() {
    final data = widget.garageDoc!.data() as Map<String, dynamic>;
    _nameController.text = data['name'];
    _addressController.text = data['address'];
    _contactController.text = data['contact'];
    _selectedServices.addAll(List<String>.from(data['services'] ?? []));
    _rating = data['rating'] ?? 3;
  }

    @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.garageDoc == null ? 'Nouveau Garage' : 'Modifier Garage',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              _buildTextField(_nameController, 'Nom du garage', Icons.garage),
              const SizedBox(height: 15),
              _buildTextField(_addressController, 'Adresse', Icons.location_on),
              const SizedBox(height: 15),
              _buildTextField(_contactController, 'Contact', Icons.phone),
              const SizedBox(height: 15),
              _buildServicesSelection(),
              const SizedBox(height: 15),
              _buildRatingSelector(),
              const SizedBox(height: 20),
              _buildSubmitButton(),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
  return TextFormField(
    controller: controller,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.grey),
      ),
      filled: true,
      fillColor: Colors.grey[50],
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Champ obligatoire';
      }
      return null;
    },
  );
}

Widget _buildServicesSelection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Services proposés :',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _availableServices.map((service) {
          return FilterChip(
            label: Text(service),
            selected: _selectedServices.contains(service),
            selectedColor: _primaryColor.withOpacity(0.2),
            checkmarkColor: _primaryColor,
            onSelected: (selected) {
              setState(() {
                if (selected) {
                  _selectedServices.add(service);
                } else {
                  _selectedServices.remove(service);
                }
              });
            },
          );
        }).toList(),
      ),
    ],
  );
}

  Widget _buildRatingSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notation :',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) => IconButton(
            icon: Icon(
              index < _rating ? Icons.star : Icons.star_border,
              color: Colors.amber,
              size: 32,
            ),
            onPressed: () => setState(() => _rating = index + 1),
          )),

        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.save, color: Colors.white),
      label: const Text('Enregistrer', 
          style: TextStyle(color: Colors.white, fontSize: 16)),
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: _submitForm,
    );
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'name': _nameController.text,
          'address': _addressController.text,
          'contact': _contactController.text,
          'services': _selectedServices.toList(),
          'rating': _rating,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        if (widget.garageDoc == null) {
          await FirebaseFirestore.instance.collection('garages').add(data);
        } else {
          await FirebaseFirestore.instance
            .collection('garages')
            .doc(widget.garageDoc!.id)
            .update(data);
        }
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
