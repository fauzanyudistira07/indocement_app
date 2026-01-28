import 'dart:io';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:indocement_apk/pages/absensi_page.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as imageLib;
import 'package:geocoding/geocoding.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mime/mime.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

class AbsensiLapanganScreen extends StatefulWidget {
  final double kantorLat;
  final double kantorLng;
  final int eventId;
  final DateTime? eventMulai;
  final DateTime? eventSelesai;
  final String? eventJamMasuk;
  final String? eventJamKeluar;
  const AbsensiLapanganScreen({
    super.key,
    required this.kantorLat,
    required this.kantorLng,
    required this.eventId,
    this.eventMulai,
    this.eventSelesai,
    this.eventJamMasuk,
    this.eventJamKeluar,
  });

  @override
  State<AbsensiLapanganScreen> createState() => _AbsensiLapanganScreenState();
}

class _AbsensiLapanganScreenState extends State<AbsensiLapanganScreen> {
  late double kantorLat;
  late double kantorLng;
  late int eventId;
  DateTime? eventMulai;
  DateTime? eventSelesai;
  String? eventJamMasuk;
  String? eventJamKeluar;
  final double radiusZona = 100; // meter

  Position? _currentPosition;
  double? _jarak;
  File? _imageFile;
  String? _statusLokasi;
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isTakingPicture = false;
  int? _idEmployee;
  Map<String, dynamic>? _employeeData;
  bool _isUploading = false;
  String? _lokasiNama;
  bool _isFakeGpsDetected = false;
  late Timer _fakeGpsTimer;

