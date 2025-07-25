import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_application_2/execute_repair_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class PlanRepairScreen extends StatefulWidget {
  @override
  _PlanRepairScreenState createState() => _PlanRepairScreenState();
}

class _PlanRepairScreenState extends State<PlanRepairScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String? _selectedVehicleId;
  String? _selectedGarageId;
  String _interventionType = 'garage';
  DateTime? _selectedDate;
  List<XFile> _images = [];
  double _estimatedCost = 0.0;

  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _costController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Planifier une réparation'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purpleAccent, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.purple.shade50],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildVehicleDropdown(),
                  SizedBox(height: 20),
                  _buildInterventionTypeSelector(),
                  SizedBox(height: 20),
                  if (_interventionType == 'garage') _buildGarageDropdown(),
                  SizedBox(height: 20),
                  _buildDescriptionField(),
                  SizedBox(height: 20),
                  _buildImageUpload(),
                  SizedBox(height: 20),
                  _buildCostField(),
                  SizedBox(height: 20),
                  _buildDatePicker(),
                  SizedBox(height: 30),
                  _buildSubmitButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('vehicles').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        return DropdownButtonFormField<String>(
          value: _selectedVehicleId,
          items: snapshot.data!.docs.map((vehicle) {
            final data = vehicle.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: vehicle.id,
              child: Text('${data['marque']} ${data['modele']} (${data['numeroImmatriculation']})'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedVehicleId = value),
          decoration: InputDecoration(
            labelText: 'Véhicule',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.directions_car),
          ),
          validator: (value) => value == null ? 'Choisissez un véhicule' : null,
        );
      },
    );
  }

  Widget _buildInterventionTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Type d\'intervention :'),
        Row(
          children: [
            Radio<String>(
              value: 'garage',
              groupValue: _interventionType,
              onChanged: (value) => setState(() => _interventionType = value!),
            ),
            Text('Garage'),
            Radio<String>(
              value: 'domicile',
              groupValue: _interventionType,
              onChanged: (value) => setState(() => _interventionType = value!),
            ),
            Text('À domicile'),
          ],
        ),
      ],
    );
  }

  Widget _buildGarageDropdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('garages').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return CircularProgressIndicator();
        
        return DropdownButtonFormField<String>(
          value: _selectedGarageId,
          items: snapshot.data!.docs.map((garage) {
            final data = garage.data() as Map<String, dynamic>;
            return DropdownMenuItem(
              value: garage.id,
              child: Text('${data['name']} - ${data['address']}'),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedGarageId = value),
          decoration: InputDecoration(
            labelText: 'Garage partenaire',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.car_repair),
          ),
          validator: (value) => _interventionType == 'garage' && value == null 
              ? 'Choisissez un garage' 
              : null,
        );
      },
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description de la panne',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.description),
      ),
      validator: (value) => value!.isEmpty ? 'Entrez une description' : null,
    );
  }

  Widget _buildImageUpload() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ajouter des photos :'),
        Wrap(
          spacing: 8,
          children: [
            ..._images.map((image) => Chip(
              label: Text(image.name),
              deleteIcon: Icon(Icons.close),
              onDeleted: () => setState(() => _images.remove(image)),
            )),
            IconButton(
              icon: Icon(Icons.add_a_photo),
              onPressed: () async {
                final images = await _picker.pickMultiImage();
                setState(() => _images.addAll(images));
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCostField() {
    return TextFormField(
      controller: _costController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: 'Coût estimé (DZD)',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.attach_money),
      ),
      validator: (value) {
        if (value!.isEmpty) return 'Entrez un coût estimé';
        if (double.tryParse(value) == null) return 'Valeur invalide';
        return null;
      },
      onChanged: (value) => _estimatedCost = double.tryParse(value) ?? 0.0,
    );
  }

  Widget _buildDatePicker() {
    return ListTile(
      title: Text(_selectedDate?.toString().split(' ')[0] ?? 'Choisir une date'),
      trailing: Icon(Icons.calendar_today),
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 365)),
        );
        if (date != null) setState(() => _selectedDate = date);
      },
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(Icons.save),
        label: Text('Planifier'),
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        ),
        onPressed: _submitRepair,
      ),
    );
  }

 Future<void> _submitRepair() async {
  if (!_formKey.currentState!.validate()) return;

  final docRef = await _firestore.collection('repairs').add({
    'vehicleId': _selectedVehicleId,
    'description': _descriptionController.text,
    'estimatedCost': _estimatedCost,
    'status': 'planned',
    'createdAt': FieldValue.serverTimestamp(),
  });

  Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      builder: (context) => ExecuteRepairScreen(repairId: docRef.id),
    ),
  );
}
}