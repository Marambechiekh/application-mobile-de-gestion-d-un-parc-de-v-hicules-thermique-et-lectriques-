import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_auth/firebase_auth.dart';

void main() {
  runApp(MaterialApp(
    home: ScheduleManagementScreen(),
  ));
}

class ScheduleManagementScreen extends StatefulWidget {
  @override
  _ScheduleManagementScreenState createState() => _ScheduleManagementScreenState();
}

class _ScheduleManagementScreenState extends State<ScheduleManagementScreen> {
  final Color _primaryColor = Color(0xFF6C5CE7);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  bool _isDateFormatInitialized = false;
  List<Map<String, dynamic>> _drivers = [];
  bool _isLoadingDrivers = true;
  List<bool> _selectedDays = List.generate(7, (index) => false);
  final List<String> _weekDays = ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _approvedAbsences = [];
  String _searchQuerySchedule = '';
  final TextEditingController _searchControllerSchedule = TextEditingController();
  int _pendingAbsenceCount = 0;
  
  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _loadDrivers();
    _loadApprovedAbsences(); 
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchControllerSchedule.dispose();
    super.dispose();
  }

  Future<void> _initializeDateFormatting() async {
    if (!_isDateFormatInitialized) {
      await initializeDateFormatting('fr_FR', null);
      setState(() {
        _isDateFormatInitialized = true;
      });
    }
  }
  
  Future<void> _loadApprovedAbsences() async {
    try {
      final snapshot = await _firestore
          .collection('absence_requests')
          .where('status', isEqualTo: 'Approuvée')
          .get();

      setState(() {
        _approvedAbsences = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'driverId': data['driverId'],
            'startDate': (data['startDate'] as Timestamp).toDate(),
            'endDate': (data['endDate'] as Timestamp).toDate(),
          };
        }).toList();
      });
    } catch (e) {
      print("Erreur de chargement des absences approuvées: $e");
    }
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoadingDrivers = true);
    
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'Chauffeur')
          .get();

      final drivers = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'uid': data['uid'] ?? doc.id,
          'name': data['name']?.toString() ?? 'Nom inconnu',
          'status': data['status'] ?? 'present',
          'lastStatusUpdate': data['lastStatusUpdate'],
        };
      }).toList();

      // Vérifier et mettre à jour les statuts expirés
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final batch = FirebaseFirestore.instance.batch();
      bool needsUpdate = false;

      for (final driver in drivers) {
        if (driver['status'] == 'absent') {
          final lastUpdate = driver['lastStatusUpdate'] as Timestamp?;
          
          if (lastUpdate == null) {
            // Si pas de date, marquer comme présent
            driver['status'] = 'present';
            needsUpdate = true;
            batch.update(
              _firestore.collection('users').doc(driver['id']),
              {'status': 'present', 'lastStatusUpdate': Timestamp.now()},
            );
          } else {
            final lastUpdateDate = lastUpdate.toDate();
            final lastUpdateDay = DateTime(
              lastUpdateDate.year, 
              lastUpdateDate.month, 
              lastUpdateDate.day
            );

            if (lastUpdateDay.isBefore(todayMidnight)) {
              // Mise à jour automatique si l'absence date d'avant aujourd'hui
              driver['status'] = 'present';
              needsUpdate = true;
              batch.update(
                _firestore.collection('users').doc(driver['id']),
                {'status': 'present', 'lastStatusUpdate': Timestamp.now()},
              );
            }
          }
        }
      }

      if (needsUpdate) {
        await batch.commit();
      }

      setState(() {
        _drivers = drivers;
        _isLoadingDrivers = false;
      });
    } catch (e) {
      print("Erreur de chargement des chauffeurs: $e");
      setState(() => _isLoadingDrivers = false);
    }
  }

  Future<void> _updateDriverStatus(String driverId, String status) async {
    try {
      await _firestore.collection('users').doc(driverId).update({
        'status': status,
        'lastStatusUpdate': Timestamp.now(),
      });
      _loadDrivers();
    } catch (e) {
      print("Erreur de mise à jour du statut: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la mise à jour du statut"),
          backgroundColor: Colors.red,
        )
      );
    }
  }

 @override
