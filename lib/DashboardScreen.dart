import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/IncidentReportScreen.dart';
import 'package:flutter_application_2/InsuranceManagementScreen.dart';
import 'package:flutter_application_2/MaintenanceManagementScreen.dart';

import 'package:flutter_application_2/maintenance_alert_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'dart:async'; // Pour StreamSubscription
import 'dart:typed_data'; 

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DashboardScreen extends StatefulWidget {
  final String role;
  DashboardScreen({required this.role, Key? key}) : super(key: key);
  final Color _accentColor = Colors.redAccent;
  final Color _cardColor = Colors.white;
  final Color _iconBackground = Color(0xFFFFEBEE);

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MaintenanceAlertService _alertService = MaintenanceAlertService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00BFA5);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _alertColor = const Color(0xFFFF7043);
  final Color _textColor = const Color(0xFF2D3436);

  // Gestion des notifications
  late StreamSubscription<QuerySnapshot>? _insuranceStreamSubscription;
  late StreamSubscription<QuerySnapshot>? _incidentStreamSubscription;
  late StreamSubscription<QuerySnapshot>? _missionStreamSubscription;
  final Set<String> _notifiedInsuranceIds = {};
  final Set<String> _notifiedIncidentIds = {};
  final Set<String> _notifiedMissionIds = {};

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    
    // Seul le responsable de parc reçoit les notifications en temps réel
    if (widget.role == 'Responsable de parc') {
      _setupInsuranceNotificationStream();
      _setupIncidentNotificationStream();
    }
    
    // Ajouté pour le rôle chauffeur
    if (widget.role == 'Chauffeur') {
      _setupMissionNotificationStream();
    }
  }

  @override
  void dispose() {
    // Annuler uniquement si les streams ont été initialisés
    _insuranceStreamSubscription?.cancel();
    _incidentStreamSubscription?.cancel();
    _missionStreamSubscription?.cancel(); // Ajouté pour le rôle chauffeur
    super.dispose();
  }

  Future<void> _initializeNotifications() async {
    // Création des canaux de notification
    final AndroidNotificationChannel insuranceChannel = AndroidNotificationChannel(
      'assurance_channel',
      'Notifications d\'assurance',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('notification_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
    );

    final AndroidNotificationChannel incidentChannel = AndroidNotificationChannel(
      'incidents_channel',
      'Notifications d\'incidents',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('alert_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );

    // Ajouté pour le rôle chauffeur
    final AndroidNotificationChannel missionChannel = AndroidNotificationChannel(
      'mission_channel',
      'Notifications de mission',
      importance: Importance.max,
      sound: const RawResourceAndroidNotificationSound('mission_sound'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
    );

    final androidPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(insuranceChannel);
      await androidPlugin.createNotificationChannel(incidentChannel);
      await androidPlugin.createNotificationChannel(missionChannel); // Ajouté pour le rôle chauffeur
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    final InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Configuration du stream pour les notifications d'assurance
  void _setupInsuranceNotificationStream() {
    _insuranceStreamSubscription = _firestore
        .collection('insurances')
        .snapshots()
        .listen((snapshot) {
      // Vérifier si l'utilisateur est toujours responsable
      if (widget.role != 'Responsable de parc') return;
      
      final now = DateTime.now();
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final insuranceId = doc.id;
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final isArchived = data['isArchived'] ?? false;

        if (isArchived || endDate == null) continue;

        final daysRemaining = endDate.difference(now).inDays;
        if (daysRemaining <= 15 && daysRemaining >= 0) {
          if (!_notifiedInsuranceIds.contains(insuranceId)) {
            final reference = data['reference'] ?? 'Sans référence';
            _showInsuranceNotification(reference, daysRemaining, insuranceId);
            _notifiedInsuranceIds.add(insuranceId);
          }
        }
      }
    });
  }

  // Configuration du stream pour les notifications d'incidents
  void _setupIncidentNotificationStream() {
    _incidentStreamSubscription = _firestore
        .collection('incidents')
        .snapshots()
        .listen((snapshot) {
      // Vérifier si l'utilisateur est toujours responsable
      if (widget.role != 'Responsable de parc') return;
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final incidentId = doc.id;
        final status = data['status'] as String? ?? '';

        if (status == 'Nouveau') {
          if (!_notifiedIncidentIds.contains(incidentId)) {
            final titre = data['titre'] as String? ?? 'Nouvel incident';
            _showIncidentNotification(titre, incidentId);
            _notifiedIncidentIds.add(incidentId);
          }
        }
      }
    });
  }

  // Ajouté pour le rôle chauffeur
  void _setupMissionNotificationStream() {
    final String? driverEmail = _auth.currentUser?.email;
    if (driverEmail == null) return;

    _missionStreamSubscription = _firestore
        .collection('missions')
        .where('driver', isEqualTo: driverEmail)
        .where('status', isEqualTo: 'En cours')
        .snapshots()
        .listen((snapshot) {
      for (final doc in snapshot.docs) {
        final missionId = doc.id;
        if (!_notifiedMissionIds.contains(missionId)) {
          final data = doc.data() as Map<String, dynamic>;
          final destination = data['destination'] as String? ?? 'Destination inconnue';
          _showMissionNotification(destination, missionId);
          _notifiedMissionIds.add(missionId);
        }
      }
    });
  }

  // Notification pour les assurances expirantes (responsable uniquement)
  Future<void> _showInsuranceNotification(
      String reference, int daysRemaining, String insuranceId) async {
    if (widget.role != 'Responsable de parc') return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'assurance_channel',
      'Notifications d\'assurance',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    await flutterLocalNotificationsPlugin.show(
      insuranceId.hashCode,
      '🔔 Assurance à renouveler',
      'L\'assurance "$reference" expire dans $daysRemaining jours',
      const NotificationDetails(android: androidDetails),
    );
  }

  // Notification pour les nouveaux incidents (responsable uniquement)
  Future<void> _showIncidentNotification(String titre, String incidentId) async {
    if (widget.role != 'Responsable de parc') return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'incidents_channel',
      'Notifications d\'incidents',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    await flutterLocalNotificationsPlugin.show(
      incidentId.hashCode,
      '⚠️ Nouvel incident signalé',
      titre,
      const NotificationDetails(android: androidDetails),
    );
  }

  // Ajouté pour le rôle chauffeur
 Future<void> _showMissionNotification(String destination, String missionId) async {
    if (widget.role != 'Chauffeur') return;

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'mission_channel',
      'Notifications de mission',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    await flutterLocalNotificationsPlugin.show(
      missionId.hashCode,
      '🚗 Mission en cours',
      'Vous avez une mission vers $destination',
      const NotificationDetails(android: androidDetails),
      payload: 'mission', // Ajout du payload pour identifier le type de notification
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
              automaticallyImplyLeading: widget.role != 'Chauffeur' && widget.role != 'admin', 
                  centerTitle: true,
    
        title: widget.role == 'Chauffeur'
        
            ? _buildAppBarTitleWithNotification()
            : widget.role == 'Responsable de parc'
                ? Text(
                    'Tableau de Bord',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  )
                : Text(
                    'Tableau de Bord',
                    style: TextStyle(
                     color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
        backgroundColor: _primaryColor,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        actions: [
          if (widget.role == 'Responsable de parc') ...[
            _buildAlertNotificationIcon(),
            _buildCombinedNotificationIcon(),
          ],
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
          ),
        ],
      ),
      drawer: widget.role == 'Responsable de parc' ? _buildModernDrawer() : null,
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.role == 'Responsable de parc') ...[
                  _buildStatsRow(),
                  const SizedBox(height: 20),
                 
                  _buildVehiclesByTypeChart(),
                   _buildInsuranceAlerts(), 
                  const SizedBox(height: 20),
                  _buildAlertStatus(),
                  const SizedBox(height: 20),
                  _buildScheduledMaintenance(),
                  const SizedBox(height: 20),
                  _buildScheduledRepairs(),
                  const SizedBox(height: 20),
                  _buildQuickAccessMenu(),
                ],
                if (widget.role == 'admin') ...[
                  _buildAdminHeader(),
                  const SizedBox(height: 30),
                  _buildAdminStats(),
                ],
                if (widget.role == 'Chauffeur') ...[
                  _buildChauffeurHeader(),
                  const SizedBox(height: 20),
                  _buildChauffeurStats(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/incident_report'),
                      icon: Icon(Icons.report_problem, color: Colors.white),
                      label: Text('Déclarer un incident', 
                          style: TextStyle(fontSize: 16, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }
 
 
  Widget _buildCombinedNotificationIcon() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('insurances').snapshots(),
      builder: (context, insuranceSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('incidents').snapshots(),
          builder: (context, incidentSnapshot) {
            int insuranceCount = 0;
            int incidentCount = 0;

            if (insuranceSnapshot.hasData) {
              final now = DateTime.now();
              insuranceCount = insuranceSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final endDate = (data['endDate'] as Timestamp?)?.toDate();
                final isArchived = data['isArchived'] ?? false;
                if (isArchived || endDate == null) return false;
                final daysRemaining = endDate.difference(now).inDays;
                return daysRemaining <= 15 && daysRemaining >= 0;
              }).length;
            }

            if (incidentSnapshot.hasData) {
              incidentCount = incidentSnapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                return data['status'] == 'Nouveau';
              }).length;
            }

            final totalCount = insuranceCount + incidentCount;

            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  onPressed: () {
                    _showBottomNotificationPanel(insuranceSnapshot.data, incidentSnapshot.data);
                  },
                ),
                if (totalCount > 0)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        totalCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showBottomNotificationPanel(
    QuerySnapshot? insuranceSnapshot,
    QuerySnapshot? incidentSnapshot,
  ) {
    final now = DateTime.now();

    final expiringInsurances = insuranceSnapshot?.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      final isArchived = data['isArchived'] ?? false;
      if (isArchived || endDate == null) return false;
      final daysRemaining = endDate.difference(now).inDays;
      return daysRemaining <= 15 && daysRemaining >= 0;
    }).toList() ?? [];

    final incidents = incidentSnapshot?.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return data['status'] == 'Nouveau';
    }).toList() ?? [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Notifications", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                if (expiringInsurances.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Assurances à renouveler", style: TextStyle(fontWeight: FontWeight.bold)),
                      ...expiringInsurances.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final reference = data['reference'] ?? 'Sans référence';
                        final endDate = (data['endDate'] as Timestamp).toDate();
                        final daysRemaining = endDate.difference(now).inDays;
                        return ListTile(
                          leading: Icon(Icons.warning, color: Colors.orange),
                          title: Text(reference),
                          subtitle: Text('Expire dans $daysRemaining jours'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => InsuranceManagementScreen(),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                if (incidents.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      const Text("Nouveaux incidents", style: TextStyle(fontWeight: FontWeight.bold)),
                      ...incidents.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final titre = data['titre'] ?? 'Incident';
                        final date = (data['createdAt'] as Timestamp?)?.toDate();
                        final dateFormatted = date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
                        return ListTile(
                          leading: Icon(Icons.report_problem, color: Colors.red),
                          title: Text(titre),
                          subtitle: Text('Déclaré le $dateFormatted'),
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => IncidentListScreen(),
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  Future<void> _checkExpiringInsurances() async {
    final snapshot = await _firestore.collection('insurances').get();
    final now = DateTime.now();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final endDate = (data['endDate'] as Timestamp?)?.toDate();
      final isArchived = data['isArchived'] ?? false;
      if (isArchived) continue;
      
      if (endDate != null) {
        final daysRemaining = endDate.difference(now).inDays;
        if (daysRemaining <= 15 && daysRemaining >= 0) {
          final reference = data['reference'] ?? 'Sans référence';
            _showInsuranceNotification(reference, daysRemaining, doc.id);
        }
      }
    }
  }
   Widget _buildInsuranceNotificationIcon() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('insurances').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications, color: Colors.white),
              onPressed: () {},
            ),
          ],
        );
      }

      final now = DateTime.now();
      final count = snapshot.data!.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final isArchived = data['isArchived'] ?? false;
        if (isArchived || endDate == null) return false;
        final daysRemaining = endDate.difference(now).inDays;
        return daysRemaining <= 15 && daysRemaining >= 0;
      }).length;

      return Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.notifications, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InsuranceManagementScreen(),
                ),
              );
            },
          ),
          if (count > 0)
            Positioned(
              top: 5,  // Position ajustée pour être plus proche de l'icône
              right: 5, // Position ajustée pour être plus proche de l'icône
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
      ] ) ;
    } );
    }
  


  Widget _buildInsuranceAlerts() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('insurances').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Container();
        
        final now = DateTime.now();
        final expiringInsurances = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final endDate = (data['endDate'] as Timestamp?)?.toDate();
          final isArchived = data['isArchived'] ?? false;
          
          if (isArchived || endDate == null) return false;
          
          final daysRemaining = endDate.difference(now).inDays;
          return daysRemaining <= 15 && daysRemaining >= 0;
        }).toList();

        if (expiringInsurances.isEmpty) return Container();

        return Container(
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.shade200),
          ),
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 10),
                  Text(
                    'Assurances à renouveler',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...expiringInsurances.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final endDate = (data['endDate'] as Timestamp).toDate();
                final daysRemaining = endDate.difference(now).inDays;
                final reference = data['reference'] ?? 'Sans référence';

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.shade100,
                    child: Icon(Icons.warning, color: Colors.orange),
                  ),
                  title: Text(reference),
                  subtitle: Text('Expire dans $daysRemaining jours'),
                  trailing: IconButton(
                    icon: Icon(Icons.arrow_forward, color: Colors.orange),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => InsuranceManagementScreen(),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

    Future<void> _refreshDashboard() async {
    final scaffold = ScaffoldMessenger.of(context);
    
    try {
      final vehicles = await _firestore.collection('vehicles').get();
      
      for (final vehicle in vehicles.docs) {
        await _alertService.checkForAlerts(vehicle.id);
      }

      setState(() {});

      scaffold.showSnackBar(
        SnackBar(
          content: Text('Données actualisées avec succès'),
          duration: const Duration(seconds: 2),
          backgroundColor: _primaryColor,
        ),
      );

    } catch (e) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text('Erreur de rafraîchissement: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  Widget _buildRenewableInsurances() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('insurances').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: CircularProgressIndicator());
      }
      
      final now = DateTime.now();
      final insurances = snapshot.data!.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final endDate = (data['endDate'] as Timestamp?)?.toDate();
        final isArchived = data['isArchived'] ?? false;
        
        if (isArchived || endDate == null) return false;
        
        final daysRemaining = endDate.difference(now).inDays;
        return daysRemaining <= 15 && daysRemaining >= 0;
      }).toList();

      if (insurances.isEmpty) {
        return Container(); // Ne rien afficher s'il n'y a pas d'assurances à renouveler
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                const SizedBox(width: 10),
                Text(
                  'Assurances à renouveler',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: _textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...insurances.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final endDate = (data['endDate'] as Timestamp).toDate();
              final daysRemaining = endDate.difference(now).inDays;
              final vehicleId = data['vehicleId'] ?? '';
              final reference = data['reference'] ?? 'Sans référence';

              return FutureBuilder<DocumentSnapshot>(
                future: _firestore.collection('vehicles').doc(vehicleId).get(),
                builder: (context, vehicleSnapshot) {
                  String vehicleName = 'Véhicule inconnu';
                  if (vehicleSnapshot.hasData && vehicleSnapshot.data!.exists) {
                    final vehicleData = vehicleSnapshot.data!.data() as Map<String, dynamic>;
                    vehicleName = '${vehicleData['marque']} ${vehicleData['modele']}';
                  }

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.shade100,
                      child: Icon(Icons.warning, color: Colors.orange),
                    ),
                    title: Text(reference),
                    subtitle: Text('$vehicleName - Expire dans $daysRemaining jours'),
                    trailing: IconButton(
                      icon: Icon(Icons.arrow_forward, color: _primaryColor),
                      onPressed: () {
                        // Naviguer vers l'écran de gestion des assurances
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => InsuranceManagementScreen(),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }).toList(),
          ],
        ),
       ) ;});
    }
  

