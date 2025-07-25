import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // Correction 1: Ajout de l'import manquant

class DriverDetailScreen extends StatelessWidget {
  final String driverId;

  const DriverDetailScreen({super.key, required this.driverId});

  Future<void> _generatePdf(BuildContext context, Map<String, dynamic> data) async {
    final pdf = pw.Document();
    // Correction 2: Utilisation correcte de DateFormat avec conversion Timestamp
    final formattedDate = data['date_naissance'] != null 
        ? DateFormat('dd/MM/yyyy').format((data['date_naissance'] as Timestamp).toDate())
        : 'Non spécifiée';

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(20),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text('FICHE CHAUFFEUR', 
                    style: pw.TextStyle( // Correction 3: Style corrigé
                      fontSize: 24, 
                      fontWeight: pw.FontWeight.bold
                    )
                  ),
                ),
                pw.SizedBox(height: 30),
                // Correction 4: Syntaxe corrigée pour les lignes PDF
                _buildPdfRow('Nom complet', '${_safeString(data['name'])} ${_safeString(data['prenom'])}'),
                _buildPdfRow('Email', _safeString(data['email'])),
                _buildPdfRow('Téléphone', _safeString(data['phone'])),
                _buildPdfRow('CIN', _safeString(data['cin'])),
                _buildPdfRow('Adresse', _safeString(data['adresse'])),
                _buildPdfRow('Expérience', _safeString(data['experience'])),
                _buildPdfRow('Date de naissance', formattedDate),
                _buildPdfRow('Permis', _safeString(data['permis_type'])),
                _buildPdfRow('Validité permis', 
                  data['validite'] != null 
                    ? DateFormat('dd/MM/yyyy').format((data['validite'] as Timestamp).toDate())
                    : 'Non spécifiée'),
                pw.SizedBox(height: 20),
                pw.Text('Observations :', 
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(_safeString(data['observations'])),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }
pw.Widget _buildPdfRow(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Row(
      children: [
        pw.Expanded(
          flex: 2,
          child: pw.Text(
            '$label :',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Expanded(
          flex: 3,
          child: pw.Text(value),
        ),
      ],
    ),
  );
}

  String _safeString(dynamic value) {
    return value?.toString().trim() ?? 'Non spécifié';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Chauffeur'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () async {
              final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(driverId)
                .get();
              
              if (doc.exists) {
                await _generatePdf(context, doc.data()!);
              }
            },
          )
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
          .collection('users')
          .doc(driverId)
          .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Chauffeur introuvable'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          // Correction 5: Conversion correcte des dates
          final dateNaissance = data['date_naissance'] != null 
              ? DateFormat('dd/MM/yyyy').format((data['date_naissance'] as Timestamp).toDate())
              : 'Non spécifiée';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Nom complet', '${data['name']} ${data['prenom']}'),
                _buildInfoRow('Email', data['email']),
                _buildInfoRow('Téléphone', data['phone']),
                _buildInfoRow('CIN', data['cin']),
                _buildInfoRow('Adresse', data['adresse']),
                _buildInfoRow('Expérience', data['experience']),
                _buildInfoRow('Date de naissance', dateNaissance),
                _buildInfoRow('Type de permis', data['permis_type']),
                _buildInfoRow('Validité permis', 
                  data['validite'] != null 
                    ? DateFormat('dd/MM/yyyy').format((data['validite'] as Timestamp).toDate())
                    : 'Non spécifiée'),
                const SizedBox(height: 20),
                const Text('Observations :', 
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(data['observations']?.toString() ?? 'Aucune observation'),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text('$label :',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16
              )
            )
          ),
          Expanded(
            flex: 3,
            child: Text(value?.toString() ?? 'Non spécifié',
              style: const TextStyle(fontSize: 16)
            )
          ),
        ],
      ),
    );
  }
}