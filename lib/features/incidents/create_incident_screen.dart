import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart' as f_auth;

import 'package:crisis_link/theme/app_colors.dart';
import 'package:crisis_link/core/constants.dart';
import 'package:crisis_link/services/firestore_service.dart';
import 'package:crisis_link/services/location_service.dart';
import 'package:crisis_link/services/ai_service.dart';
import 'package:crisis_link/models/incident_model.dart';
import 'package:crisis_link/widgets/glow_button.dart';

class CreateIncidentScreen extends ConsumerStatefulWidget {
  const CreateIncidentScreen({super.key});

  @override
  ConsumerState<CreateIncidentScreen> createState() => _CreateIncidentScreenState();
}

class _CreateIncidentScreenState extends ConsumerState<CreateIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _imagePicker = ImagePicker();

  IncidentType _selectedType = IncidentType.other;
  Severity _selectedSeverity = Severity.medium;
  
  // Incident coordinates
  double? _latitude;
  double? _longitude;
  String _addressText = 'Locating system node...';

  // Images state
  final List<String> _base64Images = [];
  final List<Uint8List> _imageBytes = [];

  // AI assessment state
  String _aiInterpretation = 'Formulate description and trigger AI Tactical Review.';
  bool _isAnalyzingAi = false;

  // Upload/Submit state
  bool _isSubmitting = false;
  double _uploadProgress = 0.0;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _lockGpsPosition();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _lockGpsPosition() async {
    try {
      final locService = ref.read(locationServiceProvider);
      final position = await locService.getCurrentLocation();
      final address = await locService.getAddressFromCoordinates(position.latitude, position.longitude);
      
      if (mounted) {
        setState(() {
          _latitude = position.latitude;
          _longitude = position.longitude;
          _addressText = address;
        });

        if (_mapController != null) {
          _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 15),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _latitude = 37.7749;
          _longitude = -122.4194;
          _addressText = 'Fallback Terminal: San Francisco, CA';
        });
      }
    }
  }

  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _imagePicker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 800,
      );

      if (pickedFiles.isNotEmpty) {
        for (final file in pickedFiles) {
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          
          setState(() {
            _imageBytes.add(bytes);
            _base64Images.add(base64String);
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to read media files: $e', style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
    }
  }

  Future<void> _triggerVoiceAssistant() async {
    // Cyberpunk Voice assistant simulation
    setState(() {
      _isAnalyzingAi = true;
      _aiInterpretation = 'Voice telemetry audio streaming active...';
    });

    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _descriptionController.text =
            'Multiple structure fire spreading quickly near residential zone. Strong winds from East accelerating expansion. Emergency evacuation needed.';
        _selectedType = IncidentType.fire;
        _selectedSeverity = Severity.critical;
        _isAnalyzingAi = false;
        _aiInterpretation = 'Voice transcription synced. Recalculating threat metrics.';
      });
      _triggerAiAnalysis();
    }
  }

  Future<void> _triggerAiAnalysis() async {
    final text = _descriptionController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _aiInterpretation = 'Unable to analyze: Description field is currently empty.';
      });
      return;
    }

    setState(() => _isAnalyzingAi = true);

    try {
      final aiService = ref.read(aiServiceProvider);
      final analysis = await aiService.analyzeIncident(text, _selectedType.name);
      if (mounted) {
        setState(() {
          _aiInterpretation = analysis;
          _isAnalyzingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiInterpretation = 'Strategic analyzer failure: $e';
          _isAnalyzingAi = false;
        });
      }
    }
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    if (_base64Images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ALERT: At least ONE on-site photographic image is MANDATORY.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS LOCK REQUIRED: Unable to establish location node.', style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.emergencyRed,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0.1;
    });

    // Simulate progress uploading
    for (int i = 2; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        setState(() {
          _uploadProgress = i / 10.0;
        });
      }
    }

    try {
      final user = f_auth.FirebaseAuth.instance.currentUser;
      final report = IncidentModel(
        id: const Uuid().v4(),
        userId: user?.uid ?? 'anonymous_operator',
        type: _selectedType.name,
        description: _descriptionController.text.trim(),
        severity: _selectedSeverity.name,
        latitude: _latitude!,
        longitude: _longitude!,
        imagesBase64: _base64Images,
        createdAt: DateTime.now(),
        status: 'active',
      );

      await ref.read(firestoreServiceProvider).createIncident(report);

      // Sync with python backend signal intake asynchronously
      final attachmentUrl = _base64Images.isNotEmpty ? _base64Images.first : null;
      ref.read(aiServiceProvider).submitHumanReport(
        userId: report.userId,
        text: '${_selectedType.displayName.toUpperCase()}: ${report.description}',
        lat: report.latitude,
        lon: report.longitude,
        attachmentUrl: attachmentUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('REPORT FILED SUCCESSFULLY. BROADCAST STREAM ACTIVE.', style: TextStyle(color: Colors.white)),
            backgroundColor: AppColors.successTeal,
          ),
        );
        // Reset or pop back
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transmission failed: $e', style: const TextStyle(color: Colors.white)),
            backgroundColor: AppColors.emergencyRed,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'FILE EMERGENCY REPORT',
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w900, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed, color: AppColors.accentAmber),
            onPressed: _lockGpsPosition,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: _isSubmitting
            ? _buildSubmittingOverlay()
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Telemetry GPS Card ---
                      _buildLocationTelemetryCard(),
                      const SizedBox(height: 16),

                      // --- Incident type & severity ---
                      _buildTypeSeveritySelection(),
                      const SizedBox(height: 16),

                      // --- Images Picker grid ---
                      _buildImageSelectorGrid(),
                      const SizedBox(height: 16),

                      // --- Report Details input ---
                      _buildIncidentFormInputs(),
                      const SizedBox(height: 16),

                      // --- AI Analytical Interpretation Card ---
                      _buildAiInterpretationPreview(),
                      const SizedBox(height: 24),

                      // --- Submission CTA ---
                      GlowButton(
                        label: 'TRANSMIT EMERGENCY DOSSIER',
                        onPressed: _submitReport,
                        color: AppColors.emergencyRed,
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // --- Widget Builders ---

  Widget _buildLocationTelemetryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.emergencyRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INCIDENT LOCATION LOCK',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _addressText,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Mini map confirmation
          SizedBox(
            height: 140,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude ?? 37.7749, _longitude ?? -122.4194),
                      zoom: 14,
                    ),
                    style: kDarkMapStyleJson,
                    myLocationEnabled: false,
                    zoomControlsEnabled: false,
                    onMapCreated: (controller) {
                      _mapController = controller;
                    },
                    markers: _latitude == null ? {} : {
                      Marker(
                        markerId: const MarkerId('report_coord'),
                        position: LatLng(_latitude!, _longitude!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                  ),
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.cardBorder.withValues(alpha: 0.5)),
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

  Widget _buildTypeSeveritySelection() {
    return Card(
      color: AppColors.secondarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Dropdown Incident Type
            const Text(
              'INCIDENT CATEGORY',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
            ),
            const SizedBox(height: 6),
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<IncidentType>(
                  value: _selectedType,
                  dropdownColor: AppColors.secondarySurface,
                  icon: const Icon(Icons.arrow_drop_down, color: AppColors.accentAmber),
                  isExpanded: true,
                  items: IncidentType.values.map((IncidentType type) {
                    return DropdownMenuItem<IncidentType>(
                      value: type,
                      child: Text(
                        type.displayName.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    );
                  }).toList(),
                  onChanged: (IncidentType? val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                      _triggerAiAnalysis(); // recalculate AI
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Severity Selector Row
            const Text(
              'REPORT SEVERITY THREAT',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            Row(
              children: Severity.values.map((sev) {
                final isSelected = _selectedSeverity == sev;
                final col = getSeverityColor(sev);
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _selectedSeverity = sev);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? col.withValues(alpha: 0.15) : AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? col : AppColors.cardBorder,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Text(
                        sev.displayName.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isSelected ? col : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSelectorGrid() {
    return Card(
      color: AppColors.secondarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PHOTOGRAPHIC EVIDENCE (MANDATORY)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
                ),
                Text(
                  '${_base64Images.length} LOADED',
                  style: TextStyle(
                    color: _base64Images.isEmpty ? AppColors.emergencyRed : AppColors.successTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            
            // Image list row
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Pick Button
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder, style: BorderStyle.solid),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: AppColors.accentAmber, size: 28),
                          SizedBox(height: 4),
                          Text('ADD PIC', style: TextStyle(color: AppColors.accentAmber, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Loaded Images
                  ...List.generate(_imageBytes.length, (idx) {
                    return Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.cardBorder),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              _imageBytes[idx],
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 14,
                          top: 4,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _imageBytes.removeAt(idx);
                                _base64Images.removeAt(idx);
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppColors.emergencyRed,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 12),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentFormInputs() {
    return Card(
      color: AppColors.secondarySurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'DETAILED BRIEFING (REQUIRED)',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5),
                ),
                GestureDetector(
                  onTap: _triggerVoiceAssistant,
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: AppColors.accentAmber, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'VOICE INPUT',
                        style: TextStyle(
                          color: AppColors.accentAmber.withValues(alpha: 0.9),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              maxLength: 500,
              decoration: const InputDecoration(
                hintText: 'Enter complete structural threat observations...',
                prefixIcon: null,
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please compile description before transmission.';
                }
                return null;
              },
              onChanged: (val) {
                // Throttle / trigger AI preview on significant length changes
                if (val.length % 15 == 0) {
                  _triggerAiAnalysis();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiInterpretationPreview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.secondarySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAnalyzingAi
              ? AppColors.successTeal
              : AppColors.cardBorder,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.psychology, color: AppColors.successTeal, size: 16),
                    const SizedBox(width: 8),
                    const Text(
                      'AI INTERPRETATION ANALYSIS',
                      style: TextStyle(
                        color: AppColors.successTeal,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                if (_isAnalyzingAi)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.successTeal),
                    ),
                  )
                else
                  GestureDetector(
                    onTap: _triggerAiAnalysis,
                    child: const Text(
                      'ANALYZE NOW',
                      style: TextStyle(
                        color: AppColors.accentAmber,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _aiInterpretation,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmittingOverlay() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.cloud_upload_rounded,
              color: AppColors.accentAmber,
              size: 64,
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 800.ms),
            const SizedBox(height: 24),
            const Text(
              'TRANSMITTING EMERGENCY FILE...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _uploadProgress,
              backgroundColor: AppColors.cardBackground,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emergencyRed),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_uploadProgress * 100).toStringAsFixed(0)}% TRANSMITTED',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