Widget _buildVehiclesByTypeChart() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('vehicles').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return Center(child: CircularProgressIndicator());
      }

      int thermicCount = 0;
      int electricCount = 0;

      snapshot.data!.docs.forEach((vehicle) {
        if (vehicle['type'] == 'thermique') {
          thermicCount++;
        } else if (vehicle['type'] == 'electrique') {
          electricCount++;
        }
      });

      final total = thermicCount + electricCount;
      final thermicPercentage = total > 0 ? (thermicCount / total * 100) : 0;
      final electricPercentage = total > 0 ? (electricCount / total * 100) : 0;

      final Color gasColor = const Color(0xFF7B61FF);       // Violet foncé
      final Color electricColor = const Color(0xFFD6CFFF);  // Violet clair

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Graphique circulaire
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.2,
                child: PieChart(
                  PieChartData(
                    sections: [
                   PieChartSectionData(
  value: thermicPercentage.toDouble(),
  color: gasColor,
  title: '${thermicPercentage.toStringAsFixed(0)}%',
  radius: 60,
  titleStyle: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  ),
),
PieChartSectionData(
  value: electricPercentage.toDouble(),
  color: electricColor,
  title: '${electricPercentage.toStringAsFixed(0)}%',
  radius: 60,
  titleStyle: const TextStyle(
    color: Colors.white,
    fontWeight: FontWeight.bold,
    fontSize: 16,
  ),
),
                    ],
                    sectionsSpace: 0,
                    centerSpaceRadius: 0,
                    startDegreeOffset: 270,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Légende à droite
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLegendRow(gasColor, 'Thermique ', '${thermicPercentage.toStringAsFixed(0)}%'),
                const SizedBox(height: 12),
                _buildLegendRow(electricColor, 'Électrique', '${electricPercentage.toStringAsFixed(0)}%'),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildLegendRow(Color color, String label, String percentage) {
  return Row(
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(width: 8),
      Text(
        percentage,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}

Widget _buildScheduledMaintenance() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('maintenances')
        .where('status', isEqualTo: 'planned')
        .snapshots(),
    builder: (context, snapshot) {
      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
      return _buildScheduledCard(
        context: context,
        count: count,
        title: 'Entretiens Planifiés',
        icon: Icons.calendar_today,
       color: _primaryColor,

        onTap: () => _showScheduledMaintenanceSheet(context),
      );
    },
  );
}
Widget _buildScheduledRepairs() {
  return StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('repairs')
        .where('status', isEqualTo: 'in_progress')
        .snapshots(),
    builder: (context, snapshot) {
      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
      return _buildScheduledCard(
        context: context,
        count: count,
        title: 'Réparations planifiées',
        icon: Icons.calendar_today,
       color: _primaryColor,

        onTap: () => _showScheduledRepairsSheet(context),
      );
    },
  );
}

