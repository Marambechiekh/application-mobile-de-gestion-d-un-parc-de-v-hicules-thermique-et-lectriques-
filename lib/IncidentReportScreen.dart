import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class IncidentReportScreen extends StatefulWidget {
  @override
  _IncidentReportScreenState createState() => _IncidentReportScreenState();
}

class _IncidentReportScreenState extends State<IncidentReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _primaryColor = Color(0xFF6C5CE7);
  final _secondaryColor = Color(0xFF00BFA5);
  final _alertColor = Color(0xFFFF7043);
  final _backgroundColor = Color(0xFFF8F9FA);
  
  String? selectedType;
  String? description;
  DateTime incidentDate = DateTime.now();
  File? selectedImage;
  bool _isSubmitting = false;
  
  String? _selectedVehicleId;
  List<Map<String, dynamic>> _vehicles = [];
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data() as Map<String, dynamic>;
        setState(() {
          // Correction: Utilisation directe du champ 'name'
          _userName = userData['name'] ?? 'Nom inconnu';
        });
      }
    }
  }

  Future<void> _loadVehicles() async {
    final vehicles = await FirebaseFirestore.instance.collection('vehicles').get();

    setState(() {
      _vehicles = vehicles.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'text': '${data['marque']} ${data['modele']} (${data['numeroImmatriculation']})'
        };
      }).toList();
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        selectedImage = File(picked.path);
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    
    setState(() => _isSubmitting = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;

      await FirebaseFirestore.instance.collection('incidents').add({
        'type': selectedType,
        'description': description,
        'dateTime': Timestamp.fromDate(incidentDate),
        'imagePath': selectedImage?.path ?? '',
        'status': 'Nouveau',
        'createdAt': Timestamp.now(),
        'userId': userId,
        'vehiculeId': _selectedVehicleId,
        'userName': _userName ?? 'Nom non défini', // Correction avec fallback
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Votre rapport a été transmis au Responsable de parc'),
        backgroundColor: _secondaryColor,
        duration: Duration(seconds: 3),
      ));

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erreur: ${e.toString()}'),
        backgroundColor: _alertColor,
      ));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Déclarer un incident',
            style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: _primaryColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_backgroundColor, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Formulaire de déclaration',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _primaryColor,
                    )),
                SizedBox(height: 5),
                Text('Remplissez tous les champs requis',
                    style: TextStyle(color: Colors.grey.shade600)),
                SizedBox(height: 25),

                _buildSectionHeader('Chauffeur', Icons.person),
                _buildUserDisplay(),
                SizedBox(height: 20),

                _buildSectionHeader('Véhicule impliqué *', Icons.directions_car),
                _buildVehicleDropdown(),
                SizedBox(height: 20),

                _buildSectionHeader('Type d\'incident *', Icons.warning_amber),
                _buildIncidentTypeSelector(),
                SizedBox(height: 25),

                _buildSectionHeader('Description *', Icons.description),
                _buildDescriptionField(),
                SizedBox(height: 25),

                _buildSectionHeader('Date et heure', Icons.calendar_today),
                _buildDateTimeSelector(),
                SizedBox(height: 25),

                _buildSectionHeader('Photo', Icons.photo_camera),
                _buildImagePicker(),
                SizedBox(height: 30),

                Center(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: _isSubmitting
                        ? CircularProgressIndicator(color: Colors.white)
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send, size: 20),
                              SizedBox(width: 10),
                              Text('Envoyer l\'incident',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white,
                                    )),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserDisplay() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.person, color: _primaryColor),
          SizedBox(width: 10),
          Text(_userName ?? 'Chargement...', style: TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget _buildVehicleDropdown() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedVehicleId,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'Sélectionnez un véhicule',
          prefixIcon: Icon(Icons.directions_car, color: _primaryColor),
        ),
        items: _vehicles.map<DropdownMenuItem<String>>((vehicle) {
          return DropdownMenuItem<String>(
            value: vehicle['id'],
            child: Text(
              vehicle['text'],
              overflow: TextOverflow.ellipsis,
            ),
          );
        }).toList(),
        validator: (value) => value == null ? 'Ce champ est requis' : null,
        onChanged: (String? value) {
          setState(() {
            _selectedVehicleId = value;
          });
        },
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: _primaryColor),
        isExpanded: true,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: _primaryColor),
          SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              )),
        ],
      ),
    );
  }

 Widget _buildIncidentTypeSelector() {
  final List<Map<String, dynamic>> incidentTypes = [
    {
      'type': 'Panne mécanique',
      'icon': Icons.settings,
      'color': Color(0xFFFF7043),
      'gradient': [Color(0xFFFF7043), Color(0xFFFFA726)],
    },
    {
      'type': 'Accident',
      'icon': Icons.car_crash,
      'color': Color(0xFFE53935),
      'gradient': [Color(0xFFE53935), Color(0xFFEF5350)],
    },
    {
      'type': 'Retard',
      'icon': Icons.timer_off,
      'color': Color(0xFF5E35B1),
      'gradient': [Color(0xFF5E35B1), Color(0xFF7E57C2)],
    },
    {
      'type': 'Autre',
      'icon': Icons.error_outline,
      'color': Color(0xFF43A047),
      'gradient': [Color(0xFF43A047), Color(0xFF66BB6A)],
    },
  ];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 8.0, bottom: 8),
        child: RichText(
          text: TextSpan(
            text: "TYPE D'INCIDENT ",
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
            children: [
              TextSpan(
                text: "*",
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 12,
              spreadRadius: 2,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          child: DropdownButtonFormField<String>(
            value: selectedType,
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.red, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: _primaryColor.withOpacity(0.4), width: 2),
              ),
            ),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade800,
            ),
            hint: Row(
              children: [
                Icon(Icons.category, size: 22, color: Colors.grey.shade400),
                SizedBox(width: 12),
                Text(
                  'Sélectionnez un type',
                  style: TextStyle(color: Colors.grey.shade400),
                ),
              ],
            ),
            items: incidentTypes.map((typeData) {
              return DropdownMenuItem<String>(
                value: typeData['type'],
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: typeData['gradient'],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: typeData['color'].withOpacity(0.2),
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          typeData['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: 16),
                      Text(
                        typeData['type'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            validator: (value) => value == null ? 'Ce champ est requis' : null,
            onChanged: (value) => setState(() => selectedType = value),
            dropdownColor: Colors.white,
            icon: Container(
              margin: EdgeInsets.only(right: 8),
              child: Icon(Icons.arrow_drop_down, size: 28, color: _primaryColor),
            ),
            selectedItemBuilder: (context) {
              return incidentTypes.map((typeData) {
                return Container(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(typeData['icon'], 
                          size: 22, 
                          color: typeData['color']),
                      SizedBox(width: 12),
                      Text(
                        selectedType ?? '',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
    ],
  );
}

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 4),
         ) ],
      ),
      child: TextFormField(
        maxLines: 5,
        decoration: InputDecoration(
          hintText: 'Décrivez ce qui s\'est passé...',
          border: OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: EdgeInsets.all(15),
        ),
        validator: (value) => 
            value == null || value.isEmpty ? 'Description requise' : null,
        onSaved: (value) => description = value,
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return InkWell(
      onTap: () async {
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: incidentDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: ColorScheme.light(primary: _primaryColor),
            ),
            child: child!,
          ),
        );
        
        if (pickedDate != null) {
          final pickedTime = await showTimePicker(
            context: context,
            initialTime: TimeOfDay.fromDateTime(incidentDate),
          );
          
          if (pickedTime != null) {
            setState(() {
              incidentDate = DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              );
            });
          }
        }
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 4),
         ) ],
        ),
        child: Row(
          children: [
            Icon(Icons.access_time, color: Colors.grey.shade600),
            SizedBox(width: 15),
            Text(
              DateFormat('dd/MM/yyyy HH:mm').format(incidentDate),
              style: TextStyle(fontSize: 16),
            ),
            Spacer(),
            Text('Modifier', style: TextStyle(color: _primaryColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
  return Column(
    children: [
      if (selectedImage != null)
        Container(
          margin: EdgeInsets.only(bottom: 15),
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              selectedImage!,
              fit: BoxFit.cover,
            ),
          ),
        ),
      
      ElevatedButton.icon(
        onPressed: _pickImage,
        icon: Icon(Icons.add_photo_alternate),
        label: Text(selectedImage == null 
            ? 'Ajouter une photo' 
            : 'Changer la photo'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: _primaryColor,
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: _primaryColor),
          ),
        ),
      ),
    ],
  );
}
}

