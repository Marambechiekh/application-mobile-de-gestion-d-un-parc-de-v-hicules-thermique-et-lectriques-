import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/maintenance_alert_service.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

const Color _primaryColor = Color(0xFF6C5CE7);

class VehicleDetailsScreen extends StatelessWidget {
  final String vehicleId;
  final MaintenanceAlertService _alertService = MaintenanceAlertService();

  VehicleDetailsScreen({Key? key, required this.vehicleId}) : super(key: key);

  double _parseToDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _getFormattedValue(dynamic value, {String? unit}) {
    if (value == null) return 'Non spécifié';
    if (value is num) {
      String formatted;
      if (value % 1 == 0) {
        formatted = value.toInt().toString();
      } else {
        formatted = value.toStringAsFixed(1);
      }
      return unit != null ? '$formatted$unit' : formatted;
    }
    if (value is String) return value.isNotEmpty ? value : 'Non spécifié';
    if (value is Timestamp) return DateFormat('dd/MM/yyyy').format(value.toDate());
    return value.toString();
  }

  Future<String> _getVehicleStatus() async {
    final firestore = FirebaseFirestore.instance;

    final missions = await firestore.collection('missions')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'En cours')
        .get();
    if (missions.docs.isNotEmpty) return 'En mission';

    final repairs = await firestore.collection('repairs')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', isEqualTo: 'in_progress')
        .get();
    if (repairs.docs.isNotEmpty) return 'En réparation';

    final maintenances = await firestore.collection('maintenances')
        .where('vehicleId', isEqualTo: vehicleId)
        .where('status', whereIn: ['in_progress', 'planned'])
        .get();
    if (maintenances.docs.isNotEmpty) return 'En entretien';

