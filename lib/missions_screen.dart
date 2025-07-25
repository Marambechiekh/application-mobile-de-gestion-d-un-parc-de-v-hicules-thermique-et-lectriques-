import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_2/edit_mission_screen.dart';
import 'validate_mission_screen.dart';

class MissionsScreen extends StatefulWidget {
  @override
  _MissionsScreenState createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  String? _userRole;
  String? _userEmail;
  final Map<String, TextEditingController> _searchControllers = {
    'En cours': TextEditingController(),
    'Terminée': TextEditingController(),
  };

  static const Color _primaryColor = Color(0xFF6C5CE7);
  
  static const Color _secondaryColor = Color(0xFF00BFA5);
  static const Color _backgroundColor = Color(0xFFF8F9FA);

  final _statusColors = {
    'En cours': Colors.orange,
    'Terminée': Colors.green,
    'En attente': Colors.grey,
    'Validée': _primaryColor,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (_user == null) return;
    DocumentSnapshot userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    if (userDoc.exists) {
      setState(() {
        _userRole = userDoc['role'];
        _userEmail = _user!.email?.trim().toLowerCase();
      });
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('dd/MM/yyyy à HH:mm').format(timestamp.toDate());
  }

 @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _backgroundColor,
    appBar: AppBar(
      leading: _userRole == 'Chauffeur'
    ? IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () {
          if (_userRole == 'Chauffeur') {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          } else {
            Navigator.of(context).pop();
          }
        },
      )
    : null,

      title: Text(
        _userRole == 'Chauffeur' ? 'Mes Missions' : 'Gestion des Missions',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: Colors.white,
        indicatorWeight: 3,
        labelStyle: TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelColor: Colors.white70,
        tabs: [
          Tab(icon: Icon(Icons.assignment_outlined), text: 'En cours'),
          Tab(icon: Icon(Icons.assignment_turned_in), text: 'Terminées'),
        ],
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: _primaryColor, // Correction 1 : 'color' au lieu de 'colors'
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
      ),
    ),
    body: TabBarView(
      controller: _tabController,
      children: [
        _buildMissionList(statusFilter: 'En cours'),
        _buildMissionList(statusFilter: 'Terminée'),
      ],
    ),
    floatingActionButton: _userRole == 'Responsable de parc'
        ? FloatingActionButton(
            backgroundColor: _primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.add, size: 28),
            onPressed: () => Navigator.pushNamed(context, '/createMission'),
          )
        : null,
  );
}
 Widget _buildMissionList({required String statusFilter}) {
  if (_userRole == null) return _buildLoadingIndicator();
  final controller = _searchControllers[statusFilter]!;
  final Color _primaryColor = const Color(0xFF6C5CE7);

  return StreamBuilder<QuerySnapshot>(
    stream: _userRole == 'Responsable de parc'
        ? _firestore.collection('missions').snapshots()
        : _firestore.collection('missions')
            .where('driver', isEqualTo: _userEmail)
            .snapshots(),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return _buildLoadingIndicator();
      }
      if (snapshot.hasError) {
        return _buildErrorState(snapshot.error.toString());
      }

      final allMissions = snapshot.data?.docs ?? [];
      final filteredMissions = allMissions.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final matchesStatus = data['status'] == statusFilter;
        final matchesSearch = _matchesSearchQuery(data, controller.text);
        return matchesStatus && matchesSearch;
      }).toList();

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller,
                onChanged: (value) => setState(() {}),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  suffixIcon: controller.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            controller.clear();
                            setState(() {});
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
            child: filteredMissions.isEmpty
                ? _buildEmptyState(searchQuery: controller.text)
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredMissions.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final mission = filteredMissions[index];
                      return _buildMissionCard(
                        mission.data() as Map<String, dynamic>,
                        mission,
                      );
                    },
                  ),
          ),
        ],
      );
    },
  );
}

  bool _matchesSearchQuery(Map<String, dynamic> missionData, String query) {
    if (query.isEmpty) return true;
    final searchTerms = query.toLowerCase().split(' ');
    final missionText = [
      missionData['title'] ?? '',
      missionData['destination'] ?? '',
      missionData['vehicle'] ?? '',
      missionData['driver'] ?? '',
    ].join(' ').toLowerCase();
    return searchTerms.every((term) => missionText.contains(term));
  }

  Widget _buildMissionCard(Map<String, dynamic> data, DocumentSnapshot mission) {
    final status = data['status'] ?? 'En attente';
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
child: InkWell(
  borderRadius: BorderRadius.circular(15),
  onTap: () => _showMissionDetails(data, mission),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      data['title'] ?? 'Sans titre',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: _primaryColor,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    ),
                    backgroundColor: _statusColors[status],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ],
              ),
              SizedBox(height: 12),
              _buildInfoRow(Icons.location_on, data['destination']),
              _buildInfoRow(Icons.date_range, _formatCustomDate(data['date'])),
              if (data['vehicle'] != null)
                _buildInfoRow(Icons.directions_car, data['vehicle']),
              SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: Icon(Icons.visibility_outlined, color: Colors.grey),
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.1)),
                    onPressed: () => _showMissionDetails(data, mission),
                  ),
                  if (_userRole == 'Responsable de parc') ...[
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.edit, color: _primaryColor),
                      style: IconButton.styleFrom(backgroundColor: Colors.blue.withOpacity(0.1)),
                      onPressed: () => _editMission(mission),
                    ),
                    SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      style: IconButton.styleFrom(backgroundColor: Colors.red.withOpacity(0.1)),
                      onPressed: () => _confirmDeleteMission(mission),
                    ),
                  ],
                  if (_userRole == 'Chauffeur' && data['status'] != 'Terminée')
                    IconButton(
                      icon: Icon(Icons.check_circle, color: Colors.green),
                      style: IconButton.styleFrom(backgroundColor: Colors.green.withOpacity(0.1)),
                      onPressed: () => _validateMission(mission),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String? text) {
    if (text == null) return SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildEmptyState({String? searchQuery}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
          SizedBox(height: 20),
          Text(
            searchQuery?.isNotEmpty ?? false 
                ? 'Aucun résultat trouvé' 
                : 'Aucune mission disponible',
            style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[800]!)),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 80, color: Colors.red[300]),
          SizedBox(height: 20),
          Text('Erreur de chargement', style: TextStyle(fontSize: 18, color: Colors.red)),
          SizedBox(height: 10),
          Text(error, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchControllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
void _showMissionDetails(Map<String, dynamic> data, DocumentSnapshot mission) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 20),
        child: FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('users')
              .where('email', isEqualTo: data['driver'])
              .limit(1)
              .get(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Erreur: ${snapshot.error}"),
              );
            }

            String driverName = 'N/A';
            if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
              final driverData = snapshot.data!.docs.first.data() as Map<String, dynamic>;
              driverName = driverData['name'] ?? 'N/A';
            }

            final vehicleType = data['vehicleType']?.toLowerCase() ?? 'thermique';
            final batteryCapacity = double.tryParse(data['batteryCapacity']?.toString() ?? '') ?? 0.0;
            final km = double.tryParse(data['kilometers']?.toString() ?? '') ?? 0.0;
            final batteryInitial = double.tryParse(data['chargeInitial']?.toString() ?? '') ?? 0.0;
            final batteryFinal = double.tryParse(data['batteryFinal']?.toString() ?? '') ?? 0.0;
            final fuelInitial = double.tryParse(data['fuel']?.toString() ?? '') ?? 0.0;
            final fuelFinal = double.tryParse(data['reservoirFinal']?.toString() ?? '') ?? 0.0;

            double? calculatedConsumption;

            if (km > 0) {
              if (vehicleType == 'electrique' && batteryCapacity > 0) {
                final usedBattery = batteryInitial - batteryFinal;
                calculatedConsumption = ((usedBattery / 100) * batteryCapacity) / km * 100;
              } else if (vehicleType == 'thermique') {
                final usedFuel = fuelInitial - fuelFinal;
                calculatedConsumption = (usedFuel / km) * 100;
              }
            }

            final double? startKm = double.tryParse(data['startKilometers']?.toString() ?? '');
            final double? endKm = double.tryParse(data['endKilometers']?.toString() ?? '');
            final double? distance = (startKm != null && endKm != null) ? endKm - startKm : null;

            return Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 15),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      _buildCardSection('📍 Mission', [
                        _buildDetailItem('Titre', data['title']),
                        _buildDetailItem('Description', data['description']),
                        _buildDetailItem('Destination', data['destination']),
                      
                        _buildDetailItem('Heure de début', data['startTime']),
                        _buildDetailItem('Heure de fin', data['endTime']),
                        if (data['startKilometers'] != null)
                          _buildDetailItem('Kilométrage initial', '${data['startKilometers']} km'),
                        if (data['endKilometers'] != null)
                          _buildDetailItem('Kilométrage final', '${data['endKilometers']} km'),
                      ]),
                      _buildCardSection('🚗 Véhicule', [
                        _buildDetailItem('Modèle', data['vehicleModel']),
                        _buildDetailItem('Marque', data['vehicleBrand']),
                        _buildDetailItem('Matricule', data['vehicleImmatriculation']),
                        if (vehicleType == 'electrique' && data['autonomie'] != null)
                          _buildDetailItem('Autonomie', '${data['autonomie']} km'),
                        if (vehicleType == 'electrique' && data['batteryFinal'] != null)
                          _buildDetailItem('Batterie finale', '${data['batteryFinal']} %'),
                        if (vehicleType == 'thermique' && data['reservoirFinal'] != null)
                          _buildDetailItem('Réservoir final', '${data['reservoirFinal']} L'),
                        if (data['status'] == 'Terminée' && distance != null)
                          _buildDetailItem('Distance parcourue', '${distance.toStringAsFixed(2)} km'),
                        if (calculatedConsumption != null && data['status'] == 'Terminée')
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                Icon(Icons.local_gas_station_outlined, color: Colors.grey[600], size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    vehicleType == 'electrique'
                                        ? 'Consommation: ${calculatedConsumption.toStringAsFixed(2)} kWh/100km'
                                        : 'Consommation: ${calculatedConsumption.toStringAsFixed(2)} L/100km',
                                    style: TextStyle(fontSize: 15, color: Colors.black87),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ]),
                      _buildCardSection('👤 Chauffeur', [
                        _buildDetailItem('Nom', driverName),
                        _buildDetailItem('Email', data['driver']),
                      ]),
                      if (data['validationDate'] != null)
                        _buildCardSection('✅ Validation', [
                          _buildDetailItem('Validée le', _formatTimestamp(data['validationDate'])),
                        ]),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: IconButton(
                    icon: Icon(Icons.close, color: Colors.grey[600]),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}




  void _editMission(DocumentSnapshot mission) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => EditMissionScreen(mission: mission)));
  }

  void _validateMission(DocumentSnapshot mission) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => ValidateMissionScreen(mission: mission)));
  }

  void _confirmDeleteMission(DocumentSnapshot mission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer cette mission définitivement ?'),
        actions: [
          TextButton(
            child: Text('Annuler'),
            onPressed: () => Navigator.pop(context)),
          TextButton(
            child: Text('Supprimer', style: TextStyle(color: Colors.red)),
            onPressed: () {
              mission.reference.delete();
              Navigator.pop(context);
            }),
        ],
      ),
    );
  }

  String _formatCustomDate(dynamic date) {
    try {
      if (date == null) return 'N/A';
      if (date is Timestamp) return DateFormat('dd/MM/yyyy').format(date.toDate());
      if (date is String) return DateFormat('dd/MM/yyyy').format(DateFormat('dd/MM/yyyy').parse(date));
      return 'Format invalide';
    } catch (e) {
      return 'Date invalide';
    }
  }

  Widget _buildCardSection(String title, List<Widget> details) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
            ),
            SizedBox(height: 10),
            ...details,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String? value) {
    if (value == null || value.isEmpty) return SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text('$label :', style: TextStyle(fontWeight: FontWeight.w500))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(color: Colors.grey[700]))),
        ],
      ),
    );
  }
}