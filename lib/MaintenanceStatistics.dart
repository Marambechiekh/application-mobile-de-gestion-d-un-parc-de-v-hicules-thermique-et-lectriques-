import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart'; 

const Color _primaryColor = Color(0xFF6C5CE7);
const Color _accentColor = Color(0xFF00BFA5);
const Color _backgroundColor = Color(0xFFF8F9FE);
class MaintenanceStatistics extends StatelessWidget {
  const MaintenanceStatistics({super.key});
  Color _getColorFromPalette(int index) {
    final colors = [
      _primaryColor,
      _accentColor,
      const Color(0xFFFF7675),  
      const Color(0xFF74B9FF),  
      const Color(0xFFFDCB6E),  
      const Color(0xFFA29BFE), 
      const Color(0xFF55EFC4), 
      const Color(0xFFFFEAA7),  
      const Color(0xFF81ECEC), 
      const Color(0xFFFAB1A0),  
    ];
    return colors[index % colors.length];
  }
  double _calculateInterval(List<Map<String, dynamic>> data) {
    if (data.isEmpty) return 1000;
    double maxCost = 0;
    for (var item in data) {
      if (item['cost'] > maxCost) maxCost = item['cost'];
    }
    return (maxCost / 5).roundToDouble();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Statistiques des entretiens',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
                fontSize: 16, 
                letterSpacing: 1.2)),
        backgroundColor: _primaryColor,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('maintenances').get(),
            builder: (context, maintenancesSnapshot) {
              if (maintenancesSnapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: _primaryColor,
                    strokeWidth: 2.5,
                  ),
                );
              }

              if (maintenancesSnapshot.hasError) {
                return Center(
                  child: Text('Erreur de chargement des données',
                      style: TextStyle(
                          color: _primaryColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                );
              }

              final maintenances = maintenancesSnapshot.data!.docs;
              final completed = maintenances.where((d) => 
                  (d.data() as Map<String, dynamic>)['status'] == 'completed').length;
              final pending = maintenances.length - completed;
              final totalCost = maintenances.fold(0.0, (sum, doc) {
                final data = doc.data() as Map<String, dynamic>;
                return sum + (data['totalCost'] ?? 0.0);
              });

              return FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance.collection('vehicles').get(),
                builder: (context, vehiclesSnapshot) {
                  if (vehiclesSnapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: _primaryColor,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (vehiclesSnapshot.hasError) {
                    return Center(
                      child: Text('Erreur de chargement des véhicules',
                          style: TextStyle(
                              color: _primaryColor,
                              fontSize: 16,
                              fontWeight: FontWeight.w500)),
                    );
                  }

                  final vehicles = vehiclesSnapshot.data!.docs;
                  
                  // 1. Calculer le coût total par véhicule
                  Map<String, double> vehicleCosts = {};
                  for (var maintenance in maintenances) {
                    final data = maintenance.data() as Map<String, dynamic>;
                    final vehicleId = data['vehicleId'];
                    final cost = data['totalCost'] ?? 0.0;
                    
                    if (vehicleId != null) {
                      vehicleCosts.update(vehicleId, (value) => value + cost, 
                          ifAbsent: () => cost);
                    }
                  }
                  
                  // 2. Associer les noms de véhicules et trier par coût
                  List<Map<String, dynamic>> topVehicles = [];
                  for (var vehicle in vehicles) {
                    final vehicleId = vehicle.id;
                    if (vehicleCosts.containsKey(vehicleId)) {
                      final vehicleData = vehicle.data() as Map<String, dynamic>;
                      final name = '${vehicleData['marque']} ${vehicleData['modele']}';
                      topVehicles.add({
                        'name': name,
                        'cost': vehicleCosts[vehicleId]!,
                        'id': vehicleId,
                      });
                    }
                  }
                  
                  topVehicles.sort((a, b) => b['cost'].compareTo(a['cost']));
                  final top10 = topVehicles.take(10).toList();
                  
                  // 4. Préparer les données pour le graphique
                  List<Map<String, dynamic>> chartData = [];
                  for (int i = 0; i < top10.length; i++) {
                    chartData.add({
                      'vehicle': top10[i]['name'],
                      'cost': top10[i]['cost'],
                      'color': _getColorFromPalette(i),
                    });
                  }
                  
                  // 5. Top 5 des entretiens les plus chers
                  final completedMaintenances = maintenances.where((m) => 
                      (m.data() as Map<String, dynamic>)['status'] == 'completed').toList();
                  
                  completedMaintenances.sort((a, b) {
                    final costA = (a.data() as Map<String, dynamic>)['totalCost'] ?? 0.0;
                    final costB = (b.data() as Map<String, dynamic>)['totalCost'] ?? 0.0;
                    return costB.compareTo(costA);
                  });
                  final topExpensive = completedMaintenances.take(5).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // En-tête
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ANALYSE DES ENTREIENS',
                              style: TextStyle(
                                color: _primaryColor,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Dernière mise à jour: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Grille de KPI
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        childAspectRatio: 1.3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        children: [
                          _buildCorporateKpiCard(
                            title: "Total entretiens",
                            value: maintenances.length.toString(),
                            icon: Icons.library_books,
                            color: _primaryColor,
                          ),
                          _buildCorporateKpiCard(
                            title: "Terminés",
                            value: completed.toString(),
                            icon: Icons.check_circle,
                            color: _accentColor,
                          ),
                          _buildCorporateKpiCard(
                            title: "En attente",
                            value: pending.toString(),
                            icon: Icons.pending,
                            color: Colors.orange,
                          ),
                          _buildCorporateKpiCard(
                            title: "Coût total",
                            value: "${totalCost.toStringAsFixed(3)} TND",
                            icon: Icons.payments,
                            color: Colors.blue,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                    
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'TOP VÉHICULES LES PLUS COÛTEUX',
                                style: TextStyle(
                                  color: _primaryColor,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Véhicules avec les coûts d\'entretien cumulés les plus élevés',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 400,
                                child: SfCartesianChart(
                                  plotAreaBorderColor: Colors.transparent,
                                  margin: const EdgeInsets.all(0),
                                  primaryXAxis: CategoryAxis(
                                    labelStyle: TextStyle(
                                      color: _primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    labelRotation: -45,
                                    axisLine: AxisLine(width: 1, color: Colors.grey.shade300),
                                    majorGridLines: MajorGridLines(width: 0),
                                  ),
                                  primaryYAxis: NumericAxis(
                                    title: AxisTitle(text: 'Coût Total (TND)'),
                                    labelStyle: TextStyle(
                                      color: _primaryColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    axisLine: AxisLine(width: 1, color: Colors.grey.shade300),
                                    majorTickLines: MajorTickLines(size: 4),
                                    minimum: 0,
                                    interval: _calculateInterval(chartData),
                                    numberFormat: NumberFormat.compactCurrency(symbol: ''),
                                  ),
                                  tooltipBehavior: TooltipBehavior(
                                    enable: true,
                                    header: '',
                                    format: 'point.x : point.y TND',
                                  ),
                                  series: <BarSeries<Map<String, dynamic>, String>>[
                                    BarSeries<Map<String, dynamic>, String>(
                                      dataSource: chartData,
                                      animationDuration: 1000,
                                      borderRadius: BorderRadius.circular(8),
                                      width: 0.6,
                                      spacing: 0.1,
                                      xValueMapper: (Map<String, dynamic> data, _) => data['vehicle'],
                                      yValueMapper: (Map<String, dynamic> data, _) => data['cost'],
                                      pointColorMapper: (Map<String, dynamic> data, _) => data['color'],
                                      name: 'Coût total',
                                      dataLabelSettings: DataLabelSettings(
                                        isVisible: true,
                                        textStyle: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 10,
                                        ),
                                        labelAlignment: ChartDataLabelAlignment.top,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                    

                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'TOP ENTREIENS COÛTEUX',
                                    style: TextStyle(
                                      color: _primaryColor,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              Icon(Icons.payments, color: _accentColor)


                                ],
                              ),
                              const SizedBox(height: 16),
                              ...topExpensive.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final vehicleId = data['vehicleId'];
                                String vehicleName = 'Véhicule inconnu';
                                
                                if (vehicleId != null) {
                                  for (var vehicle in vehicles) {
                                    if (vehicle.id == vehicleId) {
                                      final vehicleData = vehicle.data() as Map<String, dynamic>;
                                      vehicleName = '${vehicleData['marque']} ${vehicleData['modele']}';
                                      break;
                                    }
                                  }
                                }
                                
                                final cost = data['totalCost'] ?? 0.0;
                                final date = (data['scheduledDate'] as Timestamp?)?.toDate() ?? DateTime.now();
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          vehicleName,
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '${cost.toStringAsFixed(3)} TND',
                                        style: TextStyle(
                                          color: _primaryColor,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('dd/MM/yy').format(date),
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // Carte KPI style professionnel
  Widget _buildCorporateKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: _primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  Icon(icon, color: color, size: 24),
                ],
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 40),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _primaryColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}