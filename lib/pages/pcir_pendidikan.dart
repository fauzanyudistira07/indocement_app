import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:dio/dio.dart';

class TambahDataPendidikanPage extends StatefulWidget {
  const TambahDataPendidikanPage({super.key});

  @override
  State<TambahDataPendidikanPage> createState() =>
      _TambahDataPendidikanPageState();
}

class _TambahDataPendidikanPageState extends State<TambahDataPendidikanPage> {
  int? idEmployee;
  File? selectedIjazah;

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

  Future<void> pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        selectedIjazah = File(pickedFile.path);
      });
    }
  }

  // Tambahkan fungsi pickFileIjazah (pilihan PDF atau image)
  Future<void> pickFileIjazah() async {
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
          selectedIjazah = File(picked.files.single.path!);
        });
      }
    } else if (result == 'image') {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked != null) {
        setState(() {
          selectedIjazah = File(picked.path);
        });
      }
    }
  }

  void _showPopup({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
    required BuildContext context,
  }) {
    final bool isError = title.toLowerCase().contains('gagal') ||
        title.toLowerCase().contains('error');
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
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
  }

  Future<void> uploadIjazah() async {
    if (idEmployee == null) {
      _showPopup(
        context: this.context,
        title: 'Gagal',
        message: 'ID karyawan tidak valid.',
      );
      return;
    }

    if (selectedIjazah == null || !selectedIjazah!.existsSync()) {
      _showPopup(
        context: this.context,
        title: 'Gagal',
        message: 'Anda harus mengunggah Ijazah yang valid.',
      );
      return;
    }

    showLoadingDialog(this.context);

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          selectedIjazah!.path,
          filename:
              'UrlIjazahTerbaru_${idEmployee}_${DateTime.now().millisecondsSinceEpoch}${extension(selectedIjazah!.path)}',
        ),
      });

      final response = await ApiService.put(
        'http://34.50.112.226:5555/api/Employees/$idEmployee/UrlIjazahTerbaru',
        data: formData,
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      );

      Navigator.of(this.context).pop();

      if (response.statusCode == 200 || response.statusCode == 204) {
        _showPopup(
          context: this.context,
          title: 'Berhasil',
          message: 'Dokumen berhasil dikirim.',
        );
      } else {
        _showGagalKirimModal(
          title: 'Gagal',
          message:
              'Gagal mengunggah Ijazah: ${response.statusCode} - ${response.data}',
        );
      }
    } catch (e) {
      Navigator.of(this.context).pop();
      _showGagalKirimModal(
        title: 'Gagal',
        message: 'Terjadi kesalahan: ${e.toString()}',
      );
    }
  }

  void _showGagalKirimModal({
    required String title,
    required String message,
    String buttonText = 'OK',
    VoidCallback? onPressed,
  }) {
    showDialog(
      context: this.context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: const TextStyle(
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
        backgroundColor: const Color(0xFF1572E8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        elevation: 0,
        title: const Padding(
          padding: EdgeInsets.only(
              left: 4), // Tambahkan padding kiri agar tidak menempel
          child: Text(
            'Halaman Upload Ijazah',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ),
        centerTitle: false, // Pastikan judul rata kiri
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
                  color: const Color(0xFF1572E8),
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
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.school,
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
                            'Update Data Pendidikan',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Halaman ini digunakan untuk mengunggah dokumen Ijazah terbaru.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Ganti _buildBox agar UI upload sama seperti halaman lain
              _buildBox(
                title: 'Upload Ijazah',
                onTap: pickFileIjazah,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: uploadIjazah,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1572E8),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Kirim Dokumen',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _buildBox({
  //   required String title,
  //   required VoidCallback onTap,
  // }) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Container(
  //       padding: const EdgeInsets.all(16.0),
  //       decoration: BoxDecoration(
  //         color: Colors.white,
  //         borderRadius: BorderRadius.circular(12),
  //         border: Border.all(
  //           color: Colors.black,
  //           width: 1,
  //         ),
  //         boxShadow: [
  //           BoxShadow(
  //             color: Colors.black.withOpacity(0.1),
  //             blurRadius: 6,
  //             offset: const Offset(0, 3),
  //           ),
  //         ],
  //       ),
  //       child: Row(
  //         children: [
  //           Container(
  //             width: 60,
  //             height: 60,
  //             decoration: BoxDecoration(
  //               color: const Color(0xFF1572E8),
  //               borderRadius: BorderRadius.circular(8),
  //               image: selectedIjazah != null
  //                   ? DecorationImage(
  //                       image: FileImage(selectedIjazah!),
  //                       fit: BoxFit.cover,
  //                     )
  //                   : null,
  //             ),
  //             child: selectedIjazah == null
  //                 ? const Icon(
  //                     Icons.upload_file,
  //                     size: 30,
  //                     color: Colors.white,
  //                   )
  //                 : null,
  //           ),
  //           const SizedBox(width: 16),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: const TextStyle(
  //                     fontSize: 16,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   selectedIjazah != null
  //                       ? basename(selectedIjazah!.path)
  //                       : 'Belum ada file yang dipilih',
  //                   style: const TextStyle(
  //                     fontSize: 14,
  //                     color: Colors.grey,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Ganti _buildBox agar UI upload sama seperti halaman lain
  Widget _buildBox({
    required String title,
    required VoidCallback? onTap,
  }) {
    final bool uploaded = selectedIjazah != null;
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
                  ? (selectedIjazah!.path.endsWith('.pdf')
                      ? const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28)
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(selectedIjazah!, fit: BoxFit.cover),
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
                    uploaded ? basename(selectedIjazah!.path) : "File belum dikirim",
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
                    onPressed: onTap,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
