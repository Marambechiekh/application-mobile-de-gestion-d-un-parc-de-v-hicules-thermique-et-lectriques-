import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ValidateMissionScreen extends StatefulWidget {
  final DocumentSnapshot mission;

  const ValidateMissionScreen({Key? key, required this.mission}) : super(key: key);

  @override
  _ValidateMissionScreenState createState() => _ValidateMissionScreenState();
}

class _ValidateMissionScreenState extends State<ValidateMissionScreen> {
  static const Color primaryColor = Color(0xFF6C5CE7); // Purple

  static const Color statusGreen = Color(0xFF4CAF50);
  static const Color statusRed = Color(0xFFF44336);
  static const Color statusOrange = Color(0xFFFF9800);

  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late Map<String, TextEditingController> _controllers;
  String? _vehicleType;
  Map<String, dynamic> _vehicleData = {};
  String? _status;
  double? _calculatedConsumption;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controllers = {
      'kilometers': TextEditingController(),
      'chargeInitial': TextEditingController(),
      'fuel': TextEditingController(),
      'batteryFinal': TextEditingController(),
      'reservoirFinal': TextEditingController(),
    };
    _fetchVehicleData();
  }

  Future<void> _fetchVehicleData() async {
    try {
      final DocumentSnapshot doc = await _firestore.collection('vehicles')
          .doc(widget.mission['vehicleId'])
          .get();

      if (doc.exists) {
        setState(() {
          _vehicleData = doc.data() as Map<String, dynamic>;
          _vehicleType = _vehicleData['type'] ?? 'thermique';
          _prefillInitialValues();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Erreur de récupération: $e");
      setState(() => _isLoading = false);
    }
  }

  void _prefillInitialValues() {
    if (_vehicleType == 'electrique') {
      _controllers['chargeInitial']!.text =
          (_vehicleData['etatCharge']?.toString() ?? '100');
    } else {
      _controllers['fuel']!.text =
          (_vehicleData['capaciteReservoirCarburant']?.toString() ?? '50');
    }
    _calculateStatus();
  }

  void _calculateStatus() {
    if ((_vehicleType == 'electrique' && _controllers['batteryFinal']!.text.isEmpty) ||
        (_vehicleType == 'thermique' && _controllers['reservoirFinal']!.text.isEmpty)) {
      return;
    }

    double initialValue = 0;
    double finalValue = 0;

    try {
      if (_vehicleType == 'electrique') {
        initialValue = double.parse(_controllers['chargeInitial']!.text);
        finalValue = double.parse(_controllers['batteryFinal']!.text);
      } else {
        initialValue = double.parse(_controllers['fuel']!.text);
        finalValue = double.parse(_controllers['reservoirFinal']!.text);
      }

      final double percentage = (finalValue / initialValue) * 100;
      setState(() {
        _status = percentage >= 80
            ? 'Plein'
            : percentage <= 20
                ? 'Vide'
                : 'Moyenne';
      });
    } catch (e) {
      setState(() => _status = 'Erreur de calcul');
    }
  }

  void _calculateConsumption() {
    final km = double.tryParse(_controllers['kilometers']!.text) ?? 0;
    if (km == 0) return;

    if (_vehicleType == 'electrique') {
      final initial = double.parse(_controllers['chargeInitial']!.text);
      final finalCharge = double.parse(_controllers['batteryFinal']!.text);
      final batteryCapacity = _vehicleData['autonomie'];
      _calculatedConsumption = ((initial - finalCharge) / 100 * batteryCapacity) / km;
    } else {
      final initial = double.parse(_controllers['fuel']!.text);
      final finalFuel = double.parse(_controllers['reservoirFinal']!.text);
      _calculatedConsumption = ((initial - finalFuel) / km) * 100;
    }
  }

  Future<void> _submitValidation() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await _firestore.runTransaction((transaction) async {
        // 1. Récupérer les références des documents
        final missionRef = widget.mission.reference;
        final vehicleRef = _firestore.collection('vehicles').doc(widget.mission['vehicleId']);

        // 2. Récupérer les données actuelles
        final vehicleDoc = await transaction.get(vehicleRef);
        final currentKm = (vehicleDoc['nombreKmParcouru'] ?? 0.0).toDouble();
        final endKm = double.parse(_controllers['kilometers']!.text);

        // 3. Validation du kilométrage
        if (endKm < currentKm) {
          throw 'Erreur : Le kilométrage final ($endKm km) ne peut pas être inférieur au kilométrage actuel ($currentKm km)';
        }

        // 4. Préparation des données de mission
        final missionUpdateData = <String, dynamic>{
          'status': 'Terminée',
          'startKilometers': currentKm, // Nouveau champ: km initial
          'endKilometers': endKm,       // Nouveau champ: km final
          'deltaKilometers': endKm - currentKm, // Différence parcourue
          'validationDate': FieldValue.serverTimestamp(),
          'vehicleType': _vehicleType,
          'consumption': _calculatedConsumption,
        };

        // 5. Ajout des données énergétiques selon le type de véhicule
        if (_vehicleType == 'electrique') {
          missionUpdateData['batteryFinal'] = double.parse(_controllers['batteryFinal']!.text);
        } else {
          missionUpdateData['reservoirFinal'] = double.parse(_controllers['reservoirFinal']!.text);
        }

        // 6. Mise à jour de la mission
        transaction.update(missionRef, missionUpdateData);

        // 7. Préparation de la mise à jour du véhicule
        final vehicleUpdateData = <String, dynamic>{
          'status': 'available',
          'nombreKmParcouru': endKm, // Mise à jour directe avec la valeur finale
        };

        // 8. Mise à jour des données énergétiques
        if (_vehicleType == 'electrique') {
          vehicleUpdateData['etatCharge'] = double.parse(_controllers['batteryFinal']!.text);
        } else {
          vehicleUpdateData['niveauCarburant'] = double.parse(_controllers['reservoirFinal']!.text);
        }

        // 9. Application des modifications
        transaction.update(vehicleRef, vehicleUpdateData);
      });

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString().replaceFirst('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          )
      );
    }
  }

  Widget _buildStatusIndicator() {
    Color color = Colors.grey;
    if (_status == 'Plein') color = statusGreen;
    if (_status == 'Vide') color = statusRed;
    if (_status == 'Moyenne') color = statusOrange;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: color),
          const SizedBox(width: 10),
          Text(
            'État: $_status',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Card(
      elevation: 4,
      shadowColor: primaryColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation fin Mission'),
        backgroundColor: primaryColor,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildCard(
                      TextFormField(
                        controller: _controllers['kilometers'],
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Kilométrage finale (km)*',
                          prefixIcon: Icon(Icons.speed, color: primaryColor),
                          labelStyle: TextStyle(color: primaryColor),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: primaryColor),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
                        onChanged: (_) => _calculateConsumption(),
                      ),
                    ),
                    if (_vehicleType == 'electrique') ...[
                      _buildCard(
                        TextFormField(
                          controller: _controllers['chargeInitial'],
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Charge initiale (%)',
                            prefixIcon: Icon(Icons.battery_charging_full, color: primaryColor),
                            labelStyle: TextStyle(color: primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      _buildCard(
                        TextFormField(
                          controller: _controllers['batteryFinal'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Batterie finale (%)',
                            prefixIcon: Icon(Icons.battery_full, color: primaryColor),
                            labelStyle: TextStyle(color: primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
                          onChanged: (_) => _calculateStatus(),
                        ),
                      ),
                    ],
                    if (_vehicleType == 'thermique') ...[
                      _buildCard(
                        TextFormField(
                          controller: _controllers['fuel'],
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Capacité réservoir (L)',
                            prefixIcon: Icon(Icons.local_gas_station, color: primaryColor),
                            labelStyle: TextStyle(color: primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      _buildCard(
                        TextFormField(
                          controller: _controllers['reservoirFinal'],
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Niveau carburant (L)',
                            prefixIcon: Icon(Icons.local_gas_station, color: primaryColor),
                            labelStyle: TextStyle(color: primaryColor),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: primaryColor),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          validator: (value) => value!.isEmpty ? 'Obligatoire' : null,
                          onChanged: (_) => _calculateStatus(),
                        ),
                      ),
                    ],
                    if (_status != null) _buildStatusIndicator(),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                  icon: const Icon(
  Icons.check_circle_outline,
  color: Colors.white,
),

                    label: const Text(
  'Valider',
  style: TextStyle(color: Colors.white),
),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        textStyle: const TextStyle(fontSize: 18),
                      ),
                      onPressed: _submitValidation,
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
