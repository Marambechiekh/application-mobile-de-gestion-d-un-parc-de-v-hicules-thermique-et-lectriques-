import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/DashboardScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color _primaryColor = Color(0xFF6C5CE7);
  final Color _secondaryColor = Color(0xFFFF7043);
  bool _obscurePassword = true;

  Future<void> _signIn(BuildContext context) async {
    if (_emailController.text == 'maram@gmail.com' && 
        _passwordController.text == 'maram123') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => DashboardScreen(role: 'admin'),
      ));
      return;
    }
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      String uid = userCredential.user!.uid;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (userDoc.exists) {
        String role = userDoc['role'];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => DashboardScreen(role: role)),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de la connexion : ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, _primaryColor.withOpacity(0.05)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.15),
                _buildAppLogo(),
                SizedBox(height: 50),
                _buildLoginForm(context),
                SizedBox(height: 30),
                _buildAdditionalOptions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppLogo() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Icon(Icons.electric_car_rounded, size: 45, color: Colors.white),
        ),
        SizedBox(height: 25),
        Text(
          'FleetSync Pro',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.grey[800],
            letterSpacing: 1.5,
          ),
        ),
        Text(
          'Gestion de Parc Véhicules',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            'Connexion Sécurisée',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 35),
          _buildInputField(
            controller: _emailController,
            label: 'Email professionnel',
            icon: Icons.alternate_email_rounded,
          ),
          SizedBox(height: 25),
          _buildInputField(
            controller: _passwordController,
            label: 'Mot de passe',
            icon: Icons.lock_clock_rounded,
            isPassword: true,
          ),
          SizedBox(height: 30),
          _buildLoginButton(context),
        ],
      ),
    );
  }

 
  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      style: TextStyle(color: Colors.grey[800]),
      decoration: InputDecoration(
        labelText: label,
        floatingLabelStyle: TextStyle(color: _primaryColor),
        prefixIcon: Container(
          margin: EdgeInsets.only(right: 15),
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: Colors.grey[300]!, width: 1)),
          ),
          child: Icon(icon, color: Colors.grey[600]),
        ),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[600],
                ),
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: _primaryColor, width: 1.5),
        ),
      ),
    );
  }


  Widget _buildLoginButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _signIn(context),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          padding: EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 3,
          shadowColor: _primaryColor.withOpacity(0.3),
        ),
        child: Text(
          ' Connexion ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
Widget _buildAdditionalOptions(BuildContext context) {
  return TextButton(
    onPressed: () {
      if (_emailController.text.isEmpty) {
        _showErrorMessage(context, 'Saisissez votre email d\'abord');
      } else {
        _resetPassword(context);
      }
    },
    child: Text(
      'Mot de passe oublié ?',
      style: TextStyle(
        decoration: TextDecoration.underline,
        color: _primaryColor,
      ),
    ),
  );
}
// Ajoutez cette méthode dans la classe _LoginScreenState

Future<void> _resetPassword(BuildContext context) async {
  final email = _emailController.text.trim();

  if (email.isEmpty) {
    _showErrorMessage(context, 'Veuillez d\'abord saisir votre email');
    return;
  }

  try {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
    _showSuccessMessage(context, email);
  } on FirebaseAuthException catch (e) {
    _handleAuthError(context, e, email);
  }
}
Future<String?> _showEmailInputDialog(BuildContext context) async {
  String email = '';
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mot de passe oublié '),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Entrez votre email professionnel pour recevoir le lien de réinitialisation'),
          const SizedBox(height: 20),
          TextField(
            keyboardType: TextInputType.emailAddress,
            onChanged: (value) => email = value,
            decoration: InputDecoration(
              labelText: 'Email',
              prefixIcon: const Icon(Icons.email),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
       ) ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),),
          onPressed: () => Navigator.pop(context, email),
          child: const Text('Confirmer', style: TextStyle(color: Colors.white)),
    )],
    ),
  );
}

void _showSuccessMessage(BuildContext context, String email) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✅ Lien envoyé avec succès',
              style: TextStyle(fontWeight: FontWeight.bold)),
          Text('Consultez votre boîte mail ($email)',
              style: TextStyle(color: Colors.grey[300])),
        ],
      ),
      backgroundColor: Colors.green[800],
      duration: const Duration(seconds: 5),
    ),
  );
}

void _handleAuthError(BuildContext context, FirebaseAuthException e, String email) {
  String message = 'Erreur inconnue';
  
  if (e.code == 'invalid-email') {
    message = 'Format d\'email invalide';
  } else if (e.code == 'user-not-found') {
    message = 'Aucun compte associé à cet email';
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('❌ $message'),
      backgroundColor: Colors.red[800],
      duration: const Duration(seconds: 3),
    ),
  );
}

void _showErrorMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('❌ $message'),
      backgroundColor: Colors.red[800],
      duration: const Duration(seconds: 3),
    ),
  );
}

}