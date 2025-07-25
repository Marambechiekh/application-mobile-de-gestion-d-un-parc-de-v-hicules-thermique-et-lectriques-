import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_application_2/BrandManagementScreenState.dart';
import 'package:flutter_application_2/ChauffeursListScreen.dart';
import 'package:flutter_application_2/ConsumptionStatsScreen.dart';
import 'package:flutter_application_2/DashboardScreen.dart';
import 'package:flutter_application_2/DriverDetailScreen.dart';
import 'package:flutter_application_2/EcranGestionMaintenance.dart';
import 'package:flutter_application_2/EditModelScreen';
import 'package:flutter_application_2/DriverDetailScreen.dart';
import 'package:flutter_application_2/EditVehicleScreen.dart';
import 'package:flutter_application_2/GarageManagementScreen.dart';
import 'package:flutter_application_2/IncidentReportScreen.dart';
import 'package:flutter_application_2/InsuranceManagementScreen.dart';
import 'package:flutter_application_2/MaintenanceManagementScreen.dart';
import 'package:flutter_application_2/MaintenanceStatistics.dart';
import 'package:flutter_application_2/MaintenanceTypeScreen%20.dart';
import 'package:flutter_application_2/PartsManagementScreen.dart';
import 'package:flutter_application_2/PlanRepairScreen.dart';
import 'package:flutter_application_2/RepairManagementScreen.dart';
import 'package:flutter_application_2/RepairStatistics.dart';
import 'package:flutter_application_2/ScheduleManagementScreen.dart';
import 'package:flutter_application_2/TableauBordGestionEquipes.dart';
import 'package:flutter_application_2/VehicleAddScreen.dart';
import 'package:flutter_application_2/VehiclesScreen.dart';
import 'package:flutter_application_2/execute_repair_screen.dart';
import 'package:flutter_application_2/login_screen.dart';
import 'package:flutter_application_2/register_screen.dart';
import 'package:flutter_application_2/vehicle_details_screen.dart';
import 'package:flutter_application_2/user_management_screen.dart';
import 'package:flutter_application_2/add_user_screen.dart';
import 'package:flutter_application_2/edit_user_screen.dart';
import 'package:flutter_application_2/DriversScreen.dart';
import 'package:flutter_application_2/AddDriverScreen.dart';
import 'package:flutter_application_2/EditDriverScreen.dart';
import 'package:flutter_application_2/create_mission_screen.dart';
import 'package:flutter_application_2/edit_mission_screen.dart';
import 'package:flutter_application_2/missions_screen.dart';
import 'package:flutter_application_2/validate_mission_screen.dart';
import 'package:flutter_application_2/models_list.dart';
import 'package:flutter_application_2/model_form.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = 
    FlutterLocalNotificationsPlugin();
void main() async {
  
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
    FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
  );
    const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      
  final InitializationSettings initializationSettings = 
      InitializationSettings(
        android: initializationSettingsAndroid,
      );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Parc Véhicules',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue.shade800,
        fontFamily: 'Roboto',
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.orange.shade600,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade800,
         foregroundColor: Colors.white,

        ),
      ),
      initialRoute: '/login', 
      routes: {
        '/': (context) => DashboardScreen(role: 'Chauffeur'),
        '/login': (context) => LoginScreen(),
        '/register': (context) => RegisterScreen(),
        '/vehicles': (context) => VehiclesScreen(),
        '/add': (context) => AddVehicleScreen(),
        '/users': (context) => UserManagementScreen(),
        '/addUser': (context) => AddUserScreen(),
       
        '/addDriver': (context) => AddDriverScreen(),
        '/missions': (context) => MissionsScreen(), 
        '/createMission': (context) => CreateMissionScreen(),
        '/models': (context) => ModelsListScreen(),
        '/addModel': (context) => ModelFormScreen(),
        '/garage': (context) => GarageManagementScreen(),
        '/repair': (context) => PlanRepairScreen(),
        '/repair2': (context) => RepairManagementScreen(),
        '/entre': (context) => MaintenanceManagementScreen(),
        '/main': (context) => EcranGestionMaintenance(),
        '/exrepair': (context) => ExecuteRepairScreen(repairId: ''),
        '/ch': (context) => ChauffeurListScreen(),
       '/assurance': (context) =>InsuranceManagementScreen (),
      '/marque': (context) =>BrandManagementScreen (),
      '/statentre': (context) =>MaintenanceStatistics (),
      '/statrepair': (context) =>RepairStatistics (),
       '/type': (context) =>MaintenanceTypeScreen (),
       '/piece': (context) =>PartsManagementScreen (),
       '/incident_report': (context) => IncidentReportScreen(),
    '/incident_list': (context) => IncidentListScreen(),
    '/consoma': (context) => ConsumptionStatsScreen(),
      '/admin': (context) => ScheduleManagementScreen(),
      '/driver': (context) => DriverScheduleScreen(),
       '/chauffeur': (context) => TableauBordGestionEquipes(),
        },
   
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/edit':
            return MaterialPageRoute(
              builder: (context) => EditVehicleScreen(
                vehicleId: settings.arguments as String,
              ),
            );

          case '/editUser':
            return MaterialPageRoute(
              builder: (context) => EditUserScreen(
                userId: settings.arguments as String,
              ),
            );

          case '/editDriver':
            return MaterialPageRoute(
              builder: (context) => EditDriverScreen(
                driverId: settings.arguments as String,
              ),
            );

          case '/editMission':
            return MaterialPageRoute(
              builder: (context) => EditMissionScreen(
                mission: settings.arguments as QueryDocumentSnapshot<Object?>,
              ),
            );

          case '/validateMission':
            return MaterialPageRoute(
              builder: (context) => ValidateMissionScreen(
                mission: settings.arguments as QueryDocumentSnapshot<Object?>,
              ),
            );

          case '/editModel':
            return MaterialPageRoute(
              builder: (context) => EditModelScreen(
                modelDoc: settings.arguments as DocumentSnapshot,
              ),
            );

          case '/details':
            return MaterialPageRoute(
              builder: (context) => VehicleDetailsScreen(
                vehicleId: settings.arguments as String,
              ),
            );

          case '/driverDetail':
            return MaterialPageRoute(
              builder: (context) => DriverDetailScreen(
                driverId: settings.arguments as String,
              ),
            );
          default:
            return MaterialPageRoute(
              builder: (context) => const Scaffold(
                body: Center(child: Text('Page non trouvée')),
              ),
            );
        }
      },
    );
  }
}