Widget build(BuildContext context) {
  if (!_isDateFormatInitialized) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
        ),
      ),
    );
  }

  return Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      title: Text(
        "Gestion des horaires",
        textAlign: TextAlign.center,
      ),
      centerTitle: true,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
    ),
    body: Column(
      children: [
        _buildWeekSelector(),
        const SizedBox(height: 16),
        Expanded(
          child: DefaultTabController(
            length: 4,
            child: Column(
              children: [
                TabBar(
                  labelColor: _primaryColor,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _primaryColor,
                  tabs: [
                    const Tab(icon: Icon(Icons.calendar_today)),
                    Tab(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).brightness == Brightness.light
                                ? Colors.grey[300]!
                                : Colors.grey[700]!,
                          ),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(Icons.notifications),
                            if (_pendingAbsenceCount > 0)
                              Positioned(
                                right: -6,
                                top: -6,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    _pendingAbsenceCount > 9 ? '9+' : '$_pendingAbsenceCount',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const Tab(icon: Icon(Icons.people)),
                    const Tab(icon: Icon(Icons.history)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildDriversSchedule(),
                      _buildAbsenceRequests(),
                      _buildDriverPresenceTab(),
                      _buildAbsenceHistoryTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton(
      backgroundColor: _primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
      onPressed: () => _showAddWeeklyScheduleDialog(context),
    ),
  );
}
 Widget _buildAbsenceHistoryTab() {
  return StreamBuilder<QuerySnapshot>(
    stream: _firestore
        .collection('absence_requests')
        .where('status', whereIn: ['Approuvée', 'Refusée'])
        .snapshots(), 
    builder: (context, snapshot) {
      if (!snapshot.hasData) return _buildLoading();
      if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');

      final requests = snapshot.data!.docs;
      
      // Trier manuellement par processedAt décroissant
      requests.sort((a, b) {
        Timestamp? aTime = a['processedAt'] as Timestamp?;
        Timestamp? bTime = b['processedAt'] as Timestamp?;
        
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        
        return bTime.compareTo(aTime); // Ordre décroissant
      });
      
      if (requests.isEmpty) return _buildEmptyState("Aucune demande dans l'historique");
      
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final request = requests[index];
          return _buildAbsenceHistoryCard(request);
        },
      );
    },
  );
}
  Widget _buildAbsenceHistoryCard(DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    final status = data['status'];
    final statusColor = status == 'Approuvée' ? Colors.green : Colors.red;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            status == 'Approuvée' ? Icons.check : Icons.close,
            color: statusColor,
          ),
        ),
        title: Text(
          data['driverName'],
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              "${DateFormat('dd/MM/yyyy').format(data['startDate'].toDate())} - ${DateFormat('dd/MM/yyyy').format(data['endDate'].toDate())}",
            ),
            Text(
              data['reason'],
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            if (data['processedAt'] != null)
              Text(
                "Traité le: ${DateFormat('dd/MM/yyyy à HH:mm').format(data['processedAt'].toDate())}",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildDriverPresenceTab() {
    if (_isLoadingDrivers) {
      return Center(child: CircularProgressIndicator());
    }
    if (_drivers.isEmpty) {
      return Center(
        child: Text(
          "Aucun chauffeur disponible",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      );
    }
    final filteredDrivers = _searchQuery.isEmpty
        ? _drivers
        : _drivers.where((driver) {
            final name = driver['name'].toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase());
          }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              labelText: 'Rechercher un chauffeur',
              prefixIcon: Icon(Icons.search, color: _primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredDrivers.length,
            itemBuilder: (context, index) {
              final driver = filteredDrivers[index];
              return _buildDriverPresenceCard(driver);
            },
          ),
        ),
      ],
    );
  }
  Widget _buildDriverPresenceCard(Map<String, dynamic> driver) {
    final today = DateTime.now();
    final isAbsent = _approvedAbsences.any((absence) {
      return absence['driverId'] == driver['id'] &&
          today.isAfter(absence['startDate'].subtract(const Duration(days: 1))) &&
          today.isBefore(absence['endDate'].add(const Duration(days: 1)));
    });
    final statusColor = isAbsent ? Colors.red : Colors.green;
    final statusText = isAbsent ? 'Absent' : 'Présent';
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: _primaryColor),
                ),
                const SizedBox(width: 16),
                Text(
                  driver['name'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: _primaryColor),
            onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7))),
          ),
          Column(
            children: [
              Text(
                "Semaine ${DateFormat('w').format(_selectedDate)}",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                "${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM').format(endOfWeek)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: _primaryColor),
            onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _buildDriversSchedule() {
    if (_isLoadingDrivers) {
      return Center(child: CircularProgressIndicator());
    }
    
    final filteredDrivers = _searchQuerySchedule.isEmpty
        ? _drivers
        : _drivers.where((driver) {
            final name = driver['name'].toString().toLowerCase();
            return name.contains(_searchQuerySchedule.toLowerCase());
          }).toList();

    if (filteredDrivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              "Aucun chauffeur trouvé",
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            controller: _searchControllerSchedule,
            onChanged: (value) => setState(() => _searchQuerySchedule = value),
            decoration: InputDecoration(
              labelText: 'Rechercher un chauffeur',
              hintText: 'Entrez le nom d\'un chauffeur...',
              prefixIcon: Icon(Icons.search, color: _primaryColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            itemCount: filteredDrivers.length,
            itemBuilder: (context, index) {
              final driver = filteredDrivers[index];
              return _buildDriverCard(driver);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: _primaryColor),
                ),
                const SizedBox(width: 16),
                Text(
                  driver['name'],
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              "Planning du ${DateFormat('dd/MM/yyyy').format(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)))} au ${DateFormat('dd/MM/yyyy').format(_selectedDate.subtract(Duration(days: _selectedDate.weekday - 1)).add(Duration(days: 6)))}",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _buildDriverScheduleTable(driver),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverScheduleTable(Map<String, dynamic> driver) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(3),
      },
      border: TableBorder.all(color: Colors.grey.shade300, width: 0.5),
      children: [
        TableRow(
          decoration: BoxDecoration(color: _primaryColor.withOpacity(0.1)),
          children: [
            _buildHeaderCell("Jour"),
            _buildHeaderCell("Horaire"),
            _buildHeaderCell("Actions"),
          ],
        ),
        for (int i = 0; i < 7; i++)
          _buildDriverScheduleRow(driver, startOfWeek.add(Duration(days: i))),
      ],
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  TableRow _buildDriverScheduleRow(Map<String, dynamic> driver, DateTime dayDate) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
    
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            _getShortDayName(dayDate),
            style: TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('schedules')
              .where('driverId', isEqualTo: driver['id'])
              .where('date', isEqualTo: formattedDate)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return _buildTextCell("...");
            }
            if (snapshot.hasError) {
              return _buildTextCell("Erreur", color: Colors.red);
            }

            final schedules = snapshot.data!.docs;
            if (schedules.isEmpty) {
              return _buildTextCell("-", color: Colors.grey);
            }

            return _buildTextCell(
              _formatTimeRange(schedules.first['startTime'], schedules.first['endTime']),
              isBold: true,
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.edit, color: _primaryColor, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 32, height: 32),
                onPressed: () => _showEditDayScheduleDialog(context, driver, dayDate),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.delete, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(width: 32, height: 32),
                onPressed: () => _deleteDriverSchedule(driver['id'], dayDate),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextCell(String text, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w500 : FontWeight.normal,
          color: color ?? Colors.black,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  String _getShortDayName(DateTime date) {
    final fullName = DateFormat('EEEE', 'fr_FR').format(date);
    return fullName.substring(0, 3);
  }

  String _formatTimeRange(String start, String end) {
    return '$start - $end';
  }

  void _showAddWeeklyScheduleDialog(BuildContext context) {
    String? selectedDriverId;
    final startController = TextEditingController();
    final endController = TextEditingController();
    _selectedDays = List.generate(7, (index) => false);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Ajouter un planning ", 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor)),
                  SizedBox(height: 20),
                  
                  if (_isLoadingDrivers)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_drivers.isEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        "Aucun chauffeur disponible!",
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      value: selectedDriverId,
                      decoration: InputDecoration(
                        labelText: 'Chauffeur',
                        prefixIcon: Icon(Icons.person, color: _primaryColor),
                        border: OutlineInputBorder(),
                      ),
                      items: _drivers.map((driver) {
                        return DropdownMenuItem<String>(
                          value: driver['id'],
                          child: Text(driver['name']),
                        );
                      }).toList(),
                      onChanged: (value) => setState(() => selectedDriverId = value),
                    ),
                  
                  SizedBox(height: 20),
                  Text(
                    "Sélectionnez les jours:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: List.generate(7, (index) {
                      return FilterChip(
                        label: Text(
                          index < _weekDays.length 
                            ? _weekDays[index] 
                            : 'Jour ${index+1}'
                        ),
                        selected: _selectedDays[index],
                        onSelected: (selected) {
                          setState(() {
                            _selectedDays[index] = selected;
                          });
                        },
                        selectedColor: _primaryColor.withOpacity(0.2),
                        checkmarkColor: _primaryColor,
                        labelStyle: TextStyle(
                          color: _selectedDays[index] ? _primaryColor : Colors.black,
                        ),
                      );
                    }),
                  ),
                  
                  SizedBox(height: 20),
                  TextField(
                    controller: startController,
                    decoration: InputDecoration(
                      labelText: 'Heure de début (HH:mm)',
                      prefixIcon: Icon(Icons.access_time, color: _primaryColor),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 15),
                  TextField(
                    controller: endController,
                    decoration: InputDecoration(
                      labelText: 'Heure de fin (HH:mm)',
                      prefixIcon: Icon(Icons.access_time, color: _primaryColor),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: TextStyle(color: Colors.grey)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          if (selectedDriverId == null || _drivers.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Veuillez sélectionner un chauffeur"),
                                backgroundColor: Colors.red,
                              )
                            );
                            return;
                          }
                          
                          if (!_selectedDays.contains(true)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Veuillez sélectionner au moins un jour"),
                                backgroundColor: Colors.red,
                              )
                            );
                            return;
                          }
                          
                          final driver = _drivers.firstWhere(
                            (d) => d['id'] == selectedDriverId,
                            orElse: () => {'name': 'Inconnu'},
                          );
                          
                          _addWeeklySchedule(
                            selectedDriverId!,
                            driver['name'],
                            startController.text,
                            endController.text,
                          );
                          Navigator.pop(context);
                        },
                        child: Text('Ajouter', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _addWeeklySchedule(String driverId, String driverName, String startTime, String endTime) {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    for (int i = 0; i < _selectedDays.length; i++) {
      if (_selectedDays[i]) {
        final dayDate = startOfWeek.add(Duration(days: i));
        final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
        
        _firestore.collection('schedules').add({
          'driverId': driverId,
          'driverName': driverName,
          'startTime': startTime,
          'endTime': endTime,
          'date': formattedDate,
          'createdAt': Timestamp.now(),
          'recurring': true,
        });
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Planning hebdomadaire ajouté avec succès"),
        backgroundColor: Colors.green,
      )
    );
  }

  void _showEditDayScheduleDialog(BuildContext context, Map<String, dynamic> driver, DateTime dayDate) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
    final startController = TextEditingController();
    final endController = TextEditingController();
    String? existingScheduleId;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Modifier l'horaire du ${DateFormat('EEEE d MMMM', 'fr_FR').format(dayDate)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 20),
              Text(
                driver['name'],
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              SizedBox(height: 20),
              StreamBuilder<QuerySnapshot>(
                stream: _firestore
                    .collection('schedules')
                    .where('driverId', isEqualTo: driver['id'])
                    .where('date', isEqualTo: formattedDate)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                    final schedule = snapshot.data!.docs.first;
                    final data = schedule.data() as Map<String, dynamic>;
                    startController.text = data['startTime'];
                    endController.text = data['endTime'];
                    existingScheduleId = schedule.id;
                  }
                  
                  return Column(
                    children: [
                      TextField(
                        controller: startController,
                        decoration: InputDecoration(
                          labelText: 'Heure de début (HH:mm)',
                          prefixIcon: Icon(Icons.access_time, color: _primaryColor),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 15),
                      TextField(
                        controller: endController,
                        decoration: InputDecoration(
                          labelText: 'Heure de fin (HH:mm)',
                          prefixIcon: Icon(Icons.access_time, color: _primaryColor),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  );
                },
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      if (existingScheduleId != null) {
                        _deleteSchedule(existingScheduleId!);
                      }
                      Navigator.pop(context);
                    },
                    child: Text('Supprimer', style: TextStyle(color: Colors.red)),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Annuler', style: TextStyle(color: Colors.grey)),
                      ),
                      SizedBox(width: 10),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          if (existingScheduleId != null) {
                            _updateSchedule(
                              existingScheduleId!,
                              driver['id'],
                              driver['name'],
                              startController.text,
                              endController.text,
                            );
                          } else {
                            _addSchedule(
                              driver['id'],
                              driver['name'],
                              startController.text,
                              endController.text,
                              dayDate,
                            );
                          }
                          Navigator.pop(context);
                        },
                        child: Text('Enregistrer', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addSchedule(String driverId, String driverName, String startTime, String endTime, DateTime dayDate) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
    
    _firestore.collection('schedules').add({
      'driverId': driverId,
      'driverName': driverName,
      'startTime': startTime,
      'endTime': endTime,
      'date': formattedDate,
      'createdAt': Timestamp.now(),
    });
  }

  void _updateSchedule(String scheduleId, String driverId, String driverName, String startTime, String endTime) {
    _firestore.collection('schedules').doc(scheduleId).update({
      'driverId': driverId,
      'driverName': driverName,
      'startTime': startTime,
      'endTime': endTime,
      'updatedAt': Timestamp.now(),
    });
  }

  void _deleteDriverSchedule(String driverId, DateTime dayDate) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
    
    _firestore.collection('schedules')
      .where('driverId', isEqualTo: driverId)
      .where('date', isEqualTo: formattedDate)
      .get()
      .then((querySnapshot) {
        for (var doc in querySnapshot.docs) {
          doc.reference.delete();
        }
      });
  }

  void _deleteSchedule(String id) {
    _firestore.collection('schedules').doc(id).delete();
  }

  Widget _buildAbsenceRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('absence_requests')
          .where('status', isEqualTo: 'En attente')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _buildLoading();
        if (snapshot.hasError) return Text('Erreur: ${snapshot.error}');

        final requests = snapshot.data!.docs;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _pendingAbsenceCount = requests.length;
            });
          }
        });
        
        if (requests.isEmpty) return _buildEmptyState("Aucune demande en attente");
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return _buildAbsenceCard(request);
          },
        );
      },
    );
  }

  Widget _buildAbsenceCard(DocumentSnapshot request) {
    final data = request.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withOpacity(0.1),
          child: Icon(Icons.person_off, color: _primaryColor),
        ),
        title: Text(data['driverName'], style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("${DateFormat('dd/MM/yyyy').format(data['startDate'].toDate())} - ${DateFormat('dd/MM/yyyy').format(data['endDate'].toDate())}"),
            Text(data['reason'], style: TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.check, color: Colors.green),
              onPressed: () => _updateAbsenceStatus(request.id, 'Approuvée'),
            ),
            IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () => _updateAbsenceStatus(request.id, 'Refusée'),
            ),
          ],
        ),
      ),
    );
  }

  void _updateAbsenceStatus(String id, String status) {
    _firestore.collection('absence_requests').doc(id).update({
      'status': status,
      'processedAt': Timestamp.now(),
    }).then((_) {
      _loadApprovedAbsences();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Demande $status"),
          backgroundColor: status == 'Approuvée' ? Colors.green : Colors.orange,
        )
      );
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: $error"),
          backgroundColor: Colors.red,
        )
      );
    });
  }
  
  Widget _buildLoading() {
    return Center(
      child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(_primaryColor)),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 20),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey)),
        ],
      ),
    );
  }
}

