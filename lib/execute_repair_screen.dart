import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ExecuteRepairScreen extends StatefulWidget {
  final String repairId;
  const ExecuteRepairScreen({Key? key, required this.repairId}) : super(key: key);

  @override
  _ExecuteRepairScreenState createState() => _ExecuteRepairScreenState();
}

class _ExecuteRepairScreenState extends State<ExecuteRepairScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  List<String> _selectedParts = [];
  double _laborCost = 0.0;
  Map<String, dynamic>? _repairData;
  Map<String, dynamic>? _vehicleData;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final repairDoc = await _firestore.collection('repairs').doc(widget.repairId).get();
    final vehicleDoc = await _firestore.collection('vehicles').doc(repairDoc['vehicleId']).get();
    setState(() {
      _repairData = repairDoc.data();
      _vehicleData = vehicleDoc.data();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exécuter la réparation')),
      body: _repairData == null 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetail('Véhicule', _vehicleData?['marque']),
                  _buildDetail('Immatriculation', _vehicleData?['numeroImmatriculation']),
                  _buildDetail('Type', _repairData?['interventionType']),
                  _buildDetail('Description', _repairData?['description']),
                  const SizedBox(height: 20),
                  _buildPartsSection(),
                  const SizedBox(height: 20),
                  _buildCostSection(),
                  const SizedBox(height: 40),
                  _buildFinalizeButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildDetail(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text('$label :', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value?.toString() ?? 'Non spécifié')),
        ],
      ),
    );
  }

  Widget _buildPartsSection() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('parts').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const CircularProgressIndicator();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pièces utilisées :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ...snapshot.data!.docs.map((doc) => CheckboxListTile(
              title: Text(doc['name']),
              value: _selectedParts.contains(doc.id),
              onChanged: (value) => setState(() => value! 
                  ? _selectedParts.add(doc.id) 
                  : _selectedParts.remove(doc.id)),
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildCostSection() {
    final estimatedCost = (_repairData?['estimatedCost'] as double?) ?? 0.0;
    final total = estimatedCost + _laborCost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Coûts :', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        TextFormField(
          decoration: const InputDecoration(labelText: 'Main d\'œuvre (DZD)'),
          keyboardType: TextInputType.number,
          onChanged: (value) => setState(() => _laborCost = double.tryParse(value) ?? 0.0),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Total :', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('${total.toStringAsFixed(2)} DZD', style: const TextStyle(color: Colors.green)),
          ],
        ),
      ],
    );
  }

  Widget _buildFinalizeButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.check),
        label: const Text('Finaliser la réparation'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15)),
        onPressed: _finalizeRepair,
      ),
    );
  }

  Future<void> _finalizeRepair() async {
    try {
      final pdf = pw.Document();
      pdf.addPage(pw.Page(
        build: (context) => pw.Column(
          children: [
            pw.Text('Rapport #${widget.repairId}', style: const pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 20),
            pw.Text('Pièces remplacées : ${_selectedParts.join(', ')}'),
            pw.Text('Coût total : ${(_repairData?['estimatedCost'] ?? 0.0 + _laborCost).toStringAsFixed(2)} DZD'),
          ],
        ),
      ));

      final pdfBytes = await pdf.save();
      final ref = _storage.ref('reports/${widget.repairId}.pdf');
      await ref.putData(pdfBytes);

      await _firestore.collection('repairs').doc(widget.repairId).update({
        'status': 'completed',
        'finalCost': (_repairData?['estimatedCost'] ?? 0.0) + _laborCost,
        'completedAt': FieldValue.serverTimestamp(),
        'partsUsed': _selectedParts,
      });

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString().split(']').last.trim()}')),
      );
    }
  }
}