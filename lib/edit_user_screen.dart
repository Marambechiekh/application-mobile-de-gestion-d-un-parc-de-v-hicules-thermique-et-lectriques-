import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const Color _primaryColor = Color(0xFF6C5CE7);

class EditUserScreen extends StatefulWidget {
  final String userId;

  EditUserScreen({required this.userId});

  @override
  _EditUserScreenState createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final TextEditingController _permisController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();
  final TextEditingController _cinController = TextEditingController();
  final TextEditingController _adresseController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _disponibiliteController = TextEditingController();

  DateTime? _validiteDate;
  DateTime? _dateNaissance;
  String _selectedRole = "Responsable de parc";
  final List<String> _roles = ["Responsable de parc", "Chauffeur"];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    DocumentSnapshot userDoc =
        await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
    if (userDoc.exists) {
      setState(() {
        _nameController.text = userDoc['name'];
        _emailController.text = userDoc['email'];
   
        _selectedRole = userDoc['role'];

        if (_selectedRole == "Chauffeur") {
          _permisController.text = userDoc['permis_type'] ?? '';
          _phoneController.text = userDoc['phone'] ?? '';
          _validiteDate = userDoc['validite']?.toDate();
          _cinController.text = userDoc['cin'] ?? '';
          _adresseController.text = userDoc['adresse'] ?? '';
          _experienceController.text = userDoc['experience'] ?? '';
          _observationController.text = userDoc['observations'] ?? '';
          _dateNaissance = userDoc['date_naissance']?.toDate();
          _disponibiliteController.text = userDoc['disponibilite'] ?? '';
        }
      });
    }
  }

  Future<void> _updateUser() async {
    Map<String, dynamic> userData = {
      'name': _nameController.text.trim(),
 
      'email': _emailController.text.trim(),
      'role': _selectedRole,
    };

    if (_selectedRole == "Chauffeur") {
      userData.addAll({
        'permis_type': _permisController.text.trim(),
        'phone': _phoneController.text.trim(),
        'validite': _validiteDate,
        'observations': _observationController.text.trim(),
        'cin': _cinController.text.trim(),
        'adresse': _adresseController.text.trim(),
        'experience': _experienceController.text.trim(),
        'date_naissance': _dateNaissance,
        'disponibilite': _disponibiliteController.text.trim(),
      });
    }

    await FirebaseFirestore.instance.collection('users').doc(widget.userId).update(userData);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _primaryColor,
        content: const Text("Utilisateur mis à jour avec succès", style: TextStyle(color: Colors.white)),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> _selectDate(BuildContext context, bool isBirthDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isBirthDate) {
          _dateNaissance = picked;
        } else {
          _validiteDate = picked;
        }
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
      floatingLabelStyle: TextStyle(color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor, width: 2)),
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  Widget _buildInputField(TextEditingController controller, String label, [TextInputType? type]) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label),
      keyboardType: type,
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        border: Border.all(color: _primaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedRole,
          style: TextStyle(color: _primaryColor, fontSize: 16),
          dropdownColor: Colors.white,
          onChanged: (String? newValue) => setState(() => _selectedRole = newValue!),
          items: _roles.map((role) => DropdownMenuItem(
            value: role,
            child: Row(
              children: [
                Icon(
                  role == "Responsable de parc" 
                    ? Icons.directions_car
                    : Icons.person,
                  color: _primaryColor,
                  size: 20,
                ),
                SizedBox(width: 12),
                Text(role, style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, bool isBirthDate) {
    return InkWell(
      onTap: () => _selectDate(context, isBirthDate),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBirthDate 
                ? _dateNaissance != null 
                    ? DateFormat('dd/MM/yyyy').format(_dateNaissance!)
                    : "Sélectionner une date"
                : _validiteDate != null 
                    ? DateFormat('dd/MM/yyyy').format(_validiteDate!)
                    : "Sélectionner une date",
              style: TextStyle(color: Colors.grey[600]),
            ),
            Icon(Icons.calendar_month_rounded, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Modifier l'utilisateur", 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      ),
      body: Container(
        color: Colors.white,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildInputField(_nameController, "Nom complet"),
                SizedBox(height: 20),
               
                _buildInputField(_emailController, "Adresse email", TextInputType.emailAddress),
                SizedBox(height: 20),
                _buildRoleSelector(),
                
                if (_selectedRole == "Chauffeur") ...[
                  SizedBox(height: 30),
                  _buildInputField(_permisController, "Nature du permis"),
                  SizedBox(height: 20),
                  _buildInputField(_phoneController, "Téléphone", TextInputType.phone),
                  SizedBox(height: 20),
                  _buildDatePicker("Date de validité du permis", false),
                  SizedBox(height: 20),
                  _buildDatePicker("Date de naissance", true),
                  SizedBox(height: 20),
                  _buildInputField(_cinController, "Numéro CIN"),
                  SizedBox(height: 20),
                  _buildInputField(_adresseController, "Adresse"),
                  SizedBox(height: 20),
                  _buildInputField(_experienceController, "Expérience"),
                  SizedBox(height: 20),
                  _buildInputField(_disponibiliteController, "Disponibilité"),
                  SizedBox(height: 20),
                  TextFormField(
                    controller: _observationController,
                    decoration: _inputDecoration("Observations").copyWith(
                      contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20)),
                    maxLines: 3,
                  ),
                ],
                
                SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _updateUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: _primaryColor.withOpacity(0.2))),
                    ),
                    child: Text("MODIFIER", 
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}