Widget _buildScheduledCard({
  required BuildContext context,
  required int count,
  required String title,
  required IconData icon,
  required Color color,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      margin: EdgeInsets.symmetric(horizontal: 20),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min, // Ajouté
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1, // Ajouté
                    overflow: TextOverflow.ellipsis, // Ajouté
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: color,
                    )),
                SizedBox(height: 4), // Réduit l'espacement
                Text('$count interventions',
                    maxLines: 1, // Ajouté
                    overflow: TextOverflow.ellipsis, // Ajouté
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    )),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: color, size: 18),
        ],
      ),
    ),
  );
}
void _showScheduledMaintenanceSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _buildScheduledSheet(
      context,
      title: 'Entretiens Planifiés',
      stream: FirebaseFirestore.instance
          .collection('maintenances')
          .where('status', isEqualTo: 'planned')
          .snapshots(),
      builder: (doc) => _buildMaintenanceItem(doc),
    ),
  );
}

void _showScheduledRepairsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _buildScheduledSheet(
      context,
      title: 'Réparations planifiées',
      stream: FirebaseFirestore.instance
          .collection('repairs')
          .where('status', isEqualTo: 'in_progress')
          .snapshots(),
      builder: (doc) => _buildRepairItem(doc),
    ),
  );
}
Widget _buildMaintenanceItem(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final date = (data['scheduledDate'] as Timestamp).toDate();

  return FutureBuilder<DocumentSnapshot>(
    future: FirebaseFirestore.instance
        .collection('vehicles')
        .doc(data['vehicleId'])
        .get(),
    builder: (context, vehicleSnapshot) {
      if (!vehicleSnapshot.hasData) {
        return ListTile(
          title: Text('Chargement du véhicule...'),
        );
      }

      final vehicle = vehicleSnapshot.data!.data() as Map<String, dynamic>? ?? {};

      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.settings, color: Colors.blue),
        ),
        title: Text('${vehicle['marque'] ?? 'Marque inconnue'} ${vehicle['modele'] ?? 'Modèle inconnu'}'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['type'] ?? 'Type inconnu'),
            Text(DateFormat('dd/MM/yyyy').format(date)),
          ],
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: 18),
      );
    },
  );
}
Widget _buildRepairItem(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final vehicle = data['vehicleInfo'] ?? {};
  final date = (data['scheduledDate'] as Timestamp).toDate();

  return ListTile(
    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
    leading: Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.build, color: Colors.orange),
    ),
    title: Text('${vehicle['marque']} ${vehicle['modele']}'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data['description'] ?? 'Description non disponible'),
        Text(DateFormat('dd/MM/yyyy').format(date)),
      ],
    ),
    trailing: Icon(Icons.arrow_forward_ios, size: 18),
     onTap: null, 
  );
}