    return 'Disponible';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du Véhicule'),
        backgroundColor: _primaryColor,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('vehicles')
            .doc(vehicleId)
            .get()
            .then((snapshot) {
          if (snapshot.exists) {
            MaintenanceAlertService().checkForAlerts(vehicleId);
          }
          return snapshot;
        }),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Véhicule introuvable'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final vehicleType = data['type']?.toString().toLowerCase() ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildGeneralInfoSection(data),
                const SizedBox(height: 20),
                _buildTechnicalSpecsSection(data),
                const SizedBox(height: 20),
                _buildEnergySection(data, vehicleType),
                const SizedBox(height: 20),
                _buildHistorySection(),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _primaryColor,
        onPressed: () {
          MaintenanceAlertService().checkForAlerts(vehicleId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vérification des alertes en cours...'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildGeneralInfoSection(Map<String, dynamic> data) {
    final lastMaintenance = data['lastMaintenanceDetails'] ?? {};
    final lastMaintenanceExists = lastMaintenance.isNotEmpty && lastMaintenance['date'] != null;

    final lastMaintenanceKm = lastMaintenanceExists
        ? '${lastMaintenance['km']} km'
        : '';

    final lastMaintenanceDate = lastMaintenanceExists
        ? DateFormat('dd/MM/yyyy').format((lastMaintenance['date'] as Timestamp).toDate())
        : '';

    final dernierEntretien = lastMaintenanceExists
        ? '$lastMaintenanceKm le $lastMaintenanceDate'
        : 'Aucun entretien effectué';

    final fields = [
      {'label': 'Modèle', 'value': data['modele']},
      {'label': 'Marque', 'value': data['marque']},
      {'label': 'Immatriculation', 'value': data['numeroImmatriculation']},
      {'label': 'Année', 'value': data['annee']},
      {'label': 'Type', 'value': data['type'] == 'electrique' ? 'Électrique' : 'Thermique'},
      {'label': 'Puissance', 'value': '${data['puissance']} ch'},
      {'label': 'Coût d\'acquisition', 'value': '${_getFormattedValue(data['coutAcquisition'])} TND'},
      {'label': 'Numéro de chassis', 'value': data['numeroChassis']},
      {'label': 'Dernier entretien', 'value': dernierEntretien},
    ];

    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle('Informations Générales'),
            const Divider(),
            ...fields.map((field) => _buildInfoRow(field['label']!, field['value'])),
            FutureBuilder<String>(
              future: _getVehicleStatus(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildInfoRow('Statut', snapshot.data!);
                }
                return const LinearProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicalSpecsSection(Map<String, dynamic> data) {
    final fields = [
      {'label': 'Nombre de places', 'value': data['nombrePlaces']},
      {'label': 'Kilométrage', 'value': '${_getFormattedValue(data['nombreKmParcouru'])} km'},
      {'label': 'Amortissement annuel', 'value': '${_getFormattedValue(data['amortissementParAnnee'])} TND'},
      if (data['type'] == 'thermique') 
        {'label': 'Type de carburant', 'value': data['typeCarburant']},
    ];

    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle('Spécifications Techniques'),
            const Divider(),
            ...fields.map((field) => _buildInfoRow(field['label']!, field['value'])),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergySection(Map<String, dynamic> data, String vehicleType) {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle('Données Énergétiques'),
            const Divider(),
            if (vehicleType == 'electrique') ...[
              _buildInfoRow('État de la batterie', '${_getFormattedValue(data['etatCharge'])}%'),
              _buildInfoRow('Capacité batterie', '${_getFormattedValue(data['capaciteBatterie'])} kWh'),
              _buildInfoRow('Autonomie', '${_getFormattedValue(data['autonomie'])} km'),
            ],
            if (vehicleType == 'thermique') ...[
              _buildInfoRow('Capacité réservoir', '${_getFormattedValue(data['capaciteReservoirCarburant'])} L'),
              _buildInfoRow('Consommation', '${_getFormattedValue(data['consommationCarburant'])} L/100km'),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    return Card(
      elevation: 5,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const _SectionTitle('Historique'),
            const Divider(),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('maintenances')
                  .where('vehicleId', isEqualTo: vehicleId)
                  .snapshots(),
              builder: (context, maintenances) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('repairs')
                      .where('vehicleId', isEqualTo: vehicleId)
                      .snapshots(),
                  builder: (context, repairs) {
                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance.collection('insurances')
                          .where('vehicleId', isEqualTo: vehicleId)
                          .snapshots(),
                      builder: (context, insurances) {
                        final List<DocumentSnapshot> allDocs = [];
                        if (maintenances.hasData) allDocs.addAll(maintenances.data!.docs);
                        if (repairs.hasData) allDocs.addAll(repairs.data!.docs);
                        if (insurances.hasData) allDocs.addAll(insurances.data!.docs);
                        allDocs.sort((a, b) {
                          final dateA = _getDate(a).toDate();
                          final dateB = _getDate(b).toDate();
                          return dateB.compareTo(dateA);
                        });

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: allDocs.length,
                          itemBuilder: (context, index) {
                            final doc = allDocs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final collection = doc.reference.parent.id;

                            IconData icon = Icons.history;
                            String title = '';
                            String date = '';
                            String status = '';
                            String? details;
                            double? cost;

                            switch (collection) {
                              case 'maintenances':
                                icon = Icons.build;
                                title = data['type'] ?? 'Entretien';
                                date = _getFormattedValue(data['completedAt']);
                                status = data['status'];
                                cost = _parseToDouble(data['totalCost']);
                                break;
                              case 'repairs':
                                icon = Icons.car_repair;
                                title = 'Réparation';
                                date = _getFormattedValue(data['completedAt']);
                                status = data['status'];
                                cost = _parseToDouble(data['finalCost']);
                                break;
                              case 'insurances':
                                icon = Icons.assignment;
                                title = 'Assurance';
                                date = _getFormattedValue(data['expirationDate']);
                                status = (data['isArchived'] ?? false) ? 'Valide' : 'Expirée';
                                details = 'Fournisseur : ${data['provider'] ?? ''}';
                                final reference = data['reference'] ?? '';
                                if (reference.isNotEmpty) {
                                  details = '$details\nRéférence : $reference';
                                }
                                break;
                            }

                            return ListTile(
                              leading: Icon(icon, color: _getColor(collection)),
                              title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(date),
                                  if (details?.isNotEmpty ?? false) Text(details!),
                                  const SizedBox(height: 4),
                                  _buildStatusChip(status),
                                ],
                              ),
                              trailing: cost != null 
                                  ? Text('${cost.toStringAsFixed(2)} TND')
                                  : null,
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Timestamp _getDate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    try {
      switch (doc.reference.parent.id) {
        case 'maintenances':
          return data['scheduledDate'] ?? Timestamp.now();
        case 'repairs':
          return data['startDate'] ?? Timestamp.now();
        case 'insurances':
          return data['expirationDate'] ?? Timestamp.now();
        default:
          return Timestamp.now();
      }
    } catch (e) {
      return Timestamp.now();
    }
  }

  Color _getColor(String collection) {
    switch (collection) {
      case 'maintenances':
        return Colors.blue;
      case 'repairs':
        return Colors.orange;
      case 'insurances':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStatusChip(String status) {
    Color color = Colors.grey;
    String text = status;
    
    switch (status) {
      case 'completed':
        color = Colors.green;
        text = 'Terminé';
        break;
      case 'in_progress':
        color = Colors.orange;
        text = 'En cours';
        break;
      case 'Valide':
        color = Colors.green;
        break;
      case 'Expirée':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
        text = 'Inconnu';
    }

    return Chip(
      label: Text(text, style: TextStyle(color: color)),
      backgroundColor: color.withOpacity(0.1),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildInfoRow(String label, dynamic value, [String? unit]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.blueGrey.shade700),
            ),
          ),
          Expanded(
            child: Text(
              _getFormattedValue(value, unit: unit),
              style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold),
    );
  }
}