class IncidentListScreen extends StatefulWidget {
  @override
  _IncidentListScreenState createState() => _IncidentListScreenState();
}

class _IncidentListScreenState extends State<IncidentListScreen>
    with SingleTickerProviderStateMixin {
  final _primaryColor = Color(0xFF6C5CE7);
  final _secondaryColor = Color(0xFF00BFA5);
  final _alertColor = Color(0xFFFF7043);
  
  TabController? _tabController;
  String _filterStatus = 'Nouveau';

  
  @override
  void initState() {
    super.initState();
    // Initialiser normalement
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        setState(() {
          switch (_tabController!.index) {
            case 0: _filterStatus = 'Nouveau'; break;
            case 1: _filterStatus = 'En cours'; break;
            case 2: _filterStatus = 'Résolu'; break;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController?.dispose(); // Disposer avec vérification null-safe
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
     if (_tabController == null) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion des incidents'),
        backgroundColor: _primaryColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              icon: Icon(Icons.fiber_new, color: Colors.white),
              text: 'Nouveau',
            ),
            Tab(
              icon: Icon(Icons.timelapse, color: Colors.white),
              text: 'En cours',
            ),
            Tab(
              icon: Icon(Icons.check_circle, color: Colors.white),
              text: 'Résolu',
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('incidents')
            .orderBy('dateTime', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final incidents = snapshot.data!.docs.where((doc) {
            return (doc.data() as Map<String, dynamic>)['status'] == _filterStatus;
          }).toList();

          if (incidents.isEmpty) {
            return Center(
              child: Text(
                'Aucun incident à afficher',
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              return _buildIncidentCard(incidents[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildIncidentCard(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['dateTime'] as Timestamp).toDate();
    final status = data['status'] ?? 'Nouveau';

    Color statusColor;
    switch (status) {
      case 'Nouveau':
        statusColor = _alertColor;
        break;
      case 'En cours':
        statusColor = Colors.orange;
        break;
      case 'Résolu':
        statusColor = _secondaryColor;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _showIncidentDetails(doc),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Spacer(),
                  Text(DateFormat('dd/MM/yyyy').format(date)),
                ],
              ),
              SizedBox(height: 15),
              Text(
                data['type'] ?? 'Incident',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Par: ${data['userName'] ?? 'Inconnu'}",
                style: TextStyle(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              SizedBox(height: 8),
              Text(
                data['description'] ?? 'Pas de description',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              SizedBox(height: 15),
              if (data['imagePath'] != null && data['imagePath'].isNotEmpty)
                Container(
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: FileImage(File(data['imagePath'])),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
  void _showIncidentDetails(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final date = (data['dateTime'] as Timestamp).toDate();
    final status = data['status'] ?? 'Nouveau';
    String? response = data['response'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => IncidentDetailScreen(
        doc: doc,
        incidentData: data,
        date: date,
        status: status,
        initialResponse: response,
      ),
    );
  }
}

class IncidentDetailScreen extends StatefulWidget {
  final DocumentSnapshot doc;
  final Map<String, dynamic> incidentData;
  final DateTime date;
  final String status;
  final String? initialResponse;

  const IncidentDetailScreen({
    required this.doc,
    required this.incidentData,
    required this.date,
    required this.status,
    this.initialResponse,
  });

  @override
  _IncidentDetailScreenState createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  final _primaryColor = Color(0xFF6C5CE7);
  final _secondaryColor = Color(0xFF00BFA5);
  final _alertColor = Color(0xFFFF7043);
  late String _currentStatus;
  final _responseController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _responseController.text = widget.initialResponse ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      padding: EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Text(
                'Détails de l\'incident',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor,
                ),
              ),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 20),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailItem('Type', widget.incidentData['type']),
                  _buildDetailItem('Date', DateFormat('dd/MM/yyyy HH:mm').format(widget.date)),
                  _buildDetailItem('Statut', _currentStatus),
                  // Correction: Fallback à 'Inconnu' si le nom est absent
                  _buildDetailItem('Déclaré par', widget.incidentData['userName'] ?? 'Inconnu'),
                  SizedBox(height: 20),
                  
                  Text('Description',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      )),
                  SizedBox(height: 8),
                  Text(widget.incidentData['description'] ?? 'Aucune description',
                      style: TextStyle(fontSize: 16)),
                  SizedBox(height: 20),
                  
                  if (widget.incidentData['imagePath'] != null && 
                      widget.incidentData['imagePath'].isNotEmpty)
                    Column(
                      children: [
                        Text('Photo jointe',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: _primaryColor,
                            )),
                        SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(widget.incidentData['imagePath']),
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  
                  Text('Réponse du responsable',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      )),
                  SizedBox(height: 8),
                  TextField(
                    controller: _responseController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Entrez votre réponse...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  
                  Text('Changer le statut',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: _primaryColor,
                      )),
                  SizedBox(height: 10),
                  Row(
                    children: [
                      _buildStatusChip('Nouveau', _alertColor),
                      SizedBox(width: 10),
                      _buildStatusChip('En cours', Colors.orange),
                      SizedBox(width: 10),
                      _buildStatusChip('Résolu', _secondaryColor),
                    ],
                  ),
                  SizedBox(height: 30),
                  
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? CircularProgressIndicator(color: Colors.white)
                        :  Text(
          'Enregistrer les modifications',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white, // Ajout de cette ligne pour le texte blanc
          ),
        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String title, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title: ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              )),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, Color color) {
    return ChoiceChip(
      label: Text(status),
      selected: _currentStatus == status,
      onSelected: (selected) {
        if (selected) setState(() => _currentStatus = status);
      },
      selectedColor: color.withOpacity(0.2),
      backgroundColor: Colors.grey.shade200,
      labelStyle: TextStyle(
        color: _currentStatus == status ? color : Colors.grey.shade700,
        fontWeight: FontWeight.bold,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    
    try {
      await widget.doc.reference.update({
        'status': _currentStatus,
        'response': _responseController.text,
        'resolvedAt': _currentStatus == 'Résolu' ? Timestamp.now() : null,
      });
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('✅ Modifications enregistrées'),
        backgroundColor: _secondaryColor,
      ));
      
      Navigator.pop(context);
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('❌ Erreur: ${e.toString()}'),
        backgroundColor: _alertColor,
      ));
    } finally {
      setState(() => _isSaving = false);
    }
  }
}