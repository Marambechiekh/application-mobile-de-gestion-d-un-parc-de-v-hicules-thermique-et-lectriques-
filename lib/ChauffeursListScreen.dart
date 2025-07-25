import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ChauffeurListScreen extends StatefulWidget {
  const ChauffeurListScreen({super.key});

  @override
  State<ChauffeurListScreen> createState() => _ChauffeurListScreenState();
}

class _ChauffeurListScreenState extends State<ChauffeurListScreen> {
  static const Color _primaryColor = Color(0xFF6C5CE7);
  static const Color _accentColor = Color(0xFFFF7043);
  static const Color _backgroundColor = Color(0xFFF5F5FA);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _formatDate(dynamic date) {
    if (date is Timestamp) {
      return DateFormat('dd/MM/yyyy').format(date.toDate());
    }
    return 'N/A';
  }

  pw.Row _buildPdfRow(String label, dynamic value) {
    return pw.Row(
      children: [
        pw.Expanded(
            flex: 2,
            child: pw.Text("$label:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        pw.Expanded(flex: 3, child: pw.Text(value?.toString() ?? 'N/A')),
      ],
    );
  }

  pw.Widget _buildPdfSection(String title, List<pw.Widget> children) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        ...children,
        pw.SizedBox(height: 10),
      ],
    );
  }

  Future<void> _generateSinglePdf(Map<String, dynamic> chauffeur) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Fiche Chauffeur",
                style: pw.TextStyle(
                    fontSize: 24,
                    color: PdfColor.fromInt(_primaryColor.value),
                    fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 20),
            _buildPdfSection("Informations personnelles", [
              _buildPdfRow("Nom", chauffeur['name']),
              _buildPdfRow("CIN", chauffeur['cin']),
              _buildPdfRow("Date de naissance", _formatDate(chauffeur['date_naissance'])),
            ]),
            _buildPdfSection("Coordonnées", [
              _buildPdfRow("Téléphone", chauffeur['phone']),
              _buildPdfRow("Adresse", chauffeur['adresse']),
            ]),
            _buildPdfSection("Professionnelles", [
              _buildPdfRow("Permis", chauffeur['permis_type']),
              _buildPdfRow("Expérience", chauffeur['experience']),
              _buildPdfRow("Disponibilité", chauffeur['disponibilite']),
            ]),
          ],
        ),
      ),
    );
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'chauffeur_${chauffeur['name']}.pdf');
  }

  Future<void> _generateAllPdf(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Fiche Chauffeur",
                  style: pw.TextStyle(
                      fontSize: 24,
                      color: PdfColor.fromInt(_primaryColor.value),
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              _buildPdfSection("Informations personnelles", [
                _buildPdfRow("Nom", data['name']),
                _buildPdfRow("CIN", data['cin']),
                _buildPdfRow("Date de naissance", _formatDate(data['date_naissance'])),
              ]),
              _buildPdfSection("Coordonnées", [
                _buildPdfRow("Téléphone", data['phone']),
                _buildPdfRow("Adresse", data['adresse']),
              ]),
              _buildPdfSection("Professionnelles", [
                _buildPdfRow("Permis", data['permis_type']),
                _buildPdfRow("Expérience", data['experience']),
                _buildPdfRow("Disponibilité", data['disponibilite']),
              ]),
            ],
          ),
        ),
      );
    }
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'chauffeurs_liste.pdf');
  }

  List<QueryDocumentSnapshot> _filterChauffeurs(List<QueryDocumentSnapshot> docs, String query) {
    if (query.isEmpty) return docs;
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['name'].toString().toLowerCase().contains(query.toLowerCase()) ||
          data['phone'].toString().contains(query) ||
          data['permis_type'].toString().toLowerCase().contains(query.toLowerCase()) ||
          data['adresse'].toString().toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text("Chauffeurs"),
        backgroundColor: _primaryColor,
        elevation: 4,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'Chauffeur')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Erreur de chargement"));
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                final filtered = _filterChauffeurs(docs, _searchQuery);
                if (filtered.isEmpty) return const Center(child: Text("Aucun résultat"));
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: _primaryColor.withOpacity(0.2),
                          child: const Icon(Icons.person, color: _primaryColor),
                        ),
                        title: Text(data['name'] ?? '',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Téléphone : ${data['phone'] ?? 'N/A'}"),
                            Text("Permis : ${data['permis_type'] ?? 'N/A'}"),
                            Text("Adresse : ${data['adresse'] ?? 'N/A'}"),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.picture_as_pdf, color: _accentColor),
                          onPressed: () => _generateSinglePdf(data),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'Chauffeur')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox();
          return FloatingActionButton.extended(
            backgroundColor: _primaryColor,
            icon: const Icon(Icons.download),
            label: const Text("Exporter tout"),
            onPressed: () => _generateAllPdf(snapshot.data!.docs),
          );
        },
      ),
    );
  }
}