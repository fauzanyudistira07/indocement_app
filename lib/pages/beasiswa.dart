import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BeasiswaPage extends StatefulWidget {
  const BeasiswaPage({super.key});

  @override
  State<BeasiswaPage> createState() => _BeasiswaPageState();
}

class _BeasiswaPageState extends State<BeasiswaPage> {
  final _formKey = GlobalKey<FormState>();
  bool isSendingUpload = false;
  bool isSendingGenerate = false;

  // Controller untuk data karyawan (dapat diedit)
  final TextEditingController namaKaryawanController = TextEditingController();
  final TextEditingController nikController = TextEditingController();
  final TextEditingController divisiDeptSectionController =
      TextEditingController();
  final TextEditingController noHpController = TextEditingController();
  final TextEditingController noRekeningController = TextEditingController();
  final TextEditingController atasNamaController = TextEditingController();
  final TextEditingController unitController = TextEditingController();
  final TextEditingController tanggalController = TextEditingController();

  // Controller untuk data anak (diisi manual)
  final TextEditingController namaAnakController = TextEditingController();
  final TextEditingController tempatLahirAnakController =
      TextEditingController();
  final TextEditingController tanggalLahirAnakController =
      TextEditingController();
  final TextEditingController namaPerguruanTinggiController =
      TextEditingController();
  final TextEditingController jurusanController = TextEditingController();
  final TextEditingController ipkController = TextEditingController();
  final TextEditingController semesterController = TextEditingController();
  final TextEditingController namaSekolahController = TextEditingController();
  final TextEditingController kelasController = TextEditingController();
  final TextEditingController rankingController = TextEditingController();
  final TextEditingController bidangController = TextEditingController();
  final TextEditingController tingkatController = TextEditingController();

  Map<String, dynamic> _employeeData = {};
  final Map<String, dynamic> _unitData = {};

  // Tambahkan variabel controller/file untuk setiap dokumen di _BeasiswaPageState:
  File? fileSuratMahasiswa;
  File? fileNilaiIpk;
  File? fileSuratRanking;
  File? fileKibk;
  File? fileKk;
  File? fileUploadBeasiswa;

  @override
  void initState() {
    super.initState();
    _fetchAndFillEmployeeData();

    // Set tanggal otomatis
    final now = DateTime.now();
    tanggalController.text = DateFormat('dd/MM/yy').format(now);
  }

