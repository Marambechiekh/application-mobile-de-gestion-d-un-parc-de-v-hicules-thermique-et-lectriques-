import 'package:flutter/material.dart';

class EcranGestionMaintenance extends StatelessWidget {
static const Color primaryColor = Color(0xFFE70013);
static const Color secondaryColor = Color(0xFFFFFFFF);
static const Color _secondaryColor = Color(0xFF00BFA5);
static const Color _primaryColor = Color(0xFF6C5CE7);

  const EcranGestionMaintenance({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Maintenance',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
          child: Column(
            children: [
              _buildCarteAction(
                context,
                'Gestion Réparations',
                Icons.build_rounded,
                '/repair2',
              ),
              const SizedBox(height: 20),
              _buildCarteAction(
                context,
                'Gestion Entretiens',
                Icons.engineering_rounded,
                '/entre',
              ),
            ],
          ),
        ),
      ),
    
    );
  }

  Widget _buildCarteAction(BuildContext context, String titre, IconData icone, String route) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pushNamed(context, route),
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
                child: Icon(icone, size: 30, color: _primaryColor),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(titre,
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

}