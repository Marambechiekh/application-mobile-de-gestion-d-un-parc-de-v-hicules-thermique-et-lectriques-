import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/RepairStatistics.dart';
import 'package:intl/intl.dart';

class RepairManagementScreen extends StatelessWidget {
  static const Color primaryColor = Color(0xFFE70013);
static const Color secondaryColor = Color(0xFFFFFFFF);
static const Color _secondaryColor = Color(0xFF00BFA5);
static const Color _primaryColor = Color(0xFF6C5CE7);
  @override

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Gestion des Réparations',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800)),
      centerTitle: true,
      backgroundColor: _primaryColor,
      elevation: 4,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(20),
        ),
      ),
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primaryColor.withOpacity(0.05),
            _secondaryColor.withOpacity(0.03)
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: ListView(
          children: [
            
            _buildActionCard(
              context,
              'Planifier Réparation',
              Icons.calendar_today_rounded,
              RepairPlanningScreen(),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              'Liste des Réparations',
              Icons.build_rounded,
              RepairExecutionListScreen(),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              'Statistique des Réparations',
              Icons.show_chart,
              RepairStatistics(),
            ),
          ],
        ),
      ),
    ),
    bottomNavigationBar: _buildBottomNavBar(context),
  );
}

Widget _buildActionCard(BuildContext context, String title, IconData icon, Widget screen) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _primaryColor.withOpacity(0.08)
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 28, color: _primaryColor),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor)),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: _primaryColor.withOpacity(0.5), size: 20),
          ],
        ),
      ),
    ),
  );
}

 


Widget _buildBottomNavBar(BuildContext context) {
 
  final currentRoute = ModalRoute.of(context)?.settings.name;
  int currentIndex = 0;
  
  if (currentRoute == '/repair2') {
    currentIndex = 0; 
  } else if (currentRoute == '/main') {
    currentIndex = 1; 
  }

  return Container(
    height: 70,
    decoration: BoxDecoration(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [
        BoxShadow(
          color: Colors.grey.withOpacity(0.2),
          spreadRadius: 2,
          blurRadius: 10,
        )
      ],
    ),
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          switch (index) {
            case 0:
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/repair2');
              }
              break;
            case 1:
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/main');
              }
              break;
          }
        },
        backgroundColor: Colors.white,
        selectedItemColor: _primaryColor,
        unselectedItemColor: Colors.grey[600],
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.build_rounded, size: 28),
            label: 'Réparations',
            tooltip: 'Gestion des réparations',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_suggest_rounded, size: 28),
            label: 'Maintenance',
            tooltip: 'Gestion de la maintenance',
          ),
        ],
      ),
    ),
  );
}
}


class RepairPlanningScreen extends StatefulWidget {
  @override
  _RepairPlanningScreenState createState() => _RepairPlanningScreenState();
}


