import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddDriverScreen extends StatefulWidget {
  @override
  _AddDriverScreenState createState() => _AddDriverScreenState();
}

class _AddDriverScreenState extends State<AddDriverScreen> {
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _licenseTypeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _validityDateController = TextEditingController();
  final TextEditingController _observationsController = TextEditingController();

  bool? _isAvailable;

  final List<String> _availabilityOptions = ['OUI', 'NON'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ajouter un Chauffeur"),
        backgroundColor: Color(0xFF6A0DAD),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_firstNameController, "Prénom", Icons.person),
              SizedBox(height: 15),
              _buildTextField(_lastNameController, "Nom", Icons.person),
              SizedBox(height: 15),
              _buildTextField(_licenseTypeController, "Nature du permis", Icons.credit_card),
              SizedBox(height: 15),
              _buildTextField(_phoneController, "Numéro de téléphone", Icons.phone, keyboardType: TextInputType.phone),
              SizedBox(height: 15),
              _buildDateField("Date de validité", _validityDateController),
              SizedBox(height: 15),
              _buildDropdown("Disponibilité", _isAvailable, _availabilityOptions),
              SizedBox(height: 15),
              _buildTextField(_observationsController, "Observations", Icons.notes),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveDriver,
                child: Text("Enregistrer"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6A0DAD),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDateField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.calendar_today),
        border: OutlineInputBorder(),
      ),
      onTap: () async {
        FocusScope.of(context).requestFocus(FocusNode());
        DateTime? pickedDate = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          firstDate: DateTime(1900),
          lastDate: DateTime(2101),
        );
        if (pickedDate != null) {
          controller.text = "${pickedDate.day}/${pickedDate.month}/${pickedDate.year}";
        }
      },
    );
  }

  Widget _buildDropdown(String label, bool? value, List<String> items) {
    return DropdownButtonFormField<String>(
      value: value == null ? null : items[value ? 0 : 1],
      items: items.map((item) => DropdownMenuItem(
        value: item,
        child: Text(item),
      )).toList(),
      onChanged: (value) {
        setState(() {
          _isAvailable = value == 'OUI';
        });
      },
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(),
      ),
    );
  }

  Future<void> _saveDriver() async {
    try {
      await FirebaseFirestore.instance.collection('drivers').add({
        'firstName': _firstNameController.text,
        'lastName': _lastNameController.text,
        'licenseType': _licenseTypeController.text,
        'phone': _phoneController.text,
        'validityDate': _validityDateController.text,
        'availability': _isAvailable == true ? 'OUI' : 'NON',
        'observations': _observationsController.text,
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chauffeur ajouté avec succès')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
    }
  }
}
