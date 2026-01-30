import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart'; // For FormData
import 'package:indocement_apk/service/api_service.dart'; // Import ApiService
import 'package:mime/mime.dart'; // For determining file MIME type
import 'package:path/path.dart' as path; // For handling file names

class EditProfilePage extends StatefulWidget {
  final String employeeName;
  final String jobTitle;
  final String? urlFoto;
  final int? employeeId;

  const EditProfilePage({
    super.key,
    required this.employeeName,
    required this.jobTitle,
    this.urlFoto,
    this.employeeId,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool isEditing = false;
  File? _selectedImage;
  File? _supportingDocument; // Supports any file type
  String? _photoUrl;
  final bool _isUploading = false;
  final OutlineInputBorder inputBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.grey),
  );

  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _livingAreaController = TextEditingController();
  final TextEditingController _employeeNameController = TextEditingController();
  final TextEditingController _jobTitleController = TextEditingController();
  final TextEditingController _birthDateController = TextEditingController();
  final TextEditingController _employeeNoController = TextEditingController();
  final TextEditingController _serviceDateController = TextEditingController();
  final TextEditingController _noBpjsController = TextEditingController();
  final TextEditingController _workLocationController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  String? _selectedGender;
  String? _selectedEducation;
  final List<String> _genderOptions = ['Laki-laki', 'Perempuan'];
  final List<String> _educationOptions = [
    'TK',
    'SD',
    'SMP/Sederajat',
    'SLTA/Sederajat',
    'Diploma/D1',
    'Diploma/D2',
    'Diploma/D3',
    'Diploma/D4',
    'Sarjana/S1',
    'Magister/S2',
    'Doktor/S3',
    'lainnya',
  ];

  Map<String, dynamic> fullData = {};
  int? _userId;
  final Map<String, String> _changedFields = {};

  int? _coerceInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String? _mapGenderFromApi(String? apiValue) {
    if (apiValue == null) return null;
    switch (apiValue.toLowerCase()) {
      case 'l':
      case 'laki-laki':
      case 'male':
        return 'Laki-laki';
      case 'p':
      case 'perempuan':
      case 'female':
        return 'Perempuan';
      default:
        return null;
    }
  }

  String? _mapEducationFromApi(String? apiValue) {
    if (apiValue == null) return null;
    if (_educationOptions.contains(apiValue)) {
      return apiValue;
    }
    return null;
  }

  String? _mapGenderToApi(String? displayValue) {
    if (displayValue == null) return null;
    switch (displayValue.toLowerCase()) {
      case 'laki-laki':
      case 'l':
      case 'male':
        return 'L';
      case 'perempuan':
      case 'p':
      case 'female':
        return 'P';
      default:
        return displayValue;
    }
  }

  String _normalizeValueForApi(String fieldName, String value) {
    switch (fieldName) {
      case 'BirthDate':
      case 'ServiceDate':
        return _formatDateApi(value) ?? value;
      case 'Gender':
        return _mapGenderToApi(value) ?? value;
      default:
        return value;
    }
  }

