import 'package:flutter/material.dart';

class TableauBordGestionEquipes extends StatelessWidget {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _secondaryColor = Color(0xFF00BFA5);

  const TableauBordGestionEquipes({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(' Liste et Suivi des Chauffeurs',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
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
        child: Center( // Centre le contenu principal
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement
              children: [
                // Premier bouton centré
                Center(
                  child: _buildCarteAction(
                    context,
                    'Liste des Chauffeurs',
                    Icons.people_alt_rounded,
                    '/ch',
                  ),
                ),
                const SizedBox(height: 20),
                
                // Deuxième bouton centré
                Center(
                  child: _buildCarteAction(
                    context,
                    'Suivi de disponibilité',
                    Icons.schedule_rounded,
                    '/admin',
                  ),
                ),
                const SizedBox(height: 20),
                
              
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarteAction(BuildContext context, String titre, IconData icone, String route) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400), // Limite la largeur
      child: Card(
        elevation: 4,
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
  child: Text(
    titre,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: _primaryColor,
    ),
    maxLines: 1, // ← force une seule ligne
    overflow: TextOverflow.ellipsis, // ← coupe proprement si trop long
  ),
),

                Icon(Icons.arrow_forward_ios_rounded,
                    color: _primaryColor.withOpacity(0.5), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}