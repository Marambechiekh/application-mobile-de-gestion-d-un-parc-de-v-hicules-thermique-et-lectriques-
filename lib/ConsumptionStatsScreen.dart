import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

class ConsumptionStatsScreen extends StatelessWidget {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Color _primaryColor = const Color(0xFF6C5CE7); // Violet
  final Color _secondaryColor = const Color(0xFFB388FF); // Lavande
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _textColor = const Color(0xFF2D3436);

  ConsumptionStatsScreen({Key? key}) : super(key: key);

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: Text('Statistiques de Consommation', style: TextStyle(color: Colors.white)),
        backgroundColor: _primaryColor,
        elevation: 2,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('vehicles').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator(color: _primaryColor));
            }

            final vehicles = snapshot.data!.docs;
            final thermalVehicles = vehicles.where((v) => v['type'] == 'thermique').toList();
            final electricVehicles = vehicles.where((v) => v['type'] == 'electrique').toList();

            final fuelConsumption = thermalVehicles
                .map((v) => _safeParseDouble(v['consommationCarburant']))
                .toList();

            final batteryLevels = electricVehicles
                .map((v) => _safeParseDouble(v['etatCharge']))
                .toList();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thermalVehicles.isNotEmpty)
                    _buildChartSection(
                      title: 'Consommation Thermique (L/100km)',
                      data: fuelConsumption,
                      color: _primaryColor,
                      unit: 'L',
                    ),
                  if (electricVehicles.isNotEmpty)
                    _buildChartSection(
                      title: 'État Batterie Électrique (%)',
                      data: batteryLevels,
                      color: _secondaryColor,
                      unit: '%',
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildChartSection({
    required String title,
    required List<double> data,
    required Color color,
    required String unit,
  }) {
    final double maxY = data.isNotEmpty 
        ? (data.reduce((a, b) => a > b ? a : b) + 5)
        : 20.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        'Véh ${value.toInt() + 1}',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.toInt()}$unit',
                        style: TextStyle(
                          color: _textColor,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  data.length,
                  (index) => BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: data[index],
                        width: 18,
                        borderRadius: BorderRadius.circular(8),
                        color: color,
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.9),
                            color.withOpacity(0.6),
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
