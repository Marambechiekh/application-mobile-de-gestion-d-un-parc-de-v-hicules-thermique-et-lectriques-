import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_2/MaintenanceStatistics.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

const Color secondaryColor = Color(0xFFFFFFFF);
const Color _secondaryColor = Color(0xFF00BFA5);
const Color _primaryColor = Color(0xFF6C5CE7);
class ChartData {
  final String category;
  final int value;
  final Color color;

  ChartData(this.category, this.value, this.color);
}

class MaintenanceManagementScreen extends StatelessWidget {
  const MaintenanceManagementScreen({super.key});

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Gestion des Entretiens',
          style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800)),
      centerTitle: true,
      backgroundColor: _primaryColor,
      elevation: 4,
      
     
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
              'Planifier Entretien',
              Icons.schedule_rounded,
              const MaintenancePlanningScreen(),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              'Liste des Entretiens',
              Icons.checklist_rtl_rounded,
              const MaintenanceExecutionListScreen(),
            ),
            const SizedBox(height: 24),
            _buildActionCard(
              context,
              'Statistique des Entretiens',
              Icons.show_chart,
              const MaintenanceStatistics(),
            ),
            
          ],
        ),
      ),
    ),
        bottomNavigationBar: _buildBottomNavBar(context),
  );
}