class _RepairPlanningScreenState extends State<RepairPlanningScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _selectedVehicleId;
  String? _selectedGarageId;
  DateTime? _selectedDate;
  bool _isOnSite = false;
  final _descriptionController = TextEditingController();
  double _estimatedCost = 0;
  String? _selectedAddress;

  final _primaryColor = const Color(0xFF6C5CE7);
  final _backgroundColor = const Color(0xFFF5F3FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: _buildAppBar(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                _buildSection('Véhicule', _buildVehicleDropdown()),
                _buildSection('Description', _buildDescriptionField()),
                _buildSection('Lieu d\'intervention', _buildLocationSelector()),
                if (!_isOnSite) _buildSection('', _buildGarageDropdown()),
                if (_isOnSite) _buildSection('', _buildAddressField()),
                _buildSection('Date prévue', _buildDatePicker()),
                _buildSection('Coût estimé', _buildCostField()),
                const SizedBox(height: 20),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _primaryColor,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        'Planifier Réparation',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }

  Widget _buildSection(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          const SizedBox(height: 6),
          field,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? label, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
      filled: true,
      fillColor: Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return FutureBuilder<List<QueryDocumentSnapshot>>(
      future: _getAvailableVehicles(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        return DropdownButtonFormField<String>(
          decoration: _inputDecoration(label: 'Véhicule', icon: Icons.directions_car),
          value: _selectedVehicleId,
          items: snapshot.data!.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text('${data['marque']} - ${data['numeroImmatriculation']}'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedVehicleId = value),
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: _inputDecoration(label: 'Décrivez la réparation', icon: Icons.description),
    );
  }

  Widget _buildLocationSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildChoiceChip('Garage', !_isOnSite, () => setState(() => _isOnSite = false)),
        const SizedBox(width: 10),
        _buildChoiceChip('Sur site', _isOnSite, () => setState(() => _isOnSite = true)),
      ],
    );
  }

  Widget _buildChoiceChip(String label, bool selected, VoidCallback onSelected) {
    return Expanded(
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: _primaryColor,
        backgroundColor: Colors.grey.shade100,
        onSelected: (_) => onSelected(),
        labelStyle: TextStyle(
          color: selected ? Colors.white : _primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGarageDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('garages').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        return DropdownButtonFormField<String>(
          decoration: _inputDecoration(label: 'Garage', icon: Icons.garage),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name']),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedGarageId = value),
        );
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      decoration: _inputDecoration(label: 'Adresse', icon: Icons.location_on),
      onChanged: (value) => _selectedAddress = value,
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked != null) setState(() => _selectedDate = picked);
      },
      child: InputDecorator(
        decoration: _inputDecoration( icon: Icons.calendar_today),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedDate == null
                  ? 'Choisir une date'
                  : DateFormat('dd/MM/yyyy').format(_selectedDate!),
              style: const TextStyle(color: Colors.black87),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }

  Widget _buildCostField() {
    return TextFormField(
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: _inputDecoration(label: 'Coût estimé (TND)', icon: Icons.payments),
      onChanged: (value) => _estimatedCost = double.tryParse(value) ?? 0,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: _primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text('ENREGISTRER', style: TextStyle(fontSize: 16, color: Colors.white)),
    );
  }

  Future<List<QueryDocumentSnapshot>> _getAvailableVehicles() async {
    final vehicles = await _firestore.collection('vehicles').get();
    List<QueryDocumentSnapshot> available = [];
    for (var doc in vehicles.docs) {
      if (await _checkVehicleAvailability(doc.id)) available.add(doc);
    }
    return available;
  }

  Future<bool> _checkVehicleAvailability(String vehicleId) async {
    final repairs = await _firestore.collection('repairs')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'in_progress').get();
    final maintenances = await _firestore.collection('maintenances')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['planned', 'in_progress']).get();
    final missions = await _firestore.collection('missions')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'En cours').get();

    return repairs.docs.isEmpty && maintenances.docs.isEmpty && missions.docs.isEmpty;
  }

  Future<void> _submitForm() async {
    if (_selectedVehicleId == null || _descriptionController.text.isEmpty || _selectedDate == null || (_isOnSite && (_selectedAddress?.isEmpty ?? true)) || (!_isOnSite && _selectedGarageId == null)) return;
  final vehicleDoc = await _firestore.collection('vehicles').doc(_selectedVehicleId).get();
  final vehicleData = vehicleDoc.data() as Map<String, dynamic>;

    await _firestore.collection('repairs').add({
      'vehicleId': _selectedVehicleId,
        'vehicleInfo': { 
      'marque': vehicleData['marque'],
      'modele': vehicleData['modele'],
      'immatriculation': vehicleData['numeroImmatriculation'],
      'type': vehicleData['type'],
    },
      'description': _descriptionController.text,
      'garageId': _isOnSite ? null : _selectedGarageId,
      'address': _isOnSite ? _selectedAddress : null,
      'isOnSite': _isOnSite,
      'estimatedCost': _estimatedCost,
      'scheduledDate': Timestamp.fromDate(_selectedDate!),
      'status': 'in_progress',
      'createdAt': FieldValue.serverTimestamp(),
    });

    Navigator.pop(context);
  }
}
  final _primaryColor = const Color(0xFF6C5CE7);
  final _backgroundColor = const Color(0xFFF5F3FF);

