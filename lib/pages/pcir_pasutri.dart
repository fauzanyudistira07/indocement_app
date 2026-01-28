import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:indocement_apk/pages/bpjs_karyawan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart'; // Untuk mendapatkan nama file utama
import 'package:dio/dio.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:file_picker/file_picker.dart';
import 'package:indocement_apk/service/api_service.dart';

class TambahDataPasutriPage extends StatefulWidget {
  const TambahDataPasutriPage({super.key});

  @override
  State<TambahDataPasutriPage> createState() => _TambahDataPasutriPageState();
}

class _TambahDataPasutriPageState extends State<TambahDataPasutriPage> {
  int? idEmployee;
  String? urlKk;
  String? urlSuratNikah;
  bool isLoading = false;
  Map<String, File?> selectedImages =
      {}; // Menyimpan gambar yang dipilih berdasarkan fieldName

  @override
  void initState() {
    super.initState();
    _loadEmployeeId();
  }

  Future<void> _loadEmployeeId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      idEmployee = prefs.getInt('idEmployee');
    });
    if (idEmployee != null) {
      _fetchUploadedData();
    }
  }

  Future<void> _fetchUploadedData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Bpjs',
        params: {'idEmployee': idEmployee},
      );

      if (response.statusCode == 200) {
        final List<dynamic> dataList = response.data;

        // Cari data berdasarkan AnggotaBpjs = "Pasangan"
        final data = dataList.firstWhere(
          (item) => (item['AnggotaBpjs']?.toString().toLowerCase() ?? '') == 'pasangan',
          orElse: () => null,
        );

        if (data != null) {
          // Simpan data ke SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt('Id', data['Id']);
          await prefs.setInt('IdEmployee', data['IdEmployee']);
          await prefs.setString('AnggotaBpjs', data['AnggotaBpjs']);

          setState(() {
            urlKk = data['UrlKk'] ?? data['urlKk'] ?? data['url_kk'];
            urlSuratNikah = data['UrlSuratNikah'] ?? data['urlSuratNikah'] ?? data['url_surat_nikah'];
          });
        } else {
          // Jika data tidak ditemukan, tampilkan popup
          _showUploadPrompt();
        }
      } else {
        throw Exception('Gagal memuat data dari API.');
      }
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Gagal mengambil data: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> pickImage({
    required String fieldName,
  }) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        selectedImages[fieldName] = File(pickedFile.path);
      });
    }
  }

  // Tambahkan fungsi pickFile (pilihan PDF atau image)
  Future<void> pickFile({
    required String fieldName,
  }) async {
    final result = await showModalBottomSheet<String>(
      context: this.context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
        setState(() {
          selectedImages[fieldName] = File(picked.files.single.path!);
        });
      }
    } else if (result == 'image') {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          selectedImages[fieldName] = File(picked.path);
        });
      }
    }
  }

  Future<void> uploadDokumenPasutriGanda() async {
    try {
      setState(() => isLoading = true);

      // Ambil data dari SharedPreferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? id = prefs.getInt('Id');
      final int? employeeId = prefs.getInt('IdEmployee');
      final String? anggotaBpjs = prefs.getString('AnggotaBpjs');

      if (id == null || employeeId == null || anggotaBpjs == null) {
        throw Exception(
            'Data ID, IdEmployee, atau AnggotaBpjs tidak ditemukan.');
      }

      // Siapkan data untuk dikirim ke API
      final formData = FormData();

      // Tambahkan file UrlKk ke FormData
      if (selectedImages['UrlKk'] != null) {
        formData.files.add(
          MapEntry(
            'Files',
            await MultipartFile.fromFile(
              selectedImages['UrlKk']!.path,
              filename: basename(selectedImages['UrlKk']!.path),
            ),
          ),
        );
      }

      // Tambahkan file UrlSuratNikah ke FormData
      if (selectedImages['UrlSuratNikah'] != null) {
        formData.files.add(
          MapEntry(
            'Files',
            await MultipartFile.fromFile(
              selectedImages['UrlSuratNikah']!.path,
              filename: basename(selectedImages['UrlSuratNikah']!.path),
            ),
          ),
        );
      }

      // Tambahkan field tambahan ke FormData
      formData.fields.addAll([
        MapEntry('idEmployee', employeeId.toString()),
        MapEntry('FileTypes', 'UrlKk'),
        MapEntry('FileTypes', 'UrlSuratNikah'),
        MapEntry('AnggotaBpjs', anggotaBpjs),
      ]);

      // Kirim data ke API dengan metode PUT
      final uploadResponse = await ApiService.put(
        'http://34.50.112.226:5555/api/Bpjs/upload/$id',
        data: formData,
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      );

      if (uploadResponse.statusCode == 200) {
        await _fetchUploadedData(); // Refresh data dari API
        _showPopup(
          title: 'Berhasil',
          message: 'File berhasil diunggah.',
          onPressed: () {
            Navigator.pushReplacementNamed(this.context, '/master');
          },
        );
        // Tidak perlu await _fetchUploadedData(); karena langsung ke master
      } else {
        _showPopup(
          title: 'Gagal',
          message: 'Upload gagal: ${uploadResponse.statusCode}',
        );
      }
    } catch (e) {
      _showPopup(
        title: 'Gagal',
        message: 'Terjadi kesalahan: $e',
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showUploadPrompt() {
    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16), // Membuat sudut membulat
          ),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 28), // Ikon peringatan
              SizedBox(width: 8),
              Text(
                'Data Belum Tersedia',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Data KK dan Surat Nikah belum diunggah. Silakan unggah data terlebih dahulu di halaman BPJS Kesehatan.',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup popup
                Navigator.pop(context); // Kembali ke halaman PCIR Page
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey, // Warna teks tombol
              ),
              child: const Text(
                'Batal',
                style: TextStyle(fontSize: 16),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Tutup popup
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        const BPJSKaryawanPage(), // Ganti dengan halaman BPJS Kesehatan
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1572E8), // Warna tombol biru
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8), // Membuat sudut membulat
                ),
              ),
              child: const Text(
                'Unggah Sekarang',
                style: TextStyle(fontSize: 16, color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _openPdfViewer(String url, String title) {
    Navigator.push(
      this.context,
      MaterialPageRoute(
        builder: (context) => PdfViewerPage(url: url, title: title),
      ),
    );
  }

  Widget _buildUploadedFileBox(String? url, String label) {
    if (url == null) {
      return const SizedBox.shrink();
    }
    // Jika url hanya path, tambahkan base URL
    final fullUrl = url.startsWith('http') ? url : 'http://34.50.112.226:5555$url';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white, // Background card tetap putih
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            const Icon(Icons.picture_as_pdf,
                size: 40, color: Colors.red), // Ikon PDF
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    fullUrl.split('/').last,
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget upload modern (seperti di beasiswa)
  Widget uploadFieldPasutri({
    required String title,
    required File? file,
    required VoidCallback onPressed,
  }) {
    final bool uploaded = file != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              width: 44,
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
                      ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(file, fit: BoxFit.cover),
                        ))
                  : const Icon(Icons.insert_drive_file, color: Colors.grey, size: 26),
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
                    uploaded ? file.path.split('/').last : "File belum dikirim",
                    style: TextStyle(
                      color: uploaded ? Colors.green[700] : Colors.grey[500],
                      fontWeight: uploaded ? FontWeight.w600 : FontWeight.normal,
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
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
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

  // Ganti _buildBox menjadi:
  Widget _buildBox({
    required String title,
    required String fieldName,
  }) {
    return uploadFieldPasutri(
      title: title,
      file: selectedImages[fieldName],
      onPressed: () => pickFile(fieldName: fieldName),
    );
  }

  void _showPopup({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Update Data BPJS',
          style: TextStyle(
            color: Colors.white, // Pastikan warna teks putih
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF1572E8),
        iconTheme:
            const IconThemeData(color: Colors.white), // Icon back juga putih
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Data yang Telah Diunggah
                    const Text(
                      'Data yang Telah Diunggah',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildUploadedFileBox(urlKk, 'Kartu Keluarga'),
                    _buildUploadedFileBox(urlSuratNikah, 'Surat Nikah'),
                    const SizedBox(height: 24),

                    // Perbarui Data
                    const Text(
                      'Perbarui Data',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    // Form Upload
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: Colors.white, // Background card tetap putih
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Upload Dokumen',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildBox(
                              title: 'Upload Kartu Keluarga',
                              fieldName: 'UrlKk',
                            ),
                            const SizedBox(height: 16),
                            _buildBox(
                              title: 'Upload Surat Nikah',
                              fieldName: 'UrlSuratNikah',
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: () async {
                                if (selectedImages['UrlKk'] == null || selectedImages['UrlSuratNikah'] == null) {
                                  _showPopup(
                                    title: 'Gagal',
                                    message: 'Silakan upload Kartu Keluarga dan Surat Nikah terlebih dahulu!',
                                  );
                                  return;
                                }
                                await uploadDokumenPasutriGanda();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1572E8),
                                minimumSize: const Size(double.infinity, 50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Perbarui Data',
                                style: TextStyle(color: Colors.white),
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
}

class PdfViewerPage extends StatelessWidget {
  final String url;
  final String title;

  const PdfViewerPage({super.key, required this.url, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF1572E8),
      ),
      body: SfPdfViewer.network(url),
    );
  }
}