Widget _buildBottomNavBar(BuildContext context) {
  // Détermination de l'index actuel
  final currentRoute = ModalRoute.of(context)?.settings.name;
  int currentIndex = 0;
  
  if (currentRoute == '/entre') {
    currentIndex = 0; // Index 0 pour Entretien de route
  } else if (currentRoute == '/main') {
    currentIndex = 1; // Index 1 pour Maintenance de route
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
                Navigator.pushReplacementNamed(context, '/entre');
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
            icon: Icon(Icons.aod_rounded, size: 28),
            label: 'Entretien',
            tooltip: 'Gestion entretien de voirie',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_suggest_rounded, size: 28),
            label: 'Maintenance',
            tooltip: 'Gestion maintenance routière',
          ),
        ],
      ),
    ),
  );
}
}
 void _showStatistics(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.analytics_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  const Text(
                    'Statistiques',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Contenu
            FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('maintenances').get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!.docs;
                final completed = data.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed').length;
                final pending = data.length - completed;

                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Graphique
                      SizedBox(
                        height: 250,
                        child: SfCartesianChart(
                          plotAreaBorderColor: Colors.transparent,
                          primaryXAxis: CategoryAxis(
                            labelStyle: TextStyle(color: Colors.grey[600]),
                          ),
                          primaryYAxis: NumericAxis(
                            labelStyle: TextStyle(color: Colors.grey[600]),
                            minimum: 0,
                            maximum: data.length.toDouble(),
                          ),
                          series: <BarSeries<ChartData, String>>[
                            BarSeries<ChartData, String>(
                              dataSource: [
                                ChartData('Terminés', completed, _primaryColor),
                                ChartData('En attente', pending, _primaryColor.withOpacity(0.5)),
                              ],
                              xValueMapper: (ChartData data, _) => data.category,
                              yValueMapper: (ChartData data, _) => data.value,
                              pointColorMapper: (ChartData data, _) => data.color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Légende
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegend(_primaryColor, 'Terminés'),
                          const SizedBox(width: 20),
                          _buildLegend(_primaryColor.withOpacity(0.5), 'En attente'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}



Widget _buildLegend(Color color, String text) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        text,
        style: TextStyle(
          color: Colors.grey[700],
          fontSize: 12,
        ),
      ),
    ],
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


class MaintenancePlanningScreen extends StatefulWidget {
  const MaintenancePlanningScreen({super.key});

  @override
  State<MaintenancePlanningScreen> createState() => _MaintenancePlanningScreenState();
}

class _MaintenancePlanningScreenState extends State<MaintenancePlanningScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _selectedVehicleId;
  String? _selectedGarageId;
  String? _selectedMaintenanceType;
  String? _vehicleType;
  DateTime? _selectedDate;
  bool _isOnSite = false;
  String? _selectedAddress;

  Future<List<DocumentSnapshot>> _getAvailableVehicles(List<DocumentSnapshot> vehicles) async {
    List<DocumentSnapshot> available = [];
    for (var vehicle in vehicles) {
      if (await _checkVehicleAvailability(vehicle.id)) {
        available.add(vehicle);
      }
    }
    return available;
  }

  Future<bool> _checkVehicleAvailability(String vehicleId) async {
    final repairs = await _firestore.collection('repairs')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['in_progress', 'planned'])
        .get();

    final maintenances = await _firestore.collection('maintenances')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['planned', 'in_progress'])
        .get();

    if (repairs.docs.isNotEmpty || maintenances.docs.isNotEmpty) {
      return false;
    }

    final missions = await _firestore.collection('missions')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'En cours')
        .get();

    return missions.docs.isEmpty;
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planifier Entretien',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600)),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            color: secondaryColor,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: constraints.maxWidth * 0.9,
                          ),
                          child: Column(
                            children: [
                              _buildVehicleDropdown(),
                              const SizedBox(height: 24),
                              _buildMaintenanceTypeDropdown(),
                              const SizedBox(height: 24),
                              _buildLocationSelector(),
                              const SizedBox(height: 24),
                              if (!_isOnSite) _buildGarageDropdown(),
                              if (_isOnSite) _buildAddressField(),
                              const SizedBox(height: 24),
                              _buildDatePicker(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: Size(constraints.maxWidth * 0.9, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('ENREGISTRER',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1)),
                    )
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('vehicles').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator(color: _primaryColor);
        }
        
        final vehicles = snapshot.data!.docs;
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _getAvailableVehicles(vehicles),
          builder: (context, availableSnapshot) {
            if (!availableSnapshot.hasData) {
              return const CircularProgressIndicator(color: _primaryColor);
            }

            return DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.9),
                labelText: 'Véhicule',
                floatingLabelStyle: TextStyle(
                  color: _primaryColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
                prefixIcon: Container(
                  padding: const EdgeInsets.all(12),
                  child: Icon(Icons.directions_car_rounded, 
                    color: _primaryColor,
                    size: 28),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: _primaryColor, 
                    width: 2)),
                errorStyle: TextStyle(
                  color: _secondaryColor,
                  fontWeight: FontWeight.w500),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 18),
              ),
              items: availableSnapshot.data!.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return DropdownMenuItem<String>(
                  value: doc.id,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      '${data['marque']} ${data['modele']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedVehicleId == doc.id 
                            ? _primaryColor 
                            : Colors.grey.shade800,
                      ),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) async {
                final doc = await _firestore.collection('vehicles').doc(value!).get();
                setState(() {
                  _selectedVehicleId = value;
                  _vehicleType = doc['type']?.toLowerCase();
                  _selectedMaintenanceType = null;
                });
              },
              validator: (value) => value == null 
                  ? 'Veuillez sélectionner un véhicule' 
                  : null,
            );
          },
        );
      },
    );
  }

 Widget _buildMaintenanceTypeDropdown() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('maintenance_types')
        .where('vehicle_type', isEqualTo: _vehicleType)
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const CircularProgressIndicator(color: _primaryColor);
      }

      return SizedBox(
        width: 250,  // largeur fixe que tu peux ajuster
        child: DropdownButtonFormField<String>(
          isExpanded: true,  // IMPORTANT pour que le dropdown prenne toute la largeur dispo
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            labelText: "Type d'entretien",
            floatingLabelStyle: TextStyle(
                color: _primaryColor,
                fontSize: 16,
                fontWeight: FontWeight.w600),
            prefixIcon: Container(
              padding: const EdgeInsets.all(12),
              child: Icon(Icons.build_circle_rounded,
                  color: _primaryColor,
                  size: 28),
            ),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                    color: _primaryColor,
                    width: 2)),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18
            ),
            errorStyle: TextStyle(
                color: _secondaryColor,
                fontWeight: FontWeight.w500
            ),
          ),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem<String>(
              value: data['name'],
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedMaintenanceType == data['name']
                      ? _primaryColor.withOpacity(0.1)
                      : Colors.transparent,
                ),
                child: Text(
                  data['name'],
                  style: TextStyle(
                      fontSize: 16,
                      color: _selectedMaintenanceType == data['name']
                          ? _primaryColor
                          : Colors.grey.shade800,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedMaintenanceType = value),
          validator: (value) => value == null
              ? 'Veuillez sélectionner un type d\'entretien'
              : null,
        ),
      );
    },
  );
}


  Widget _buildLocationSelector() {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Garage'),
            selected: !_isOnSite,
            onSelected: (val) => setState(() => _isOnSite = !val),
          ),
        ),
        Expanded(
          child: ChoiceChip(
            label: const Text('Sur site'),
            selected: _isOnSite,
            onSelected: (val) => setState(() => _isOnSite = val),
          ),
        ),
      ],
    );
  }

  Widget _buildGarageDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('garages').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        
        return DropdownButtonFormField<String>(
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            labelText: 'Sélectionner un garage',
            prefixIcon: Icon(Icons.garage_rounded, color: _primaryColor),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: _primaryColor, width: 2),
            ),
          ),
          items: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: doc.id,
              child: Text(data['name'],
                style: TextStyle(
                  color: Colors.grey[800],
                  fontWeight: FontWeight.w600
                )),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedGarageId = value),
        );
      },
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      decoration: const InputDecoration(labelText: 'Adresse'),
      onChanged: (value) => _selectedAddress = value,
    );
  }

 Widget _buildDatePicker() {
  bool isDateValid(DateTime? date) => date != null && date.isAfter(DateTime.now());

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now().add(const Duration(days: 1)),
          firstDate: DateTime.now().add(const Duration(days: 1)),
          lastDate: DateTime.now().add(const Duration(days: 365)),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(
                primary: _primaryColor,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
              dialogBackgroundColor: Colors.white,
            ),
            child: child!,
          ),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          labelText: 'Date prévue',
          labelStyle: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
          floatingLabelStyle: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          prefixIcon: Icon(Icons.calendar_today_rounded, color: _primaryColor),
          suffixIcon: Icon(Icons.arrow_drop_down_rounded, color: _primaryColor),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          errorText: _selectedDate == null
              ? 'Sélection obligatoire'
              : isDateValid(_selectedDate)
                  ? null
                  : 'Date antérieure non autorisée',
          errorStyle: TextStyle(
            color: _secondaryColor,
            fontWeight: FontWeight.w500,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
        child: Text(
          _selectedDate == null
              ? 'Choisir une date'
              : DateFormat('dd/MM/yyyy').format(_selectedDate!),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _selectedDate == null
                ? Colors.grey.shade600
                : isDateValid(_selectedDate!)
                    ? Colors.grey.shade800
                    : _secondaryColor,
          ),
        ),
      ),
    ),
  );
}

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_isOnSite && (_selectedAddress == null || _selectedAddress!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez saisir une adresse pour l\'intervention sur site',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )  );
      return;
    }

    if (!_isOnSite && _selectedGarageId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Veuillez sélectionner un garage',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       ) );
      return;
    }

    final selectedDate = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day
    );
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day
    );

    if (!selectedDate.isAfter(today)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('La date doit être dans le futur',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        )  );
      return;
    }

    try {
      await _firestore.runTransaction((transaction) async {
        final vehicleRef = _firestore.collection('vehicles').doc(_selectedVehicleId);
        final vehicleDoc = await transaction.get(vehicleRef);
        
        if (!await _checkVehicleAvailability(_selectedVehicleId!)) {
          throw 'Véhicule non disponible pour entretien';
        }

        final maintenanceRef = _firestore.collection('maintenances').doc();
        transaction.set(maintenanceRef, {
          'vehicleId': _selectedVehicleId,
          'type': _selectedMaintenanceType,
          'scheduledDate': Timestamp.fromDate(_selectedDate!),
          'status': 'planned',
          'vehicleType': _vehicleType,
          'isOnSite': _isOnSite,
          'garageId': _isOnSite ? null : _selectedGarageId,
          'address': _isOnSite ? _selectedAddress : null,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(vehicleRef, {
          'status': 'in_maintenance',
          'lastMaintenanceDate': Timestamp.fromDate(_selectedDate!),
        });
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Entretien planifié le ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _primaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       ) );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : ${e.toString()}',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          backgroundColor: _secondaryColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
       ) );
    }
  }
}