class RepairExecutionListScreen extends StatefulWidget {
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _backgroundColor = const Color(0xFFF5F3FF);

  final Color secondaryColor = const Color(0xFF00BFA5); 
  @override
  _RepairExecutionListScreenState createState() => _RepairExecutionListScreenState();
}

class _RepairExecutionListScreenState extends State<RepairExecutionListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Color secondaryColor = const Color(0xFF00BFA5); 
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: widget._backgroundColor,
        
        appBar: AppBar(
          title: Row(
            children: [
             
              SizedBox(width: 12),
              Text('Liste des Réparations',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5
                ),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: widget._primaryColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
        // In _RepairExecutionListScreenState class
bottom: PreferredSize(
  preferredSize: const Size.fromHeight(56),
  child: StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance.collection('repairs').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return LinearProgressIndicator();

      final repairs = snapshot.data!.docs;
      final inProgressCount = repairs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'in_progress').length;
      final completedCount = repairs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed').length;

      return Container(
        color: widget._primaryColor,
        child: TabBar(
          indicatorColor: secondaryColor,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          tabs: [
            _buildTab(
              Icons.hourglass_top, 
              'Planifiées', 
              inProgressCount, 
              secondaryColor // Same color for both badges
            ),
            _buildTab(
              Icons.check_circle, 
              'Terminées', 
              completedCount, 
              secondaryColor // Same color for both badges
            ),
          ],
        ),
      );
    },
  ),
),
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
          onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: Icon(Icons.search, color: widget._primaryColor),
            suffixIcon: _searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.clear, color: widget._primaryColor),
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
              child: TabBarView(
                children: [
                  _buildRepairList('in_progress'),
                  _buildRepairList('completed'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
 Tab _buildTab(IconData icon, String label, int count, Color badgeColor) {
  return Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 22),
        const SizedBox(width: 6),
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.9),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildRepairList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('repairs')
          .where('status', isEqualTo: status)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        
        final filteredRepairs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final vehicleInfo = data['vehicleInfo'] ?? {};
          final description = data['description']?.toString().toLowerCase() ?? '';
          
          final vehicleText = '${vehicleInfo['marque']} ${vehicleInfo['modele']} ${vehicleInfo['immatriculation']}'
              .toLowerCase();

          return vehicleText.contains(_searchQuery) || description.contains(_searchQuery);
        }).toList();

        return ListView.separated(
          padding: EdgeInsets.all(16),
          itemCount: filteredRepairs.length,
          separatorBuilder: (context, index) => SizedBox(height: 12),
          itemBuilder: (context, index) => _buildRepairCard(context, filteredRepairs[index]),
        );
      },
    );
  }

