import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceAlertService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot> getActiveAlerts() {
    return _firestore.collection('maintenance_alerts')
        .where('resolved', isEqualTo: false)
        .snapshots();
  }

  Future<void> checkForAlerts(String vehicleId) async {
  try {
    final vehicleSnapshot = await _firestore.collection('vehicles').doc(vehicleId).get();
    if (!vehicleSnapshot.exists) return;

    final vehicleData = vehicleSnapshot.data() as Map<String, dynamic>;
    final currentKm = _safeParseDouble(vehicleData['nombreKmParcouru']);
    final vehicleType = vehicleData['type']?.toString().toLowerCase() ?? '';
    final lastMaintenance = vehicleData['lastMaintenanceDetails'] as Map<String, dynamic>?;

    final typesSnapshot = await _firestore.collection('maintenance_types')
        .where('vehicle_type', isEqualTo: vehicleType)
        .get();

    for (final typeDoc in typesSnapshot.docs) {
      final typeData = typeDoc.data();
      final intervalValue = _safeParseDouble(typeData['interval_value']);
      final alertMargin = _safeParseDouble(typeData['alert_margin']);

      double alertThreshold;
      String alertType;

      // Calcul différent pour véhicule neuf
      if (lastMaintenance == null) {
        alertThreshold = intervalValue;
        alertType = 'premiere';
      } else {
        final lastMaintenanceKm = _safeParseDouble(lastMaintenance['km']);
        alertThreshold = lastMaintenanceKm + intervalValue;
        alertType = 'recurrente';
      }

      final alertThresholdWithMargin = alertThreshold * (1 - (alertMargin / 100));

      if (currentKm >= alertThresholdWithMargin) {
        await _createAlertIfNotExists(
          vehicleSnapshot, 
          typeDoc, 
          currentKm, 
          alertThreshold,
          alertType
        );
      }
    }
  } catch (e) {
    print('[ALERT ERROR] Error checking alerts for $vehicleId: $e');
  }
}


double _safeParseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}
  Future<void> _createAlertIfNotExists(
  DocumentSnapshot vehicle, 
  QueryDocumentSnapshot type, 
  double currentKm,
  double threshold,
  String alertType
) async {
  final existing = await _firestore.collection('maintenance_alerts')
      .where('vehicleId', isEqualTo: vehicle.id)
      .where('typeId', isEqualTo: type.id)
      .where('resolved', isEqualTo: false)
      .get();

  if (existing.docs.isEmpty) {
    await _firestore.collection('maintenance_alerts').add({
      'vehicleId': vehicle.id,
      'typeId': type.id,
      'triggeredAt': FieldValue.serverTimestamp(),
      'resolved': false,
      'currentKm': currentKm,
      'threshold': threshold,
      'alertMargin': type['alert_margin'],
      'alertType': alertType,
      'vehicleData': vehicle.data(),
      'typeData': type.data(),
    });
  }
}

  Future<void> resolveAlert(String alertId, String maintenanceId) async {
    await _firestore.collection('maintenance_alerts').doc(alertId).update({
      'resolved': true,
      'maintenanceId': maintenanceId,
      'resolvedAt': FieldValue.serverTimestamp()
    });
  }
  Future<void> deleteAlert(String alertId) async {
  await _firestore.collection('maintenance_alerts').doc(alertId).delete();
}
}