class MaintenanceExecutionListScreen extends StatelessWidget {
  const MaintenanceExecutionListScreen({super.key});
 @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
            
              SizedBox(width: 12),
              Text('Liste des Entretiens',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5
                ),
              ),
            ],
          ),
          backgroundColor: _primaryColor,
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(56),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('maintenances').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return LinearProgressIndicator();

                final maintenances = snapshot.data!.docs;
                final plannedCount = maintenances.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'planned').length;
                final completedCount = maintenances.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'completed').length;

                return Container(
                  color: _primaryColor,
                  child: TabBar(
                    indicatorColor: _secondaryColor,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.7),
                    tabs: [
                      _buildTab(Icons.hourglass_top, 'Planifiées', plannedCount, _secondaryColor),
                      _buildTab(Icons.check_circle, 'Terminées', completedCount, _secondaryColor),
                    ],
                  ),
                );
              },
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
          child: TabBarView(
            children: [
              _ListeMaintenance(status: 'planned'),
              _ListeMaintenance(status: 'completed'),
            ],
          ),
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
          SizedBox(width: 6),
          Text(label),
          SizedBox(width: 6),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(0.9),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$count',
              style: TextStyle(
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
}


class _ListeMaintenance extends StatefulWidget {
  final String status;
  const _ListeMaintenance({required this.status});