Widget _buildRepairCard(BuildContext context, DocumentSnapshot repair) {
  final data = repair.data() as Map<String, dynamic>? ?? {};
  final vehicleInfo = data['vehicleInfo'] as Map<String, dynamic>;

  return Card(
    elevation: 2,
    margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Icon(Icons.directions_car, color: widget._primaryColor, size: 20),
                  SizedBox(height: 6),
                  Icon(Icons.confirmation_number, size: 16, color: Colors.grey[700]),
                ],
              ),
              SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${vehicleInfo['marque']} ${vehicleInfo['modele']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: widget._primaryColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    vehicleInfo['immatriculation'] ?? '',
                    style: TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: Colors.grey[300], thickness: 1),
          ),
          _buildInfoRow(Icons.build, "Description :", data['description'], isLink: true),
          _buildInfoRow(
            Icons.calendar_today,
            "Date :",
            DateFormat('dd/MM/yyyy').format((data['scheduledDate'] as Timestamp).toDate()),
            isLink: true,
          ),
          _buildInfoRow(
            Icons.payments,
            "Coût estimé :",
            '${(data['estimatedCost'] ?? 0).toStringAsFixed(3)} TND',
            isLink: true,
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(data['status']).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _getStatusText(data['status']),
                  style: TextStyle(
                    color: _getStatusColor(data['status']),
                    fontWeight: FontWeight.w600)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.info_outline, color: widget._primaryColor),
                    onPressed: () => _showRepairDetails(context, repair.id, data),
                  ),
                  
                   if (data['status'] == 'in_progress')
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context, repair.id),
                  ),
                  if (data['status'] == 'in_progress')
                    IconButton(
                      icon: Icon(Icons.arrow_forward_ios, 
                        size: 20, 
                        color: widget._primaryColor),
                      onPressed: () => _showRepairDetails(context, repair.id, data),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Méthode pour générer les lignes avec icône + label + valeur
Widget _buildInfoRow(IconData icon, String label, String value, {bool isLink = false}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Icon(icon, size: 18, color: widget._primaryColor),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: Colors.black87),
        ),
        SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: isLink ? widget._primaryColor : Colors.black87,
              fontWeight: FontWeight.w600,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}




}

  IconData _getStatusIcon(String status) {
    switch(status) {
      case 'in_progress': return Icons.schedule;
      case 'completed': return Icons.check_circle;
      default: return Icons.help_outline;
    }
  }

  String _getStatusText(String status) {
    switch(status) {
      case 'in_progress': return 'Planifiée';
   
      case 'completed': return 'Terminée';
      case 'canceled': return 'Annulée';
      default: return 'Inconnu';
    }
  }

  Color _getStatusColor(String status) {
    switch(status) {
    
      case 'in_progress': return Colors.orange;
      case 'completed': return Colors.green;
      case 'canceled': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _confirmDelete(BuildContext context, String repairId) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text('Confirmer suppression'),
          content: Text('Supprimer cette réparation ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Annuler')),
            TextButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('repairs')
                      .doc(repairId)
                      .delete();
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Réparation supprimée avec succès')),
                  );
                } catch (e) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur de suppression: $e')),
                  );
                }
              },
              child: Text('Supprimer', style: TextStyle(color: Colors.red))),
          ],
        );
      },
    );
  }