class DriverScheduleScreen extends StatefulWidget {
  @override
  _DriverScheduleScreenState createState() => _DriverScheduleScreenState();
}

class _DriverScheduleScreenState extends State<DriverScheduleScreen> {
  List<Map<String, dynamic>> _driverAbsences = [];
  final Color _primaryColor = Color(0xFF6C5CE7);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  DateTime _selectedDate = DateTime.now();
  bool _isDateFormatInitialized = false;
  Map<String, dynamic>? _driver;
  bool _isLoading = true;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeDateFormatting();
    _loadDriverData();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('fr_FR', null);
    setState(() {
      _isDateFormatInitialized = true;
    });
  }

  Future<void> _loadDriverData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final driverDoc = await _firestore.collection('users').doc(user.uid).get();
      if (driverDoc.exists) {
        setState(() {
          _driver = driverDoc.data()!;
          _driver!['id'] = user.uid;
        });
        
        await _loadDriverAbsences();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      print("Erreur de chargement du chauffeur: $e");
      setState(() => _isLoading = false);
    }
  }
  
  String _calculateEffectiveStatus() {
    if (_driver == null) return 'present';

    final now = DateTime.now();
    
    for (var absence in _driverAbsences) {
      if (absence['status'] == 'Approuvée') {
        final startDate = (absence['startDate'] as Timestamp).toDate();
        final endDate = (absence['endDate'] as Timestamp).toDate().add(const Duration(days: 1));

        if (now.isAfter(startDate) && now.isBefore(endDate)) {
          return 'absent';
        }
      }
    }
    
    return _driver?['status'] ?? 'present';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveStatus = _calculateEffectiveStatus();
    final statusColor = effectiveStatus == 'absent' ? Colors.red : Colors.green;
    final statusText = effectiveStatus == 'absent' ? 'Absent' : 'Présent';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text("Mon Planning", style: TextStyle(color: Colors.white)),
          centerTitle: true,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_primaryColor, _primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        body: Column(
          children: [
            TabBar(
              labelColor: _primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: _primaryColor,
              tabs: const [
                Tab(icon: Icon(Icons.calendar_today)), 
                Tab(icon: Icon(Icons.add)), 
                Tab(icon: Icon(Icons.list)), 
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildPlanningTab(effectiveStatus, statusColor, statusText),
                  _buildAbsenceRequestTab(),
                  _buildMyRequestsTab(),
                  _buildHistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHistoryTab() {
    return Center(
      child: Text("Historique des demandes", style: TextStyle(fontSize: 18)),
    );
  }
  Future<void> _loadDriverAbsences() async {
    if (_driver == null) return;

    try {
      final snapshot = await _firestore
          .collection('absence_requests')
          .where('driverId', isEqualTo: _driver!['id'])
          .get();

      setState(() {
        _driverAbsences = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print("Erreur de chargement des absences: $e");
    }
  }

  Widget _buildMyRequestsTab() {
    if (_driver == null) {
      return Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('absence_requests')
          .where('driverId', isEqualTo: _driver!['id'])
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(child: CircularProgressIndicator());
        }

        List<QueryDocumentSnapshot> requests = snapshot.data!.docs;
        
        requests.sort((a, b) {
          Timestamp aTime = (a.data() as Map<String, dynamic>)['createdAt'];
          Timestamp bTime = (b.data() as Map<String, dynamic>)['createdAt'];
          return bTime.compareTo(aTime);
        });

        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.list, size: 60, color: Colors.grey[400]),
                SizedBox(height: 20),
                Text(
                  "Aucune demande d'absence",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            final data = request.data() as Map<String, dynamic>;
            return _buildAbsenceItem(data);
          },
        );
      },
    );
  }
  Widget _buildAbsenceItem(Map<String, dynamic> data) {
    final startDate = (data['startDate'] as Timestamp).toDate();
    final endDate = (data['endDate'] as Timestamp).toDate();
    final status = data['status'] ?? 'En attente';

    Color statusColor;
    if (status == 'Approuvée') {
      statusColor = Colors.green;
    } else if (status == 'Refusée') {
      statusColor = Colors.red;
    } else {
      statusColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 4,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: _primaryColor.withOpacity(0.1),
          child: Icon(Icons.calendar_today, color: _primaryColor),
        ),
        title: Text(
          "${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}",
        ),
        subtitle: Text(
          data['reason'],
          style: TextStyle(fontStyle: FontStyle.italic),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: statusColor),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildPlanningTab(String effectiveStatus, Color statusColor, String statusText) {
    return Column(
      children: [
        _buildWeekSelector(),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Statut actuel:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildScheduleList()),
      ],
    );
  }
  Widget _buildAbsenceRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            "Demande d'absence",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          _buildDateSelector(context, "Date de début", (date) {
            setState(() => _startDate = date);
          }),
          const SizedBox(height: 20),
          _buildDateSelector(context, "Date de fin", (date) {
            setState(() => _endDate = date);
          }),
          const SizedBox(height: 20),
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Motif de l\'absence',
              border: const OutlineInputBorder(),
              prefixIcon: Icon(Icons.note, color: _primaryColor),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: _submitAbsenceRequest,
            child: const Text(
              "Envoyer la demande",
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector(BuildContext context, String label, Function(DateTime) onDateSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime(DateTime.now().year + 1),
            );
            if (selectedDate != null) {
              onDateSelected(selectedDate);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: _primaryColor),
                const SizedBox(width: 15),
                Text(
                  label == "Date de début" 
                    ? (_startDate == null 
                        ? "Sélectionner une date" 
                        : DateFormat('dd/MM/yyyy').format(_startDate!))
                    : (_endDate == null 
                        ? "Sélectionner une date" 
                        : DateFormat('dd/MM/yyyy').format(_endDate!)),
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  void _submitAbsenceRequest() {
    if (_driver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: informations chauffeur manquantes"),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    if (_startDate == null || _endDate == null || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Veuillez remplir tous les champs"),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("La date de début doit être avant la date de fin"),
          backgroundColor: Colors.red,
        )
      );
      return;
    }

    FirebaseFirestore.instance.collection('absence_requests').add({
      'driverId': _driver!['id'],
      'driverName': _driver!['name'],
      'startDate': Timestamp.fromDate(_startDate!),
      'endDate': Timestamp.fromDate(_endDate!),
      'reason': _reasonController.text,
      'status': 'En attente',
      'createdAt': Timestamp.now(),
    }).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Demande d'absence envoyée au responsable"),
          backgroundColor: Colors.green,
        )
      );
      
      setState(() {
        _startDate = null;
        _endDate = null;
        _reasonController.clear();
      });
    }).catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de l'envoi: $error"),
          backgroundColor: Colors.red,
        )
      );
    });
  }

  Widget _buildWeekSelector() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: _primaryColor),
            onPressed: () => setState(() => _selectedDate = _selectedDate.subtract(const Duration(days: 7))),
          ),
          Column(
            children: [
              Text(
                "Semaine ${DateFormat('w').format(_selectedDate)}",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                "${DateFormat('dd/MM').format(startOfWeek)} - ${DateFormat('dd/MM').format(endOfWeek)}",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _primaryColor),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios, color: _primaryColor),
            onPressed: () => setState(() => _selectedDate = _selectedDate.add(const Duration(days: 7))),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleList() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    return ListView.builder(
      itemCount: 7,
      itemBuilder: (context, index) {
        final dayDate = startOfWeek.add(Duration(days: index));
        return _buildDayScheduleCard(dayDate);
      },
    );
  }

  Widget _buildDayScheduleCard(DateTime dayDate) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(dayDate);
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('schedules')
              .where('driverId', isEqualTo: _driver?['id'])
              .where('date', isEqualTo: formattedDate)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListTile(
                title: Text(
                  DateFormat('EEEE d MMMM', 'fr_FR').format(dayDate),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text("Chargement..."),
              );
            }
            
            final schedules = snapshot.data!.docs;
            final hasSchedule = schedules.isNotEmpty;
            final schedule = hasSchedule ? schedules.first.data() as Map<String, dynamic> : null;

            return ListTile(
              title: Text(
                DateFormat('EEEE d MMMM', 'fr_FR').format(dayDate),
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: hasSchedule
                  ? Text("${schedule!['startTime']} - ${schedule['endTime']}")
                  : Text("Pas de planning", style: TextStyle(color: Colors.grey)),
              trailing: hasSchedule ? null : Icon(Icons.close, color: Colors.grey),
            );
          },
        ),
      ),
    );
  }
}