import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

// Déplacer CurrencyInputFormatter au niveau supérieur
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;
    
    // Nettoyer le texte (supprimer tous les caractères non numériques sauf le point)
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9.]'), '');
    
    // Empêcher plusieurs points décimaux
    if ('.'.allMatches(cleanText).length > 1) {
      cleanText = cleanText.substring(0, cleanText.lastIndexOf('.'));
    }
    
    // Formater avec séparateur de milliers
    final formatter = NumberFormat("#,##0.###", "fr_FR");
    double value = double.tryParse(cleanText) ?? 0;
    String formatted = formatter.format(value);
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class InsuranceManagementScreen extends StatefulWidget {
  const InsuranceManagementScreen({super.key});

  @override
  State<InsuranceManagementScreen> createState() => _InsuranceManagementScreenState();
}

class _InsuranceManagementScreenState extends State<InsuranceManagementScreen> {
  bool _endDateError = false;
  bool _durationError = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy');
  final _formKey = GlobalKey<FormState>();
  final _renewalFormKey = GlobalKey<FormState>();
  final Color _primaryColor = const Color(0xFF6C5CE7);
  final Color _secondaryColor = const Color(0xFF00BFA5);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _textColor = const Color(0xFF2D3436);
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _providerController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedVehicleId;
  String? _currentDocId;
  final ValueNotifier<String> _activeSearchNotifier = ValueNotifier('');
  final ValueNotifier<String> _expiredSearchNotifier = ValueNotifier('');
  final ValueNotifier<String> _archivedSearchNotifier = ValueNotifier('');
  Map<String, String> _vehicleMap = {};
  String? _renewalOriginalDocId;
  List<String> _insuredVehicleIds = [];