void _showRepairDetails(BuildContext context, String repairId, Map<String, dynamic> data) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
              const SizedBox(height: 25),

              /// Info Véhicule
              FutureBuilder(
                future: FirebaseFirestore.instance.collection('vehicles').doc(data['vehicleId']).get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                  final vehicle = snapshot.data!.data() as Map<String, dynamic>;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.directions_car, color: _primaryColor),
                          const SizedBox(width: 8),
                          const Text('Véhicule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('${vehicle['marque']} - ${vehicle['numeroImmatriculation']}',
                          style: TextStyle(fontSize: 16)),
                      Text('Type: ${vehicle['type']}', style: TextStyle(color: Colors.grey[700])),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),

              Divider(),

              /// Description
              Row(
                children: [
                  Icon(Icons.description, color: _primaryColor),
                  const SizedBox(width: 8),
                  const Text('Description', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Text(data['description'] ?? '', style: TextStyle(fontSize: 16)),
              const SizedBox(height: 20),

              Divider(),

          
              Row(
                children: [
                  Icon(Icons.info_outline, color:_primaryColor),
                  const SizedBox(width: 8),
                  const Text('Détails', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Lieu:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(data['isOnSite'] ? 'Sur site' : 'Garage'),
                ],
              ),
              if (!data['isOnSite'] && data['garageId'] != null)
                FutureBuilder(
                  future: FirebaseFirestore.instance.collection('garages').doc(data['garageId']).get(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                    final garage = snapshot.data!.data() as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Nom Garage:', style: TextStyle(fontWeight: FontWeight.w500)),
                          Text(garage['name'] ?? ''),
                        ],
                      ),
                    );
                  },
                ),

              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Date prévue:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text(DateFormat('dd/MM/yyyy').format((data['scheduledDate'] as Timestamp).toDate())),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Coût estimé:', style: TextStyle(fontWeight: FontWeight.w500)),
                  Text('${(data['estimatedCost'] ?? 0).toStringAsFixed(3)} TND'),
                ],
              ),

              if (data['status'] == 'completed') ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Coût final:', style: TextStyle(fontWeight: FontWeight.w500)),
                    Text('${(data['finalCost'] ?? 0).toStringAsFixed(3)} TND'),
                  ],
                ),
                const SizedBox(height: 15),
                const Text('Pièces utilisées:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: (List<String>.from(data['usedParts'] ?? []))
                      .map((part) => Chip(
                            label: Text(part),
                            backgroundColor: Colors.deepPurple.shade100,
                            labelStyle: TextStyle(color: _primaryColor),
                          ))
                      .toList(),
                ),
              ],

              if (data['status'] == 'in_progress')
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 25),
                  child: Center(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RepairExecutionScreen(repairId: repairId),
                          ),
                        );
                      },
                      icon: Icon(Icons.build, color: Colors.white),
                      label: const Text('Terminer la réparation', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    ),
  );
}



class RepairExecutionScreen extends StatefulWidget {
  final String repairId;

  RepairExecutionScreen({required this.repairId});

  @override
  _RepairExecutionScreenState createState() => _RepairExecutionScreenState();
}


class _RepairExecutionScreenState extends State<RepairExecutionScreen> {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFF00BFA5);
  static const Color accentColor = Color(0xFFE70013);
  static const Color backgroundColor = Color(0xFFF9F9FB);

  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  List<String> _usedParts = [];
  double _totalCost = 0;
  Map<String, dynamic>? _repairData;
  List<String> _necessaryParts = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final repairDoc = await FirebaseFirestore.instance
        .collection('repairs')
        .doc(widget.repairId)
        .get();

    final vehicleDoc = await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(repairDoc['vehicleId'])
        .get();

    if (vehicleDoc.exists) {
      final vehicleType = vehicleDoc['type'];
      
   
      final partsSnapshot = await FirebaseFirestore.instance
          .collection('repair_parts')
          .where('vehicle_type', isEqualTo: vehicleType)
          .get();

      setState(() {
        _repairData = repairDoc.data();
        _usedParts = List<String>.from(_repairData?['usedParts'] ?? []);
        _totalCost = (_repairData?['finalCost'] ?? 0).toDouble();
        _necessaryParts = partsSnapshot.docs
            .map((doc) => doc['name'] as String)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_repairData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Exécuter la réparation'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 5),
              )
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(Icons.directions_car, 'Informations Véhicule'),
                const SizedBox(height: 10),
                _buildVehicleInfo(),
                const SizedBox(height: 20),
                _sectionTitle(Icons.description, 'Détails Réparation'),
                const SizedBox(height: 10),
                _buildRepairInfo(),
                const SizedBox(height: 20),
                _sectionTitle(Icons.build_circle, 'Pièces Utilisées'),
                const SizedBox(height: 10),
                _buildPartsSection(),
                const SizedBox(height: 20),
                _sectionTitle(Icons.payments, 'Coût Final'),
                const SizedBox(height: 10),
                _buildCostInput(),
                const SizedBox(height: 30),

                Center(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                    label: const Text('Finaliser Réparation', style: TextStyle(fontSize: 16,  color: Colors.white, )),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 6,
                    ),
                    onPressed: () => _validateAndUpdate('completed'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: primaryColor),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildVehicleInfo() {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('vehicles')
          .doc(_repairData!['vehicleId'])
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
        final vehicle = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${vehicle['marque']} - ${vehicle['numeroImmatriculation']}'),
            Text('Type: ${vehicle['type']}'),
            const Divider(),
          ],
        );
      },
    );
  }

  Widget _buildRepairInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_repairData!['description'] ?? ''),
        const SizedBox(height: 10),
        const Divider(),
        const SizedBox(height: 10),
        Text('Date prévue: ${DateFormat('dd/MM/yyyy').format((_repairData!['scheduledDate'] as Timestamp).toDate())}'),
      ],
    );
  }

  Widget _buildPartsSection() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 10),
      Text(
        'Pièces disponibles :',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: _primaryColor,
        ),
      ),
      const SizedBox(height: 15),
      SizedBox(
        height: 150,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _necessaryParts.length,
          itemBuilder: (context, index) {
            final part = _necessaryParts[index];
            final isSelected = _usedParts.contains(part);

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? _primaryColor.withOpacity(0.1)
                    : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? _primaryColor : Colors.grey[200]!,
                  width: 1.5,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                leading: Icon(
                  Icons.construction_rounded,
                  color: isSelected ? _primaryColor : Colors.grey[600],
                ),
                title: Text(
                  part,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: isSelected ? _primaryColor : Colors.black87,
                  ),
                ),
                trailing: Icon(
                  isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: isSelected ? secondaryColor : Colors.grey[400],
                ),
                onTap: () {
                  setState(() {
                    isSelected 
                        ? _usedParts.remove(part)
                        : _usedParts.add(part);
                  });
                },
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 20),
      if (_usedParts.isNotEmpty) ...[
        Text(
          'Pièces sélectionnées :',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _primaryColor,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _usedParts.map((part) => Chip(
            label: Text(part),
            deleteIcon: const Icon(Icons.close, size: 18),
            onDeleted: () => setState(() => _usedParts.remove(part)),
            backgroundColor: secondaryColor.withOpacity(0.1),
            labelStyle: TextStyle(color: _primaryColor),
          )).toList(),
        ),
      ],
    ],
  );
}