  @override
  __ListeMaintenanceState createState() => __ListeMaintenanceState();
}

class __ListeMaintenanceState extends State<_ListeMaintenance> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildSearchBar(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('maintenances')
                .where('status', isEqualTo: widget.status)
                .snapshots(),
            builder: (context, maintenancesSnapshot) {
              if (!maintenancesSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('vehicles').snapshots(),
                builder: (context, vehiclesSnapshot) {
                  if (!vehiclesSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final vehicleMap = _createVehicleMap(vehiclesSnapshot.data!.docs);
                  final filteredMaintenances = _filterMaintenances(
                    maintenancesSnapshot.data!.docs,
                    vehicleMap,
                  );

                  return ListView.builder(
                    itemCount: filteredMaintenances.length,
                    itemBuilder: (context, index) => _buildMaintenanceCard(
                      context,
                      filteredMaintenances[index],
                      vehicleMap,
                      widget.status == 'completed'
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
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


  Map<String, dynamic> _createVehicleMap(List<QueryDocumentSnapshot> vehicles) {
    return {for (var vehicle in vehicles) vehicle.id: vehicle.data()};
  }

  List<DocumentSnapshot> _filterMaintenances(
    List<DocumentSnapshot> maintenances,
    Map<String, dynamic> vehicleMap,
  ) {
    return maintenances.where((maintenance) {
      final data = maintenance.data() as Map<String, dynamic>;
      final vehicle = vehicleMap[data['vehicleId'] ?? {}];
      final vehicleInfo = '${vehicle['marque']} ${vehicle['modele']} ${vehicle['numeroImmatriculation']}'.toLowerCase();
      final maintenanceType = (data['type'] as String?)?.toLowerCase() ?? '';
      return vehicleInfo.contains(_searchQuery) || maintenanceType.contains(_searchQuery);
    }).toList();
  }

  Widget _buildMaintenanceCard(
    BuildContext context,
    DocumentSnapshot maintenance,
    Map<String, dynamic> vehicleMap,
    bool isCompleted,
  ) {
    final data = maintenance.data() as Map<String, dynamic>;
    final vehicle = vehicleMap[data['vehicleId'] ?? {}];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.1),
            blurRadius: 12,
            spreadRadius: 2,
          )
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildVehicleInfo(vehicle),
            const Divider(height: 24, color: Colors.black12),
            _buildDetailRow('Type', data['type'] ?? 'Non spécifié', Icons.build_rounded),
            _buildDetailRow('Date', 
              DateFormat('dd/MM/yyyy').format((data['scheduledDate'] as Timestamp).toDate()), 
              Icons.calendar_month_rounded),
            if (isCompleted) _buildDetailRow('Coût', 
              '${data['totalCost']?.toStringAsFixed(3) ?? '0.000'} TND', 
              Icons.payments),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatusChip(data['status'] ?? 'unknown'),
                _buildActionButtons(context, maintenance.id, isCompleted, data),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildVehicleInfo(Map<String, dynamic> vehicle) {
    if (vehicle.isEmpty) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded, color: _secondaryColor, size: 20),
          const SizedBox(width: 8),
          Text('Véhicule inconnu', 
            style: TextStyle(color: _secondaryColor, fontWeight: FontWeight.w600)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.directions_car_rounded, color: _primaryColor, size: 24),
            const SizedBox(width: 12),
            Text('${vehicle['marque']} ${vehicle['modele']}', 
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _primaryColor)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(Icons.confirmation_number_rounded, 
              color: Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Text(vehicle['numeroImmatriculation'] ?? 'N/A',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, dynamic value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: _primaryColor),
          const SizedBox(width: 12),
          Text('$label : ', style: TextStyle(
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w600)),
          Text(value.toString(), style: TextStyle(
            color: _primaryColor,
            fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
  final isCompleted = status == 'completed';
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: isCompleted ? Color(0xFFEAF6ED) : Color(0xFFFFF3E8), // vert pâle / orange pâle
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      isCompleted ? 'Terminée' : 'Planifiée',
      style: TextStyle(
        color: isCompleted ? Color(0xFF3DA35D) : Color(0xFFFF8C00), // vert / orange
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    ),
  );
}


  Widget _buildActionButtons(BuildContext context, String maintenanceId, bool isCompleted, Map<String, dynamic> data) {
    return Row(
      children: [
      
         if (data['status'] == 'planned')
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _confirmDelete(context,  maintenanceId),
                  ),
        if (isCompleted) IconButton(
          icon: Icon(Icons.info_outline_rounded, color: _primaryColor, size: 28),
          onPressed: () => _showDetailsDialog(context, data),
        ),
        IconButton(
          icon: Icon(
            isCompleted ? Icons.download_rounded : Icons.arrow_forward_ios_rounded,
            color: _primaryColor,
            size: 28),
          onPressed: () => isCompleted 
              ? _generatePdf(context, maintenanceId) 
              : Navigator.push(context, MaterialPageRoute(
                  builder: (_) => ExecutionMaintenanceScreen(maintenanceId: maintenanceId))),
        ),
      ],
    );
  }

void _showDetailsDialog(BuildContext context, Map<String, dynamic> data) {
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  // Futures pour récupérer les données supplémentaires
  final vehicleFuture = FirebaseFirestore.instance
      .collection('vehicles')
      .doc(data['vehicleId'])
      .get();

  final garageFuture = data['isOnSite']
      ? Future.value(null)
      : FirebaseFirestore.instance
          .collection('garages')
          .doc(data['garageId'])
          .get();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => FutureBuilder(
      future: Future.wait([vehicleFuture, garageFuture]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator(color: _primaryColor));
        }

        final results = snapshot.data as List<DocumentSnapshot?>;
        final vehicle = results[0]?.data() as Map<String, dynamic>?;
        final garage = results[1]?.data() as Map<String, dynamic>?;

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
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
                _buildDetailHeader('Détails de l\'Entretien'),
                _buildDetailItem(
                  Icons.build_rounded,
                  'Type d\'Entretien',
                  Text(data['type'] ?? 'N/A'),
                ),
                _buildDetailItem(
                  Icons.directions_car_rounded,
                  'Véhicule',
                  Text(vehicle != null
                      ? '${vehicle['marque']} ${vehicle['modele']}\n${vehicle['numeroImmatriculation'] ?? ''}'
                      : 'Non trouvé'),
                ),
                _buildDetailItem(
                  Icons.calendar_today_rounded,
                  'Date Planifiée',
                 Text(DateFormat('dd/MM/yyyy HH:mm').format((data['createdAt'] as Timestamp).toDate())),
                ),
                _buildDetailItem(
                  data['isOnSite'] ? Icons.location_on_rounded : Icons.garage_rounded,
                  'Localisation',
                  data['isOnSite']
                      ? Text('Sur site\n${data['address'] ?? 'N/A'}')
                      : Text(garage != null
                          ? 'Garage ${garage['name']}'
                          : 'Garage inconnu'),
                ),
                _buildDetailItem(
                  Icons.money_rounded,
                  'Coûts',
                  Text('Total: ${data['totalCost']?.toStringAsFixed(3) ?? '0.000'} TND'),
                ),
                if (data['checklist'] != null) ...[
                  _buildSectionTitle('Tâche(s) effectuée(s)'),
                  ...(data['checklist'] as List).map((task) =>
                      _buildChecklistItem(task['description'], task['completed'])),
                ],
                _buildDetailItem(
                  Icons.history_rounded,
                  'Historique',
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🕒 Planifiée le: ${dateFormat.format((data['createdAt'] as Timestamp).toDate())}'),
                      Text('✅ Terminée le: ${dateFormat.format((data['completedDate'] as Timestamp).toDate())}'),
                    
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    ),
  );
}

String _calculateAdditionalCosts(List<dynamic>? costs) {
  if (costs == null) return '0.000';
  final total = costs.fold(0.0, (sum, item) => sum + (item['amount'] ?? 0));
  return total.toStringAsFixed(3);
}

Widget _buildDetailHeader(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: _primaryColor,
        letterSpacing: 0.8)),
  );
}

Widget _buildSectionTitle(String text) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: _primaryColor)),
  );
}