  Future<void> _fetchAndFillEmployeeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      print('Fetching data for idEmployee: $idEmployee');
      if (idEmployee == null || idEmployee <= 0) {
        print('Invalid idEmployee: $idEmployee');
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(
              content: Text('ID karyawan tidak valid, silakan login ulang')),
        );
        return;
      }

      _showLoading(this.context);

      // Fetch employee data pakai ApiService
      final employeeResponse = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees/$idEmployee',
        headers: {'Content-Type': 'application/json'},
      );

      print('Employee API Response Status: ${employeeResponse.statusCode}');
      print('Employee API Response Body: ${employeeResponse.data}');

      if (employeeResponse.statusCode == 200) {
        _employeeData = employeeResponse.data is String
            ? jsonDecode(employeeResponse.data)
            : employeeResponse.data;
        final idSection = _employeeData['IdSection'] != null
            ? int.tryParse(_employeeData['IdSection'].toString())
            : null;
        print('IdSection: $idSection');

        // Fetch unit data pakai ApiService
        final unitResponse = await ApiService.get(
          'http://34.50.112.226:5555/api/Units',
          headers: {'Content-Type': 'application/json'},
        );

        print('Units API Response Status: ${unitResponse.statusCode}');
        print('Units API Response Body: ${unitResponse.data}');

        Navigator.pop(this.context); // Close loading dialog

        if (unitResponse.statusCode == 200) {
          final units = unitResponse.data is String
              ? jsonDecode(unitResponse.data)
              : unitResponse.data as List;
          String namaUnit = '';
          String namaPlantDivision = '';
          String namaDepartement = '';
          String namaSection = '';

          if (idSection != null) {
            for (var unit in units) {
              for (var plantDivision in (unit['PlantDivisions'] as List)) {
                for (var departement
                    in (plantDivision['Departements'] as List)) {
                  for (var section in (departement['Sections'] as List)) {
                    if (section['Id'] == idSection) {
                      namaUnit = unit['NamaUnit'] ?? '';
                      namaPlantDivision =
                          plantDivision['NamaPlantDivision'] ?? '';
                      namaDepartement = departement['NamaDepartement'] ?? '';
                      namaSection = section['NamaSection'] ?? '';
                      print(
                          'Found matching section: Unit=$namaUnit, Division=$namaPlantDivision, Dept=$namaDepartement, Section=$namaSection');
                      break;
                    }
                  }
                }
              }
            }
          }

          setState(() {
            namaKaryawanController.text = _employeeData['EmployeeName'] ?? '';
            nikController.text = _employeeData['EmployeeNo'] ?? '';
            divisiDeptSectionController.text =
                '$namaPlantDivision - $namaDepartement - $namaSection';
            noHpController.text = _employeeData['Telepon'] ?? '';
            noRekeningController.text =
                _employeeData['BankAccountNumber'] ?? '';
            atasNamaController.text = _employeeData['EmployeeName'] ?? '';
            unitController.text = namaUnit;
          });
        } else {
          Navigator.pop(this.context); // Close loading dialog
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
                content:
                    Text('Gagal memuat data unit: ${unitResponse.statusCode}')),
          );
        }
      } else {
        Navigator.pop(this.context); // Close loading dialog
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
              content: Text(
                  'Gagal memuat data karyawan: ${employeeResponse.statusCode}')),
        );
      }
    } catch (e) {
      print('Error fetching employee/unit data: $e');
      Navigator.pop(this.context); // Close loading dialog
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.blue),
                const SizedBox(height: 16),
                const Text(
                  "Memuat data...",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Harap tunggu sebentar",
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime firstDate = DateTime(1900);
    final DateTime lastDate = DateTime.now();
    DateTime initialDate = DateTime.now();

    if (tanggalLahirAnakController.text.isNotEmpty) {
      try {
        initialDate =
            DateFormat('dd/MM/yy').parse(tanggalLahirAnakController.text);
        if (initialDate.isBefore(firstDate)) {
          initialDate = firstDate;
        }
        if (initialDate.isAfter(lastDate)) {
          initialDate = lastDate;
        }
      } catch (e) {
        initialDate = DateTime.now();
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
        tanggalLahirAnakController.text =
            DateFormat('dd/MM/yy').format(picked);
      });
    }
  }

  // Fungsi untuk memilih file (pdf/jpg/png)
  Future<void> _pickFile(Function(File) onPicked) async {
    final result = await showModalBottomSheet<String>(
      context: this.context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Upload Dokumen Pengajuan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pilih jenis file yang ingin diunggah untuk pengajuan beasiswa.',
                style: TextStyle(fontSize: 14, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Pilih PDF dari File'),
                onTap: () async {
                  Navigator.pop(context, 'pdf');
                  // Modal instruksi modern
                  final confirm = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => Dialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1572E8).withOpacity(0.08),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(18),
                              child: const Icon(Icons.upload_file, color: Color(0xFF1572E8), size: 48),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Konfirmasi Upload Dokumen',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                                color: Color(0xFF1572E8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              "Pastikan dokumen yang Anda kirim sudah berisi:",
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F8FE),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("• KIBK (Kartu Izin Berobat Keluarga)", style: TextStyle(fontSize: 14)),
                                  Text("• Fotocopy Kartu Keluarga", style: TextStyle(fontSize: 14)),
                                  Text("• Surat keterangan dan nilai dari kampus/sekolah", style: TextStyle(fontSize: 14)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              "Apakah Anda sudah menyiapkan dokumen tersebut?",
                              style: TextStyle(fontSize: 15, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.close, color: Color(0xFF1572E8)),
                                    label: const Text(
                                      'Belum',
                                      style: TextStyle(
                                        color: Color(0xFF1572E8),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      side: const BorderSide(color: Color(0xFF1572E8), width: 2),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                    ),
                                    onPressed: () => Navigator.pop(context, false),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.check_circle, color: Colors.white),
                                    label: const Text(
                                      'Sudah',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1572E8),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      elevation: 2,
                                    ),
                                    onPressed: () => Navigator.pop(context, true),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ));
                  if (confirm == true) {
                    FilePickerResult? picked = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    );
                    if (picked != null && picked.files.single.path != null) {
                      onPicked(File(picked.files.single.path!));
                    }
                  } else {
  // Kembali ke halaman Beasiswa
  Navigator.of(this.context).pop();
}
                },
              ),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text('Pilih Gambar dari Galeri'),
                onTap: () => Navigator.pop(context, 'image'),
              ),
            ],
          ),
        ),
      ));

    if (result == 'image') {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        onPicked(File(picked.path));
      }
    }
  }

  // Widget upload modern
  Widget uploadField({
    required String title,
    required File? file,
    required VoidCallback onPressed,
  }) {
    final bool uploaded = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12), // Sama seperti TextFormField
      child: Container(
        // Hilangkan margin, padding seragam
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: uploaded ? Colors.green : Colors.grey[400]!,
            width: 1.2,
          ),
          borderRadius:
              BorderRadius.circular(10), // Sama seperti OutlineInputBorder
        ),
        child: Row(
          children: [
            Container(
              width: 44, // Lebih kecil agar proporsional
              height: 44,
              decoration: BoxDecoration(
                border: Border.all(
                  color: uploaded ? Colors.green : Colors.grey[300]!,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey[100],
              ),
              child: uploaded
                  ? (file.path.endsWith('.pdf')
                      ? const Icon(Icons.picture_as_pdf,
                          color: Colors.red, size: 28)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(file, fit: BoxFit.cover),
                        ))
                  : const Icon(Icons.insert_drive_file,
                      color: Colors.grey, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.5,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    uploaded
                        ? file.path.split('/').last
                        : "File belum dikirim",
                    style: TextStyle(
                      color: uploaded ? Colors.green[700] : Colors.grey[500],
                      fontWeight:
                          uploaded ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  OutlinedButton.icon(
                    icon: Icon(Icons.upload_file, color: Colors.blue, size: 18),
                    label: Text(
                      uploaded ? "Ganti File" : "Upload",
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
                      padding: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 10),
                      backgroundColor: Colors.white,
                      minimumSize: const Size(0, 32),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: onPressed,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitBeasiswa() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        isSendingGenerate = true;
      });

      try {
        final prefs = await SharedPreferences.getInstance();
        final idEmployee = prefs.getInt('idEmployee');
        print('Submitting beasiswa for idEmployee: $idEmployee');
        if (idEmployee == null || idEmployee <= 0) {
          print('Invalid idEmployee: $idEmployee');
          throw Exception('ID karyawan tidak valid. Harap login ulang.');
        }

        final tempatTanggalLahir =
            '${tempatLahirAnakController.text}, ${tanggalLahirAnakController.text}';
        print('TempatTanggalLahirAnak: $tempatTanggalLahir');

        final data = {
          'NamaKaryawan': namaKaryawanController.text,
          'NIK': nikController.text,
          'DivisiDeptSection': divisiDeptSectionController.text,
          'NoHp': noHpController.text,
          'NoRekening': noRekeningController.text,
          'AtasNama': atasNamaController.text,
          'NamaAnak': namaAnakController.text,
          'TempatTanggalLahirAnak': tempatTanggalLahir,
          'NamaPerguruanTinggi': namaPerguruanTinggiController.text.isEmpty
              ? null
              : namaPerguruanTinggiController.text,
          'Jurusan':
              jurusanController.text.isEmpty ? null : jurusanController.text,
          'IPK': ipkController.text.isEmpty ? null : ipkController.text,
          'Semester':
              semesterController.text.isEmpty ? null : semesterController.text,
          'NamaSekolah': namaSekolahController.text.isEmpty
              ? null
              : namaSekolahController.text,
          'Kelas': kelasController.text.isEmpty ? null : kelasController.text,
          'Ranking':
              rankingController.text.isEmpty ? null : rankingController.text,
          'Bidang':
              bidangController.text.isEmpty ? null : bidangController.text,
          'Tingkat':
              tingkatController.text.isEmpty ? null : tingkatController.text,
          'Unit': unitController.text,
          'Tanggal': DateTime.now().toIso8601String(),
          'Status': 'Diajukan',
          'IdEmployee': idEmployee,
        };

        print('Beasiswa Payload: ${jsonEncode(data)}');

        _showLoading(this.context);

        final response = await ApiService.post(
          'http://34.50.112.226:5555/api/Beasiswa',
          data: jsonEncode(data),
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );

        print('Beasiswa API Response Status: ${response.statusCode}');
        print('Beasiswa API Response Body: ${response.data}');

        Navigator.pop(this.context); // Close loading dialog

        if (response.statusCode == 200 || response.statusCode == 201) {
          print('Beasiswa submitted successfully');
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(
                content: Text('Pengajuan beasiswa berhasil dikirim!')),
          );

          Navigator.pushReplacement(
            this.context,
            MaterialPageRoute(builder: (context) => const BeasiswaPage()),
          );
        } else {
          print('Failed to submit beasiswa: ${response.statusCode}');
          throw Exception(
              'Gagal mengirim data: ${response.statusCode} - ${response.data}');
        }
      } catch (e) {
        print('Error submitting beasiswa: $e');
        Navigator.pop(this.context); // Close loading dialog
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      } finally {
        setState(() {
          isSendingGenerate = false;
        });
      }
    } else {
      print('Form validation failed');
      showDialog(
        context: this.context,
        builder: (context) => AlertDialog(
          title: const Text('Lengkapi Data'),
          content: const Text(
              'Silakan lengkapi semua data yang wajib diisi sebelum mengirim.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    namaKaryawanController.dispose();
    nikController.dispose();
    divisiDeptSectionController.dispose();
    noHpController.dispose();
    noRekeningController.dispose();
    atasNamaController.dispose();
    namaAnakController.dispose();
    tempatLahirAnakController.dispose();
    tanggalLahirAnakController.dispose();
    namaPerguruanTinggiController.dispose();
    jurusanController.dispose();
    ipkController.dispose();
    semesterController.dispose();
    namaSekolahController.dispose();
    kelasController.dispose();
    rankingController.dispose();
    bidangController.dispose();
    tingkatController.dispose();
    unitController.dispose();
    tanggalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF1572E8),
        title: const Text(
          'Pengajuan Beasiswa',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.note, size: 40, color: Color(0xFF1572E8)),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instruksi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Silakan isi data yang diperlukan pada form di bawah untuk mengajukan beasiswa. Data karyawan akan terisi otomatis tetapi dapat diedit. Data anak harus diisi secara manual.',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.edit_document,
                                color: Color(0xFF1572E8), size: 28),
                            SizedBox(width: 8),
                            Text(
                              'Form Pengajuan Beasiswa',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1572E8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Data Karyawan
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.account_circle,
                                        color: Color(0xFF1572E8)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Data Karyawan',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF1572E8),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                TextFormField(
                                  controller: namaKaryawanController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Karyawan *',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: nikController,
                                  decoration: const InputDecoration(
                                    labelText: 'NIK *',
                                    prefixIcon: Icon(Icons.credit_card),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: divisiDeptSectionController,
                                  decoration: const InputDecoration(
                                    labelText: 'Divisi/Departemen/Section *',
                                    prefixIcon: Icon(Icons.apartment),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: noHpController,
                                  decoration: const InputDecoration(
                                    labelText: 'No. HP *',
                                    prefixIcon: Icon(Icons.phone),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: noRekeningController,
                                  decoration: const InputDecoration(
                                    labelText: 'No. Rekening *',
                                    prefixIcon: Icon(Icons.account_balance),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: atasNamaController,
                                  decoration: const InputDecoration(
                                    labelText: 'Atas Nama Rekening *',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Data Anak
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.child_care,
                                        color: Color(0xFF1572E8)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Data Anak',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF1572E8),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                TextFormField(
                                  controller: namaAnakController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Anak *',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: tempatLahirAnakController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tempat Lahir Anak *',
                                    prefixIcon: Icon(Icons.location_city),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: tanggalLahirAnakController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal Lahir Anak *',
                                    prefixIcon: Icon(Icons.cake_outlined),
                                    suffixIcon: Icon(Icons.calendar_today),
                                  ),
                                  readOnly: true,
                                  onTap: () => _selectDate(context),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                // Upload KIBK & KK di sini
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // Pendidikan Kuliah
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.school, color: Colors.green),
                                    SizedBox(width: 8),
                                    Text(
                                      'Pendidikan Kuliah',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                TextFormField(
                                  controller: namaPerguruanTinggiController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Perguruan Tinggi',
                                    prefixIcon: Icon(Icons.school),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: jurusanController,
                                  decoration: const InputDecoration(
                                    labelText: 'Jurusan',
                                    prefixIcon: Icon(Icons.book),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: ipkController,
                                  decoration: const InputDecoration(
                                    labelText: 'IPK',
                                    prefixIcon: Icon(Icons.grade),
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: semesterController,
                                  decoration: const InputDecoration(
                                    labelText: 'Semester',
                                    prefixIcon: Icon(Icons.calendar_today),
                                  ),
                                ),
                                // Upload Surat Mahasiswa & Nilai IPK di sini
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),

                        // Pendidikan Sekolah
                        Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.school_outlined,
                                        color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text(
                                      'Pendidikan Sekolah',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 18),
                                TextFormField(
                                  controller: namaSekolahController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nama Sekolah',
                                    prefixIcon: Icon(Icons.school_outlined),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: kelasController,
                                  decoration: const InputDecoration(
                                    labelText: 'Kelas',
                                    prefixIcon: Icon(Icons.class_),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: rankingController,
                                  decoration: const InputDecoration(
                                    labelText: 'Ranking',
                                    prefixIcon: Icon(Icons.star),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: bidangController,
                                  decoration: const InputDecoration(
                                    labelText: 'Bidang Prestasi',
                                    prefixIcon: Icon(Icons.emoji_events),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: tingkatController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tingkat Prestasi',
                                    prefixIcon: Icon(Icons.stairs),
                                  ),
                                ),
                                // Upload Surat Ranking di sini
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ),
                        // Data Lainnya
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: const [
                                    Icon(Icons.info, color: Color(0xFF1572E8)),
                                    SizedBox(width: 8),
                                    Text(
                                      'Data Lainnya',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                        color: Color(0xFF1572E8),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                TextFormField(
                                  controller: unitController,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit *',
                                    prefixIcon:
                                        Icon(Icons.account_tree_outlined),
                                  ),
                                  validator: (v) => v == null || v.isEmpty
                                      ? 'Wajib diisi'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: tanggalController,
                                  decoration: const InputDecoration(
                                    labelText: 'Tanggal Pengajuan',
                                    prefixIcon: Icon(Icons.event_note_outlined),
                                  ),
                                  readOnly: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Hapus Card Upload Dokumen, karena uploadField sudah dipindah ke lokasi yang diminta
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: isSendingGenerate
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.download,
                                    color: Colors.white),
                            label: Text(
                              isSendingGenerate
                                  ? 'Memproses...'
                                  : 'Generate & Download Surat',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1572E8),
                              minimumSize: const Size(double.infinity, 48),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: isSendingGenerate
                                ? null
                                : () async {
                                    if (!(_formKey.currentState?.validate() ??
                                        false)) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Lengkapi Data'),
                                          content: const Text(
                                              'Silakan lengkapi semua data yang wajib diisi sebelum download surat.'),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              child: const Text('OK'),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      isSendingGenerate = true;
                                    });
                                    try {
                                      final prefs =
                                          await SharedPreferences.getInstance();
                                      final idEmployee =
                                          prefs.getInt('idEmployee');
                                      if (idEmployee == null) {
                                        throw Exception(
                                            'ID karyawan tidak ditemukan. Harap login ulang.');
                                      }

                                      final tempatTanggalLahir =
                                          '${tempatLahirAnakController.text}, ${tanggalLahirAnakController.text}';
                                      final now = DateTime.now();

                                      // Hanya field yang diperlukan API generate
                                      final data = {
                                        "NamaKaryawan":
                                            namaKaryawanController.text,
                                        "NIK": nikController.text,
                                        "DivisiDeptSection":
                                            divisiDeptSectionController.text,
                                        "NoHp": noHpController.text,
                                        "NoRekening": noRekeningController.text,
                                        "AtasNama": atasNamaController.text,
                                        "NamaAnak": namaAnakController.text,
                                        "TempatTanggalLahirAnak":
                                            tempatTanggalLahir,
                                        "NamaPerguruanTinggi":
                                            namaPerguruanTinggiController.text,
                                        "Jurusan": jurusanController.text,
                                        "IPK": ipkController.text,
                                        "Semester": semesterController.text,
                                        "NamaSekolah":
                                            namaSekolahController.text,
                                        "Kelas": kelasController.text,
                                        "Ranking": rankingController.text,
                                        "Bidang": bidangController.text,
                                        "Tingkat": tingkatController.text,
                                        "Unit": unitController.text,
                                        "Tanggal": now.toIso8601String(),
                                      };

                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => AlertDialog(
                                          content: Row(
                                            children: const [
                                              SizedBox(
                                                width: 28,
                                                height: 28,
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                              SizedBox(width: 20),
                                              Expanded(
                                                child: Text(
                                                  'Mohon tunggu, surat sedang diproses...',
                                                  style:
                                                      TextStyle(fontSize: 15),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
final response = await ApiService.post(
  'http://34.50.112.226:5555/api/Beasiswa/generate-document',
  data: data,
  headers: {
    'accept': '*/*',
    'Content-Type': 'application/json',
  },
  responseType: ResponseType.bytes,
);

Navigator.of(context).pop(); 

                                      if (response.statusCode == 200) {
                                        // Simpan file ke Download
                                        final directory = Directory(
                                            '/storage/emulated/0/Download');
                                        if (!directory.existsSync()) {
                                          directory.createSync(recursive: true);
                                        }
                                        final filePath =
                                            '${directory.path}/beasiswa_${DateTime.now().millisecondsSinceEpoch}.pdf';
                                        final file = File(filePath);
                                        await file.writeAsBytes(response.data!);

                                        // Modal sukses: centang biru, tombol OK hanya menutup modal
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 28),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                      Icons
                                                          .check_circle_outline_rounded,
                                                      color: Color(0xFF1572E8),
                                                      size: 54),
                                                  const SizedBox(height: 18),
                                                  const Text(
                                                    'Download Berhasil',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 22,
                                                      color: Color(0xFF1572E8),
                                                      letterSpacing: 0.2,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'File berhasil di-generate dan didownload ke:\n$filePath',
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
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                                0xFF1572E8),
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 15),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: const Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                          ),
                                        );
                                      } else {
                                        // Modal gagal: icon merah, tombol OK hanya menutup modal
                                        showDialog(
                                          context: context,
                                          barrierDismissible: false,
                                          builder: (context) => Dialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 24,
                                                      vertical: 28),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.cancel_rounded,
                                                      color: Colors.red,
                                                      size: 54),
                                                  const SizedBox(height: 18),
                                                  const Text(
                                                    'Gagal Download Surat',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 22,
                                                      color: Colors.red,
                                                      letterSpacing: 0.2,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Gagal generate surat: ${response.statusCode}',
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
                                                      style: ElevatedButton
                                                          .styleFrom(
                                                        backgroundColor:
                                                            Colors.red,
                                                        shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                vertical: 15),
                                                      ),
                                                      onPressed: () {
                                                        Navigator.of(context)
                                                            .pop();
                                                      },
                                                      child: const Text(
                                                        'OK',
                                                        style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
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
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      Navigator.of(context)
                                          .pop(); // Tutup dialog loading jika error
                                      showDialog(
                                        context: context,
                                        builder: (context) => Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 24, vertical: 28),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.cancel_rounded,
                                                    color: Colors.red,
                                                    size: 54),
                                                const SizedBox(height: 18),
                                                const Text(
                                                  'Gagal Download Surat',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 22,
                                                    color: Colors.red,
                                                    letterSpacing: 0.2,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Terjadi kesalahan: $e',
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
                                                    style: ElevatedButton
                                                        .styleFrom(
                                                      backgroundColor: Colors.red,
                                                      shape:
                                                          RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          12)),
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          vertical: 15),
                                                    ),
                                                    onPressed: () {
                                                      Navigator.of(context)
                                                          .pop();
                                                    },
                                                    child: const Text(
                                                      'OK',
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
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
                                        ),
                                      );
                                    } finally {
                                      setState(() {
                                        isSendingGenerate = false;
                                      });
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
// Ganti Card Upload Pengajuan Beasiswa agar tampil beda dari card lain (misal: warna background, icon, border, dsb)

              Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: Color(0xFF1572E8), width: 2),
                ),
                color:
                    const Color(0xFFF5F8FE), // Biru muda, beda dari card lain
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.cloud_upload_rounded,
                              color: Color(0xFF1572E8), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Upload Pengajuan Beasiswa',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1572E8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border:
                              Border.all(color: Color(0xFF1572E8), width: 1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: uploadField(
                          title: 'Upload PDF atau Gambar Pengajuan Beasiswa',
                          file: fileUploadBeasiswa,
                          onPressed: () => _pickFile(
                              (f) => setState(() => fileUploadBeasiswa = f)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: isSendingUpload
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.upload, color: Colors.white),
                          label: Text(
                            isSendingUpload
                                ? 'Mengirim...'
                                : 'Kirim Pengajuan Beasiswa',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1572E8),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 1,
                          ),
                          onPressed: isSendingUpload
                              ? null
                              : () async {
                                  if (fileUploadBeasiswa == null) {
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Upload Dokumen'),
                                        content: const Text(
                                            'Silakan upload dokumen pengajuan beasiswa terlebih dahulu.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text('OK'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    isSendingUpload = true;
                                  });
                                  try {
                                    final prefs =
                                        await SharedPreferences.getInstance();
                                    final idEmployee =
                                        prefs.getInt('idEmployee');
                                    if (idEmployee == null) {
                                      throw Exception(
                                          'ID karyawan tidak ditemukan. Harap login ulang.');
                                    }

          final formData = FormData.fromMap({
            "IdEmployee": idEmployee,
            "Status": "Diajukan",
            "UrlDokumen": await MultipartFile.fromFile(
              fileUploadBeasiswa!.path,
              filename: basename(fileUploadBeasiswa!.path),
            ),
          });

                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        content: Row(
                                          children: const [
                                            SizedBox(
                                              width: 28,
                                              height: 28,
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                            SizedBox(width: 20),
                                            Expanded(
                                              child: Text(
                                                'Mengirim dokumen...',
                                                style: TextStyle(fontSize: 15),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );

          final response = await ApiService.post(
            'http://34.50.112.226:5555/api/Beasiswa',
            data: formData,
            headers: {
              'accept': '*/*',
            },
          );

                                    Navigator.of(context)
                                        .pop(); // tutup loading

          if (response.statusCode == 200 || response.statusCode == 201) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1572E8), size: 54),
                      const SizedBox(height: 18),
                      const Text(
                        'Pengajuan Berhasil',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Color(0xFF1572E8),
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Dokumen pengajuan beasiswa berhasil dikirim.',
                        style: TextStyle(
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
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
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
              ),
            );
            setState(() {
              fileUploadBeasiswa = null;
            });
          } else {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_rounded, color: Colors.red, size: 54),
                      const SizedBox(height: 18),
                      const Text(
                        'Gagal Mengirim',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: Colors.red,
                          letterSpacing: 0.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal mengirim dokumen: ${response.statusCode}',
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
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'OK',
                            style: TextStyle(
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
              ),
            );
          }
        } catch (e) {
          Navigator.of(context).pop(); // pastikan loading tertutup
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cancel_rounded, color: Colors.red, size: 54),
                    const SizedBox(height: 18),
                    const Text(
                      'Gagal Mengirim',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        color: Colors.red,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Terjadi kesalahan: $e',
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
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: const Text(
                          'OK',
                          style: TextStyle(
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
            ),
          );
        }
      },
          ),
        ),
      ],
    ),
  ),
),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> uploadBeasiswaDocument(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final idEmployee = prefs.getInt('idEmployee');
  if (idEmployee == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ID karyawan tidak ditemukan. Harap login ulang.')),
    );
    return;
  }
  if (fileUploadBeasiswa == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Silakan upload dokumen pengajuan beasiswa terlebih dahulu.')),
    );
    return;
  }

  final formData = FormData.fromMap({
    "IdEmployee": idEmployee,
    "Status": "Diajukan",
    "UrlDokumen": await MultipartFile.fromFile(
      fileUploadBeasiswa!.path,
      filename: basename(fileUploadBeasiswa!.path),
    ),
  });

  print('=== FormData yang akan dikirim (Beasiswa) ===');
  formData.fields.forEach((f) => print('Field: ${f.key}, Value: ${f.value}'));
  formData.files.forEach((f) => print('File Field: ${f.key}, Filename: ${f.value.filename}'));
  print('=================================');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final response = await ApiService.post(
      'http://34.50.112.226:5555/api/Beasiswa',
      data: formData,
    );

    Navigator.of(context).pop(); // Tutup loading

    if (response.statusCode == 200 || response.statusCode == 201) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1572E8), size: 54),
                const SizedBox(height: 18),
                const Text(
                  'Pengajuan Berhasil',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Color(0xFF1572E8),
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Dokumen pengajuan beasiswa berhasil dikirim.',
                  style: TextStyle(
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
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
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
        ),
      );
      setState(() {
        fileUploadBeasiswa = null;
      });
    } else {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cancel_rounded, color: Colors.red, size: 54),
                const SizedBox(height: 18),
                const Text(
                  'Gagal Mengirim',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: Colors.red,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal mengirim dokumen: ${response.statusCode}',
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
                      backgroundColor: Colors.red,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(
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
        ),
      );
    }
  } catch (e) {
    Navigator.of(context).pop(); // pastikan loading tertutup
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_rounded, color: Colors.red, size: 54),
              const SizedBox(height: 18),
              const Text(
                'Gagal Mengirim',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.red,
                  letterSpacing: 0.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Terjadi kesalahan: $e',
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
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
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
      ),
    );
  }
}}