Widget _buildCostInput() {
  return TextFormField(
    controller: _costController,
    keyboardType: const TextInputType.numberWithOptions(
      decimal: true,
      signed: false,
    ),
    decoration: InputDecoration(
      labelText: 'Coût final (TND)',
      suffixText: 'TND',
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor),
      ),
      filled: true,
      fillColor: secondaryColor.withOpacity(0.1),
      prefixIcon: Icon(Icons.payments, color: _primaryColor),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2),
      ),
    ),
    validator: (value) {
      if (value == null || value.isEmpty) {
        return 'Veuillez saisir le coût';
      }
      final numericValue = double.tryParse(value);
      if (numericValue == null) {
        return 'Saisie numérique invalide';
      }
      if (numericValue <= 0) {
        return 'Le coût doit être positif';
      }
      return null;
    },
    inputFormatters: [
      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
    ],
    onChanged: (value) {
      final numericValue = double.tryParse(value);
      if (numericValue != null && numericValue > 0) {
        setState(() {
          _totalCost = numericValue;
        });
      }
    },
  );
}

 void _validateAndUpdate(String status) {
  if (!_formKey.currentState!.validate()) return;

  final costValue = double.tryParse(_costController.text);
  if (costValue == null || costValue <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Veuillez saisir un coût valide')),
    );
    return;
  }

  if (_usedParts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ajouter des pièces utilisées')),
    );
    return;
  }

  _updateStatus(status);
}

  Future<void> _updateStatus(String status) async {
    try {
      await FirebaseFirestore.instance.collection('repairs').doc(widget.repairId).update({
        'usedParts': _usedParts,
        'finalCost': _totalCost,
        'status': status,
        'completedAt': FieldValue.serverTimestamp(),
      });
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
    }
  }
}