Widget _buildDetailItem(IconData icon, String title, Widget valueWidget) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _primaryColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              DefaultTextStyle(
                style: TextStyle(
                  color: Colors.grey[800],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                child: valueWidget,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget _buildChecklistItem(String task, bool isCompleted) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Icon(
          isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
          color: _secondaryColor, // même couleur pour tous
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            task,
            style: TextStyle(
              color: _secondaryColor, // texte en secondaryColor
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration: TextDecoration.none, // pas de barre
            ),
          ),
        ),
      ],
    ),
  );
}

  Future<void> _confirmDelete(BuildContext context, String maintenanceId) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer suppression'),
        content: const Text('Supprimer cet entretien ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('maintenances').doc(maintenanceId).delete();
              Navigator.pop(context);
            },
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf(BuildContext context, String maintenanceId) async {
    final doc = await FirebaseFirestore.instance.collection('maintenances').doc(maintenanceId).get();
    final data = doc.data()!;
    final vehicleDoc = await FirebaseFirestore.instance.collection('vehicles').doc(data['vehicleId']).get();
    final vehicle = vehicleDoc.data()!;

    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      build: (pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Header(text: 'Rapport d\'Entretien', level: 0),
          pw.SizedBox(height: 20),
          pw.Text('Véhicule: ${vehicle['marque']} ${vehicle['modele']}'),
          pw.Text('Plaque: ${vehicle['numeroImmatriculation'] ?? 'Non renseignée'}'),
          pw.Divider(),
          pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Type:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(data['type']),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Date:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(DateFormat('dd/MM/yyyy')
                      .format((data['scheduledDate'] as Timestamp).toDate())),
                ),
              ]),
              pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('Coût:', 
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text('${data['totalCost']?.toStringAsFixed(3) ?? '0.000'} TND'),
                ),
              ]),
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text('Signature:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Container(
            width: 200,
            height: 1,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 1),
              ),
            ),
          ),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Responsable: ...............................'),
          ),
        ],
      ),
    ));

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf.save());
  }
}


