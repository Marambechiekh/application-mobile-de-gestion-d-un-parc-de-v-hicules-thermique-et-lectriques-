import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModelFormScreen extends StatefulWidget {
  @override
  _ModelFormScreenState createState() => _ModelFormScreenState();
}

class _ModelFormScreenState extends State<ModelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  String? _selectedType = 'electrique';
  DocumentSnapshot? _existingModel;
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _secondaryColor = Color(0xFFFF7043);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final doc = ModalRoute.of(context)?.settings.arguments as DocumentSnapshot?;
    if (doc != null && _existingModel == null) {
      _existingModel = doc;
      final data = doc.data() as Map<String, dynamic>;
      _controller.text = data['nom'];
      _selectedType = data['type'];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_existingModel == null ? 'Nouveau Modèle' : 'Modifier Modèle',
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
      body: Stack(
        children: [
          // Fond semi-transparent
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          
          // Carte formulaire en bas
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.6,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    spreadRadius: 2,
                  )
                ],
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle de la carte
                      Center(
                        child: Container(
                          width: 50,
                          height: 4,
                          margin: EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      
                      _buildTypeDropdown(),
                      SizedBox(height: 20),
                      _buildNameField(),
                      SizedBox(height: 30),
                      _buildSubmitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedType,
      dropdownColor: Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
      decoration: InputDecoration(
        labelText: 'Type de véhicule',
        labelStyle: TextStyle(color: Colors.grey[600]),),
      items: [
        DropdownMenuItem(
          value: 'electrique',
          child: Row(
            children: [
              Icon(Icons.electric_bolt, color: _secondaryColor),
              SizedBox(width: 10),
              Text('Électrique',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        DropdownMenuItem(
          value: 'thermique',
          child: Row(
            children: [
              Icon(Icons.local_gas_station, color: Colors.grey[600]),
              SizedBox(width: 10),
              Text('Thermique',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
      onChanged: (value) => setState(() => _selectedType = value),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _controller,
      decoration: InputDecoration(
        labelText: 'Nom du modèle',
        prefixIcon: Icon(Icons.directions_car, color: _primaryColor),
      ),
      validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: Icon(Icons.save, color: Colors.white),
        label: Text(
          _existingModel == null ? 'ENREGISTRER' : 'MODIFIER',
          style: TextStyle(fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color.fromARGB(255, 255, 255, 255),
          padding: EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _saveModel,
      ),
    );
  }

  Future<void> _saveModel() async {
    if (_formKey.currentState!.validate()) {
      try {
        final data = {
          'nom': _controller.text,
          'type': _selectedType,
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (_existingModel == null) {
          await FirebaseFirestore.instance.collection('modeles').add(data);
          _showSnackBar('Modèle ajouté avec succès', Colors.green);
        } else {
          await _existingModel!.reference.update(data);
          _showSnackBar('Modèle modifié avec succès', Colors.green);
        }
        
        Navigator.pop(context);
        
      } catch (e) {
        _showSnackBar('Erreur: $e', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}