  DateTime? _parseDateFlexible(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      return DateTime.parse(value);
    } catch (_) {}
    try {
      return DateFormat('yyyy-MM-dd').parseStrict(value);
    } catch (_) {}
    try {
      return DateFormat('dd/MM/yy').parseStrict(value);
    } catch (_) {}
    return null;
  }

  String? _formatDateDisplay(String? dateString) {
    final dateTime = _parseDateFlexible(dateString);
    if (dateTime == null) return null;
    return DateFormat('dd/MM/yy').format(dateTime);
  }

  String? _formatDateApi(String? dateString) {
    final dateTime = _parseDateFlexible(dateString);
    if (dateTime == null) return null;
    return DateFormat('yyyy-MM-dd').format(dateTime);
  }

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
    _startPolling();
  }

  Future<String> _fetchSectionName(int? idSection) async {
    if (idSection == null || idSection <= 0) {
      return 'Tidak Tersedia';
    }

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Sections/$idSection',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final sectionData =
            response.data is String ? jsonDecode(response.data) : response.data;
        return sectionData['NamaSection']?.toString() ?? 'Tidak Tersedia';
      } else {
        return 'Tidak Tersedia';
      }
    } catch (e) {
      return 'Tidak Tersedia';
    }
  }

  Future<void> _fetchVerifData() async {
    final employeeId = widget.employeeId ??
        (await SharedPreferences.getInstance()).getInt('idEmployee');
    if (employeeId == null) return;

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/VerifData/requests',
        params: {'employeeId': employeeId},
      );

      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        final verifData = data
            .cast<Map<String, dynamic>>()
            .where((verif) =>
                verif['EmployeeId']?.toString() == employeeId.toString() &&
                verif['Status'] == 'Approved') // Only process Approved status
            .toList();

        for (var verif in verifData) {
          final fieldName = verif['FieldName']?.toString();
          final newValueRaw = verif['NewValue']?.toString();
          final status = verif['Status']?.toString();
          if (fieldName != null &&
              newValueRaw != null &&
              status == 'Approved') {
            String? newValue = newValueRaw;
            if (fieldName == 'BirthDate' || fieldName == 'ServiceDate') {
              newValue = _formatDateDisplay(newValueRaw);
            }

            setState(() {
              switch (fieldName) {
                case 'EmployeeName':
                  _employeeNameController.text = newValue ?? '';
                  fullData['EmployeeName'] = newValue;
                  break;
                case 'BirthDate':
                  _birthDateController.text = newValue ?? '';
                  fullData['BirthDate'] =
                      _formatDateApi(newValue) ?? newValue;
                  break;
                case 'Gender':
                  _selectedGender = _mapGenderFromApi(newValue);
                  fullData['Gender'] = newValue;
                  break;
                case 'Education':
                  _selectedEducation = _mapEducationFromApi(newValue);
                  fullData['Education'] = newValue;
                  break;
                case 'EmployeeNo':
                  _employeeNoController.text = newValue ?? '';
                  fullData['EmployeeNo'] = newValue;
                  break;
                case 'JobTitle':
                  _jobTitleController.text = newValue ?? '';
                  fullData['JobTitle'] = newValue;
                  break;
                case 'ServiceDate':
                  _serviceDateController.text = newValue ?? '';
                  fullData['ServiceDate'] =
                      _formatDateApi(newValue) ?? newValue;
                  break;
                case 'NoBpjs':
                  _noBpjsController.text = newValue ?? '';
                  fullData['NoBpjs'] = newValue;
                  break;
                case 'WorkLocation':
                  _workLocationController.text = newValue ?? '';
                  fullData['WorkLocation'] = newValue;
                  break;
                case 'Section':
                  _sectionController.text = newValue ?? '';
                  fullData['Section'] = newValue;
                  break;
                case 'Telepon':
                  _phoneController.text = newValue ?? '';
                  fullData['Telepon'] = newValue;
                  break;
                case 'Email':
                  _emailController.text = newValue ?? '';
                  fullData['Email'] = newValue;
                  break;
                case 'LivingArea':
                  _livingAreaController.text = newValue ?? '';
                  fullData['LivingArea'] = newValue;
                  break;
              }
              final prefs = SharedPreferences.getInstance();
              prefs.then(
                  (p) => p.setString(fieldName.toLowerCase(), newValue ?? ''));
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching verification data: $e');
    }
  }

  Future<void> _fetchInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = widget.employeeId ?? prefs.getInt('idEmployee');
    final userId = prefs.getInt('id');

    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ID karyawan tidak ditemukan, silakan login ulang')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    setState(() {
      _userId = userId;
      _employeeNameController.text =
          prefs.getString('employeeName') ?? widget.employeeName;
      _phoneController.text = prefs.getString('telepon') ?? '';
      _emailController.text = prefs.getString('email') ?? '';
      _jobTitleController.text = prefs.getString('jobTitle') ?? widget.jobTitle;
      _livingAreaController.text = prefs.getString('livingArea') ?? '';
      _photoUrl = widget.urlFoto ?? prefs.getString('urlFoto');
    });

    await _fetchVerifData();

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees/$employeeId',
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final employee =
            response.data is String ? jsonDecode(response.data) : response.data;
        final idSection = employee['IdSection'] != null
            ? int.tryParse(employee['IdSection'].toString())
            : null;
        final sectionName = await _fetchSectionName(idSection);

        String? validatedBirthDate =
            _formatDateDisplay(employee['BirthDate']);
        if (validatedBirthDate != null && validatedBirthDate.isNotEmpty) {
          final parsedDate = _parseDateFlexible(validatedBirthDate);
          final firstDate = DateTime(1900);
          if (parsedDate == null || parsedDate.isBefore(firstDate)) {
            validatedBirthDate = '';
          }
        }

        String? validatedServiceDate =
            _formatDateDisplay(employee['ServiceDate']);
        if (validatedServiceDate != null && validatedServiceDate.isNotEmpty) {
          final parsedDate = _parseDateFlexible(validatedServiceDate);
          final firstDate = DateTime(1900);
          if (parsedDate == null || parsedDate.isBefore(firstDate)) {
            validatedServiceDate = '';
          }
        }

        setState(() {
          fullData = employee;
          _employeeNameController.text =
              employee['EmployeeName']?.isNotEmpty == true
                  ? employee['EmployeeName']
                  : _employeeNameController.text;
          _jobTitleController.text =
              employee['JobTitle'] ?? _jobTitleController.text;
          _livingAreaController.text =
              employee['LivingArea'] ?? _livingAreaController.text;
          _birthDateController.text = validatedBirthDate ?? '';
          _employeeNoController.text = employee['EmployeeNo'] ?? '';
          _serviceDateController.text = validatedServiceDate ?? '';
          _noBpjsController.text = employee['NoBpjs'] ?? '';
          _selectedGender = _mapGenderFromApi(employee['Gender']);
          _selectedEducation = _mapEducationFromApi(employee['Education']);
          _workLocationController.text = employee['WorkLocation'] ?? '';
          _sectionController.text = sectionName;

          if (employee['UrlFoto'] != null && employee['UrlFoto'].isNotEmpty) {
            _photoUrl = employee['UrlFoto'].startsWith('/')
                ? 'http://34.50.112.226:5555${employee['UrlFoto']}'
                : employee['UrlFoto'];
          } else {
            _photoUrl = null;
          }
        });

        await prefs.setString('employeeNo', _employeeNoController.text);
        await prefs.setString('employeeName', _employeeNameController.text);
        await prefs.setString('jobTitle', _jobTitleController.text);
        await prefs.setString('livingArea', _livingAreaController.text);
        await prefs.setString('birthDate', _birthDateController.text);
        await prefs.setString('gender', _selectedGender ?? '');
        await prefs.setString('education', _selectedEducation ?? '');
        await prefs.setString('serviceDate', _serviceDateController.text);
        await prefs.setString('workLocation', _workLocationController.text);
        await prefs.setString('section', _sectionController.text);
        await prefs.setString('telepon', _phoneController.text);
        await prefs.setString('email', _emailController.text);
        await prefs.setString('livingArea', _livingAreaController.text);
        await prefs.setString('noBpjs', _noBpjsController.text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat data: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  void _startPolling() {
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted) {
        await _fetchVerifData();
      } else {
        timer.cancel();
      }
    });
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Permintaan berhasil dikirim, silakan menunggu verifikasi dari PIC Anda",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1572E8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitChangeRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = widget.employeeId ??
        _coerceInt(fullData['Id']) ??
        _coerceInt(fullData['EmployeeId']) ??
        _coerceInt(fullData['id']) ??
        _coerceInt(fullData['idEmployee']) ??
        prefs.getInt('idEmployee');
    print(
        'submitChangeRequests employeeId=$employeeId fullDataId=${fullData['Id']} prefsId=${prefs.getInt('idEmployee')}');
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('ID karyawan tidak ditemukan, silakan login ulang')),
      );
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    if (_supportingDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap unggah dokumen pendukung terlebih dahulu')),
      );
      return;
    }

    bool atLeastOneSuccess = false;
    List<String> failedFields = [];

    for (var entry in _changedFields.entries) {
      final fieldName = entry.key;
      final newValue = entry.value;
      final oldValue = fullData[fieldName] ?? '';
      final normalizedNewValue =
          _normalizeValueForApi(fieldName, newValue.toString());
      final normalizedOldValue =
          _normalizeValueForApi(fieldName, oldValue.toString());

      try {
        // Determine MIME type dynamically
        final mimeType = lookupMimeType(_supportingDocument!.path) ??
            'application/octet-stream';
        final mimeParts = mimeType.split('/');
        final formData = FormData.fromMap({
          // Match Swagger exactly
          'EmployeeId': employeeId,
          'FieldName': fieldName,
          'OldValue': normalizedOldValue,
          'NewValue': normalizedNewValue,
          'SupportingDocumentPath': await MultipartFile.fromFile(
            _supportingDocument!.path,
            contentType: MediaType(mimeParts[0], mimeParts[1]),
            filename: path.basename(_supportingDocument!.path),
          ),
        });

        final response = await ApiService.post(
          'http://34.50.112.226:5555/api/VerifData/request',
          data: formData,
          headers: {
            'accept': '*/*',
          },
          validateStatus: (_) => true,
        ).timeout(const Duration(seconds: 10));

        print('Response status for $fieldName: ${response.statusCode}');
        print('Response body for $fieldName: ${response.data}');

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! <= 204) {
          atLeastOneSuccess = true;
        } else {
          failedFields.add(fieldName);
          print(
              'Failed to submit $fieldName: ${response.statusCode} - ${response.data}');
        }
      } on DioException catch (e) {
        failedFields.add(fieldName);
        final status = e.response?.statusCode;
        final data = e.response?.data;
        print('Error submitting $fieldName: $status - $data');
      } catch (e) {
        failedFields.add(fieldName);
        print('Error submitting $fieldName: $e');
      }
    }

    setState(() {
      isEditing = false;
      _supportingDocument = null;
      _changedFields.clear();
      // Reset text controllers to original values
      _employeeNameController.text = fullData['EmployeeName'] ?? '';
      _jobTitleController.text = fullData['JobTitle'] ?? '';
      _livingAreaController.text = fullData['LivingArea'] ?? '';
      _birthDateController.text =
          _formatDateDisplay(fullData['BirthDate']) ?? '';
      _employeeNoController.text = fullData['EmployeeNo'] ?? '';
      _serviceDateController.text =
          _formatDateDisplay(fullData['ServiceDate']) ?? '';
      _noBpjsController.text = fullData['NoBpjs'] ?? '';
      _selectedGender = _mapGenderFromApi(fullData['Gender']);
      _selectedEducation = _mapEducationFromApi(fullData['Education']);
      _workLocationController.text = fullData['WorkLocation'] ?? '';
      _phoneController.text = fullData['Telepon'] ?? '';
      _emailController.text = fullData['Email'] ?? '';
      // Section is fetched separately, so we don't reset it here
    });

    if (atLeastOneSuccess) {
      _showSuccessModal();
    }
    if (failedFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Gagal mengirim perubahan untuk field: ${failedFields.join(', ')}')),
      );
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
      _showImageConfirmationPopup(File(image.path));
    }
  }

  Future<void> _pickSupportingDocument() async {
    final ImagePicker picker = ImagePicker();
    final XFile? file =
        await picker.pickMedia(); // Allows picking any file type

    if (file != null) {
      setState(() {
        _supportingDocument = File(file.path);
      });
      _showDocumentConfirmationPopup(File(file.path));
    }
  }

  Future<void> _uploadImage(File image) async {
    final employeeId = widget.employeeId ??
        (await SharedPreferences.getInstance()).getInt('idEmployee');
    if (employeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID karyawan tidak ditemukan')),
      );
      return;
    }

    try {
      final formData = FormData.fromMap({
        'File': await MultipartFile.fromFile(
          image.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      final response = await ApiService.put(
        'http://34.50.112.226:5555/api/Employees/$employeeId/UrlFoto',
        data: formData,
        headers: {
          'accept': '*/*',
        },
      );

      if (response.statusCode == 204) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gambar berhasil diunggah')),
        );
        await _fetchInitialData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Gagal mengunggah gambar: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  void _showImageConfirmationPopup(File image) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(image,
                      width: 200, height: 200, fit: BoxFit.cover),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Apakah Anda yakin ingin mengganti foto profil?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _uploadImage(image);
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.cancel, color: Colors.red, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _selectedImage = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDocumentConfirmationPopup(File document) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description, color: Colors.blue, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Apakah Anda yakin ingin menggunakan dokumen ${path.basename(document.path)}?",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.cancel, color: Colors.red, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() {
                          _supportingDocument = null;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEditConfirmationPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Apakah Anda yakin ingin mengedit profil Anda?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                        setState(() => isEditing = true);
                      },
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.cancel, color: Colors.red, size: 32),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRequestConfirmationPopup() {
    if (_supportingDocument == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Harap unggah dokumen pendukung terlebih dahulu')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Apakah Anda yakin ingin mengajukan perubahan berikut?",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87),
                  ),
                  const SizedBox(height: 16),
                  ..._changedFields.entries.map((entry) {
                    final fieldName = entry.key;
                    final newValue = entry.value;
                    final oldValue = fullData[fieldName] ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "Field: $fieldName\nDari: $oldValue\nMenjadi: $newValue",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text(
                    "Dokumen Pendukung: ${_supportingDocument != null ? path.basename(_supportingDocument!.path) : 'Tidak ada'}",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle,
                            color: Colors.green, size: 32),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _submitChangeRequests();
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel,
                            color: Colors.red, size: 32),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(
      BuildContext context,
      TextEditingController controller,
      String fieldName,
      String oldValue) async {
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime.now();
    DateTime initialDate = DateTime.now();

    if (controller.text.isNotEmpty) {
      final parsed = _parseDateFlexible(controller.text);
      if (parsed != null) {
        initialDate = parsed;
        if (initialDate.isBefore(firstDate)) {
          initialDate = firstDate;
        }
        if (initialDate.isAfter(lastDate)) {
          initialDate = lastDate;
        }
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );

    if (picked != null) {
      setState(() {
        final displayValue = DateFormat('dd/MM/yy').format(picked);
        final apiValue = DateFormat('yyyy-MM-dd').format(picked);
        controller.text = displayValue;
        final normalizedOld = _formatDateApi(oldValue) ?? oldValue;
        if (apiValue != normalizedOld && controller.text.isNotEmpty) {
          _changedFields[fieldName] = apiValue;
        } else {
          _changedFields.remove(fieldName);
        }
      });
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required TextInputType keyboardType,
    bool isDateField = false,
    String? fieldName,
    String? oldValue,
    bool alwaysReadOnly = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        readOnly: alwaysReadOnly || !isEditing || (isDateField && isEditing),
        keyboardType: keyboardType,
        onTap: isDateField && isEditing && !alwaysReadOnly
            ? () => _selectDate(context, controller, fieldName!, oldValue!)
            : null,
        onChanged: isEditing &&
                !alwaysReadOnly &&
                fieldName != null &&
                oldValue != null
            ? (value) {
                setState(() {
                  if (value != oldValue && value.isNotEmpty) {
                    _changedFields[fieldName] = value;
                  } else {
                    _changedFields.remove(fieldName);
                  }
                });
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: inputBorder,
          labelStyle: GoogleFonts.poppins(fontSize: 16),
          suffixIcon: isDateField && isEditing
              ? const Icon(Icons.calendar_today)
              : null,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String fieldName,
    required String oldValue,
    required Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value != null && items.contains(value) ? value : null,
        items: items.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: GoogleFonts.poppins(fontSize: 16)),
          );
        }).toList(),
        onChanged: isEditing
            ? (newValue) {
                onChanged(newValue);
                setState(() {
                  if (newValue != null && newValue != oldValue) {
                    _changedFields[fieldName] = newValue;
                  } else {
                    _changedFields.remove(fieldName);
                  }
                });
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: inputBorder,
          labelStyle: GoogleFonts.poppins(fontSize: 16),
        ),
        hint: Text('Pilih $label',
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
      ),
    );
  }

  Widget _buildSectionCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: const Color(0xFF1572E8)),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget uploadDokumenBox({
    required String title,
    required File? file,
    required VoidCallback onPick,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: file != null ? Colors.green : Colors.grey[400]!,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(
                color: file != null ? Colors.green : Colors.grey[300]!,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: file != null
                ? (file.path.endsWith('.pdf')
                    ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(file, fit: BoxFit.cover),
                      ))
                : const Icon(Icons.insert_drive_file, color: Colors.grey, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  file != null ? file.path.split('/').last : "File belum dipilih",
                  style: TextStyle(
                    color: file != null ? Colors.green[700] : Colors.grey[500],
                    fontWeight: file != null ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, color: Colors.blue, size: 18),
                  label: Text(
                    file != null ? "Ganti File" : "Pilih File",
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.blue, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: onPick,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profil Saya',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF1572E8),
        actions: [
          IconButton(
            icon:
                Icon(isEditing ? Icons.close : Icons.edit, color: Colors.white),
            onPressed: isEditing
                ? () => setState(() {
                      isEditing = false;
                      _changedFields.clear();
                      _supportingDocument = null;
                      // Reset text controllers to original values
                      _employeeNameController.text =
                          fullData['EmployeeName'] ?? '';
                      _jobTitleController.text = fullData['JobTitle'] ?? '';
                      _livingAreaController.text = fullData['LivingArea'] ?? '';
                      _birthDateController.text =
                          _formatDateDisplay(fullData['BirthDate']) ?? '';
                      _employeeNoController.text = fullData['EmployeeNo'] ?? '';
                      _serviceDateController.text =
                          _formatDateDisplay(fullData['ServiceDate']) ?? '';
                      _noBpjsController.text = fullData['NoBpjs'] ?? '';
                      _selectedGender = _mapGenderFromApi(fullData['Gender']);
                      _selectedEducation =
                          _mapEducationFromApi(fullData['Education']);
                      _workLocationController.text =
                          fullData['WorkLocation'] ?? '';
                      _phoneController.text = fullData['Telepon'] ?? '';
                      _emailController.text = fullData['Email'] ?? '';
                    })
                : _showEditConfirmationPopup,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!) as ImageProvider
                      : (_photoUrl != null && _photoUrl!.isNotEmpty
                          ? NetworkImage(_photoUrl!)
                          : const AssetImage('assets/images/profile.png')),
                  backgroundColor: Colors.grey[200],
                  child: _selectedImage == null &&
                          (_photoUrl == null || _photoUrl!.isEmpty)
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                if (_isUploading) const CircularProgressIndicator(),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: isEditing ? _pickImage : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1572E8),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                'Edit Foto Profil',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            _buildSectionCard('Informasi Pribadi', [
              _buildTextField(
                label: 'Nama Karyawan',
                controller: _employeeNameController,
                keyboardType: TextInputType.text,
                fieldName: 'EmployeeName',
                oldValue: fullData['EmployeeName'] ?? '',
              ),
              _buildTextField(
                label: 'Tanggal Lahir',
                controller: _birthDateController,
                keyboardType: TextInputType.datetime,
                isDateField: true,
                fieldName: 'BirthDate',
                oldValue: fullData['BirthDate'] ?? '',
              ),
              _buildDropdownField(
                label: 'Jenis Kelamin',
                value: _selectedGender,
                items: _genderOptions,
                fieldName: 'Gender',
                oldValue: fullData['Gender'] ?? '',
                onChanged: (value) => setState(() => _selectedGender = value),
              ),
              _buildDropdownField(
                label: 'Pendidikan',
                value: _selectedEducation,
                items: _educationOptions,
                fieldName: 'Education',
                oldValue: fullData['Education'] ?? '',
                onChanged: (value) =>
                    setState(() => _selectedEducation = value),
              ),
            ]),
            _buildSectionCard('Informasi Pekerjaan', [
              _buildTextField(
                label: 'Nomor Karyawan',
                controller: _employeeNoController,
                keyboardType: TextInputType.text,
                fieldName: 'EmployeeNo',
                oldValue: fullData['EmployeeNo'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Jabatan',
                controller: _jobTitleController,
                keyboardType: TextInputType.text,
                fieldName: 'JobTitle',
                oldValue: fullData['JobTitle'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Tanggal Mulai Kerja',
                controller: _serviceDateController,
                keyboardType: TextInputType.datetime,
                isDateField: true,
                fieldName: 'ServiceDate',
                oldValue: fullData['ServiceDate'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Nomor BPJS',
                controller: _noBpjsController,
                keyboardType: TextInputType.text,
                fieldName: 'NoBpjs',
                oldValue: fullData['NoBpjs'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Lokasi Kerja',
                controller: _workLocationController,
                keyboardType: TextInputType.text,
                fieldName: 'WorkLocation',
                oldValue: fullData['WorkLocation'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Section',
                controller: _sectionController,
                keyboardType: TextInputType.text,
                fieldName: 'Section',
                oldValue: fullData['Section'] ?? '',
                alwaysReadOnly: true,
              ),
            ]),
            _buildSectionCard('Kontak', [
              _buildTextField(
                label: 'Nomor Telepon',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                fieldName: 'Telepon',
                oldValue: fullData['Telepon'] ?? '',
              ),
              _buildTextField(
                label: 'Email',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                fieldName: 'Email',
                oldValue: fullData['Email'] ?? '',
                alwaysReadOnly: true,
              ),
              _buildTextField(
                label: 'Living Area',
                controller: _livingAreaController,
                keyboardType: TextInputType.text,
                fieldName: 'LivingArea',
                oldValue: fullData['LivingArea'] ?? '',
              ),
            ]),
            const SizedBox(height: 16),
            uploadDokumenBox(
              title: 'Upload Dokumen Pendukung',
              file: _supportingDocument,
              onPick: isEditing ? _pickSupportingDocument : () {},
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isEditing &&
                      _supportingDocument != null &&
                      _changedFields.isNotEmpty
                  ? _showRequestConfirmationPopup
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing &&
                        _supportingDocument != null &&
                        _changedFields.isNotEmpty
                    ? const Color(0xFF1572E8)
                    : Colors.grey,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
              ),
              child: Text(
                'Ajukan Perubahan',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _livingAreaController.dispose();
    _employeeNameController.dispose();
    _jobTitleController.dispose();
    _birthDateController.dispose();
    _employeeNoController.dispose();
    _serviceDateController.dispose();
    _noBpjsController.dispose();
    _workLocationController.dispose();
    _sectionController.dispose();
    super.dispose();
  }
}