class ExecutionMaintenanceScreen extends StatefulWidget {
  final String maintenanceId;
  const ExecutionMaintenanceScreen({super.key, required this.maintenanceId});

  @override
  State<ExecutionMaintenanceScreen> createState() => _ExecutionMaintenanceScreenState();
}

class _ExecutionMaintenanceScreenState extends State<ExecutionMaintenanceScreen> {
    double _currentKm = 0;
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  List<Map<String, dynamic>> _checklist = [];
  List<Map<String, dynamic>> _additionalCosts = [];
  double _totalCost = 0;
  Map<String, dynamic>? _maintenanceData;
  Map<String, dynamic>? _vehicleData;
  String? _vehicleType;
  @override
  void initState() {
    super.initState();
    _loadData();
  }
Future<void> _loadData() async {
  final maintenanceDoc = await FirebaseFirestore.instance
      .collection('maintenances').doc(widget.maintenanceId).get();
  
  final vehicleId = maintenanceDoc['vehicleId']; // Récupération directe de l'ID
  final vehicleDoc = await FirebaseFirestore.instance
      .collection('vehicles').doc(vehicleId).get();

  final maintenanceTypeQuery = await FirebaseFirestore.instance
      .collection('maintenance_types')
      .where('name', isEqualTo: maintenanceDoc['type'])
      .where('vehicle_type', isEqualTo: maintenanceDoc['vehicleType'] ?? 'thermique') // Fallback
      .get();

  setState(() {
    _maintenanceData = maintenanceDoc.data()!;
    _vehicleData = vehicleDoc.data()!;
    _vehicleType = maintenanceDoc['vehicleType'] ?? 'thermique'; // Garantit une valeur non-nulle
    _currentKm = (vehicleDoc.data()!['nombreKmParcouru'] as num).toDouble();

    if (maintenanceTypeQuery.docs.isNotEmpty) {
      final typeData = maintenanceTypeQuery.docs.first.data();
      _checklist = (typeData['tasks'] as List<dynamic>).map((task) => {
        'description': task.toString(), 
        'completed': false
      }).toList();
    } else {
      _checklist = [];
    }

    _totalCost = (_maintenanceData!['totalCost'] as num?)?.toDouble() ?? 0.0;
    _additionalCosts = List<Map<String, dynamic>>.from(
        _maintenanceData!['additionalCosts'] ?? []);
  });
}
 Widget _buildKmInput(bool isCompleted) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, color: _primaryColor, size: 24),
                SizedBox(width: 12),
                Text('Kilométrage actuel',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor)),
              ],
            ),
            SizedBox(height: 12),
            Text(
              '${_currentKm.toStringAsFixed(0)} km',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade800,
                fontWeight: FontWeight.bold
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
 Widget build(BuildContext context) {
  if (_maintenanceData == null || _vehicleData == null) {
    return Center(
      child: CircularProgressIndicator(color: _primaryColor),
    );
  }

  final isCompleted = _maintenanceData!['status'] == 'completed';

  return Scaffold(
    appBar: AppBar(
      title: Row(
        children: [
        
          SizedBox(width: 12),
          Text('Exécution Entretien',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white)),
        ],
      ),
      backgroundColor: _primaryColor,
      actions: [
        if (isCompleted) IconButton(
          icon: Icon(Icons.download_rounded, color: Colors.white),
          onPressed: _generateReport,
        )
      ],
    ),
    body: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            _primaryColor.withOpacity(0.03),
            _secondaryColor.withOpacity(0.01)
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: _buildVehicleInfo(),
                ),
              ),
               SizedBox(height: 24),
      _buildKmInput(isCompleted),
              SizedBox(height: 24),
              _buildChecklist(isCompleted),
              SizedBox(height: 24),
              _buildAdditionalCosts(isCompleted),
              if (!isCompleted) _buildFinalizeButton(),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildVehicleInfo() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(Icons.directions_car_rounded, 
            color: _primaryColor, size: 28),
          SizedBox(width: 12),
          Text('${_vehicleData!['marque']} ${_vehicleData!['modele']}',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: _primaryColor)),
        ],
      ),
      SizedBox(height: 8),
      Row(
        children: [
          Icon(Icons.confirmation_number_rounded, 
            color: Colors.grey.shade600, size: 20),
          SizedBox(width: 8),
          Text(_vehicleData!['numeroImmatriculation'] ?? 'N/A',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14)),
        ],
      ),
    ],
  );
}