Widget _buildScheduledSheet(BuildContext context, {
  required String title,
  required Stream<QuerySnapshot> stream,
  required Widget Function(DocumentSnapshot) builder,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        constraints: BoxConstraints(
          maxHeight: constraints.maxHeight * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _textColor,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: stream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  
                  if (docs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Aucun élément à afficher',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    physics: BouncingScrollPhysics(),
                    padding: EdgeInsets.only(bottom: 16),
                    itemCount: docs.length,
                    itemBuilder: (context, index) => builder(docs[index]),
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
Widget _buildAlertStatus() {
  return StreamBuilder<QuerySnapshot>(
    stream: _alertService.getActiveAlerts(),
    builder: (context, snapshot) {
      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
      return GestureDetector(
        onTap: () => _showAlertsBottomSheet(context),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1), // ✅ Fond modifié
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.warning_rounded,
                    color: count > 0 ? Colors.red : Colors.grey,
                    size: 28,
                  ),
                  if (count > 0)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          count.toString(),
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              const Text(
                'Entretien à prévoir',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}


Widget _buildAlertNotificationIcon() {
  return StreamBuilder<QuerySnapshot>(
    stream: _alertService.getActiveAlerts(),
    builder: (context, snapshot) {
      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        mainAxisSize: MainAxisSize.min, // Modifié ici
        children: [
          Flexible( // Ajout d'un Flexible
            child: Text(
              'Tableau de Bord',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
              overflow: TextOverflow.ellipsis, // Gestion du débordement
              maxLines: 1,
            ),
          ),
          SizedBox(width: 8), // Espacement ajouté
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: Icon(
                  Icons.warning_rounded,
                  color: count > 0 ? Colors.redAccent : Colors.white54,
                  size: 32, // Taille réduite
                ),
                padding: EdgeInsets.all(4), // Padding ajusté
                onPressed: () => _showAlertsBottomSheet(context),
              ),
              if (count > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: EdgeInsets.all(4), // Taille réduite
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      count.toString(),
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 10, // Taille de police réduite
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
}
void _showAlertsBottomSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return AnimatedContainer(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeOut,
            margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
            ),
            constraints: BoxConstraints(
              maxHeight: constraints.maxHeight * 0.9, // 90% de la hauteur disponible
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle drag
                Padding(
                  padding: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                
                // Titre
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Entretien à prévoir ',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                
                // Liste d'alertes avec scroll
                Expanded( // Utilisation de Expanded pour le contenu scrollable
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _alertService.getActiveAlerts(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }
                      final alerts = snapshot.data!.docs;
                      
                      if (alerts.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              'Aucune alerte active',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }
                      
                      return ListView.builder( // Remplacement par ListView
                        physics: BouncingScrollPhysics(),
                        padding: EdgeInsets.only(bottom: 16),
                        itemCount: alerts.length,
                        itemBuilder: (context, index) {
                          return _buildAlertCard(alerts[index]);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
Widget _buildAlertCard(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final vehicle = data['vehicleData'];
  final type = data['typeData'];
  final Color _primaryColor = const Color(0xFF6C5CE7);

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    elevation: 0,
    color: Colors.transparent,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(4, 4),
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.6),
            blurRadius: 20,
            offset: const Offset(-4, -4),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.5,
        ),
        backgroundBlendMode: BlendMode.overlay,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Alert Indicator
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.redAccent,
                            Colors.red.shade400,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.redAccent.withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.warning_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Vehicle Info
                    Expanded(
                      child: Text(
                        '${vehicle['marque']} ${vehicle['modele']}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),

                    // Km Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.blueGrey.shade100,
                            Colors.blueGrey.shade50,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.speed, size: 16, color: Colors.blueGrey.shade600),
                          const SizedBox(width: 4),
                          Text(
                            '${data['currentKm']?.toStringAsFixed(0) ?? '0'} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blueGrey.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Alert Type
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _primaryColor.withOpacity(0.2),
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    type['name'],
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: _primaryColor,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    // Planifier Button
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MaintenancePlanningScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_today, size: 16, color: Colors.white),
                     label: const Text(
  'PLANIFIER',
  style: TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.bold,
    color: Colors.white, // Couleur du texte en blanc
  ),
),

                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 4,
                          shadowColor: _primaryColor.withOpacity(0.3),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Ignorer Button
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("Confirmer la suppression"),
                              content: const Text("Voulez-vous vraiment ignorer définitivement cette alerte ?"),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text("Annuler"),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text(
                                    "Supprimer",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            _alertService.deleteAlert(doc.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Alerte supprimée avec succès"),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.grey.shade700),
                        label: Text(
                          'IGNORER',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                            color: Colors.grey.shade400,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _buildAppBarTitleWithNotification() {
  final String? driverEmail = _auth.currentUser?.email;

  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('missions')
        .where('driver', isEqualTo: driverEmail)
        .where('status', isEqualTo: 'En cours')
        .snapshots(),
    builder: (context, snapshot) {
      final count = snapshot.hasData ? snapshot.data!.docs.length : 0;

      return Stack(
        alignment: Alignment.center,
        children: [
          // Texte centré
          const Text(
            'Tableau de Bord',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications, color: Colors.white),
                  iconSize: 32,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () {
                    if (widget.role == 'Chauffeur') {
                      Navigator.pushNamed(context, '/missions');
                    }
                  },
                ),
                if (count > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 22,
                        minHeight: 22,
                      ),
                      child: Center(
                        child: Text(
                          count > 9 ? '9+' : count.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
Widget _buildAdminHeader() {
  return Column(
    children: [
      Center(
        child: Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryColor, _secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _primaryColor.withOpacity(0.3),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.verified_user_rounded,
              size: 55,
              color: Colors.white,
            ),
          ),
        ),
      ),
      const SizedBox(height: 25),
      AnimatedOpacity(
        duration: Duration(milliseconds: 500),
        opacity: 1.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenue Admin',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w600,
                color: _textColor,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.waving_hand_rounded,
              color: Colors.amber,
              size: 28,
            ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Tableau de bord admin ',
        style: TextStyle(
          fontSize: 16,
          color: Colors.grey.shade600,
        ),
      ),
    ],
  );
}



Widget _buildChauffeurHeader() {
  return StreamBuilder<DocumentSnapshot>(
    stream: _firestore.collection('users').doc(_auth.currentUser?.uid).snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox();

      final userData = snapshot.data!.data() as Map<String, dynamic>;

      return Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryColor.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.person,
                      size: 60,
                      color: _primaryColor,
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            userData['name'] ?? '',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            userData['email'] ?? '',
            style: TextStyle(
              color: _textColor.withOpacity(0.7),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildChauffeurStats() {
  final String? driverEmail = _auth.currentUser?.email;

  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('missions')
        .where('driver', isEqualTo: driverEmail)
        .snapshots(),
    builder: (context, mainSnapshot) {
      if (!mainSnapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final allMissions = mainSnapshot.data!.docs;
      final completed = allMissions.where((d) => d['status'] == 'Terminée').length;
      final inProgress = allMissions.length - completed;

      return Column(
        children: [
          const SizedBox(height: 20),

         
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStatCard(
                      title: 'Terminées',
                      count: completed,
                      color: _secondaryColor,
                      icon: Icons.check_circle_outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStatCard(
                      title: 'En cours',
                      count: inProgress,
                      color: _alertColor,
                      icon: Icons.timer_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),
        ],
      );
    },
  );
}
Widget _buildAdminStats() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('users').snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final allUsers = snapshot.data!.docs;
      final totalUsers = allUsers.length;
      final chauffeurs = allUsers.where((u) => u['role'] == 'Chauffeur').length;
      final responsables = allUsers.where((u) => u['role'] == 'Responsable de parc').length;

      return Column(
        children: [
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStatCard(
                      title: 'Utilisateurs',
                      count: totalUsers,
                      color: _primaryColor,
                      icon: Icons.people_alt,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStatCard(
                      title: 'Chauffeurs',
                      count: chauffeurs,
                      color: _secondaryColor,
                      icon: Icons.drive_eta,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () {},
                    borderRadius: BorderRadius.circular(15),
                    child: _buildStatCard(
                      title: 'Responsables',
                      count: responsables,
                      color: _alertColor,
                      icon: Icons.engineering,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      );
    },
  );
}





Widget _buildStatCard({
  required String title,
  required int count,
  required Color color,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 10),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              color: color,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMissionItem({required String title, required String date, required String status}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _backgroundColor,
      borderRadius: BorderRadius.circular(12),),
    child: Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: _statusColor(status),
            borderRadius: BorderRadius.circular(20)),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: _textColor)),
              const SizedBox(height: 4),
              Text(date,
                  style: TextStyle(
                    fontSize: 12,
                    color: _textColor.withOpacity(0.6))),
            ],
          ),
        ),
        Chip(
          label: Text(status),
          backgroundColor: _statusColor(status).withOpacity(0.1),
          labelStyle: TextStyle(
            color: _statusColor(status),
            fontSize: 12),
          side: BorderSide.none,
        ),
      ],
    ),
  );
}
  Color _statusColor(String status) {
  switch (status.toLowerCase()) {
    case 'terminée': return _secondaryColor;
    case 'en cours': return _alertColor;
    case 'disponible': return Colors.green;
    case 'en mission': return Colors.red;
    default: return Colors.grey;
  }
}Widget _buildModernDrawer() {
  return Drawer(
    width: 280,
    child: Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryColor.withOpacity(0.97), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ajout de l'image sans cadre
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/images/image.png'),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  'FleetSync Pro',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
                Text(
                  'Gestion de Parc Véhicules',
                  style: TextStyle(
                    fontSize: 14,
                    color: _textColor.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ..._buildDrawerItems(),
                  const Divider(height: 40, indent: 20, endIndent: 20),
                  _buildLogoutTile(),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  List<Widget> _buildDrawerItems() {
    final List<Map<String, dynamic>> menuItems = [

  {'title': 'Gestion des véhicules', 'icon': Icons.directions_car, 'route': '/vehicles'},
      {'title': 'Statistiques de consommation', 'icon': Icons.bar_chart, 'route': '/consoma'},
    {'title': 'Gestion des garages', 'icon': Icons.garage, 'route': '/garage'},
  {'title': 'Gestion des marques', 'icon': Icons.factory, 'route': '/marque'},
  {'title': 'Gestion des modèles', 'icon': Icons.model_training, 'route': '/models'},
  {'title': 'Liste des chauffeurs', 'icon': Icons.people, 'route': '/ch'},
  {
    'title': 'Gestion des maintenances',
    'icon': Icons.build,
    'route': '/main', 
    'children': [
      {'title': 'Gestion des entretiens', 'icon': Icons.settings_suggest, 'route': '/entre'},
      {'title': 'Gestion des réparations', 'icon': Icons.construction, 'route': '/repair2'},
    ]
  },
  {'title': 'Gestion des missions', 'icon': Icons.assignment, 'route': '/missions'},
  {'title': 'Gestion des assurances', 'icon': Icons.security, 'route': '/assurance'},
  {'title': 'Gestion des pièces utilisées', 'icon': Icons.miscellaneous_services, 'route': '/piece'},
  {'title': 'Gestion des types d’entretien', 'icon': Icons.settings_suggest, 'route': '/type'},
    {'title': 'Gestion des incidents', 'icon': Icons.report_problem, 'route': '/incident_list'},
    {'title': 'Suivi & Planning des chauffeurs', 'icon': Icons.event_note, 'route': '/admin'},

];

       return menuItems.map((item) => Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => Navigator.pushNamed(context, item['route'].toString()),
          child: ListTile(
            leading: Icon(item['icon'], 
                color: _textColor.withOpacity(0.8), 
                size: 26),
            title: Text(item['title'],
                style: TextStyle(
                  color: _textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                )),
            trailing: Icon(Icons.arrow_forward_ios_rounded, 
                color: _textColor.withOpacity(0.5), 
                size: 18),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    )).toList();
  }
   Widget _buildLogoutTile() {
    return Container(
      margin: const EdgeInsets.all(12),
      child: Material(
        borderRadius: BorderRadius.circular(15),
        color: Colors.red.withOpacity(0.1),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: _logout,
          child: ListTile(
            leading: Icon(Icons.logout, 
                color: Colors.red[400], 
                size: 26),
            title: Text('Déconnexion',
                style: TextStyle(
                  color: Colors.red[400],
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                )),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
    );
  }
Widget _buildStatsRow() {
  return Row(
    children: [
      Expanded(child: _buildVehicleAvailabilityStream()),
      const SizedBox(width: 10),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('users').where('role', isEqualTo: 'Chauffeur').snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return _buildStyledStatCard(
             icon: Icons.person_rounded, // Icône pour chauffeur
              count: count,
              label: 'Chauffeurs',
              color: Colors.teal,
              background: Colors.tealAccent.withOpacity(0.2),
            );
          },
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('missions').where('status', isEqualTo: 'En cours').snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.hasData ? snapshot.data!.docs.length : 0;
            return _buildStyledStatCard(
              icon: Icons.work_history, // Icône pour missions
              count: count,
              label: 'Missions',
              color: Colors.deepOrange,
              background: Colors.deepOrangeAccent.withOpacity(0.2),
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildVehicleAvailabilityStream() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore.collection('vehicles').snapshots(),
    builder: (context, vehiclesSnapshot) {
      if (!vehiclesSnapshot.hasData) return SizedBox();

      return StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('repairs').where('status', isEqualTo: 'in_progress').snapshots(),
        builder: (context, repairsSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('maintenances').where('status', whereIn: ['planned', 'in_progress']).snapshots(),
            builder: (context, maintenancesSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('missions').where('status', isEqualTo: 'En cours').snapshots(),
                builder: (context, missionsSnapshot) {
                  List<String> unavailableIds = [];

                  if (repairsSnapshot.hasData) {
                    unavailableIds.addAll(repairsSnapshot.data!.docs.map((doc) => doc['vehicleId'] as String));
                  }
                  if (maintenancesSnapshot.hasData) {
                    unavailableIds.addAll(maintenancesSnapshot.data!.docs.map((doc) => doc['vehicleId'] as String));
                  }
                  if (missionsSnapshot.hasData) {
                    unavailableIds.addAll(missionsSnapshot.data!.docs.map((doc) => doc['vehicleId'] as String));
                  }

                  final uniqueIds = unavailableIds.toSet();
                  final availableCount = vehiclesSnapshot.data!.docs.where((doc) => !uniqueIds.contains(doc.id)).length;

                  return _buildStyledStatCard(
                    icon: Icons.directions_bus_filled, // Icône véhicule
                    count: availableCount,
                    label: 'Véhicules',
                   color: _primaryColor, // ✅ Couleur d'origine conservée
  background: _primaryColor.withOpacity(0.1),
                  );
                },
              );
            },
          );
        },
      );
    },
  );
}

Widget _buildStyledStatCard({
  required IconData icon,
  required int count,
  required String label,
  required Color color,
  required Color background,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 36, color: color),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}


  Widget _buildConsumptionChart() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8),
        ],
      ),
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

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thermalVehicles.isNotEmpty) ...[
                _buildChartSection(
                  title: 'Consommation Thermique (L/100km)',
                  data: fuelConsumption,
                  color: _primaryColor,
                  unit: 'L',
                ),
                const SizedBox(height: 20),
              ],
              if (electricVehicles.isNotEmpty) ...[
                _buildChartSection(
                  title: 'État Batterie Électrique (%)',
                  data: batteryLevels,
                  color: _secondaryColor,
                  unit: '%',
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  double _safeParseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0;
  }

  Widget _buildChartSection({
    required String title,
    required List<double> data,
    required Color color,
    required String unit,
  }) {
    final double maxY = data.isNotEmpty 
        ? (data.reduce((a, b) => a > b ? a : b) + 5).toDouble()
        : 20.0;

    return Column(
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
              barTouchData: BarTouchData(enabled: false),
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
                      toY: data[index].toDouble(), 
                      width: 20,
                      borderRadius: BorderRadius.circular(8),
                      color: color,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



Widget _buildAlertItem(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  final vehicleData = data['vehicleData'] as Map<String, dynamic>;
  final typeData = data['typeData'] as Map<String, dynamic>;
  final isNewVehicle = data['alertType'] == 'premiere';

  return ListTile(
    leading: Icon(Icons.warning, color: Colors.orange),
    title: Text('${vehicleData['marque']} ${vehicleData['modele']}'),
    subtitle: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('KM actuel: ${data['currentKm'].toStringAsFixed(0)}'),
        if(isNewVehicle)
          Text('Premier entretien requis à: ${data['threshold'].toStringAsFixed(0)} km')
        else
          Text('Prochain entretien à: ${data['threshold'].toStringAsFixed(0)} km'),
        Text('Marge d\'alerte: ${data['alertMargin']}%'),
      ],
    ),
    onTap: isNewVehicle ? null : () => _resolveAlert(doc),
    trailing: isNewVehicle 
        ? const Icon(Icons.info_outline, color: Colors.grey)
        : const Icon(Icons.build, color: Colors.blue),
  );
}
    void _handleAlertAction(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    Navigator.pushNamed(
      context,
      '/planification-entretien',
      arguments: {
        'vehicleId': data['vehicleId'],
        'typeData': data['typeData'],
        'alertId': doc.id,
        'prefilled': {
          'tasks': List<String>.from(data['typeData']['tasks']),
          'currentKm': data['currentKm'],
          'threshold': data['threshold'],
          'alertMargin': data['alertMargin'],
        }
      },
    ).then((_) => setState(() {})); // Rafraîchir après retour
  }
void _resolveAlert(DocumentSnapshot alertDoc) async {
  final alertData = alertDoc.data() as Map<String, dynamic>;
  
  Navigator.pushNamed(
    context,
    '/entre',
    arguments: {
      'vehicleId': alertData['vehicleId'],
      'prefilledData': {
        'type': alertData['typeData']['name'],
        'tasks': alertData['typeData']['tasks'],
        'currentKm': alertData['currentKm'],
        'vehicleInfo': '${alertData['vehicleData']['marque']} ${alertData['vehicleData']['modele']}'
      }
    },
  );
  
  await _alertService.deleteAlert(alertDoc.id);
}

 Widget _buildQuickAccessMenu() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accès rapide',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor)),
        const SizedBox(height: 15),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          childAspectRatio: 0.9,
          children: [
            _buildNavButton(Icons.directions_car, 'Véhicules', '/vehicles'),
            _buildNavButton(Icons.security, 'Assurance ', '/assurance'),
            _buildNavButton(Icons.assignment, 'Missions', '/missions'),
            _buildNavButton(Icons.build, 'Maintenance', '/main'),
          
            if (widget.role == 'admin' || widget.role == 'Chauffeur')
              _buildNavButton(Icons.schedule, 'Horaires', 
                widget.role == 'admin' ? '/admin' : '/driver')
          ],
        ),
      ],
    ),
  );
}
  Widget _buildNavButton(IconData icon, String label, String route) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: _primaryColor.withOpacity(0.1),
          radius: 26,
          child: IconButton(
            icon: Icon(icon, color: _primaryColor, size: 28),
            onPressed: () => Navigator.pushNamed(context, route),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: TextStyle(
              color: _textColor,
              fontSize: 12,
              fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildBottomNavBar() {
  return BottomNavigationBar(
    backgroundColor: Colors.white,
    selectedItemColor: _primaryColor,
    unselectedItemColor: _textColor.withOpacity(0.5),
    showUnselectedLabels: true,
    elevation: 5,
    items: widget.role == 'admin'
        ? [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home), 
              label: 'Accueil'
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.person), 
              label: 'Utilisateurs'
            ),
       
          ]
        : widget.role == 'Chauffeur'
          ? [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home), 
                label: 'Accueil'
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.assignment), 
                label: 'Missions'
              ),
              // Ajout pour chauffeur
              const BottomNavigationBarItem(
                icon: Icon(Icons.schedule), 
                label: 'Disponibilité'
              ),
            ]
            : [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home), 
                  label: 'Accueil'),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.directions_car), 
                  label: 'Véhicules'),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.people), 
                  label: 'Chauffeurs'),
              ],
    currentIndex: 0,
    onTap: (index) => _handleNavTap(index, context),
  );
}
  String _formatDate(Timestamp? date) {
    return date != null 
        ? DateFormat('dd/MM/yyyy').format(date.toDate())
        : 'Date inconnue';
  }

  void _handleNavTap(int index, BuildContext context) {
  if (widget.role == 'admin') {
    switch (index) {
      case 0:
        // Accueil
        break;
      case 1:
        Navigator.pushNamed(context, '/users');
        break;
      case 2:
        Navigator.pushNamed(context, '/admin');
        break;
    }
  } else if (widget.role == 'Chauffeur') {
    switch (index) {
      case 0:
        // Accueil
        break;
      case 1:
        Navigator.pushNamed(context, '/missions');
        break;
      case 2:
        Navigator.pushNamed(context, '/driver');
        break;
    }
  } else {
    // Autres rôles
    switch (index) {
      case 0:
        // Accueil
        break;
      case 1:
        Navigator.pushNamed(context, '/vehicles');
        break;
      case 2:
        Navigator.pushNamed(context, '/chauffeur');
        break;
    }
  }
}
  Future<void> _logout() async {
    await _auth.signOut();
    Navigator.of(context).pushReplacementNamed('/login');
  }
}