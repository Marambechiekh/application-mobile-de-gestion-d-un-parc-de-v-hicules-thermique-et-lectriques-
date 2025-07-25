import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DriversScreen extends StatelessWidget {
  void _showDriverDetails(BuildContext context, Map<String, dynamic> driverData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Détails du Chauffeur",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("👤 Nom: ${driverData['firstName']} ${driverData['lastName']}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
           
            Text("📞 Téléphone: ${driverData['phone'] ?? 'Non disponible'}", style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text("🚗 Véhicule: ${driverData['assignedVehicle'] ?? 'Non assigné'}", style: TextStyle(fontSize: 16)),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Fermer", style: TextStyle(color: Colors.black)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  void _deleteDriver(BuildContext context, String driverId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Supprimer ce chauffeur ?", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text("Cette action est irréversible."),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Annuler", style: TextStyle(color: Colors.black)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Supprimer", style: TextStyle(color: Colors.white)),
            onPressed: () {
              FirebaseFirestore.instance.collection('drivers').doc(driverId).delete();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Gestion des Chauffeurs"),
        backgroundColor: Color(0xFF6A0DAD),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: Colors.white, size: 28),
            onPressed: () {
              Navigator.pushNamed(context, '/addDriver');
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          var drivers = snapshot.data!.docs;

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              var driver = drivers[index];
              var driverData = driver.data() as Map<String, dynamic>;

              return Card(
                color: Colors.white,
                elevation: 6,
                shadowColor: Colors.black.withOpacity(0.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: ListTile(
                  contentPadding: EdgeInsets.all(16),
                  title: Text(
                    "${driverData['firstName']} ${driverData['lastName']}",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text(
                    "Véhicule: ${driverData['assignedVehicle'] ?? 'Non assigné'}",
                    style: TextStyle(fontSize: 14),
                  ),
                  onTap: () => _showDriverDetails(context, driverData),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit, color: Colors.blue),
                        onPressed: () {
                          Navigator.pushNamed(
                            context,
                            '/editDriver',
                            arguments: {'driverId': driver.id},
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () => _deleteDriver(context, driver.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
