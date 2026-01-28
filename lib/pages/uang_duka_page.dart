import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indocement_apk/pages/layanan_menu.dart';
import 'package:dio/dio.dart';
import 'package:indocement_apk/service/api_service.dart';

class UangDukaPage extends StatefulWidget {
  const UangDukaPage({super.key});

  @override
  State<UangDukaPage> createState() => _UangDukaPageState();
}

class _UangDukaPageState extends State<UangDukaPage> {
  File? _kkFile;
  File? _skkFile;
  int? _idEmployee;
  Map<String, dynamic>? _employeeData;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadIdEmployee();
  }

  Future<void> _loadIdEmployee() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _idEmployee = prefs.getInt('idEmployee');
    });
    if (_idEmployee != null) {
      await _fetchEmployeeData(_idEmployee!);
    }
  }

  Future<void> _fetchEmployeeData(int id) async {
    try {
      final response = await ApiService.get('http://34.50.112.226:5555/api/Employees');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is String ? jsonDecode(response.data) : response.data;
        final emp = data.firstWhere(
          (e) => e['Id'] == id,
          orElse: () => null,
        );
        if (emp != null) {
          setState(() {
            _employeeData = emp;
          });
        }
      }
    } catch (e) {
      setState(() {
        _employeeData = null;
      });
    }
  }

  Future<void> _pickFile(bool isKK) async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        if (isKK) {
          _kkFile = File(pickedFile.path);
        } else {
          _skkFile = File(pickedFile.path);
        }
      });
    }
  }

  void _showPopup({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    // Deteksi warna berdasarkan judul
    final bool isError = title.toLowerCase().contains('gagal') || title.toLowerCase().contains('error');
    final Color mainColor = isError ? Colors.red : const Color(0xFF1572E8);

    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: mainColor,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: mainColor,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(
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
                      backgroundColor: mainColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      if (onPressed != null) onPressed();
                    },
                    child: Text(
                      buttonText,
                      style: const TextStyle(
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

  Widget _buildBox({
    required String title,
    required bool isKK,
    File? file,
  }) {
    return GestureDetector(
      onTap: () => _pickFile(isKK),
      child: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF1572E8),
                borderRadius: BorderRadius.circular(8),
                image: file != null
                    ? DecorationImage(
                        image: FileImage(file),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: file == null
                  ? const Icon(
                      Icons.upload_file,
                      size: 30,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    file != null
                        ? basename(file.path)
                        : 'Belum ada file yang dipilih',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Tambahkan fungsi upload ke server
  Future<void> _uploadPengajuanUangDuka() async {
    if (_kkFile == null || _skkFile == null) {
      _showPopup(
        title: 'Gagal Mengupload',
        message: 'Silakan upload KK dan Surat Keterangan Kematian terlebih dahulu!',
      );
      return;
    }

    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final formData = FormData.fromMap({
        'IdEmployee': _idEmployee,
        'FileKk': await MultipartFile.fromFile(
          _kkFile!.path,
          filename: basename(_kkFile!.path),
        ),
        'FileSuratKematian': await MultipartFile.fromFile(
          _skkFile!.path,
          filename: basename(_skkFile!.path),
        ),
      });

      final response = await ApiService.post(
        'http://34.50.112.226:5555/api/UangDuka/upload',
        data: formData,
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      );

      Navigator.of(this.context).pop(); // Tutup loading

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showPopup(
          title: 'Berhasil',
          message: 'Dokumen berhasil diupload!',
        );
        setState(() {
          _kkFile = null;
          _skkFile = null;
        });
      } else {
        _showPopup(
          title: 'Gagal Mengupload',
          message: 'Upload gagal. Silakan coba lagi.',
        );
      }
    } catch (e) {
      Navigator.of(this.context).pop();
      _showPopup(
        title: 'Gagal Mengupload',
        message: 'Terjadi error saat upload. Silakan coba lagi.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cek jika data belum ada, tampilkan loading
    if (_employeeData == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Ambil IdEsl dari data employee
    final int? idEsl = _employeeData?['IdEsl'];

   // Jika Non Staff (6) atau Staff (5), tampilkan form
    if (idEsl == 6 || idEsl == 5) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pengajuan Uang Duka'),
          backgroundColor: const Color(0xFF1572E8),
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: const TextStyle(
            color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LayananMenuPage()),
              );
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner biru
                    Card(
                      color: const Color(0xFF1572E8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
                        child: Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(16),
                              child: const Icon(
                                Icons.volunteer_activism,
                                color: Colors.white,
                                size: 38,
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Form Pengajuan Uang Duka',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Silakan upload KK dan Surat Keterangan Kematian untuk proses pengajuan.',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upload Dokumen Pengajuan:',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                            const SizedBox(height: 24),
                            uploadDokumenBox(
                              title: 'Kartu Keluarga (KK)',
                              file: _kkFile,
                              onPick: () => _pickFile(true),
                            ),
                            uploadDokumenBox(
                              title: 'Surat Keterangan Kematian',
                              file: _skkFile,
                              onPick: () => _pickFile(false),
                            ),
                            const SizedBox(height: 28),
                            ElevatedButton.icon(
                              onPressed: _uploadPengajuanUangDuka,
                              icon: const Icon(Icons.cloud_upload, size: 24, color: Colors.white),
                              label: const Text(
                                'Upload Pengajuan',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1572E8),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Selain 5 dan 6, tampilkan pesan tidak bisa mengajukan
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengajuan Uang Duka'),
        backgroundColor: const Color(0xFF1572E8),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LayananMenuPage()),
            );
          },
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Pengajuan Uang Duka hanya dapat dilakukan oleh Staff dan Non Staff.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
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
}}