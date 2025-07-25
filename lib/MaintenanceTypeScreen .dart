import 'package:flutter/material.dart'; 
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _primaryColor = Color(0xFF6C5CE7);
const Color _secondaryColor = Color(0xFFE70013);

class MaintenanceTypeScreen extends StatefulWidget {
  const MaintenanceTypeScreen({super.key});

  @override
  State<MaintenanceTypeScreen> createState() => _MaintenanceTypeScreenState();
}

class _MaintenanceTypeScreenState extends State<MaintenanceTypeScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  late TabController _tabController;
  final TextEditingController _taskController = TextEditingController();

  String? _selectedVehicleType;
  String? _selectedIntervalType;
  String? _editingId;
  int _threshold = 0;
  int _alertMargin = 0;
  List<String> _selectedTasks = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Types d\'Entretien',
          style: TextStyle(color: Colors.white),),
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
                prefixIcon: const Icon(Icons.search, color: _primaryColor),
                hintText: 'Rechercher...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTypeList('electrique'),
                _buildTypeList('thermique'),
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

  String _searchQuery = '';

  Widget _buildTypeList(String type) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('maintenance_types').snapshots(),
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
            return _buildTypeCard(doc.id, doc.data() as Map<String, dynamic>);
          },
        );
      },
    );
  }

  Widget _buildTypeCard(String id, Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(
          data['vehicle_type'] == 'electrique'
              ? Icons.electric_bolt
              : Icons.engineering,
          color: _primaryColor,
        ),
        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${data['interval_value']} ${data['interval_type']}'),
            Text('Alerte à ${data['alert_margin']}%',
              style: TextStyle(color: _secondaryColor)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: _primaryColor),
              onPressed: () => _showBottomSheet(id: id, data: data),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: _secondaryColor),
              onPressed: () => _deleteType(id),
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
      _selectedIntervalType = data['interval_type'];
      _threshold = data['interval_value'];
      _alertMargin = data['alert_margin'];
      _editingId = id;
      _selectedTasks = List<String>.from(data['tasks'] ?? []);
    } else {
      _nameController.clear();
      _selectedVehicleType = null;
      _selectedIntervalType = null;
      _threshold = 0;
      _alertMargin = 0;
      _editingId = null;
      _selectedTasks.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          top: 16,
          left: 16,
          right: 16,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom',
                    prefixIcon: Icon(Icons.build, color: _primaryColor),
                  ),
                  validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                ),
                DropdownButtonFormField<String>(
                  value: _selectedVehicleType,
                  items: ['electrique', 'thermique'].map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.capitalize()),
                      )).toList(),
                  onChanged: (value) => setState(() => _selectedVehicleType = value),
                  decoration: const InputDecoration(
                    labelText: 'Type de véhicule',
                    prefixIcon: Icon(Icons.directions_car, color: _primaryColor),
                  ),
                ),
                DropdownButtonFormField<String>(
                  value: _selectedIntervalType,
                  items: ['km'].map((type) => DropdownMenuItem(
                        value: type,
                        child: const Text('Kilométrage'),
                      )).toList(),
                  onChanged: (value) => setState(() => _selectedIntervalType = value),
                  decoration: const InputDecoration(
                    labelText: 'Intervalle',
                    prefixIcon: Icon(Icons.schedule, color: _primaryColor),
                  ),
                ),
                TextFormField(
                  initialValue: _threshold.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Valeur',
                    prefixIcon: Icon(Icons.speed, color: _primaryColor),
                  ),
                  onChanged: (value) => _threshold = int.tryParse(value) ?? 0,
                ),
                TextFormField(
                  initialValue: _alertMargin.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Marge d\'alerte (%)',
                    prefixIcon: Icon(Icons.warning, color: _primaryColor),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Champ requis';
                    final margin = int.tryParse(value);
                    if (margin == null || margin < 0 || margin > 100) {
                      return 'Entre 0 et 100%';
                    }
                    return null;
                  },
                  onChanged: (value) => _alertMargin = int.tryParse(value) ?? 0,
                ),
                const SizedBox(height: 16),
                const Text('Tâches à effectuer :'),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _taskController,
                        decoration: const InputDecoration(
                          labelText: 'Nouvelle tâche',
                          prefixIcon: Icon(Icons.task, color: _primaryColor),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: _primaryColor),
                      onPressed: () {
                        final task = _taskController.text.trim();
                        if (task.isNotEmpty) {
                          setState(() {
                            _selectedTasks.add(task);
                            _taskController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _selectedTasks
                      .asMap()
                      .entries
                      .map((entry) => ListTile(
                            leading: const Icon(Icons.check_box_outlined, color: _primaryColor),
                            title: Text(entry.value),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: _secondaryColor),
                              onPressed: () {
                                setState(() {
                                  _selectedTasks.removeAt(entry.key);
                                });
                              },
                            ),
                          ))
                      .toList(),
                ),
                ElevatedButton(
                  onPressed: _saveType,
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveType() async {
    if (!_formKey.currentState!.validate()) return;

    final data = {
      'name': _nameController.text,
      'vehicle_type': _selectedVehicleType,
      'interval_type': _selectedIntervalType,
      'interval_value': _threshold,
      'alert_margin': _alertMargin,
      'tasks': _selectedTasks,
      'created_at': FieldValue.serverTimestamp(),
    };

    if (_editingId == null) {
      await _firestore.collection('maintenance_types').add(data);
    } else {
      await _firestore.collection('maintenance_types').doc(_editingId).update(data);
    }

    _resetForm();
    Navigator.pop(context);
  }

  Future<void> _deleteType(String id) async {
    await _firestore.collection('maintenance_types').doc(id).delete();
  }

  void _resetForm() {
    _nameController.clear();
    _selectedVehicleType = null;
    _selectedIntervalType = null;
    _threshold = 0;
    _alertMargin = 0;
    _editingId = null;
    _selectedTasks.clear();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}