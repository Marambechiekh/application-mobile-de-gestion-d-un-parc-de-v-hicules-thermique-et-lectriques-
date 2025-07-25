import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditVehicleScreen extends StatefulWidget {
  final String vehicleId;
  const EditVehicleScreen({Key? key, required this.vehicleId}) : super(key: key);

  @override
  _EditVehicleScreenState createState() => _EditVehicleScreenState();
}

class _EditVehicleScreenState extends State<EditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, TextEditingController> _controllers = {
    'annee': TextEditingController(),
    'numeroImmatriculation': TextEditingController(),
    'nombrePlaces': TextEditingController(),
    'puissance': TextEditingController(),
    'coutAcquisition': TextEditingController(),
    'numeroChassis': TextEditingController(),
    'nombreKmParcouru': TextEditingController(),
    'amortissementParAnnee': TextEditingController(),
    'typeCarburant': TextEditingController(),
    'capaciteReservoirCarburant': TextEditingController(),
    'consommationCarburant': TextEditingController(),
    'capaciteBatterie': TextEditingController(),
    'autonomie': TextEditingController(),
    'etatCharge': TextEditingController(),
  };

  final Color _primaryColor = Color(0xFF6C5CE7);
  final Color _backgroundColor = Color(0xFFF8F9FA);

  String? _vehicleType;
  bool _isLoading = true;
  List<String> _modelsList = [];
  List<String> _brandsList = [];
  String? _selectedModel;
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    _loadVehicleData();
  }

  Future<void> _loadVehicleData() async {
    try {
      final doc = await _firestore.collection('vehicles').doc(widget.vehicleId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _vehicleType = data['type'];
          _selectedModel = data['modele'];
          _selectedBrand = data['marque'];
          _controllers.forEach((key, controller) {
            if (data.containsKey(key)) controller.text = data[key]?.toString() ?? '';
          });
          _isLoading = false;
        });
        _fetchData();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: $e')));
      Navigator.pop(context);
    }
  }

  Future<void> _fetchData() async {
    if (_vehicleType != null) {
      final models = await _firestore.collection('modeles')
          .where('type', isEqualTo: _vehicleType).get();
      final brands = await _firestore.collection('brands')
          .where('type', isEqualTo: _vehicleType).get();

      setState(() {
        _modelsList = models.docs.map((d) => d['nom'].toString()).toList();
        _brandsList = brands.docs.map((d) => d['name'].toString()).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Véhicule', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: _primaryColor))
          : Container(
              color: _backgroundColor,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDropdown(
                          'Type de véhicule',
                          _vehicleType,
                          ['electrique', 'thermique'],
                          (value) => setState(() {
                            _vehicleType = value;
                            _selectedModel = null;
                            _selectedBrand = null;
                            _fetchData();
                          }),
                          icon: Icons.directions_car,
                        ),
                        SizedBox(height: 20),
                        _buildBrandDropdown(),
                        SizedBox(height: 20),
                        _buildModelDropdown(),
                        SizedBox(height: 20),
                        _buildNumberField('annee', 'Année', Icons.calendar_today),
                        SizedBox(height: 20),
                        _buildTextField('numeroImmatriculation', 'Immatriculation', Icons.directions_car),
                        SizedBox(height: 20),
                        _buildNumberField('nombrePlaces', 'Places', Icons.chair),
                        SizedBox(height: 20),
                        _buildNumberField('puissance', 'Puissance (ch)', Icons.electric_bolt),
                        SizedBox(height: 20),
                        _buildNumberField('coutAcquisition', 'Coût (€)', Icons.euro, isDouble: true),
                        SizedBox(height: 20),
                        _buildTextField('numeroChassis', 'Châssis', Icons.confirmation_number),
                        SizedBox(height: 20),
                        _buildNumberField('nombreKmParcouru', 'Kilométrage', Icons.speed, isDouble: true),
                        SizedBox(height: 20),
                        _buildNumberField('amortissementParAnnee', 'Amortissement/an', Icons.trending_down, isDouble: true),
                        SizedBox(height: 20),
                        if (_vehicleType == 'thermique') ..._buildThermicFields(),
                        if (_vehicleType == 'electrique') ..._buildElectricFields(),
                        SizedBox(height: 30),
                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _updateVehicle,
                            label: Text('MODIFIER', style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 60, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                     ) ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  // Méthodes communes avec AddVehicleScreen
  Widget _buildNumberField(String field, String label, IconData icon, {bool isDouble = false}) {
    return TextFormField(
      controller: _controllers[field],
      keyboardType: TextInputType.numberWithOptions(decimal: isDouble),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(),
      ),
      validator: (v) => v!.isEmpty ? 'Requis' : (isDouble ? double.tryParse(v) : int.tryParse(v)) == null ? 'Nombre invalide' : null,
    );
  }

  Widget _buildTextField(String field, String label, IconData icon) {
    return TextFormField(
      controller: _controllers[field],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _primaryColor),
        border: OutlineInputBorder(),
      ),
      validator: (v) => v!.isEmpty ? 'Requis' : null,
    );
  }

  List<Widget> _buildThermicFields() {
    return [
      SizedBox(height: 20),
      _buildDropdown('Carburant', _controllers['typeCarburant']!.text, ['Diesel', 'Essence'],
        (v) => _controllers['typeCarburant']!.text = v!),
         SizedBox(height: 20),
      _buildNumberField('capaciteReservoirCarburant', 'Capacité réservoir (L)', Icons.local_gas_station, isDouble: true),
      SizedBox(height: 20),
      _buildNumberField('consommationCarburant', 'Consommation (L/100km)', Icons.speed, isDouble: true),
    ];
  }

  List<Widget> _buildElectricFields() {
    return [
      SizedBox(height: 20),
      _buildNumberField('capaciteBatterie', 'Capacité batterie (kWh)', Icons.battery_charging_full, isDouble: true),
      SizedBox(height: 20),
      _buildNumberField('autonomie', 'Autonomie (km)', Icons.ev_station, isDouble: true),
      SizedBox(height: 20),
      _buildNumberField('etatCharge', 'Charge (%)', Icons.battery_full, isDouble: true),
    ];
  }

  Widget _buildDropdown(String label, String? value, List<String> items, Function(String?) onChanged, {IconData? icon}) {
    return DropdownButtonFormField<String>(
      value: value?.isEmpty ?? true ? null : value,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon, color: _primaryColor) : null,
        border: OutlineInputBorder(),
      ),
      validator: (v) => v == null ? 'Sélection requis' : null,
    );
  }

  Widget _buildBrandDropdown() {
    return _buildDropdown('Marque', _selectedBrand, _brandsList, (v) => setState(() {
      _selectedBrand = v;
    }), icon: Icons.branding_watermark);
  }

  Widget _buildModelDropdown() {
    return _buildDropdown('Modèle', _selectedModel, _modelsList, (v) => setState(() {
      _selectedModel = v;
    }), icon: Icons.car_repair);
  }

  Future<void> _updateVehicle() async {
    if (_formKey.currentState!.validate()) {
      try {
        final updateData = {
          'type': _vehicleType,
          'marque': _selectedBrand,
          'modele': _selectedModel,
          'annee': int.tryParse(_controllers['annee']!.text) ?? 0,
          'numeroImmatriculation': _controllers['numeroImmatriculation']!.text,
          'nombrePlaces': int.tryParse(_controllers['nombrePlaces']!.text) ?? 0,
          'puissance': int.tryParse(_controllers['puissance']!.text) ?? 0,
          'coutAcquisition': double.tryParse(_controllers['coutAcquisition']!.text) ?? 0.0,
          'numeroChassis': _controllers['numeroChassis']!.text,
          'nombreKmParcouru': double.tryParse(_controllers['nombreKmParcouru']!.text) ?? 0.0,
          'amortissementParAnnee': double.tryParse(_controllers['amortissementParAnnee']!.text) ?? 0.0,
          if (_vehicleType == 'thermique') ...{
            'typeCarburant': _controllers['typeCarburant']!.text,
            'capaciteReservoirCarburant': double.tryParse(_controllers['capaciteReservoirCarburant']!.text) ?? 0.0,
            'consommationCarburant': double.tryParse(_controllers['consommationCarburant']!.text) ?? 0.0,
          },
          if (_vehicleType == 'electrique') ...{
            'capaciteBatterie': double.tryParse(_controllers['capaciteBatterie']!.text) ?? 0.0,
            'autonomie': double.tryParse(_controllers['autonomie']!.text) ?? 0.0,
            'etatCharge': double.tryParse(_controllers['etatCharge']!.text) ?? 0.0,
          }
        };

        await _firestore.collection('vehicles').doc(widget.vehicleId).update(updateData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modifications enregistrées avec succès'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur : ${e.toString()}"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _controllers.values.forEach((c) => c.dispose());
    super.dispose();
  }
}