  @override
  void initState() {
    super.initState();
    kantorLat = widget.kantorLat; // Ambil dari parameter halaman sebelumnya
    kantorLng = widget.kantorLng; // Ambil dari parameter halaman sebelumnya
    eventId = widget.eventId; // <-- simpan eventId dari halaman sebelumnya
    eventMulai = widget.eventMulai;
    eventSelesai = widget.eventSelesai;
    eventJamMasuk = widget.eventJamMasuk;
    eventJamKeluar = widget.eventJamKeluar;
    _getCurrentLocation();
    _loadIdEmployee();
    _initCamera();

    // Periodic check setiap 3 detik
    _fakeGpsTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (mounted) {
        try {
          Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          if (pos.isMocked && !_isFakeGpsDetected) {
            setState(() {
              _isFakeGpsDetected = true;
            });
            _showFakeGpsModal();
          } else if (!pos.isMocked && _isFakeGpsDetected) {
            setState(() {
              _isFakeGpsDetected = false;
            });
          }
        } catch (_) {}
      }
    });
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
      final response = await ApiService.get('http://103.31.235.237:5555/api/Employees');
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final emp = data.firstWhere(
          (e) => e['Id'] == id,
          orElse: () => null,
        );
        if (emp != null) {
          setState(() {
            _employeeData = emp;
          });
          await _setKantorCoordinateFromSection();
        }
      }
    } catch (e) {}
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        Fluttertoast.showToast(msg: 'Layanan lokasi tidak aktif.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          Fluttertoast.showToast(msg: 'Izin lokasi ditolak.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        Fluttertoast.showToast(msg: 'Izin lokasi ditolak permanen.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Deteksi fake GPS
      if (position.isMocked) {
        setState(() {
          _isFakeGpsDetected = true;
        });
        _showFakeGpsModal();
        return;
      } else {
        setState(() {
          _isFakeGpsDetected = false;
        });
      }

      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        kantorLat,
        kantorLng,
      );
      setState(() {
        _currentPosition = position;
        _jarak = distance;
        _statusLokasi = 'Bebas Lokasi';
      });
      // Ambil nama lokasi dengan geocoding
      _getNamaLokasi(position.latitude, position.longitude);
    } catch (e) {
      Fluttertoast.showToast(msg: 'Gagal mendapatkan lokasi.');
    }
  }

  Future<void> _getNamaLokasi(double lat, double long) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final nama = [
          place.name,
          place.street,
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          _lokasiNama = nama;
        });
      }
    } catch (e) {
      setState(() {
        _lokasiNama = "-";
      });
    }
  }

  Future<void> _initCamera() async {
    _cameras = await availableCameras();
    final frontCamera = _cameras?.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.front,
      orElse: () => _cameras!.first,
    );
    if (frontCamera != null) {
      _cameraController = CameraController(frontCamera, ResolutionPreset.medium);
      await _cameraController!.initialize();
      setState(() {
        _isCameraInitialized = true;
      });
    }
  }

  Future<bool> _isFaceDetected(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final options = FaceDetectorOptions(
      enableContours: false,
      enableClassification: false,
    );
    final faceDetector = FaceDetector(options: options);
    final faces = await faceDetector.processImage(inputImage);
    await faceDetector.close();

    if (faces.isEmpty) {
      Fluttertoast.showToast(msg: 'Tidak ada wajah terdeteksi pada foto.');
      return false;
    }
    if (faces.length > 1) {
      Fluttertoast.showToast(msg: 'Terdeteksi lebih dari satu wajah.');
      return false;
    }
    return true;
  }

  Future<void> _takePicture() async {
    if (_cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_isTakingPicture) {
      setState(() {
        _isTakingPicture = true;
      });
      try {
        final XFile file = await _cameraController!.takePicture();
        File imgFile = File(file.path);

        if (_cameraController!.description.lensDirection == CameraLensDirection.front) {
          final bytes = await imgFile.readAsBytes();
          final original = imageLib.decodeImage(bytes);
          final mirrored = imageLib.flipHorizontal(original!);
          final mirroredBytes = imageLib.encodeJpg(mirrored);
          imgFile = await imgFile.writeAsBytes(mirroredBytes);
        }

        bool adaWajah = await _isFaceDetected(imgFile);
        if (!adaWajah) {
          setState(() {
            _isTakingPicture = false;
          });
          return;
        }

        setState(() {
          _imageFile = imgFile;
        });
      } finally {
        setState(() {
          _isTakingPicture = false;
        });
      }
    }
  }

  String _getStatusWaktu() {
    final now = DateTime.now();
    final jam = now.hour;
    final menit = now.minute;
    if ((jam == 6) || (jam == 7) || (jam == 8 && menit == 0)) {
      return 'Tepat Waktu';
    }
    if (jam > 6 && jam < 8) {
      return 'Tepat Waktu';
    }
    if (jam == 8 && menit == 0) {
      return 'Tepat Waktu';
    }
    return 'Terlambat';
  }

  Future<void> _setKantorCoordinateFromSection() async {
    int? idSection;
    if (_employeeData != null && _employeeData!['IdSection'] != null) {
      idSection = _employeeData!['IdSection'];
    } else {
      final prefs = await SharedPreferences.getInstance();
      idSection = prefs.getInt('idSection');
    }
    if (idSection == null) return;

    try {
      final response = await ApiService.get('http://103.31.235.237:5555/api/Units');
      if (response.statusCode == 200) {
        final List<dynamic> units = response.data;

        Map<String, dynamic>? foundUnit;
        for (var unit in units) {
          final sections = unit['Sections'] ?? unit['PlantDivisions'];
          if (sections != null) {
            for (var section in sections) {
              if (section['Id'] == idSection) {
                foundUnit = unit;
                break;
              }
            }
          }
          if (foundUnit != null) break;
        }

        if (foundUnit != null && foundUnit['Latitude'] != null && foundUnit['Longitude'] != null) {
          setState(() {
            kantorLat = double.tryParse(foundUnit!['Latitude'].toString()) ?? 0.0;
            kantorLng = double.tryParse(foundUnit['Longitude'].toString()) ?? 0.0;
          });
        }
      }
    } catch (e) {}
  }

  Future<int> _countAbsenHariIni() async {
    try {
      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/Absensi',
        headers: {'accept': 'text/plain'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        final now = DateTime.now();
        int count = 0;
        for (var absen in data) {
          if (absen['IdEmployee'] == _idEmployee && absen['EventId'] == eventId) {
            // Cek CreatedAt
            final createdAtStr = absen['CreatedAt'];
            if (createdAtStr != null) {
              final createdAt = DateTime.tryParse(createdAtStr);
              if (createdAt != null &&
                  createdAt.year == now.year &&
                  createdAt.month == now.month &&
                  createdAt.day == now.day) {
                count++;
              }
            }
          }
        }
        return count;
      }
    } catch (e) {
      // Bisa tambahkan log jika perlu
    }
    return 0;
  }

  DateTime? _parseTimeOnDate(DateTime baseDate, String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    // Expect "HH:mm" or "HH:mm:ss"
    final parsed = DateTime.tryParse('1970-01-01T$timeStr');
    if (parsed == null) return null;
    return DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
    );
  }

  DateTime _dateOnly(DateTime dt) {
    return DateTime(dt.year, dt.month, dt.day);
  }

  bool _isWithinEventDateRange(DateTime now) {
    if (eventMulai == null && eventSelesai == null) return true;
    final nowDate = _dateOnly(now);
    final startDate = eventMulai != null ? _dateOnly(eventMulai!) : null;
    final endDate = eventSelesai != null ? _dateOnly(eventSelesai!) : null;
    if (startDate != null && nowDate.isBefore(startDate)) return false;
    if (endDate != null && nowDate.isAfter(endDate)) return false;
    return true;
  }

  ({DateTime? start, DateTime? end}) _buildShiftWindow(DateTime now) {
    final baseDate = _dateOnly(now);
    final start = _parseTimeOnDate(baseDate, eventJamMasuk);
    final end = _parseTimeOnDate(baseDate, eventJamKeluar);
    if (start == null || end == null) {
      return (start: start, end: end);
    }
    if (!end.isAfter(start)) {
      // Shift melewati tengah malam
      return (start: start, end: end.add(const Duration(days: 1)));
    }
    return (start: start, end: end);
  }

  Future<void> _uploadAbsensi() async {
    if (_imageFile == null || _idEmployee == null || _jarak == null) {
      Fluttertoast.showToast(msg: 'Data absensi tidak lengkap!');
      return;
    }

    // Validasi rentang waktu event (tanggal/jam jika tersedia) sebelum upload
    final now = DateTime.now();
    if (!_isWithinEventDateRange(now)) {
      Fluttertoast.showToast(msg: 'Absensi hanya bisa dilakukan pada rentang tanggal event.');
      return;
    }
    final window = _buildShiftWindow(now);
    if (window.start != null && now.isBefore(window.start!)) {
      Fluttertoast.showToast(
        msg: 'Absensi belum dibuka. Jam masuk: ${_formatDateTime(window.start!)}',
      );
      return;
    }

    // CEK ABSEN HARI INI
    final absenCount = await _countAbsenHariIni();
    if (absenCount >= 2) {
      Fluttertoast.showToast(msg: 'Anda sudah melakukan absensi masuk dan keluar hari ini.');
      return;
    }
    if (absenCount >= 1 && window.end != null && now.isBefore(window.end!)) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: const Color(0xFFF6F8FC),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: const Icon(
                      Icons.event_busy,
                      color: Color(0xFFD32F2F),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Sudah Absen Hari Ini',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    window.end != null
                        ? 'Anda sudah absen masuk. Silakan kembali saat jam keluar (${_formatDateTime(window.end!)}).'
                        : 'Anda sudah melakukan absensi untuk hari ini.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF333333),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const EventMenuPage()),
                        );
                      },
                      child: const Text('Kembali'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final mimeType = lookupMimeType(_imageFile!.path) ?? 'image/jpeg';
      final formData = FormData.fromMap({
        'IdEmployee': _idEmployee.toString(),
        'Jarak': _jarak.toString(),
        'Status': _getStatusWaktu(),
        'EventId': eventId.toString(),
        'UrlFoto': await MultipartFile.fromFile(
          _imageFile!.path,
          filename: path.basename(_imageFile!.path),
          contentType: MediaType.parse(mimeType),
        ),
      });

      final response = await ApiService.post(
        'http://103.31.235.237:5555/api/Absensi/upload',
        data: formData,
        headers: {'accept': 'text/plain'},
      );
      print('Absensi upload status: ${response.statusCode}');
      print('Absensi upload response: ${response.data}');

      setState(() {
        _isUploading = false;
      });

      if (response.statusCode == 200 || response.statusCode == 201) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text(
              'Absensi Terkirim',
              style: TextStyle(
                color: Color(0xFF1572E8),
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            content: const Text('Data absensi berhasil dikirim.'),
            actions: [
              TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFF1572E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(context, '/master');
                  setState(() {
                    _imageFile = null;
                    _isCameraInitialized = false;
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } else {
        Fluttertoast.showToast(msg: 'Gagal upload absensi!');
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      String msg = 'Terjadi error saat upload absensi!';
      if (e is DioException) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        if (status == 401) {
          Fluttertoast.showToast(msg: 'Sesi login sudah habis. Silakan login ulang.');
          return;
        }
        msg = 'Upload gagal: ${status ?? '-'} ${data ?? ''}'.trim();
      }
      Fluttertoast.showToast(msg: msg);
    }
  }

  String _formatDateTime(DateTime dt) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}-${two(dt.month)}-${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  }

  void _showFakeGpsModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFFF6F8FC),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: const Icon(
                    Icons.location_off, // Lebih simple dan relevan
                    color: Color(0xFFD32F2F),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Fake GPS Terdeteksi!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Matikan aplikasi fake GPS atau fitur lokasi palsu di perangkat Anda untuk melanjutkan absensi.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF333333),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFFD32F2F),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const EventMenuPage()),
                      );
                    },
                    child: const Text('Kembali'),
                  ),
                ),
              ],
            ),
          ),
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
  void dispose() {
    _fakeGpsTimer.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Jika fake GPS terdeteksi, modal akan tetap muncul
    if (_isFakeGpsDetected) {
      Future.delayed(Duration.zero, () {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          _showFakeGpsModal();
        }
      });
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1572E8),
        title: const Text('Absensi Lapangan'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const EventMenuPage()),
            );
          },
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _currentPosition == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_employeeData != null)
                      Card(
                        elevation: 8,
                        margin: const EdgeInsets.only(bottom: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(
                            color: Color(0xFF1572E8),
                            width: 1.5,
                          ),
                        ),
                        color: const Color(0xFFF8FAFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.black,
                                        width: 0.8,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    width: 64,
                                    height: 64,
                                    child: (_employeeData!['UrlFoto'] != null && _employeeData!['UrlFoto'].toString().isNotEmpty)
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: Image.network(
                                              'http://103.31.235.237:5555${_employeeData!['UrlFoto']}',
                                              fit: BoxFit.cover,
                                              width: 56,
                                              height: 56,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.account_circle, color: Colors.black, size: 40),
                                            ),
                                          )
                                        : const Icon(Icons.account_circle, color: Colors.black, size: 40),
                                  ),
                                  const SizedBox(width: 18),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _employeeData!['EmployeeNo'] ?? '-',
                                          style: const TextStyle(
                                            color: Color(0xFF1572E8),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 17,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _employeeData!['EmployeeName'] ?? '-',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.badge, size: 18, color: Colors.black54),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _employeeData!['JobTitle'] ?? '-',
                                                style: const TextStyle(fontSize: 15, color: Colors.black54),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            const Icon(Icons.location_city, size: 18, color: Colors.black45),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                _employeeData!['WorkLocation'] ?? '-',
                                                style: const TextStyle(fontSize: 15, color: Colors.black45),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              AspectRatio(
                                aspectRatio: 3 / 4,
                                child: _imageFile != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.file(
                                          _imageFile!,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                        ),
                                      )
                                    : _isCameraInitialized &&
                                            _cameraController != null &&
                                            _cameraController!.value.isInitialized
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: CameraPreview(_cameraController!),
                                          )
                                        : const Center(child: CircularProgressIndicator()),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  icon: Icon(
                                    _imageFile == null ? Icons.camera_alt : Icons.refresh,
                                    color: Colors.white,
                                  ),
                                  label: Text(
                                    _imageFile == null ? 'Ambil Foto' : 'Ambil Ulang Foto',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1572E8),
                                    minimumSize: const Size(0, 48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    elevation: 4,
                                  ),
                                  onPressed: _isTakingPicture
                                      ? null
                                      : () async {
                                          if (_imageFile != null) {
                                            setState(() {
                                              _imageFile = null;
                                            });
                                            await _initCamera();
                                          } else {
                                            await _takePicture();
                                          }
                                        },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(
                          color: Color(0xFF1572E8),
                          width: 1.2,
                        ),
                      ),
                      color: const Color(0xFFF8FAFF),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.location_on, color: Color(0xFF1572E8)),
                                const SizedBox(width: 8),
                                Text(
                                  'Lokasi Anda',
                                  style: const TextStyle(
                                    color: Color(0xFF1572E8),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_currentPosition!.latitude.toStringAsFixed(5)}, ${_currentPosition!.longitude.toStringAsFixed(5)}',
                              style: const TextStyle(fontSize: 15, color: Colors.black87),
                            ),
                            if (_lokasiNama != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _lokasiNama!,
                                style: const TextStyle(fontSize: 15, color: Colors.black54),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.social_distance, color: Colors.orange[700]),
                                const SizedBox(width: 8),
                                Text(
                                  'Jarak ke Event',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _jarak != null
                                      ? (_jarak! >= 1000
                                          ? '${(_jarak! / 1000).toStringAsFixed(2)} km'
                                          : '${_jarak!.round()} m')
                                      : '-',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  (_jarak != null && _jarak! <= radiusZona)
                                      ? Icons.verified
                                      : Icons.warning_amber_rounded,
                                  color: (_jarak != null && _jarak! <= radiusZona)
                                      ? Colors.green
                                      : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  (_jarak != null && _jarak! <= radiusZona)
                                      ? 'Berada di lingkungan Event'
                                      : 'Di luar lingkungan Event',
                                  style: TextStyle(
                                    color: (_jarak != null && _jarak! <= radiusZona)
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_jarak != null && _jarak! > radiusZona)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline, color: Colors.red, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Anda harus berada di lingkungan Event untuk dapat melakukan absensi.',
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                                label: _isUploading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 3,
                                        ),
                                      )
                                    : const Text(
                                        'Upload Foto Absensi',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1572E8),
                                  minimumSize: const Size(0, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  elevation: 4,
                                ),
                                onPressed: (_imageFile != null && !_isUploading && _jarak != null && _jarak! <= radiusZona)
                                    ? () async {
                                        print('IdEmployee: $_idEmployee');
                                        print('Jarak: $_jarak');
                                        print('Status: ${_getStatusWaktu()}');
                                        print('EventId: $eventId');
                                        print('Foto: ${_imageFile?.path}');
                                        await _uploadAbsensi();
                                      }
                                    : null,
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
