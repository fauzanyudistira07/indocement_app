import 'dart:io';
import 'package:animate_do/animate_do.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:path/path.dart' as path;
import 'package:indocement_apk/pages/layanan_menu.dart'; // pastikan import ini ada

class DispensasiPage extends StatefulWidget {
  const DispensasiPage({super.key});

  @override
  _DispensasiPageState createState() => _DispensasiPageState();
}

class _DispensasiPageState extends State<DispensasiPage> {
  final _jenisDispensasiController = TextEditingController();
  final _keteranganController = TextEditingController();
  File? _suratKeteranganMeninggal;
  File? _ktp;
  File? _sim;
  final List<File> _dokumenLain = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _jenisDispensasiController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      if (mounted) {
        _showErrorModal(
            'Tidak ada koneksi internet. Silakan cek jaringan Anda.');
      }
      return false;
    }
    return true;
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
                  'Pengajuan dispensasi berhasil dikirim.',
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
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LayananMenuPage()),
                      ); // Return to previous screen
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

  Future<String?> _pickFileSource() async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('PDF', style: GoogleFonts.poppins()),
                onTap: () => Navigator.of(context).pop('pdf'),
              ),
              ListTile(
                leading:
                    const Icon(Icons.photo_library, color: Color(0xFF1572E8)),
                title: Text('Foto (Galeri)', style: GoogleFonts.poppins()),
                onTap: () => Navigator.of(context).pop('image'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFile(String field) async {
    try {
      final source = await _pickFileSource();
      if (source == null) return;

      File? selectedFile;
      if (source == 'pdf') {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['pdf'],
        );
        if (result != null &&
            result.files.isNotEmpty &&
            result.files.first.path != null) {
          selectedFile = File(result.files.first.path!);
        }
      } else {
        final picked =
            await ImagePicker().pickImage(source: ImageSource.gallery);
        if (picked != null) {
          selectedFile = File(picked.path);
        }
      }

      if (selectedFile != null) {
        setState(() {
          switch (field) {
            case 'SuratKeteranganMeninggal':
              _suratKeteranganMeninggal = selectedFile;
              break;
            case 'Ktp':
              _ktp = selectedFile;
              break;
            case 'Sim':
              _sim = selectedFile;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Gagal memilih file: $e');
      }
    }
  }

  Future<void> _pickOptionalPhotos() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isNotEmpty) {
        setState(() {
          _dokumenLain.addAll(picked.map((x) => File(x.path)));
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Gagal memilih foto: $e');
      }
    }
  }

  String? _validateFormat(String format) {
    bool isPdf(File? file) =>
        file != null && file.path.toLowerCase().endsWith('.pdf');
    bool isImage(File? file) {
      if (file == null) return false;
      final lower = file.path.toLowerCase();
      return lower.endsWith('.jpg') ||
          lower.endsWith('.jpeg') ||
          lower.endsWith('.png');
    }

    if (format == 'pdf') {
      if (_suratKeteranganMeninggal != null &&
          !isPdf(_suratKeteranganMeninggal)) {
        return 'Surat Keterangan Meninggal harus berformat PDF jika diunggah.';
      }
      if (!isPdf(_ktp)) {
        return 'KTP harus berformat PDF.';
      }
      if (_sim != null && !isPdf(_sim)) {
        return 'SIM harus berformat PDF jika diunggah.';
      }
      if (_dokumenLain.isNotEmpty) {
        return 'Foto opsional hanya bisa dikirim jika memilih format JPG/PNG.';
      }
    } else {
      if (_suratKeteranganMeninggal != null &&
          !isImage(_suratKeteranganMeninggal)) {
        return 'Surat Keterangan Meninggal harus berformat JPG/PNG jika diunggah.';
      }
      if (!isImage(_ktp)) {
        return 'KTP harus berformat JPG/PNG.';
      }
      if (_sim != null && !isImage(_sim)) {
        return 'SIM harus berformat JPG/PNG jika diunggah.';
      }
    }
    return null;
  }

  Future<void> _handleSubmit(String format) async {
    if (_jenisDispensasiController.text.trim().isEmpty) {
      if (mounted) {
        _showErrorModal('Jenis dispensasi tidak boleh kosong.');
      }
      return;
    }
    if (_keteranganController.text.trim().isEmpty) {
      if (mounted) {
        _showErrorModal('Keterangan tidak boleh kosong.');
      }
      return;
    }
    if (_ktp == null) {
      if (mounted) {
        _showErrorModal('KTP wajib diunggah.');
      }
      return;
    }
    final formatError = _validateFormat(format);
    if (formatError != null) {
      if (mounted) {
        _showErrorModal(formatError);
      }
      return;
    }

    if (!await _checkNetwork()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null || idEmployee <= 0) {
        if (mounted) {
          _showErrorModal('ID karyawan tidak valid. Silakan login ulang.');
        }
        setState(() => _isLoading = false);
        return;
      }

      final formData = FormData.fromMap({
        'IdEmployee': idEmployee.toString(),
        'JenisDispensasi': _jenisDispensasiController.text.trim(),
        'Keterangan': _keteranganController.text.trim(),
        'OutputFormat': format,
        if (_suratKeteranganMeninggal != null)
          'SuratKeteranganMeninggal': await MultipartFile.fromFile(
            _suratKeteranganMeninggal!.path,
            filename: path.basename(_suratKeteranganMeninggal!.path),
          ),
        if (_ktp != null)
          'Ktp': await MultipartFile.fromFile(
            _ktp!.path,
            filename: path.basename(_ktp!.path),
          ),
        if (_sim != null)
          'Sim': await MultipartFile.fromFile(
            _sim!.path,
            filename: path.basename(_sim!.path),
          ),
        if (_dokumenLain.isNotEmpty)
          'DokumenLain': [
            for (final file in _dokumenLain)
              await MultipartFile.fromFile(
                file.path,
                filename: path.basename(file.path),
              ),
          ],
      });

      _showLoading(context);

      final response = await ApiService.post(
        'http://103.31.235.237:5555/api/Dispensasi',
        data: formData,
        headers: {
          'Accept': 'application/json',
        },
        contentType: 'multipart/form-data',
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessModal();
        }
      } else {
        String errorMessage = 'Gagal mengajukan dispensasi';
        try {
          errorMessage = response.data['message'] ?? errorMessage;
        } catch (e) {
          errorMessage = response.data.toString().isNotEmpty
              ? response.data.toString()
              : errorMessage;
        }
        if (mounted) {
          _showErrorModal(errorMessage);
        }
      }
    } catch (e) {
      print('Error: $e');
      Navigator.pop(context); // Close loading dialog if open
      if (mounted) {
        _showErrorModal('Terjadi kesalahan: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LayananMenuPage()),
            );
          },
        ),
        title: Text(
          'Pengajuan Dispensasi',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: MediaQuery.of(context).size.width * 0.05,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1572E8),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.05,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 30),
                  FadeInDown(
                    duration: const Duration(milliseconds: 800),
                    child: Center(
                      child: Image.asset(
                        'assets/images/logo2.png',
                        width: 200,
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  FadeInLeft(
                    duration: const Duration(milliseconds: 800),
                    child: Text(
                      'Pengajuan Dispensasi',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1A2035),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildTextField(
                    'Jenis Dispensasi',
                    _jenisDispensasiController,
                    900,
                  ),
                  _buildTextField(
                    'Keterangan',
                    _keteranganController,
                    1000,
                    maxLines: 3,
                  ),
                  _buildFileField('KTP', 'Ktp', 1100),
                  _buildFileField(
                    'Surat Keterangan Meninggal (Opsional)',
                    'SuratKeteranganMeninggal',
                    1200,
                  ),
                  _buildFileField('SIM (Opsional)', 'Sim', 1300),
                  _buildOptionalPhotosField(1400),
                  const SizedBox(height: 30),
                  FadeInUp(
                    duration: const Duration(milliseconds: 1500),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isLoading ? null : () => _showSubmitFormatDialog(),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          backgroundColor: const Color(0xFF1572E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : Text(
                                'KIRIM',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    TextEditingController controller,
    int duration,
    {int maxLines = 1}
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: FadeInLeft(
        duration: Duration(milliseconds: duration),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              hint,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2035),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLines: maxLines,
              style: GoogleFonts.poppins(fontSize: 15.5),
              decoration: InputDecoration(
                hintText: 'Masukkan $hint',
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE1E7EF)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF1572E8), width: 1.4),
                ),
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14.5,
                  color: const Color(0xFF9AA4B2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileField(String label, String field, int duration) {
    File? file;
    switch (field) {
      case 'SuratKeteranganMeninggal':
        file = _suratKeteranganMeninggal;
        break;
      case 'Ktp':
        file = _ktp;
        break;
      case 'Sim':
        file = _sim;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: FadeInLeft(
        duration: Duration(milliseconds: duration),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2035),
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _pickFile(field),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9FC),
                  border: Border.all(color: const Color(0xFFE1E7EF)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      file == null
                          ? Icons.upload_file
                          : (file.path.toLowerCase().endsWith('.pdf')
                              ? Icons.picture_as_pdf
                              : Icons.image_outlined),
                      color: file == null
                          ? const Color(0xFF1572E8)
                          : const Color(0xFF1A2035),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        file != null
                            ? path.basename(file.path)
                            : 'Pilih file (JPG, PNG, PDF)',
                        style: GoogleFonts.poppins(
                          fontSize: 14.5,
                          color: file != null
                              ? const Color(0xFF1A2035)
                              : const Color(0xFF9AA4B2),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (file != null)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF2CB67D),
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSubmitFormatDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Pilih Format Pengiriman',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Pilih format file yang akan dikirimkan.',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleSubmit('pdf');
              },
              child: Text(
                'PDF',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1572E8),
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _handleSubmit('image');
              },
              child: Text(
                'JPG/PNG',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1572E8),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOptionalPhotosField(int duration) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: FadeInLeft(
        duration: Duration(milliseconds: duration),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foto Pendukung (Opsional)',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A2035),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FC),
                border: Border.all(color: const Color(0xFFE1E7EF)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _dokumenLain.isEmpty
                          ? 'Belum ada foto dipilih'
                          : '${_dokumenLain.length} foto dipilih',
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        color: _dokumenLain.isEmpty
                            ? const Color(0xFF9AA4B2)
                            : const Color(0xFF1A2035),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _pickOptionalPhotos,
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1572E8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_dokumenLain.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_dokumenLain.length, (index) {
                  final file = _dokumenLain[index];
                  return Chip(
                    label: Text(
                      path.basename(file.path),
                      overflow: TextOverflow.ellipsis,
                    ),
                    deleteIcon: const Icon(Icons.close, size: 18),
                    onDeleted: () {
                      setState(() {
                        _dokumenLain.removeAt(index);
                      });
                    },
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
