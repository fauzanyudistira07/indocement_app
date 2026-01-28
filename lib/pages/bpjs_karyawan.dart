import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:indocement_apk/pages/bpjs_kesehatan.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart'; // Tambahkan ini untuk mendapatkan nama file utama
import 'bpjs_upload_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class BPJSKaryawanPage extends StatefulWidget {
  const BPJSKaryawanPage({super.key});

  @override
  State<BPJSKaryawanPage> createState() => _BPJSKaryawanPageState();
}

class _BPJSKaryawanPageState extends State<BPJSKaryawanPage> {
  int? idEmployee;
  Map<String, File?> selectedImages =
      {}; // Menyimpan gambar yang dipilih berdasarkan fieldName
  String? selectedAnakKe; // Ubah tipe data menjadi String

  // Tambahkan variabel untuk loading upload per tombol jika ingin lebih aman
  bool isUploadingPasangan = false;
  bool isUploadingAnak = false;

  @override
  void initState() {
    super.initState();
    _loadEmployeeId();
  }

  void _loadEmployeeId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      idEmployee = prefs.getInt('idEmployee');
    });
  }

  // Fungsi untuk memilih file (pdf atau image)
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

  void _showPopup({
    required BuildContext context,
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

  void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible:
          false, // Dialog tidak bisa ditutup dengan klik di luar
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Future<void> uploadBpjsWithArray({
    required BuildContext context,
    required String anggotaBpjs,
    required List<Map<String, dynamic>> documents,
    String? anakKe,
  }) async {
    if (idEmployee == null) {
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'ID karyawan belum tersedia.',
      );
      return;
    }

    List<File> files = [];
    List<String> fieldNames = [];

    // Konversi dokumen ke arrays untuk upload
    for (var doc in documents) {
      if (doc['file'] != null) {
        files.add(doc['file'] as File);
        fieldNames.add(doc['fieldName'] as String);
      }
    }

    if (files.isEmpty) {
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'Pilih minimal satu dokumen untuk diunggah.',
      );
      return;
    }

    if (files.length != fieldNames.length) {
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'Jumlah file dan tipe file tidak sesuai.',
      );
      return;
    }

    showLoadingDialog(context);

    try {
      final formData = FormData();

      for (int i = 0; i < files.length; i++) {
        formData.files.add(MapEntry(
          'Files',
          await MultipartFile.fromFile(
            files[i].path,
            filename: basename(files[i].path),
          ),
        ));
        formData.fields.add(MapEntry('FileTypes', fieldNames[i]));
      }

      formData.fields.add(MapEntry('idEmployee', idEmployee.toString()));
      formData.fields.add(MapEntry('AnggotaBpjs', anggotaBpjs.toLowerCase())); // lowercase!
      if (anakKe != null) {
        formData.fields.add(MapEntry('AnakKe', anakKe));
      }

      print('=== FormData yang akan dikirim ===');
      formData.fields.forEach((f) => print('Field: ${f.key}, Value: ${f.value}'));
      formData.files.forEach((f) => print('File Field: ${f.key}, Filename: ${f.value.filename}'));
      print('=================================');

      final uploadResponse = await ApiService.post(
        'http://34.50.112.226:5555/api/Bpjs/upload',
        data: formData,
      );

      Navigator.of(context).pop();
      _showPopup(
        context: context,
        title: 'Berhasil',
        message:
            'Dokumen BPJS ${anggotaBpjs == "Pasangan" ? "Pasangan" : "Anak"} berhasil diunggah.',
        onPressed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MenuPage()),
          );
        },
      );

      // Jeda 2 detik sebelum cek BPJS terbaru
      await Future.delayed(const Duration(seconds: 2));

      // Ambil data employee dari API
      final empResponse = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees',
        params: {'id': idEmployee},
      );
      int? idSection;
      if (empResponse.statusCode == 200 &&
          empResponse.data is List &&
          empResponse.data.isNotEmpty) {
        final employee = empResponse.data.firstWhere(
          (e) => e['Id'] == idEmployee,
          orElse: () => null,
        );
        if (employee != null) {
          idSection = employee['IdSection'];
        }
      }

      // Ambil BPJS terbaru sesuai IdSection
      int? latestBpjsId;
      if (idSection != null) {
        final bpjsResponse = await ApiService.get(
          'http://34.50.112.226:5555/api/Bpjs',
          params: {'idSection': idSection},
        );
        if (bpjsResponse.statusCode == 200 &&
            bpjsResponse.data is List &&
            bpjsResponse.data.isNotEmpty) {
          final latestEntry = bpjsResponse.data.last;
          latestBpjsId = latestEntry['Id'];
        }
      }
    } catch (e) {
      Navigator.of(context).pop();
      print("❌ Error saat mengunggah dokumen: $e");
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'Terjadi kesalahan saat mengunggah dokumen.',
      );
    }
  }

  Future<void> uploadBpjsDocuments({
    required BuildContext context,
    required String anggotaBpjs,
    required List<Map<String, dynamic>> documents,
    String? anakKe,
  }) async {
    if (idEmployee == null) {
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'ID karyawan belum tersedia.',
      );
      return;
    }

    if (documents.isEmpty) {
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'Pilih minimal satu dokumen untuk diunggah.',
      );
      return;
    }

    showLoadingDialog(context);

    try {
      // Ambil data dari API untuk mendapatkan ID yang sesuai
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Bpjs',
        params: {'idEmployee': idEmployee},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;

        // Cari ID yang sesuai dengan AnggotaBpjs dan AnakKe (jika ada)
        final matchingEntry = data.firstWhere(
          (item) =>
              item['IdEmployee'] == idEmployee &&
              item['AnggotaBpjs'] == anggotaBpjs &&
              (anakKe == null || item['AnakKe'] == anakKe),
          orElse: () => null,
        );

        if (matchingEntry == null) {
          throw Exception(
              'Data untuk ID Employee dan kategori BPJS tidak ditemukan.');
        }

        final matchingId = matchingEntry['Id']; // Ambil ID yang sesuai

        // Siapkan data untuk dikirim ke API
        final formData = FormData();

        for (int i = 0; i < documents.length; i++) {
          formData.files.add(MapEntry(
            documents[i]['fieldName'],
            await MultipartFile.fromFile(
              (documents[i]['file'] as File).path,
              filename: basename((documents[i]['file'] as File).path),
            ),
          ));
        }

        // Kirim data ke API dengan endpoint dinamis
        final uploadResponse = await ApiService.post(
          'http://34.50.112.226:5555/api/Bpjs/upload',
          data: formData,
        );

        print('Headers: ${uploadResponse.requestOptions.headers}');

        if (uploadResponse.statusCode == 200) {
          Navigator.of(context).pop();
          _showPopup(
            context: context,
            title: 'Berhasil',
            message: 'Dokumen BPJS berhasil diunggah.',
          );

          // Jeda 2 detik sebelum cek BPJS terbaru
          await Future.delayed(const Duration(seconds: 2));

          // Ambil data employee dari API
          final empResponse = await ApiService.get(
            'http://34.50.112.226:5555/api/Employees',
            params: {'id': idEmployee},
          );
          int? idSection;
          if (empResponse.statusCode == 200 &&
              empResponse.data is List &&
              empResponse.data.isNotEmpty) {
            final employee = empResponse.data.firstWhere(
              (e) => e['Id'] == idEmployee,
              orElse: () => null,
            );
            if (employee != null) {
              idSection = employee['IdSection'];
            }
          }

          // Ambil BPJS terbaru sesuai IdSection
          int? latestBpjsId;
          if (idSection != null) {
            final bpjsResponse = await ApiService.get(
              'http://34.50.112.226:5555/api/Bpjs',
              params: {'idSection': idSection},
            );
            if (bpjsResponse.statusCode == 200 &&
                bpjsResponse.data is List &&
                bpjsResponse.data.isNotEmpty) {
              final latestEntry = bpjsResponse.data.last;
              latestBpjsId = latestEntry['Id'];
            }
          }
        } else {
          throw Exception(
              'Gagal memperbarui data: ${uploadResponse.statusCode}');
        }
      } else {
        throw Exception('Gagal memuat data dari API.');
      }
    } catch (e) {
      Navigator.of(context).pop(); // Tutup loading dialog
      print("❌ Error saat mengunggah dokumen: $e");
      _showPopup(
        context: context,
        title: 'Gagal',
        message: 'Terjadi kesalahan saat mengunggah dokumen.',
      );
    }
  }

  // Widget upload modern (seperti di beasiswa)
  Widget uploadFieldBpjs({
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
    required String anggotaBpjs,
  }) {
    return uploadFieldBpjs(
      title: title,
      file: selectedImages[fieldName],
      onPressed: () => pickFile(fieldName: fieldName),
    );
  }

  Widget _buildUploadButton({
    required String title,
    required VoidCallback onPressed,
    required IconData icon,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 24, color: Colors.white),
      label: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1572E8), // Warna tombol
        minimumSize: const Size(double.infinity, 50), // Lebar penuh
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12), // Sudut melengkung
        ),
        elevation: 4, // Bayangan tombol
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
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
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildUploadedFileBox(String? url, String label) {
    if (url == null) {
      return const SizedBox.shrink();
    }

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
                    url.split('/').last,
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

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1572E8),
        title: const Text(
          'BPJS Karyawan',
          style: TextStyle(
            color: Colors.white, // Judul header warna putih
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white, // Tombol back warna putih
          ),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MenuPage(),
              ),
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informasi BPJS Karyawan
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
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
                              'Informasi BPJS Karyawan',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Halaman ini digunakan untuk mengunggah dokumen yang diperlukan untuk pengelolaan BPJS Pasangan dan BPJS Anak.',
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

              // BPJS Istri Section
              _buildSection(
                title: 'BPJS Pasangan',
                children: [
                  _buildBox(
                    title: 'Upload KK',
                    fieldName: 'UrlKk',
                    anggotaBpjs: 'Pasangan',
                  ),
                  const SizedBox(height: 16),
                  _buildBox(
                    title: 'Upload Surat Nikah',
                    fieldName: 'UrlSuratNikah',
                    anggotaBpjs: 'Pasangan',
                  ),
                  const SizedBox(height: 16),
                  _buildUploadButton(
                    title: 'Kirim Dokumen BPJS Pasangan',
                    icon: Icons.upload_file,
                    onPressed: () async {
                      // Validasi dan pengunggahan dokumen
                      if (selectedImages['UrlKk'] == null ||
                          selectedImages['UrlSuratNikah'] == null) {
                        _showPopup(
                          context: context,
                          title: 'Gagal',
                          message: 'Anda harus mengunggah KK dan Surat Nikah.',
                        );
                        return;
                      }

                      final List<Map<String, dynamic>> documents = [
                        {
                          'fieldName': 'UrlKk',
                          'file': selectedImages['UrlKk'],
                        },
                        {
                          'fieldName': 'UrlSuratNikah',
                          'file': selectedImages['UrlSuratNikah'],
                        },
                      ];

                      try {
                        await uploadBpjsWithArray(
                          context: context,
                          anggotaBpjs: 'Pasangan',
                          documents: documents,
                        );
                      } catch (e) {
                        print("❌ Error saat mengunggah dokumen: $e");
                        _showPopup(
                          context: context,
                          title: 'Gagal',
                          message: 'Terjadi kesalahan saat mengunggah dokumen.',
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // BPJS Anak Section
              _buildSection(
                title: 'BPJS Anak', // Ganti judul section di sini
                children: [
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedAnakKe,
                        hint: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Pilih Anak Ke-'),
                        ),
                        isExpanded: true,
                        // Hanya anak ke 1-3
                        items:
                            List.generate(3, (index) => (index + 1).toString())
                                .map((e) => DropdownMenuItem(
                                      value: e,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12),
                                        child: Text('Anak ke-$e'),
                                      ),
                                    ))
                                .toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedAnakKe = value;
                          });
                        },
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Note: "Untuk anak ke 4 sampai seterusnya di halaman BPJS Tambahan"',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.redAccent,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                  _buildBox(
                    title: 'Upload KK',
                    fieldName: 'UrlKkAnak',
                    anggotaBpjs: 'Anak',
                  ),
                  const SizedBox(height: 16),
                  _buildBox(
                    title: 'Upload Surat Keterangan Lahir',
                    fieldName: 'UrlAkteLahir',
                    anggotaBpjs: 'Anak',
                  ),
                  const SizedBox(height: 16),
                  _buildUploadButton(
                    title: 'Kirim Dokumen BPJS Anak',
                    icon: Icons.upload_file,
                    onPressed: () async {
                      // Validasi dan pengunggahan dokumen
                      if (selectedAnakKe == null) {
                        _showPopup(
                          context: context,
                          title: 'Gagal',
                          message: 'Pilih Anak Ke berapa terlebih dahulu.',
                        );
                        return;
                      }

                      if (selectedImages['UrlKkAnak'] == null ||
                          selectedImages['UrlAkteLahir'] == null) {
                        _showPopup(
                          context: context,
                          title: 'Gagal',
                          message: 'Anda harus mengunggah KK dan Akta Lahir.',
                        );
                        return;
                      }

                      final List<Map<String, dynamic>> documents = [
                        {
                          'fieldName': 'UrlKk',
                          'file': selectedImages['UrlKkAnak'],
                        },
                        {
                          'fieldName': 'UrlAkteLahir',
                          'file': selectedImages['UrlAkteLahir'],
                        },
                      ];

                      try {
                        await uploadBpjsWithArray(
                          context: context,
                          anggotaBpjs: 'Anak',
                          documents: documents,
                          anakKe: selectedAnakKe,
                        );
                      } catch (e) {
                        print("❌ Error saat mengunggah dokumen: $e");
                        _showPopup(
                          context: context,
                          title: 'Gagal',
                          message: 'Terjadi kesalahan saat mengunggah dokumen.',
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
