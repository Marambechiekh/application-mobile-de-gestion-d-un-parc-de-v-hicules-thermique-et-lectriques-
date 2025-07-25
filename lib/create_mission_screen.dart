import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CreateMissionScreen extends StatefulWidget {
  static const Color primaryColor = Color(0xFF6C5CE7);
  static const Color secondaryColor = Color(0xFFFFFFFF);

  static const Color _primaryColor = Color(0xFF6C5CE7);

  @override
  _CreateMissionScreenState createState() => _CreateMissionScreenState();
}

class _CreateMissionScreenState extends State<CreateMissionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  String? _selectedVehicleId;
  String? _selectedDriverEmail;
  List<Map<String, String>> _vehicles = [];
  List<Map<String, dynamic>> _drivers = [];
  final Color _primaryColor = CreateMissionScreen._primaryColor;

  @override
  void initState() {
    super.initState();
    _fetchAvailableVehicles();
    _fetchAvailableDrivers();
  }

 Future<void> _fetchAvailableVehicles() async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance.collection('vehicles').get();
    List<Map<String, String>> availableVehicles = [];
    for (var doc in snapshot.docs) {
      final vehicleId = doc.id;
      final isAvailable = await _checkVehicleAvailability(vehicleId);
      if (isAvailable) {
        availableVehicles.add({
          'id': vehicleId,
          'marque': doc['marque'].toString(),
          'model': doc['modele'].toString(),
          'immatriculation': doc['numeroImmatriculation'].toString()
        });
      }
    }
    setState(() {
      _vehicles = availableVehicles;
    });
  } catch (e) {
    print("Erreur véhicules: $e");
  }
}
Future<bool> _isDriverAbsent(String driverId) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  
  final absences = await FirebaseFirestore.instance
      .collection('absence_requests')
      .where('driverId', isEqualTo: driverId)
      .where('status', isEqualTo: 'Approuvée')
      .get();

  for (var absence in absences.docs) {
    final startDate = (absence['startDate'] as Timestamp).toDate();
    final endDate = (absence['endDate'] as Timestamp).toDate().add(const Duration(days: 1));
    
    if (today.isAfter(startDate.subtract(const Duration(days: 1))) && 
        today.isBefore(endDate)) {
      return true;
    }
  }
  
  return false;
}
  Future<bool> _checkVehicleAvailability(String vehicleId) async {
    final repairs = await FirebaseFirestore.instance
        .collection('repairs')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'in_progress')
        .get();

    final maintenances = await FirebaseFirestore.instance
        .collection('maintenances')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['planned', 'in_progress'])
        .get();

    if (repairs.docs.isNotEmpty || maintenances.docs.isNotEmpty) {
      return false;
    }

    final missions = await FirebaseFirestore.instance
        .collection('missions')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'En cours')
        .get();

    return missions.docs.isEmpty;
  }

 Future<void> _submitMission() async {
  try {
    final selectedVehicle = _vehicles.firstWhere((v) => v['id'] == _selectedVehicleId);
    
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final missionRef = FirebaseFirestore.instance.collection('missions').doc();
      transaction.set(missionRef, {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'destination': _destinationController.text,
        'date': _dateController.text,
        'endDate': _endDateController.text,
        'vehicleId': _selectedVehicleId,
        'vehicleBrand': selectedVehicle['marque'],
        'vehicleModel': selectedVehicle['model'],
        'vehicleImmatriculation': selectedVehicle['immatriculation'],
        'driver': _selectedDriverEmail,
        'status': 'En cours',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Mission créée avec succès !'),
          backgroundColor: Colors.green,
        )
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur : \${e.toString()}'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  Future<void> _fetchAvailableDrivers() async {
  try {
    QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'Chauffeur')
        .get();

    List<Map<String, dynamic>> availableDrivers = [];
    
    for (var doc in snapshot.docs) {
      final email = doc['email'];
      final isAvailable = await _checkDriverAvailability(email);
      
      if (isAvailable) {
        availableDrivers.add({
          'id': doc.id, // Ajoutez l'ID du document
          'email': email,
          'name': doc['name']
        });
      }
    }
    
    setState(() {
      _drivers = availableDrivers;
    });
  } catch (e) {
    print("Erreur chauffeurs: $e");
  }
}

  Future<bool> _checkDriverAvailability(String email) async {
  // Vérifier les missions en cours
  final missions = await FirebaseFirestore.instance
      .collection('missions')
      .where('driver', isEqualTo: email)
      .where('status', isEqualTo: 'En cours')
      .get();
  
  if (missions.docs.isNotEmpty) {
    return false;
  }
  
  // Vérifier les absences approuvées
  final userSnapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('email', isEqualTo: email)
      .limit(1)
      .get();
  
  if (userSnapshot.docs.isEmpty) return true;
  
  final driverId = userSnapshot.docs.first.id;
  return !(await _isDriverAbsent(driverId));
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nouvelle Mission', style: TextStyle(color: Colors.white)),
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
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildInputField(_titleController, "Titre de la mission", Icons.title),
                SizedBox(height: 20),
                _buildInputField(_descriptionController, "Description", Icons.description),
                SizedBox(height: 20),
                _buildInputField(_destinationController, "Destination", Icons.place),
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text('Période de mission', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                        SizedBox(height: 15),
                        Row(
                          children: [
                            Expanded(child: _buildDatePicker("Date début*", _dateController)),
                            SizedBox(width: 15),
                            Expanded(child: _buildDatePicker("Date fin*", _endDateController, isEndDate: true)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text('Affectation des ressources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _primaryColor)),
                        SizedBox(height: 15),
                        _buildVehicleDropdown(),
                        SizedBox(height: 15),
                        _buildDriverDropdown(),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                ElevatedButton.icon(
            
                  label: Text('ENREGISTRER', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    padding: EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      _submitMission();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      validator: (value) => value?.isEmpty ?? true ? 'Ce champ est obligatoire' : null,
    );
  }

  Widget _buildDatePicker(String label, TextEditingController controller, {bool isEndDate = false}) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.calendar_today, color: _primaryColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onTap: () async {
        final DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: _primaryColor),
            ),
            child: child!,
          ),
        );
        if (pickedDate != null) {
          controller.text = DateFormat('dd/MM/yyyy').format(pickedDate);
          if (isEndDate && _dateController.text.isNotEmpty) {
            _validateEndDate(pickedDate);
          }
        }
      },
      validator: (value) {
        if (value?.isEmpty ?? true) return 'Sélectionnez une date';
        if (isEndDate && _dateController.text.isNotEmpty) {
          final startDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
          final endDate = DateFormat('dd/MM/yyyy').parse(value!);
          if (endDate.isBefore(startDate)) {
            return 'La date de fin ne peut pas être antérieure à la date de début';
          }
        }
        return null;
      },
    );
  }

  void _validateEndDate(DateTime endDate) {
    final startDate = DateFormat('dd/MM/yyyy').parse(_dateController.text);
    if (endDate.isBefore(startDate)) {
      _endDateController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Date de fin invalide !'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildVehicleDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedVehicleId,
    items: _vehicles.map((vehicle) {
      return DropdownMenuItem(
        value: vehicle['id'],
        child: RichText(
          text: TextSpan(
            style: TextStyle(color: Colors.grey[800], fontSize: 14),
            children: [
              TextSpan(
                text: "${vehicle['marque']} ${vehicle['model']}\n",
                style: TextStyle(fontWeight: FontWeight.w600)
              ),
              TextSpan(
                text: vehicle['immatriculation']!,
                style: TextStyle(fontSize: 12, color: Colors.grey[600])
              ),
            ],
          ),
        ),
      );
    }).toList(),
    onChanged: (value) => setState(() => _selectedVehicleId = value),
    decoration: InputDecoration(
      labelText: "Véhicule*",
      hintText: "Rechercher par marque, modèle ou immatriculation",
      prefixIcon: Icon(Icons.directions_car, color: _primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    validator: (value) => value == null ? 'Sélectionnez un véhicule' : null,
    isExpanded: true,
    dropdownColor: Colors.white,
    menuMaxHeight: 300,
  );
}

  Widget _buildDriverDropdown() {
  return DropdownButtonFormField<String>(
    value: _selectedDriverEmail,
    items: _drivers.map<DropdownMenuItem<String>>((driver) {
      return DropdownMenuItem<String>(
        value: driver['email'],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(driver['name'], style: TextStyle(fontWeight: FontWeight.bold)),
            Text(driver['email'], style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ],
        ),
      );
    }).toList(),
    onChanged: (String? newValue) => setState(() => _selectedDriverEmail = newValue),
    decoration: InputDecoration(
      labelText: "Chauffeur*",
      prefixIcon: Icon(Icons.person, color: _primaryColor),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    ),
    isExpanded: true,
    iconSize: 30,
    dropdownColor: Colors.white,
    menuMaxHeight: 300,
    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
    validator: (value) => value == null ? 'Sélectionnez un chauffeur' : null,
  );
}
}