Widget _buildChecklist(bool isCompleted) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15)),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rtl_rounded, 
                color: _primaryColor, size: 24),
              SizedBox(width: 12),
              Text('Checklist',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor)),
            ],
          ),
          SizedBox(height: 12),
          if (_checklist.isEmpty)
            Text('Aucune tâche définie pour cet entretien',
              style: TextStyle(color: Colors.grey)),
          ..._checklist.map((step) => CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(step['description'],
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500)),
            value: step['completed'],
            activeColor: _primaryColor,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: isCompleted 
                ? null 
                : (value) => setState(() => step['completed'] = value ?? false),
          )).toList(),
        ],
      ),
    ),
  );
}
Widget _buildAdditionalCosts(bool isCompleted) {
  return Card(
    elevation: 4,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15)),
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments, 
                color: _primaryColor, size: 24),
              SizedBox(width: 12),
              Text('Coûts',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _primaryColor)),
            ],
          ),
          SizedBox(height: 12),
         TextFormField(
  controller: _costController,
  decoration: InputDecoration(
    filled: true,
    fillColor: Colors.white.withOpacity(0.9),
    labelText: 'Ajouter coût (TND)',
    floatingLabelStyle: TextStyle(
      color: _primaryColor,
      fontWeight: FontWeight.w600),
    suffixIcon: IconButton(
      icon: Icon(Icons.add_circle_rounded, 
        color: isCompleted ? Colors.grey : _primaryColor),
      onPressed: isCompleted ? null : _addCost,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: _primaryColor, 
        width: 2)),
    enabled: !isCompleted,
  ),
  // CONTROLE DE SAISIE AJOUTÉ ICI
  keyboardType: const TextInputType.numberWithOptions(
    decimal: true,
    signed: false,
  ),
  inputFormatters: [
    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
  ],
  validator: (value) {
    if (value == null || value.isEmpty) return null;
    final numericValue = double.tryParse(value);
    if (numericValue == null) return 'Format numérique invalide';
    if (numericValue <= 0) return 'Le coût doit être positif';
    return null;
  },
),
          ..._additionalCosts.map((cost) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.circle_rounded, 
              color: _secondaryColor, size: 12),
            title: Text(cost['description'],
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w500)),
            trailing: Text('${cost['amount'].toStringAsFixed(2)} TND',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600)),
          )).toList(),
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total: ${_totalCost.toStringAsFixed(2)} TND',
              style: TextStyle(
                fontSize: 16,
                color: _primaryColor,
                fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    ),
  );
}

Widget _buildFinalizeButton() {
  return Padding(
    padding: EdgeInsets.symmetric(vertical: 24),
    child: SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
          elevation: 4,
          shadowColor: _primaryColor.withOpacity(0.3),
        ),
        onPressed: _completeMaintenance,
        child: Text('FINALISER L\'ENTRETIEN',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8)),
      ),
    ),
  );
}
 void _addCost() {
  final value = _costController.text;
  if (value.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Veuillez saisir un montant')),
    );
    return;
  }
  final numericValue = double.tryParse(value);
  if (numericValue == null || numericValue <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Montant invalide. Veuillez saisir un nombre positif')),
    );
    return;
  }
  setState(() {
    _additionalCosts.add({
      'description': 'Coût',
      'amount': numericValue,
      'date': DateTime.now()
    });
    _totalCost += numericValue;
    _costController.clear();
  });
}

