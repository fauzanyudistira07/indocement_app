import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:file_picker/file_picker.dart';
import 'package:indocement_apk/service/api_service.dart'; 
import 'package:dio/dio.dart';

class IdCardUploadPage extends StatefulWidget {
  const IdCardUploadPage({super.key});

  @override
  State<IdCardUploadPage> createState() => _IdCardUploadPageState();
}

class _IdCardUploadPageState extends State<IdCardUploadPage> {
  String _selectedStatus = 'Baru';
  int? idEmployee;

  File? fotoBaru;
  File? fotoRusak;
  File? suratKehilangan;

  final picker = ImagePicker();
  bool isLoading = false;
  bool isDateFormattingInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadEmployeeId();
    _initializeDateFormatting();
  }

  Future<void> _initializeDateFormatting() async {
    await initializeDateFormatting('id_ID', null);
    setState(() {
      isDateFormattingInitialized = true;
    });
  }

  Future<void> _loadEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      idEmployee = prefs.getInt('idEmployee');
    });
    if (idEmployee == null) {
      print('Error: idEmployee is null');
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: const Text('Gagal memuat ID karyawan. Silakan login ulang.'),
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

  Future<void> pickImage(Function(File) onPicked,
      {bool allowPdf = false}) async {
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final mimeType = lookupMimeType(picked.path);
      if (allowPdf) {
        if (mimeType != 'image/png' &&
            mimeType != 'image/jpeg' &&
            mimeType != 'application/pdf') {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Format Tidak Didukung'),
              content: const Text(
                  'Hanya file PNG, JPG, atau PDF yang diperbolehkan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      } else {
        if (mimeType != 'image/png' && mimeType != 'image/jpeg') {
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('Format Tidak Didukung'),
              content:
                  const Text('Hanya file PNG atau JPG yang diperbolehkan.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }
      onPicked(File(picked.path));
    }
  }

  Future<void> submitForm(BuildContext dialogContext) async {
    if (idEmployee == null) {
      _showPopup(
        title: 'Error',
        message: 'ID karyawan tidak ditemukan. Silakan login ulang.',
      );
      return;
    }

    // Validasi
    if (fotoBaru == null) {
      _showPopup(
        title: 'Validasi Gagal',
        message: 'Mohon upload foto terbaru.',
      );
      return;
    }
    if (_selectedStatus == 'Rusak' && fotoRusak == null) {
      _showPopup(
        title: 'Validasi Gagal',
        message: 'Mohon upload foto ID card rusak.',
      );
      return;
    }
    if (_selectedStatus == 'Hilang' && suratKehilangan == null) {
      _showPopup(
        title: 'Validasi Gagal',
        message: 'Mohon upload surat kehilangan.',
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final formData = FormData.fromMap({
        'IdEmployee': idEmployee.toString(),
        'StatusPengajuan': _selectedStatus,
        'UrlFotoTerbaru': await MultipartFile.fromFile(
          fotoBaru!.path,
          filename: path.basename(fotoBaru!.path),
          contentType:
              MediaType.parse(lookupMimeType(fotoBaru!.path) ?? 'image/png'),
        ),
        if (_selectedStatus == 'Rusak' && fotoRusak != null)
          'UrlCardRusak': await MultipartFile.fromFile(
            fotoRusak!.path,
            filename: path.basename(fotoRusak!.path),
            contentType:
                MediaType.parse(lookupMimeType(fotoRusak!.path) ?? 'image/png'),
          ),
        if (_selectedStatus == 'Hilang' && suratKehilangan != null)
          'UrlSuratKehilangan': await MultipartFile.fromFile(
            suratKehilangan!.path,
            filename: path.basename(suratKehilangan!.path),
            contentType: MediaType.parse(
                lookupMimeType(suratKehilangan!.path) ?? 'application/pdf'),
          ),
      });

      final response = await ApiService.post(
        'http://34.50.112.226:5555/api/IdCards/upload',
        data: formData,
        headers: {'accept': 'text/plain'},
      );

      setState(() => isLoading = false);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseData =
            response.data is String ? jsonDecode(response.data) : response.data;
        final tglPengajuan = responseData['TglPengajuan'];
        String formattedDate = 'Tanggal tidak tersedia';
        if (tglPengajuan != null) {
          final dateTime = DateTime.parse(tglPengajuan).toLocal();
          formattedDate = DateFormat('dd/MM/yy HH:mm').format(dateTime);
        }

        _showPopup(
          title: 'Pengajuan Berhasil',
          message:
              'Pengajuan ID Card Anda telah berhasil disubmit.\nTanggal Pengajuan: $formattedDate',
          onPressed: () {
            setState(() {
              fotoBaru = null;
              fotoRusak = null;
              suratKehilangan = null;
            });
          },
        );
      } else {
        _showPopup(
          title: 'Gagal',
          message: 'Dokumen gagal dikirim.',
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showPopup(
        title: 'Koneksi Gagal',
        message: 'Gagal terhubung ke server: $e',
      );
    }
  }

  void _showPopup({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    final bool isError = title.toLowerCase().contains('gagal') ||
        title.toLowerCase().contains('error');
    final Color mainColor = isError ? Colors.red : const Color(0xFF1572E8);

    showDialog(
      context: context,
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
                Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_outline_rounded,
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
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  Future<void> pickFileModern(Function(File) onPicked,
      {bool allowPdf = false}) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (allowPdf)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: const Text('Pilih PDF dari File'),
                onTap: () => Navigator.pop(context, 'pdf'),
              ),
            ListTile(
              leading: const Icon(Icons.image, color: Colors.blue),
              title: const Text('Pilih Gambar dari Galeri'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
          ],
        ),
      ),
    );

    if (result == 'pdf') {
      FilePickerResult? picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (picked != null && picked.files.single.path != null) {
        onPicked(File(picked.files.single.path!));
      }
    } else if (result == 'image') {
      final picked =
          await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        onPicked(File(picked.path));
      }
    }
  }

  Widget buildUploadSection(String label, File? file, Function(File) onPicked,
      {bool allowPdf = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => pickImage(onPicked, allowPdf: allowPdf),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.black,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
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
                      const Text(
                        'Pilih File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        file != null
                            ? path.basename(file.path)
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
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget buildUploadSectionModern(
      String label, File? file, Function(File) onPicked,
      {bool allowPdf = false}) {
    final bool uploaded = file != null;
    final bool isPdf = uploaded && file.path.toLowerCase().endsWith('.pdf');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => pickFileModern(onPicked, allowPdf: allowPdf),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: uploaded ? Colors.green : Colors.black,
                width: 1.2,
              ),
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
                  ),
                  child: uploaded
                      ? (isPdf
                          ? const Icon(Icons.picture_as_pdf,
                              color: Colors.white, size: 36)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(file, fit: BoxFit.cover),
                            ))
                      : const Icon(Icons.upload_file,
                          size: 30, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pilih File',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        uploaded
                            ? path.basename(file.path)
                            : 'Belum ada file yang dipilih',
                        style: TextStyle(
                          fontSize: 14,
                          color: uploaded ? Colors.green[700] : Colors.grey,
                          fontWeight:
                              uploaded ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget uploadDokumenBoxModern({
    required String title,
    required File? file,
    required VoidCallback onPick,
    bool allowPdf = false,
  }) {
    final bool uploaded = file != null;
    final bool isPdf = uploaded && file!.path.toLowerCase().endsWith('.pdf');
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: uploaded ? Colors.green : Colors.grey[400]!,
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
                color: uploaded ? Colors.green : Colors.grey[300]!,
                width: 1.0,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: uploaded
                ? (isPdf
                    ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(file!, fit: BoxFit.cover),
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
                  uploaded ? file!.path.split('/').last : "File belum dipilih",
                  style: TextStyle(
                    color: uploaded ? Colors.green[700] : Colors.grey[500],
                    fontWeight: uploaded ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.upload_file, color: Colors.blue, size: 18),
                  label: Text(
                    uploaded ? "Ganti File" : "Pilih File",
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
        title: const Text('Pengajuan ID Card'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner / Header
            Padding(
              padding: const EdgeInsets.all(25.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/banner_id.png',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Form Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Form Pengajuan ID Card",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Status
                  const Text("Status Pengajuan",
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    items: ['Baru', 'Rusak', 'Hilang']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStatus = val!),
                  ),
                  const SizedBox(height: 24),
                  // Upload Foto
                  uploadDokumenBoxModern(
                    title: 'Foto Terbaru',
                    file: fotoBaru,
                    onPick: () => pickFileModern((f) => setState(() => fotoBaru = f)),
                  ),
                  if (_selectedStatus == 'Rusak')
                    uploadDokumenBoxModern(
                      title: 'Foto ID Card Rusak',
                      file: fotoRusak,
                      onPick: () => pickFileModern((f) => setState(() => fotoRusak = f)),
                    ),
                  if (_selectedStatus == 'Hilang')
                    uploadDokumenBoxModern(
                      title: 'Surat Kehilangan',
                      file: suratKehilangan,
                      onPick: () => pickFileModern((f) => setState(() => suratKehilangan = f), allowPdf: true),
                      allowPdf: true,
                    ),

                  // Tombol Submit
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (BuildContext buttonContext) {
                        return ElevatedButton.icon(
                          icon: isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                )
                              : const Icon(Icons.send),
                          label: isLoading
                              ? const Text('Mengirim...')
                              : const Text('Ajukan Sekarang'),
                          onPressed: isLoading
                              ? null
                              : () async {
                                  // Validasi data jika perlu
                                  if (fotoBaru == null ||
                                      (_selectedStatus == 'Rusak' &&
                                          fotoRusak == null) ||
                                      (_selectedStatus == 'Hilang' &&
                                          suratKehilangan == null)) {
                                    _showPopup(
                                      title: 'Gagal',
                                      message:
                                          'Silakan lengkapi semua field yang wajib diisi!',
                                    );
                                    return;
                                  }

                                  // Panggil submitForm agar data benar-benar dikirim ke API
                                  await submitForm(context);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1572E8),
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            textStyle: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white, // Warna teks tetap putih
                            ),
                            foregroundColor: Colors.white, // Warna ikon default
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              final ScrollController scrollController = ScrollController();
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.all(16.0),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.95,
                  height: MediaQuery.of(context).size.height * 0.6,
                  child: Scrollbar(
                    controller: scrollController,
                    thumbVisibility: false,
                    thickness: 3,
                    radius: const Radius.circular(10),
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Frequently Asked Questions (FAQ)',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1572E8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildFAQItem(
                            icon: Icons.badge,
                            question: 'Apa fungsi menu ID Card?',
                            answer:
                                'Menu ID Card digunakan oleh karyawan untuk mengajukan pembuatan kartu identitas. Tersedia tiga jenis pengajuan: Baru, Rusak, dan Hilang. Setiap jenis pengajuan memiliki ketentuan unggah dokumen yang berbeda. Pastikan Anda membaca ketentuannya terlebih dahulu dan mengunggah dokumen sesuai dengan status pengajuan.',
                          ),
                          _buildFAQItem(
                            icon: Icons.schedule_send,
                            question:
                                'Apa yang terjadi setelah saya mengajukan ID Card?',
                            answer:
                                'Setelah pengajuan ID Card dilakukan, permintaan Anda akan diproses oleh tim HR. Silakan menunggu hingga proses selesai dan ID Card Anda siap.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                actions: [
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
        icon: const Icon(Icons.help_outline, color: Colors.white),
        label: const Text(
          "FAQ",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),
    );
  }
}

Widget _buildFAQItem({
  required IconData icon,
  required String question,
  required String answer,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1572E8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
