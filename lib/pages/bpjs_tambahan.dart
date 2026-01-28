import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:indocement_apk/service/api_service.dart';

class BPJSTambahanPage extends StatefulWidget {
  const BPJSTambahanPage({super.key});

  @override
  State<BPJSTambahanPage> createState() => _BPJSTambahanPageState();
}

class _BPJSTambahanPageState extends State<BPJSTambahanPage> {
  int? idEmployee;
  String? selectedAnggotaBpjs;
  String? selectedRelationship;
  String? anakKe;
  File? fileKk;
  File? fileAkte;
  File? fileSuratRegis;
  bool isDownloaded = false;
  bool isLoading = false;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadEmployeeId();
    _requestStoragePermission();
  }

  Future<void> _loadEmployeeId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      idEmployee = prefs.getInt('idEmployee');
    });
  }

  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.storage.request();
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }
  }

  bool get isAnak =>
      selectedAnggotaBpjs != null &&
      selectedAnggotaBpjs!.toLowerCase().startsWith('anak');

  Future<void> _pickFile(Function(File) onPicked) async {
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      onPicked(File(picked.path));
    }
  }

  Future<void> _pickPdf(Function(File) onPicked) async {
    // Untuk contoh ini, hanya pakai image_picker (PNG/JPG)
    await _pickFile(onPicked);
    // Untuk support PDF, gunakan file_picker package.
  }

  Future<void> _submit() async {
    if (idEmployee == null ||
        selectedAnggotaBpjs == null ||
        fileKk == null ||
        (isAnak ? fileAkte == null : fileSuratRegis == null) ||
        (isAnak && (anakKe == null || anakKe!.isEmpty))) {
      _showPopup('Gagal', 'Semua dokumen dan data wajib diisi!');
      return;
    }

    setState(() => isLoading = true);

    try {
      final now = DateTime.now().toIso8601String();
      final formData = FormData();

      // Field utama
      formData.fields
        ..add(MapEntry("idEmployee", idEmployee.toString()))
        ..add(MapEntry("AnggotaBpjs", isAnak ? "Anak" : selectedAnggotaBpjs!))
        ..add(MapEntry("AnakKe", isAnak ? anakKe! : ""))
        ..add(MapEntry("CreatedAt", now))
        ..add(MapEntry("UpdatedAt", now));

      // Files dan FileTypes (multiple key, bukan join)
      formData.files.add(MapEntry(
        "Files",
        await MultipartFile.fromFile(fileKk!.path, filename: basename(fileKk!.path)),
      ));
      formData.fields.add(MapEntry("FileTypes", "UrlKk"));

      if (isAnak) {
        formData.files.add(MapEntry(
          "Files",
          await MultipartFile.fromFile(fileAkte!.path, filename: basename(fileAkte!.path)),
        ));
        formData.fields.add(MapEntry("FileTypes", "UrlAkteLahir"));
      } else {
        formData.files.add(MapEntry(
          "Files",
          await MultipartFile.fromFile(fileSuratRegis!.path, filename: basename(fileSuratRegis!.path)),
        ));
        formData.fields.add(MapEntry("FileTypes", "UrlSuratPotongGaji"));
      }

      // Pakai ApiService.post agar otomatis pakai token
      final response = await ApiService.post(
        "http://34.50.112.226:5555/api/Bpjs/upload",
        data: formData,
      );

      if (response.statusCode == 200) {
        _showPopup('Sukses', 'Dokumen berhasil dikirim!');
      } else {
        _showPopup('Gagal', 'Gagal upload: ${response.data}');
      }
    } catch (e) {
      String msg = e is DioException && e.response != null
          ? e.response.toString()
          : e.toString();
      _showPopup('Gagal', 'Gagal upload: $msg');
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Widget upload modern dengan preview file, judul, status, border dinamis
  Widget modernUploadField({
    required BuildContext context,
    required String title,
    required File? file,
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
    bool isImage = true,
  }) {
    final bool uploaded = file != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: uploaded ? Colors.green : color,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview kotak
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              border: Border.all(
                color: uploaded ? Colors.green : Colors.grey[300]!,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey[100],
            ),
            child: uploaded
                ? (isImage && (file.path.endsWith('.jpg') || file.path.endsWith('.jpeg') || file.path.endsWith('.png'))
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(file, fit: BoxFit.cover),
                      )
                    : Icon(Icons.insert_drive_file, color: Colors.green, size: 32))
                : Icon(Icons.insert_drive_file, color: Colors.grey[400], size: 32),
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
                    fontSize: 15.5,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  uploaded ? basename(file.path) : "File belum dikirim",
                  style: TextStyle(
                    color: uploaded ? Colors.green[700] : Colors.grey[500],
                    fontWeight: uploaded ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13.5,
                  ),
                ),
                const SizedBox(height: 2),
                OutlinedButton.icon(
                  icon: Icon(icon, color: color, size: 20),
                  label: Text(
                    uploaded ? "Ganti File" : "Upload",
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: color, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: onPressed,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Popup umum, otomatis pindah ke master hanya jika sukses pada submit
  void _showPopup(String title, String message, {bool success = true, VoidCallback? onOk}) {
    showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                success ? Icons.verified_rounded : Icons.cancel_rounded,
                color: success ? const Color(0xFF1572E8) : Colors.red,
                size: 54,
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: success ? const Color(0xFF1572E8) : Colors.red,
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
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: success ? const Color(0xFF1572E8) : Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.of(this.context).pop();
                    if (onOk != null) {
                      onOk();
                    } else if (success) {
                      Navigator.of(this.context).pushReplacementNamed('/master');
                    }
                  },
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
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

  Future<void> downloadFile() async {
    if (idEmployee == null) {
      _showPopup('Gagal', 'ID karyawan belum tersedia.');
      return;
    }
    if (selectedRelationship == null) {
      _showPopup('Gagal', 'Pilih hubungan keluarga terlebih dahulu.');
      return;
    }

    final String fileUrl =
        'http://34.50.112.226:5555/api/Bpjs/generate-salary-deduction/$idEmployee/$selectedRelationship';

    try {
      showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: const [
                SizedBox(
                    width: 28, height: 28, child: CircularProgressIndicator()),
                SizedBox(width: 20),
                Expanded(
                    child: Text('Mohon tunggu, file sedang didownload...')),
              ],
            ),
          );
        },
      );

final response = await ApiService.get(
  'http://34.50.112.226:5555/api/Bpjs/generate-salary-deduction/$idEmployee/$selectedRelationship',
  headers: {
    "accept": "/", // sesuai cURL
  },
  responseType: ResponseType.bytes,  // ← Tambahkan baris ini
);


      Navigator.of(this.context).pop();

      if (response.statusCode == 200) {
        // Simpan file ke storage
   final directory = await getApplicationDocumentsDirectory(); // Folder app sendiri
final filePath = '${directory.path}/salary_deduction_${idEmployee}_$selectedRelationship.pdf';
final file = File(filePath);
await file.writeAsBytes(response.data);  // Ini pasti berhasil semua android

        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('File berhasil didownload ke $filePath')),
        );

        setState(() {
          isDownloaded = true;
        });

        _showDownloadPopup(
          title: 'Download Berhasil',
          message: 'File berhasil diunduh.',
          success: true,
          onOpenFile: () {
            OpenFile.open(filePath);
          },
        );
      } else {
        _showDownloadPopup(
          title: 'Gagal Download',
          message: 'Data keluarga belum tersedia. Silakan input data keluarga terlebih dahulu.',
          success: false,
          onOpenFile: () {},
        );
      }
    } catch (e) {
      Navigator.of(this.context).pop();
      _showDownloadPopup(
        title: 'Download Gagal',
        message: 'Data keluarga belum tersedia. Silakan input data keluarga terlebih dahulu.',
        success: false,
        onOpenFile: () {},
      );
    }
  }

  // Popup download: warna dan icon beda untuk sukses/gagal, tidak pernah pindah halaman
  void _showDownloadPopup({
    required String title,
    required String message,
    required bool success,
    required VoidCallback onOpenFile,
    String okText = 'OK',
    String openText = 'Open File',
  }) {
    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  success ? Icons.file_download_done_rounded : Icons.cloud_off_rounded,
                  color: success ? const Color(0xFF1572E8) : Colors.red,
                  size: 48,
                ),
                const SizedBox(height: 22),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                    color: success ? const Color(0xFF1572E8) : Colors.red,
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
                const SizedBox(height: 32),
                Row(
                  children: [
                    if (success)
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.folder_open_rounded,
                              size: 20, color: Colors.white),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1572E8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            onOpenFile();
                          },
                          label: Text(
                            openText,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 15.5,
                            ),
                          ),
                        ),
                      ),
                    if (success) const SizedBox(width: 14),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color: success ? const Color(0xFF1572E8) : Colors.red, width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text(
                          okText,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: success ? const Color(0xFF1572E8) : Colors.red,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1572E8),
        title: const Text(
          'BPJS Tambahan',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1572E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info,
                        size: 30,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Informasi BPJS Tambahan',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Halaman ini digunakan untuk mengunggah dokumen tambahan untuk pengelolaan data BPJS Tambahan.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Dropdown dan tombol download
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
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1572E8),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.group,
                            size: 28,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Pilih Anggota BPJS',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF1572E8),
                          width: 1.5,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedAnggotaBpjs,
                          hint: const Text(
                            'Pilih Anggota BPJS',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1572E8),
                            ),
                          ),
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1572E8), size: 32),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                            fontSize: 16,
                          ),
                          items: [
                            'Ayah',
                            'Ibu',
                            'Ayah Mertua',
                            'Ibu Mertua',
                            'Anak ke-1',
                            'Anak ke-2',
                            'Anak ke-3',
                            'Anak ke-4',
                            'Anak ke-5',
                            'Anak ke-6',
                            'Anak ke-7',
                          ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) {
                            setState(() {
                              selectedAnggotaBpjs = v;
                              selectedRelationship = v;
                              anakKe = (v != null && v.toLowerCase().startsWith('anak'))
                                  ? v.split('-').last.trim()
                                  : null;
                              fileKk = null;
                              fileAkte = null;
                              fileSuratRegis = null;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Tombol download di bawah dropdown
                    ElevatedButton.icon(
                      onPressed: downloadFile,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        'Download Surat Registrasi BPJS Tambahan',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1572E8),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),

                    // Batas antara download dan form
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18.0),
                      child: Divider(
                        color: Color(0xFF1572E8),
                        thickness: 1.2,
                      ),
                    ),

                    // Form upload
                    if (selectedAnggotaBpjs != null) ...[
                      modernUploadField(
                        context: context,
                        title: "Kartu Keluarga (KK)",
                        file: fileKk,
                        onPressed: () => _pickPdf((f) => setState(() => fileKk = f)),
                        icon: Icons.upload_file,
                        color: const Color(0xFF1572E8),
                        isImage: true,
                      ),
                      if (isAnak)
                        modernUploadField(
                          context: context,
                          title: "Akte Kelahiran Anak",
                          file: fileAkte,
                          onPressed: () => _pickPdf((f) => setState(() => fileAkte = f)),
                          icon: Icons.upload_file,
                          color: const Color(0xFF1572E8),
                          isImage: true,
                        ),
                      if (!isAnak)
                        modernUploadField(
                          context: context,
                          title: "Surat Registrasi BPJS Tambahan",
                          file: fileSuratRegis,
                          onPressed: () => _pickPdf((f) => setState(() => fileSuratRegis = f)),
                          icon: Icons.upload_file,
                          color: const Color(0xFF1572E8),
                          isImage: true,
                        ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1572E8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 3,
                          ),
                          child: isLoading
                              ? const SizedBox(
                                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text(
                                  'Kirim',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 17,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget tombol upload modern
  Widget _modernUploadButton({
    required BuildContext context,
    required String label,
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(icon, color: color, size: 22),
        label: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 15.5,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: Colors.white,
        ),
        onPressed: onPressed,
      ),
    );
  }
}