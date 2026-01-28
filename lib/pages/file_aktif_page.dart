import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as path;
import 'package:open_file/open_file.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:dio/dio.dart';
import 'package:indocement_apk/pages/layanan_menu.dart';

class FileAktifPage extends StatefulWidget {
  const FileAktifPage({super.key});

  @override
  State<FileAktifPage> createState() => _FileAktifPageState();
}

class _FileAktifPageState extends State<FileAktifPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _noFileController = TextEditingController();
  final TextEditingController _employeeNameController = TextEditingController();
  XFile? _selectedFile;
  int? _idEmployee;
  bool _isLoading = false;
  String? _errorMessage;
  List<dynamic> _submissionHistory = [];

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _fetchEmployeeData();
    await _fetchSubmissionHistory();
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

  Future<void> _fetchEmployeeData() async {
    if (!await _checkNetwork()) {
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    final int? idEmployee = prefs.getInt('idEmployee');
    if (idEmployee == null) {
      setState(() =>
          _errorMessage = 'ID karyawan tidak ditemukan. Silakan login ulang.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees/$idEmployee',
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          _idEmployee = idEmployee;
          _employeeNameController.text = response.data['EmployeeName'] ?? '-';
          _errorMessage = null;
        });
      } else {
        setState(() =>
            _errorMessage = 'Gagal memuat data karyawan: ${response.data}');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubmissionHistory() async {
    if (_idEmployee == null) return;
    if (!await _checkNetwork()) {
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/FileAktif',
        headers: {'Accept': 'application/json'},
      );
      final List data =
          response.data is String ? jsonDecode(response.data) : response.data;
      final filtered = data
          .where((item) => item["IdEmployee"] == _idEmployee)
          .toList()
          .cast<dynamic>();
      setState(() {
        _submissionHistory = filtered;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Gagal memuat riwayat: $e');
    } finally {
      setState(() => _isLoading = false);
    }
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

  void _showSuccessModal(String message) {
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
                      backgroundColor: const Color(0xFF1572E8),
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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final chosenFile = await picker.pickImage(source: ImageSource.gallery);
    if (chosenFile != null) {
      setState(() => _selectedFile = chosenFile);
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      if (mounted) {
        _showErrorModal('Lengkapi semua informasi dan unggah file.');
      }
      return;
    }

    if (!await _checkNetwork()) {
      return;
    }

    final String noFile = _noFileController.text;
    final String fileName = path.basename(_selectedFile!.path);
    setState(() => _isLoading = true);
    _showLoading(context);
    try {
      final formData = FormData.fromMap({
        'IdEmployee': _idEmployee.toString(),
        'NoFileAktif': noFile,
        'file': await MultipartFile.fromFile(
          _selectedFile!.path,
          filename: fileName,
        ),
      });

      final response = await ApiService.post(
        'http://34.50.112.226:5555/api/FileAktif/request',
        data: formData,
        headers: {
          'Accept': 'application/json',
        },
        contentType: 'multipart/form-data',
      );

      Navigator.pop(context); // Close loading dialog
      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessModal('Pengajuan berhasil dikirim.');
        }
        _noFileController.clear();
        setState(() => _selectedFile = null);
        await _fetchSubmissionHistory();
      } else {
        String errorMessage = 'Pengajuan gagal. Coba lagi.';
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
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        _showErrorModal('Terjadi kesalahan: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _requestStoragePermission() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      final audio = await Permission.audio.request();
      return photos.isGranted && videos.isGranted && audio.isGranted;
    } else {
      final storage = await Permission.storage.request();
      return storage.isGranted;
    }
  }

  Future<void> _downloadFileAktif(String? noFile, String? urlPath) async {
    if (noFile == null || urlPath == null) {
      if (mounted) {
        _showErrorModal('Data file tidak lengkap.');
      }
      return;
    }

    if (!await _checkNetwork()) {
      return;
    }

    final String baseUrl = 'http://34.50.112.226:5555';
    final String fullUrl = '$baseUrl$urlPath';

    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      if (mounted) {
        _showErrorModal('Izin penyimpanan ditolak.');
      }
      return;
    }

    setState(() => _isLoading = true);
    _showLoading(context);
    try {
      final response = await ApiService.get(
        fullUrl,
        headers: {'Accept': '*/*'},
        responseType: ResponseType.bytes,
      );

      Navigator.pop(context); // Close loading dialog
      if (response.statusCode == 200) {
        Directory dir;
        if (Platform.isAndroid) {
          dir = await getExternalStorageDirectory() ??
              await getTemporaryDirectory();
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        String ext = path.extension(urlPath);
        if (ext.isEmpty) ext = '.pdf';

        final filePath = path.join(dir.path, 'fileaktif-$noFile$ext');
        final file = File(filePath);

        await file.writeAsBytes(response.data);

        if (mounted) {
          _showSuccessModal('File berhasil diunduh ke:\n$filePath');
        }

        await OpenFile.open(file.path);
      } else {
        if (mounted) {
          _showErrorModal('File tidak ditemukan di server: ${response.data}');
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        _showErrorModal('Gagal mengunduh file: $e');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'DiUpload':
        return Icons.upload_file;
      case 'Diproses':
        return Icons.hourglass_top;
      case 'Selesai':
        return Icons.check_circle;
      case 'Ditolak':
        return Icons.cancel;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'DiUpload':
        return Colors.blueGrey;
      case 'Diproses':
        return Colors.orange;
      case 'Selesai':
        return Colors.green;
      case 'Ditolak':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget formSection() {
    return Form(
      key: _formKey,
      child: Card(
        elevation: 4,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextFormField(
                controller: _employeeNameController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Nama Karyawan',
                  filled: true,
                  fillColor: Color(0xFFF1F3F4),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noFileController,
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                decoration: const InputDecoration(
                  labelText: 'Nomor File Aktif',
                ),
              ),
              const SizedBox(height: 12),
              uploadDokumenBoxModern(
                title: "File (PDF/Gambar)",
                file: _selectedFile,
                onPick: () async {
                  final picked = await showModalBottomSheet<XFile?>(
                    context: context,
                    builder: (ctx) => SafeArea(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            leading: const Icon(Icons.image),
                            title: const Text('Pilih Gambar'),
                            onTap: () async {
                              final img = await ImagePicker()
                                  .pickImage(source: ImageSource.gallery);
                              Navigator.pop(ctx, img);
                            },
                          ),
                          ListTile(
                            leading: const Icon(Icons.picture_as_pdf),
                            title: const Text('Pilih PDF'),
                            onTap: () async {
                              final pdf = await ImagePicker().pickImage(
                                source: ImageSource.gallery,
                                preferredCameraDevice: CameraDevice.rear,
                              );
                              // Ganti dengan file picker jika ingin PDF saja
                              Navigator.pop(ctx, pdf);
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                  if (picked != null) setState(() => _selectedFile = picked);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitForm,
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text("Ajukan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1572E8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                  elevation: 2,
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget uploadDokumenBoxModern({
    required String title,
    required XFile? file,
    required VoidCallback onPick,
    bool allowPdf = true,
  }) {
    final bool uploaded = file != null;
    final bool isPdf = uploaded && file!.path.toLowerCase().endsWith('.pdf');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
                        child: Image.file(File(file!.path), fit: BoxFit.cover),
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
  void dispose() {
    _noFileController.dispose();
    _employeeNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        title: const Text('File Aktif', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1572E8),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchSubmissionHistory,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Image.asset('assets/images/banner_file_aktif.jpg',
                      height: 180, fit: BoxFit.cover),
                  const SizedBox(height: 16),
                  formSection(),
                  const SizedBox(height: 20),
                  const Text(
                    "Riwayat Pengajuan",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (_submissionHistory.isEmpty)
                    const Center(child: Text("Belum ada pengajuan."))
                  else
                    ..._submissionHistory.map((data) => Card(
                          child: ListTile(
                            leading: Icon(
                              _statusIcon(data['Status']),
                              color: _statusColor(data['Status']),
                            ),
                            title: Text(
                                'No: ${data['NoFileAktif'] ?? 'Tidak Ada'}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status: ${data['Status']}'),
                                Text(
                                    'Tanggal: ${data['CreatedAt']?.substring(0, 10) ?? ''}'),
                              ],
                            ),
                            trailing: (data['Status'] != 'DiUpload' &&
                                    data['UrlFileAktif'] != null)
                                ? IconButton(
                                    icon: const Icon(Icons.download,
                                        color: Color(0xFF1572E8)),
                                    onPressed: () {
                                      _downloadFileAktif(data['NoFileAktif'],
                                          data['UrlFileAktif']);
                                    },
                                  )
                                : null,
                          ),
                        )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
    );
  }
}