  // Validateur pour les montants
  String? _validateAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Ce champ est obligatoire';
    }
    
    final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
    final amount = double.tryParse(cleanValue);
    
    if (amount == null) {
      return 'Valeur numérique invalide';
    }
    
    if (amount <= 0) {
      return 'Le montant doit être supérieur à zéro';
    }
    
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadInsuredVehicles();
  }

  Future<void> _loadVehicles() async {
    final snapshot = await _firestore.collection('vehicles').get();
    final map = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      map[doc.id] = '${data['marque']} ${data['modele']}';
    }
    setState(() {
      _vehicleMap = map;
    });
  }

  Future<void> _loadInsuredVehicles() async {
    final snapshot = await _firestore.collection('insurances')
      .where('isArchived', isEqualTo: false)
      .get();
    
    setState(() {
      _insuredVehicleIds = snapshot.docs
        .map((doc) => doc['vehicleId'] as String? ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
    });
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _providerController.dispose();
    _totalAmountController.dispose();
    _activeSearchNotifier.dispose();
    _expiredSearchNotifier.dispose();
    _archivedSearchNotifier.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime initialDate = DateTime.now();
    DateTime firstDate = DateTime(2000);
    DateTime lastDate = DateTime(2100);

    if (isStartDate) {
      initialDate = _startDate ?? DateTime.now();
    } else {
      initialDate = _endDate ?? _startDate ?? DateTime.now();
      firstDate = _startDate ?? DateTime(2000);
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: _primaryColor,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && picked.isAfter(_endDate!)) {
            _endDateError = true;
          } else {
            _endDateError = false;
          }
        } else {
          _endDate = picked;
          if (_startDate != null && picked.isBefore(_startDate!)) {
            _endDateError = true;
          } else {
            _endDateError = false;
          }
        }
        
        if (_startDate != null && _endDate != null) {
          final duration = _endDate!.difference(_startDate!).inDays;
          _durationError = duration < 1;
        } else {
          _durationError = false;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    // Nettoyer le montant avant soumission
    final cleanAmount = _totalAmountController.text
        .replaceAll(RegExp(r'[^0-9]'), '');
    _totalAmountController.text = cleanAmount;
    
    if (_endDate != null && _startDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() => _endDateError = true);
      return;
    }

    if (_formKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veuillez sélectionner les deux dates'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_endDate!.difference(_startDate!).inDays < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('La date de fin doit être postérieure au début'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_endDate!.difference(_startDate!).inDays < 1) {
        setState(() => _durationError = true);
        return;
      }

      try {
        final insuranceData = {
          'reference': _referenceController.text,
          'vehicleId': _selectedVehicleId,
          'startDate': Timestamp.fromDate(_startDate!),
          'endDate': Timestamp.fromDate(_endDate!),
          'provider': _providerController.text,
          'totalAmount': double.parse(_totalAmountController.text),
          'createdAt': FieldValue.serverTimestamp(),
          'isArchived': false,
        };
        if (_currentDocId == null) {
          await _firestore.collection('insurances').add(insuranceData);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Assurance créée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          await _firestore.collection('insurances').doc(_currentDocId).update(insuranceData);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mise à jour réussie'),
              backgroundColor: Colors.green,
            ),
          );
        }
        Navigator.pop(context);
        _clearForm();
        _loadInsuredVehicles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitRenewalForm() async {
    // Nettoyer le montant avant soumission
    final cleanAmount = _totalAmountController.text
        .replaceAll(RegExp(r'[^0-9]'), '');
    _totalAmountController.text = cleanAmount;
    
    if (_endDate != null && _startDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() => _endDateError = true);
      return;
    }

    if (_renewalFormKey.currentState!.validate()) {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Veuillez sélectionner les deux dates'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_endDate!.difference(_startDate!).inDays < 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('La date de fin doit être postérieure au début'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      if (_endDate!.difference(_startDate!).inDays < 1) {
        setState(() => _durationError = true);
        return;
      }

      try {
        final newInsuranceData = {
          'reference': _referenceController.text,
          'vehicleId': _selectedVehicleId,
          'startDate': Timestamp.fromDate(_startDate!),
          'endDate': Timestamp.fromDate(_endDate!),
          'provider': _providerController.text,
          'totalAmount': double.parse(_totalAmountController.text),
          'createdAt': FieldValue.serverTimestamp(),
          'isArchived': false,
        };

        await _firestore.collection('insurances').add(newInsuranceData);
        
        if (_renewalOriginalDocId != null) {
          await _firestore.collection('insurances').doc(_renewalOriginalDocId).update({
            'isArchived': true,
            'renewedAt': FieldValue.serverTimestamp(),
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assurance renouvelée avec succès'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
        _clearForm();
        _loadInsuredVehicles();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _clearForm() {
    _referenceController.clear();
    _providerController.clear();
    _totalAmountController.clear();
    setState(() {
      _selectedVehicleId = null;
      _startDate = null;
      _endDate = null;
      _currentDocId = null;
      _renewalOriginalDocId = null;
      _endDateError = false;
      _durationError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        appBar: AppBar(
          title: const Text('Gestion des Assurances'),
          backgroundColor: _primaryColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
          bottom: TabBar(
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(50),
              color: Colors.white.withOpacity(0.2),
            ),
            indicatorColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(text: 'Actives', icon: Icon(Icons.check_circle)),
              Tab(text: 'Expirées', icon: Icon(Icons.warning)),
              Tab(text: 'Archives', icon: Icon(Icons.archive)),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _primaryColor,
          onPressed: () => _showInsuranceForm(),
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: _firestore.collection('insurances').snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            
            final docs = snapshot.data!.docs;
            _checkExpiringInsurances(docs);

            final List<QueryDocumentSnapshot> activeInsurances = [];
            final List<QueryDocumentSnapshot> expiredInsurances = [];
            final List<QueryDocumentSnapshot> archivedInsurances = [];
            
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final endDate = (data['endDate'] as Timestamp?)?.toDate();
              final isArchived = data['isArchived'] ?? false;

              if (isArchived) {
                archivedInsurances.add(doc);
              } else {
                if (endDate?.isAfter(DateTime.now()) ?? false) {
                  activeInsurances.add(doc);
                } else {
                  expiredInsurances.add(doc);
                }
              }
            }

            return TabBarView(
              children: [
                ValueListenableBuilder<String>(
                  valueListenable: _activeSearchNotifier,
                  builder: (context, activeSearchQuery, _) {
                    return _buildInsuranceList(
                      activeInsurances, 
                      'Aucune assurance active',
                      activeSearchQuery,
                      _activeSearchNotifier,
                    );
                  },
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _expiredSearchNotifier,
                  builder: (context, expiredSearchQuery, _) {
                    return _buildInsuranceList(
                      expiredInsurances, 
                      'Aucune assurance expirée',
                      expiredSearchQuery,
                      _expiredSearchNotifier,
                    );
                  },
                ),
                ValueListenableBuilder<String>(
                  valueListenable: _archivedSearchNotifier,
                  builder: (context, archivedSearchQuery, _) {
                    return _buildInsuranceList(
                      archivedInsurances, 
                      'Aucune assurance archivée',
                      archivedSearchQuery,
                      _archivedSearchNotifier,
                      isArchived: true,
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

 void _checkExpiringInsurances(List<QueryDocumentSnapshot> docs) async {
  // 1. Parcours de toutes les assurances
  for (final doc in docs) {
    
    // 2. Extraction des données de l'assurance
    final data = doc.data() as Map<String, dynamic>;
    
    // 3. Vérification si l'assurance est archivée
    final isArchived = data['isArchived'] ?? false;
    if (isArchived) continue;  // On ignore les assurances archivées
    
    // 4. Récupération de la date d'expiration
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    
    // 5. Vérification si la date d'expiration existe
    if (endDate != null) {
      
      // 6. Normalisation des dates (ignorer l'heure)
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final expirationDay = DateTime(endDate.year, endDate.month, endDate.day);
      
      // 7. Calcul du nombre exact de jours restants
      final daysRemaining = expirationDay.difference(today).inDays;
      
      // 8. Vérification si on est exactement à 15 jours avant expiration
      if (daysRemaining == 15) {
        
        // 9. Envoi de notification
        _showNotification(
          doc.id,
          'Assurance à renouveler',
          'L\'assurance ${data['reference']} expire dans 15 jours'
        );
      }
    }
  }
}

  Future<void> _showNotification(String id, String title, String body) async {
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
      id.hashCode.abs(),
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

 Widget _buildInsuranceList(
  List<QueryDocumentSnapshot> docs,
  String emptyMessage,
  String searchQuery,
  ValueNotifier<String> searchNotifier,
  {bool isArchived = false}
) {
  final Color _primaryColor = const Color(0xFF6C5CE7);

  final filteredDocs = docs.where((doc) {
    if (searchNotifier.value.isEmpty) return true;
    final data = doc.data() as Map<String, dynamic>;
    final reference = data['reference']?.toString().toLowerCase() ?? '';
    final vehicleId = data['vehicleId']?.toString() ?? '';
    final vehicleName = _vehicleMap[vehicleId]?.toLowerCase() ?? '';

    return reference.contains(searchNotifier.value.toLowerCase()) ||
           vehicleName.contains(searchNotifier.value.toLowerCase());
  }).toList();

  final TextEditingController _searchController =
      TextEditingController(text: searchQuery);

  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: ValueListenableBuilder<String>(
          valueListenable: searchNotifier,
          builder: (context, value, _) {
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => searchNotifier.value = value,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  prefixIcon: Icon(Icons.search, color: _primaryColor),
                  suffixIcon: value.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            searchNotifier.value = '';
                          },
                          child: Icon(Icons.close, color: _primaryColor),
                        )
                      : null,
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: InputBorder.none,
                ),
              ),
            );
          },
        ),
      ),
      Expanded(
        child: filteredDocs.isEmpty
            ? Center(
                child: Text(
                  emptyMessage,
                  style: TextStyle(
                    color: _textColor.withOpacity(0.6),
                    fontSize: 16,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(0),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  return _buildInsuranceCard(
                    doc.id,
                    doc.data() as Map<String, dynamic>,
                    isArchived: isArchived,
                  );
                },
              ),
      ),
    ],
  );
}


  Widget _buildInsuranceCard(String docId, Map<String, dynamic> data, {bool isArchived = false}) {
    final startDate = (data['startDate'] as Timestamp?)?.toDate();
    final endDate = (data['endDate'] as Timestamp?)?.toDate();
    final status = isArchived 
      ? 'Archivée' 
      : (endDate?.isAfter(DateTime.now()) ?? false ? 'Actif' : 'Expiré');
      
    final statusColor = isArchived 
      ? Colors.grey 
      : (status == 'Actif' ? Colors.green : Colors.red);
      
    final vehicleName = _vehicleMap[data['vehicleId']] ?? 'Véhicule inconnu';

    return Dismissible(
      key: Key(docId),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
   child: Icon(Icons.clear, color: _primaryColor, size: 40),

      ),
      confirmDismiss: (direction) async { 
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Confirmer la suppression'),
            content: const Text('Voulez-vous vraiment supprimer cette assurance ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Annuler', style: TextStyle(color: _textColor))),
              TextButton(
                onPressed: () {
                  _firestore.collection('insurances').doc(docId).delete();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Supprimer', style: TextStyle(color: Colors.red))),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [ 
                    isArchived 
                      ? Colors.grey.withOpacity(0.8)
                      : _primaryColor.withOpacity(0.8),
                    isArchived ? Colors.grey : _primaryColor,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isArchived ? Icons.archive : Icons.verified_user, 
                    color: Colors.white, 
                    size: 28
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(data['reference'] ?? 'Sans référence',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          )),
                        const SizedBox(height: 4),
                        Text(vehicleName,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          )),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      )),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow(
                    icon: Icons.business,
                    title: 'Prestataire',
                    value: data['provider'] ?? 'Non spécifié',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.calendar_today,
                          title: 'Début',
                          value: startDate != null 
                              ? _dateFormat.format(startDate)
                              : 'Non défini',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoRow(
                          icon: Icons.date_range,
                          title: 'Fin',
                          value: endDate != null
                              ? _dateFormat.format(endDate)
                              : 'Non défini',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    icon: Icons.payments,
                    title: 'Montant',
                    value: _formatAmount(data['totalAmount']),
                  ),
                  if (isArchived && data['renewedAt'] != null)
                    _buildInfoRow(
                      icon: Icons.autorenew,
                      title: 'Renouvelée le',
                      value: _dateFormat.format((data['renewedAt'] as Timestamp).toDate()),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isArchived) ...[
                        IconButton(
                          icon: Icon(Icons.edit, color: _primaryColor),
                          onPressed: () => _showInsuranceForm(docId, data)),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(Icons.autorenew, color: Colors.blue),
                          onPressed: () => _showRenewalForm(docId, data)),
                        const SizedBox(width: 8),
                      ],
                      FloatingActionButton(
                        mini: true,
                        backgroundColor: Colors.red.shade100,
                        onPressed: () => _confirmDelete(docId),
                        child: Icon(Icons.delete, color: Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRenewalForm(String docId, Map<String, dynamic> data) {
    _clearForm();
    
    _renewalOriginalDocId = docId;
    _referenceController.text = data['reference'] ?? '';
    _providerController.text = data['provider'] ?? '';
    _totalAmountController.text = data['totalAmount']?.toString() ?? '0.0';
    _selectedVehicleId = data['vehicleId'] ?? '';
    _startDate = (data['startDate'] as Timestamp?)?.toDate();
    _endDate = (data['endDate'] as Timestamp?)?.toDate();
    
    _currentDocId = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildRenewalForm(),
    );
  }

  Widget _buildRenewalForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16),
      child: Form(
        key: _renewalFormKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _referenceController,
              enabled: false,
              style: TextStyle(color: _textColor.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Référence assurance',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.assignment_ind, color: _primaryColor.withOpacity(0.6)),
              ),),
            const SizedBox(height: 16),
            TextFormField(
              enabled: false,
              style: TextStyle(color: _textColor.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Véhicule',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.directions_car, color: _primaryColor.withOpacity(0.6)),
              ),
              initialValue: _vehicleMap[_selectedVehicleId] ?? 'Véhicule inconnu',
            ),
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_durationError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'La durée minimale doit être de 24h',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Nouvelle date début',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.calendar_today, color: _primaryColor)),
                          child: Text(_startDate != null 
                              ? _dateFormat.format(_startDate!) 
                              : 'Sélectionner une date'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Nouvelle date fin',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: Icon(Icons.calendar_today, color: _primaryColor)),
                              child: Text(_endDate != null 
                                  ? _dateFormat.format(_endDate!) 
                                  : 'Sélectionner une date'),
                            ),
                          ),
                          if (_endDateError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'La date de fin doit être postérieure à la date de début',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Ancienne période: ${_dateFormat.format((_startDate ?? DateTime.now()))} - ${_dateFormat.format((_endDate ?? DateTime.now()))}',
              style: TextStyle(
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _providerController,
              enabled: false,
              style: TextStyle(color: _textColor.withOpacity(0.6)),
              decoration: InputDecoration(
                labelText: 'Prestataire',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.business, color: _primaryColor.withOpacity(0.6)),
              ),),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                CurrencyInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Montant DT',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.payments, color: _primaryColor)),
              validator: _validateAmount,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              onPressed: _submitRenewalForm,
              child: const Text(
                'Renouveler l\'assurance',
                style: TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({required IconData icon, required String title, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  )),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                    fontSize: 16,
                    color: _textColor,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
      ],
    );
  }

  void _showInsuranceForm([String? docId, Map<String, dynamic>? data]) {
    _clearForm();
    
    if (data != null) {
      _currentDocId = docId;
      _referenceController.text = data['reference'] ?? '';
      _providerController.text = data['provider'] ?? '';
      _totalAmountController.text = data['totalAmount']?.toString() ?? '0.0';
      _startDate = (data['startDate'] as Timestamp?)?.toDate();
      _endDate = (data['endDate'] as Timestamp?)?.toDate();
      _selectedVehicleId = data['vehicleId'] ?? '';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _buildInsuranceForm(),
    );
  }

  Widget _buildInsuranceForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _referenceController,
              decoration: InputDecoration(
                labelText: 'Référence assurance',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.assignment_ind, color: _primaryColor)),
              validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('vehicles').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                
                final validDocs = snapshot.data!.docs.where((doc) {
                  return !_insuredVehicleIds.contains(doc.id) || 
                         doc.id == _selectedVehicleId;
                }).toList();

                return DropdownButtonFormField<String>(
                  value: _selectedVehicleId,
                  decoration: InputDecoration(
                    labelText: 'Véhicule',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    prefixIcon: Icon(Icons.directions_car, color: _primaryColor)),
                  items: validDocs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text('${data['marque']} ${data['modele']}'),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedVehicleId = value),
                  validator: (value) => value == null ? 'Sélectionnez un véhicule' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_durationError)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      'La durée minimale doit être de 24h',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                      ),
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _selectDate(context, true),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Date début',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.calendar_today, color: _primaryColor)),
                          child: Text(_startDate != null 
                              ? _dateFormat.format(_startDate!) 
                              : 'Sélectionner une date'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _selectDate(context, false),
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Date fin',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                prefixIcon: Icon(Icons.calendar_today, color: _primaryColor)),
                              child: Text(_endDate != null 
                                  ? _dateFormat.format(_endDate!) 
                                  : 'Sélectionner une date'),
                            ),
                          ),
                          if (_endDateError)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                'La date de fin doit être postérieure à la date de début',
                                style: TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _providerController,
              decoration: InputDecoration(
                labelText: 'Prestataire',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.business, color: _primaryColor)),
              validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _totalAmountController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                CurrencyInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Montant DT',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: Icon(Icons.payments, color: _primaryColor)),
              validator: _validateAmount,
              autovalidateMode: AutovalidateMode.onUserInteraction,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
              onPressed: _submitForm,
              child: Text(
                _currentDocId == null ? 'Ajouter Assurance' : 'Mettre à jour',
                style: const TextStyle(color: Colors.white)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _formatAmount(dynamic amount) {
    final parsed = double.tryParse(amount.toString());
    if (parsed == null) return '0,000 DT';
    
    final formatter = NumberFormat("#,##0.000", "fr_FR");
    return '${formatter.format(parsed)} DT';
  }

  void _confirmDelete(String docId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer cette assurance ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Annuler', style: TextStyle(color: _textColor))),
          TextButton(
            onPressed: () {
              _firestore.collection('insurances').doc(docId).delete();
              Navigator.of(context).pop();
            },
            child: Text('Supprimer', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }
}