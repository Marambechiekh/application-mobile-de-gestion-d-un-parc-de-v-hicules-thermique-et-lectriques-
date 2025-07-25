import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _primaryColor = Color(0xFF6C5CE7);

class AddUserScreen extends StatefulWidget {
  @override
  _AddUserScreenState createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _prenomController = TextEditingController();
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
  bool _showManualPassword = false;
  final List<String> _roles = ["Responsable de parc", "Chauffeur"];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _dateErrorText;
String? _validateCIN(String? value) {
  if (value == null || value.isEmpty) {
    return "Le CIN est obligatoire";
  } else if (value.length != 8) {
    return "Le CIN doit contenir exactement 8 chiffres";
  } else if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
    return "Le CIN doit contenir uniquement des chiffres";
  }
  return null;
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

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'prenom': _prenomController.text.trim(),
        'email': _emailController.text.trim(),
        'role': _selectedRole,
        'uid': userCredential.user!.uid,
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
          'disponibilite': _disponibiliteController.text.trim(),
          'date_naissance': _dateNaissance,
              'disponibilites': [],
        });
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(userData);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: _primaryColor,
        content: const Text("Utilisateur ajouté avec succès",
            style: TextStyle(color: Colors.white)),
      ));
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      if (e.code == 'email-already-in-use') {
        errorMessage = "Cette adresse email est déjà utilisée.";
      } else if (e.code == 'invalid-email') {
        errorMessage = "L'adresse email est invalide.";
      } else if (e.code == 'weak-password') {
        errorMessage = "Le mot de passe est trop faible (minimum 6 caractères).";
      } else {
        errorMessage = "Erreur : ${e.message}";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Erreur : $e")));
    }
  }

  InputDecoration _inputDecoration(String label, {bool isRequired = false}) {
    return InputDecoration(
      labelText: isRequired ? "$label *" : label,
      filled: true,
      fillColor: Colors.white,
      floatingLabelStyle: TextStyle(color: _primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _primaryColor.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor.withOpacity(0.3))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryColor, width: 2)),
      contentPadding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  String? _validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return "Ce champ est obligatoire";
    }
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return "L'email est obligatoire";
    } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return "Entrez une adresse email valide";
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return "Le mot de passe est obligatoire";
    } else if (value.length < 6) {
      return "Le mot de passe doit contenir au moins 6 caractères";
    }
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return "Le téléphone est obligatoire";
    } else if (!RegExp(r'^[0-9]{8,11}$').hasMatch(value)) {
      return "Entrez un numéro de téléphone valide";
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ajouter un utilisateur",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildInputField(_nameController, "Nom complet", true),
                  SizedBox(height: 20),
                  _buildInputField(_emailController, "Adresse email", true, 
                    TextInputType.emailAddress, _validateEmail),
                  SizedBox(height: 20),
                  _buildRoleSelector(),
                  if (_selectedRole == "Chauffeur") ...[
                    SizedBox(height: 30),
                    _buildDriverFormSection(),
                  ],
                  SizedBox(height: 30),
                  _buildPasswordSection(),
                  SizedBox(height: 40),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(
    TextEditingController controller, 
    String label, 
    bool isRequired, [
    TextInputType? type,
    String? Function(String?)? validator,
  ]) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(label, isRequired: isRequired),
      keyboardType: type,
      validator: validator ?? (value) => isRequired ? _validateRequired(value, label) : null,
    );
  }

  Widget _buildRoleSelector() {
    return Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          border: Border.all(color: _primaryColor.withOpacity(0.3))),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedRole,
          style: TextStyle(color: _primaryColor, fontSize: 16),
          dropdownColor: Colors.white,
          onChanged: (String? newValue) =>
              setState(() => _selectedRole = newValue!),
          items: _roles
              .map((role) => DropdownMenuItem(
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
          ))
              .toList(),
        ),
      ),
    );
  }

 Widget _buildDriverFormSection() {
  return Column(
    children: [
      _buildInputField(_permisController, "Nature du permis", true),
      SizedBox(height: 20),
      _buildInputField(_phoneController, "Téléphone", true, 
        TextInputType.phone, _validatePhone),
      SizedBox(height: 20),
      _buildDatePicker("Date de validité du permis", false, true),
      SizedBox(height: 20),
      _buildDatePicker("Date de naissance", true, true),
      SizedBox(height: 20),
      TextFormField(
        controller: _cinController,
        decoration: _inputDecoration("Numéro CIN", isRequired: true),
        keyboardType: TextInputType.number,
        maxLength: 8,
        validator: _validateCIN, 
      ),
      SizedBox(height: 20),
      _buildInputField(_adresseController, "Adresse", true),
      SizedBox(height: 20),
      _buildInputField(_experienceController, "Expérience", true),

      SizedBox(height: 20),
      TextFormField(
        controller: _observationController,
        decoration: _inputDecoration("Observations").copyWith(
            contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20)),
        maxLines: 3,
      ),
    ],
  );
}


  Widget _buildDatePicker(String label, bool isBirthDate, bool isRequired) {
    return InkWell(
      onTap: () => _selectDate(context, isBirthDate),
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: _inputDecoration(label, isRequired: isRequired).copyWith(
          errorText: isRequired && 
                    ((isBirthDate && _dateNaissance == null) || 
                     (!isBirthDate && _validiteDate == null))
            ? "Ce champ est obligatoire"
            : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isBirthDate
                  ? (_dateNaissance != null
                  ? "${_dateNaissance!.day}/${_dateNaissance!.month}/${_dateNaissance!.year}"
                  : "Sélectionner une date")
                  : (_validiteDate != null
                  ? "${_validiteDate!.day}/${_validiteDate!.month}/${_validiteDate!.year}"
                  : "Sélectionner une date"),
              style: TextStyle(color: Colors.grey[600]),
            ),
            Icon(Icons.calendar_month_rounded, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordSection() {
    return TextFormField(
      controller: _passwordController,
      obscureText: !_showManualPassword,
      decoration: _inputDecoration("Mot de passe", isRequired: true).copyWith(
        suffixIcon: IconButton(
            icon: Icon(
                _showManualPassword ? Icons.visibility : Icons.visibility_off,
                color: _primaryColor),
            onPressed: () => setState(() => _showManualPassword = !_showManualPassword)),
      ),
      validator: _validatePassword,
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _addUser,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: _primaryColor.withOpacity(0.2))),
            ),
            child: Text("ENREGISTRER",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8)),
          ),
        ),
      ],
    );
  }
}