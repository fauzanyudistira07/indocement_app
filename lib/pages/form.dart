import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/hr_menu.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';

class KeluhanPage extends StatefulWidget {
  const KeluhanPage({super.key});

  @override
  _KeluhanPageState createState() => _KeluhanPageState();
}

class _KeluhanPageState extends State<KeluhanPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  String? _sectionName;
  int? _idSection;
  final List<XFile> _selectedFiles = [];
  int _lines = 0;
  int _words = 0;
  int? _employeeId;
  String? _whatsappNumber;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
    _messageController.addListener(_updateLinesAndWords);
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  void _showErrorModal(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Gagal',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.red,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSuccessModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline_rounded,
                  color: Color(0xFF1572E8),
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Berhasil',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF1572E8),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Keluhan Berhasil Terkirim',
                  style: GoogleFonts.poppins(
                    fontSize: 16.5,
                    color: Colors.black87,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1572E8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'OK',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    print('SharedPreferences keys: ${prefs.getKeys()}');
    for (var key in prefs.getKeys()) {
      print('$key: ${prefs.get(key)}');
    }

    final employeeName = prefs.getString('employeeName') ?? 'Unknown';
    final email = prefs.getString('email') ?? 'Unknown';
    final employeeId = prefs.getInt('idEmployee');
    final whatsappNumber = prefs.getString('telepon');
    final sectionName = prefs.getString('section') ?? 'Unknown';

    setState(() {
      _nameController.text = employeeName;
      _emailController.text = email;
      _employeeId = employeeId;
      _whatsappNumber = whatsappNumber;
      _sectionName = sectionName;
      _sectionController.text = sectionName;
    });
  }

  void _updateLinesAndWords() {
    final text = _messageController.text;
    print('Message input: $text');
    setState(() {
      _lines = text.isEmpty ? 0 : text.split('\n').length;
      _words = text.length;
    });
  }

  Future<void> _chooseFile() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'files',
        extensions: ['jpg', 'gif', 'jpeg', 'png', 'txt', 'pdf'],
      );
      final file = await openFile(acceptedTypeGroups: [typeGroup]);

      if (file != null) {
        final fileSize = await file.length();
        const maxSize = 10 * 1024 * 1024;
        if (fileSize > maxSize) {
          if (mounted) {
            _showErrorModal('Ukuran file melebihi batas 10MB.');
          }
          return;
        }

        setState(() {
          _selectedFiles.add(file);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Kesalahan saat memilih file: $e');
      }
    }
  }

  Future<void> _addMoreFiles() async {
    try {
      const typeGroup = XTypeGroup(
        label: 'files',
        extensions: ['jpg', 'gif', 'jpeg', 'png', 'txt', 'pdf'],
      );
      final files = await openFiles(acceptedTypeGroups: [typeGroup]);

      if (files.isNotEmpty) {
        const maxSize = 10 * 1024 * 1024;
        for (var file in files) {
          final fileSize = await file.length();
          if (fileSize > maxSize) {
            if (mounted) {
              _showErrorModal('File ${file.name} melebihi batas 10MB.');
            }
            return;
          }
        }

        setState(() {
          _selectedFiles.addAll(files);
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Kesalahan saat menambahkan file: $e');
      }
    }
  }

  Future<bool> _sendWhatsAppNotification(String number, String message) async {
    final phoneRegex = RegExp(r'^\+62\d{9,11}$');
    if (!phoneRegex.hasMatch(number)) {
      print('Invalid WhatsApp number: $number');
      return false;
    }

    try {
      print('Simulating WhatsApp notification to $number: $message');
      return true;
    } catch (e) {
      print('WhatsApp notification error: $e');
      return false;
    }
  }

  Future<void> _submitComplaint() async {
    if (_employeeId == null) {
      if (mounted) {
        _showErrorModal('ID Karyawan tidak ditemukan. Silakan login kembali.');
      }
      return;
    }
    if (_subjectController.text.isEmpty) {
      if (mounted) _showErrorModal('Subjek harus diisi.');
      return;
    }
    if (_sectionName == null ||
        _sectionName!.isEmpty ||
        _sectionName == 'Unknown') {
      if (mounted) _showErrorModal('Section harus diisi.');
      return;
    }
    if (_messageController.text.isEmpty) {
      if (mounted) _showErrorModal('Pesan harus diisi.');
      return;
    }

    bool whatsappSuccess = false;
    if (_whatsappNumber != null) {
      whatsappSuccess = await _sendWhatsAppNotification(
        _whatsappNumber!,
        'Keluhan baru telah dikirim: ${_subjectController.text}',
      );
    }

    try {
      _showLoading(context);

      // Siapkan FormData
      final Map<String, dynamic> fields = {
        'IdEmployee': _employeeId.toString(),
        'Keluhan': _messageController.text,
        'TglKeluhan': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String(),
        'CreatedAt': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String(),
        'UpdatedAt': DateTime.now()
            .toUtc()
            .add(const Duration(hours: 7))
            .toIso8601String(),
        'Status': 'Terkirim',
        'subject': _subjectController.text,
        'NamaSection': _sectionName!,
      };

      if (_selectedFiles.isNotEmpty) {
        final fileNames = _selectedFiles.map((file) => file.name).join(',');
        fields['NamaFile'] = fileNames;
      }

      final formData = FormData();
      fields.forEach((key, value) {
        formData.fields.add(MapEntry(key, value));
      });

      for (var file in _selectedFiles) {
        formData.files.add(MapEntry(
          'FotoKeluhan',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ));
      }

      final response = await ApiService.post(
        'http://103.31.235.237:5555/api/keluhans',
        data: formData,
        headers: {'accept': 'application/json'},
      );

      Navigator.of(context).pop();

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) _showSuccessModal();
      } else {
        if (mounted) {
          _showErrorModal(
            'Gagal mengirim keluhan: ${response.statusCode} - ${response.data}',
          );
        }
      }
    } catch (e) {
      if (mounted) _showErrorModal('Kesalahan saat mengirim keluhan: $e');
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _sectionController.dispose();
    _messageController.removeListener(_updateLinesAndWords);
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        exit(0);
        return false;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double screenWidth = constraints.maxWidth;
          final double screenHeight = constraints.maxHeight;
          final double paddingValue = screenWidth * 0.05;
          final double baseFontSize = screenWidth * 0.04;
          final double cardElevation = screenWidth * 0.008;
          final Color primaryColor = const Color(0xFF1C6FE8);
          final Color backgroundColor = const Color(0xFFF4F6F9);
          final Color cardColor = Colors.white;
          final Color borderColor = const Color(0xFFE3E7EE);
          final Color textColor = const Color(0xFF1F2937);
          final double cardRadius = 16;
          final double fieldRadius = 12;

          InputDecoration inputDecoration({
            required String label,
            String? hint,
            Widget? suffixIcon,
          }) {
            return InputDecoration(
              labelText: label,
              hintText: hint,
              labelStyle: GoogleFonts.poppins(
                fontSize: baseFontSize * 0.85,
                color: Colors.grey[700],
              ),
              hintStyle: GoogleFonts.poppins(
                fontSize: baseFontSize * 0.8,
                color: Colors.grey[500],
              ),
              filled: true,
              fillColor: cardColor,
              contentPadding: EdgeInsets.symmetric(
                horizontal: paddingValue * 0.9,
                vertical: paddingValue * 0.7,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldRadius),
                borderSide: BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldRadius),
                borderSide: BorderSide(color: borderColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(fieldRadius),
                borderSide: BorderSide(color: primaryColor, width: 1.5),
              ),
              suffixIcon: suffixIcon,
            );
          }

          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(
              title: Text(
                'HR Care',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: baseFontSize * 1.2,
                  color: Colors.white,
                ),
              ),
              backgroundColor: primaryColor,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const HRCareMenuPage()),
                  );
                },
              ),
            ),
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(paddingValue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: paddingValue * 0.6),
                    Text(
                      'Form Keluhan',
                      style: GoogleFonts.poppins(
                        fontSize: baseFontSize * 1.35,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    SizedBox(height: paddingValue * 0.2),
                    Text(
                      'Lengkapi detail keluhan agar dapat diproses lebih cepat.',
                      style: GoogleFonts.poppins(
                        fontSize: baseFontSize * 0.85,
                        color: Colors.grey[600],
                      ),
                    ),
                    SizedBox(height: paddingValue),
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      color: cardColor,
                      child: Padding(
                        padding: EdgeInsets.all(paddingValue * 0.9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _nameController,
                              readOnly: true,
                              decoration: inputDecoration(label: 'Nama'),
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.5),
                            TextField(
                              controller: _emailController,
                              readOnly: true,
                              decoration:
                                  inputDecoration(label: 'Alamat Email'),
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.5),
                            TextField(
                              controller: _subjectController,
                              decoration: inputDecoration(
                                label: 'Subjek',
                                hint: 'Contoh: Perbaikan fasilitas',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.5),
                            TextField(
                              controller: _sectionController,
                              readOnly: true,
                              decoration: inputDecoration(label: 'Seksi'),
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.5),
                            Text(
                              'Pesan',
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.3),
                            TextField(
                              controller: _messageController,
                              maxLines: 5,
                              decoration: inputDecoration(
                                label: 'Detail Keluhan',
                                hint: 'Jelaskan kronologi atau kebutuhan Anda.',
                              ),
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.8,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(
                                  'Baris: $_lines',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: baseFontSize * 0.7,
                                  ),
                                ),
                                SizedBox(width: paddingValue * 0.4),
                                Text(
                                  'Karakter: $_words',
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: baseFontSize * 0.7,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: paddingValue),
                    Card(
                      elevation: cardElevation,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(cardRadius),
                      ),
                      color: cardColor,
                      child: Padding(
                        padding: EdgeInsets.all(paddingValue * 0.9),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lampiran',
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: paddingValue * 0.4),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: backgroundColor,
                                borderRadius:
                                    BorderRadius.circular(fieldRadius),
                                border: Border.all(color: borderColor),
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: paddingValue * 0.8,
                                  vertical: paddingValue * 0.7,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(
                                          paddingValue * 0.35),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: borderColor),
                                      ),
                                      child: Icon(
                                        Icons.folder_open,
                                        size: baseFontSize * 0.9,
                                        color: primaryColor,
                                      ),
                                    ),
                                    SizedBox(width: paddingValue * 0.6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _selectedFiles.isEmpty
                                                ? 'Belum ada file'
                                                : '${_selectedFiles.length} file dipilih',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.85,
                                              color: textColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(
                                              height: paddingValue * 0.15),
                                          Text(
                                            'JPG, PNG, PDF, TXT (maks 10MB)',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.7,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: paddingValue * 0.4),
                                    Column(
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: _chooseFile,
                                          icon: const Icon(Icons.upload_file,
                                              size: 18),
                                          label: Text(
                                            'Pilih',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.75,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: paddingValue * 0.6,
                                              vertical: paddingValue * 0.45,
                                            ),
                                            elevation: 0,
                                          ),
                                        ),
                                        SizedBox(height: paddingValue * 0.25),
                                        OutlinedButton(
                                          onPressed: _addMoreFiles,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: primaryColor,
                                            side:
                                                BorderSide(color: borderColor),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            padding: EdgeInsets.symmetric(
                                              horizontal: paddingValue * 0.6,
                                              vertical: paddingValue * 0.35,
                                            ),
                                          ),
                                          child: Text(
                                            'Tambah',
                                            style: GoogleFonts.poppins(
                                              fontSize: baseFontSize * 0.7,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_selectedFiles.isNotEmpty)
                              Padding(
                                padding:
                                    EdgeInsets.only(top: paddingValue * 0.5),
                                child: Wrap(
                                  spacing: paddingValue * 0.4,
                                  runSpacing: paddingValue * 0.3,
                                  children: _selectedFiles.map((file) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: paddingValue * 0.6,
                                        vertical: paddingValue * 0.35,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF4FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                        border: Border.all(
                                          color: const Color(0xFFD6E4FF),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.insert_drive_file_outlined,
                                            size: baseFontSize * 0.75,
                                            color: primaryColor,
                                          ),
                                          SizedBox(
                                              width: paddingValue * 0.25),
                                          ConstrainedBox(
                                            constraints: BoxConstraints(
                                              maxWidth:
                                                  screenWidth * 0.45,
                                            ),
                                            child: Text(
                                              file.name,
                                              style: GoogleFonts.poppins(
                                                fontSize: baseFontSize * 0.75,
                                                color: textColor,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          SizedBox(
                                              width: paddingValue * 0.25),
                                          GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _selectedFiles.remove(file);
                                              });
                                            },
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: paddingValue),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _submitComplaint,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(fieldRadius),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: paddingValue * 0.8,
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'KIRIM',
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: paddingValue * 0.5),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: textColor,
                              side: BorderSide(color: borderColor),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(fieldRadius),
                              ),
                              padding: EdgeInsets.symmetric(
                                vertical: paddingValue * 0.8,
                              ),
                            ),
                            child: Text(
                              'BATAL',
                              style: GoogleFonts.poppins(
                                fontSize: baseFontSize * 0.9,
                                color: textColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: paddingValue),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