Future<void> _completeMaintenance() async {
   if (!_formKey.currentState!.validate()) {
    return;
  }

  try {
    // Vérification de la complétion du checklist
    if (_checklist.any((step) => !step['completed'])) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez compléter toutes les étapes du checklist !'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    final String vehicleId = _maintenanceData!['vehicleId'] as String;
    final DocumentSnapshot vehicleDoc = await FirebaseFirestore.instance
        .collection('vehicles')
        .doc(vehicleId)
        .get();
    final double currentKm = (vehicleDoc['nombreKmParcouru'] as num).toDouble();
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.update(
        FirebaseFirestore.instance.collection('maintenances').doc(widget.maintenanceId), 
        {
          'status': 'completed',
          'performed_km': currentKm,
          'totalCost': _totalCost,
          'checklist': _checklist,
          'additionalCosts': _additionalCosts,
          'completedAt': FieldValue.serverTimestamp(),
          'completedDate': FieldValue.serverTimestamp(), 
          'vehicleType': _vehicleType ?? 'thermique', 
        },
      );

  
      transaction.update(
        FirebaseFirestore.instance.collection('vehicles').doc(vehicleId),
        {
          'lastMaintenance': FieldValue.serverTimestamp(),
          'lastMaintenanceDetails': {
            'km': currentKm,
            'date': FieldValue.serverTimestamp(),
          },
          'nombreKmParcouru': currentKm,
          'nextMaintenanceKm': currentKm + 10000, 
        },
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Entretien finalisé à ${currentKm.toStringAsFixed(0)} km'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Retour à l'écran précédent
    Navigator.pop(context);

  } catch (e, stackTrace) {
    // Gestion d'erreur détaillée
    debugPrint('Erreur lors de la finalisation: $e');
    debugPrint('Stack trace: $stackTrace');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Erreur: ${e.toString().split(':').first}'), // Message simplifié
        backgroundColor: Colors.red,
        duration: Duration(seconds: 5),
      ),
    );
  }
}
double _calculateNextMaintenance(double currentKm) {
  const maintenanceInterval = 10000;
  return currentKm + maintenanceInterval;
}
Future<void> _generateReport() async {
  final pdf = pw.Document();

  final headerStyle = pw.TextStyle(
    fontSize: 18,
    fontWeight: pw.FontWeight.bold,
    color: PdfColor.fromInt(_primaryColor.value & 0xFFFFFF),
  );

  final sectionTitleStyle = pw.TextStyle(
    fontSize: 14,
    fontWeight: pw.FontWeight.bold,
    color: PdfColor.fromInt(_secondaryColor.value & 0xFFFFFF),
  );

  pdf.addPage(
    pw.Page(
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text("Rapport d'Entretien", style: headerStyle),
            ),
            pw.SizedBox(height: 20),

            // Section Véhicule
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('VÉHICULE', style: sectionTitleStyle),
                  pw.SizedBox(height: 5),
                  pw.Text('${_vehicleData!['marque']} ${_vehicleData!['modele']}'),
                  pw.Text('Plaque: ${_vehicleData!['numeroImmatriculation'] ?? 'Non renseignée'}'),
                ],
              ),
            ),

            pw.SizedBox(height: 15),

            // Détails Entretien
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              padding: pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('DÉTAILS', style: sectionTitleStyle),
                  pw.SizedBox(height: 5),
                  pw.Row(
                    children: [
                      pw.Text('Type: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(_maintenanceData!['type'] ?? ''),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Text('Date: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(
                        (_maintenanceData!['scheduledDate'] as Timestamp).toDate(),
                      )),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Text('Coût: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      pw.Text('${_totalCost.toStringAsFixed(3)} TND'),
                    ],
                  ),
                ],
              ),
            ),

            pw.SizedBox(height: 25),

            // Signature
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(height: 1, width: 200, color: PdfColors.black),
                pw.SizedBox(height: 5),
                pw.Text('Responsable technique', style: pw.TextStyle(fontSize: 10)),
                pw.Text('Signature et cachet', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
              ],
            ),
          ],
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (PdfPageFormat format) => pdf.save());
}


}