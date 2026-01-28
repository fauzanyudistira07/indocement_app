import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:dio/dio.dart';

class SkkFormPage extends StatefulWidget {
  const SkkFormPage({super.key});

  @override
  State<SkkFormPage> createState() => _SkkFormPageState();
}

class _SkkFormPageState extends State<SkkFormPage> {
  int? idEmployee;
  String? employeeName;
  String? employeeNo;
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _tempatLahirController = TextEditingController();
  List<Map<String, dynamic>> skkData = [];
  bool isLoading = false;
  bool isEmployeeDataLoading = true;
  final String baseUrl = 'http://34.50.112.226:5555';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEmployeeData();
    _loadSkkData();
    _fetchSkkData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _keperluanController.dispose();
    _tempatLahirController.dispose();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _fetchSkkData();
      }
    });
  }

  Future<void> _loadEmployeeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      idEmployee = prefs.getInt('idEmployee');
      employeeName = prefs.getString('employeeName') ?? 'Nama Tidak Diketahui';
      employeeNo = prefs.getString('employeeNo') ?? 'NIK Tidak Diketahui';
      isEmployeeDataLoading = false;
    });

    await _fetchEmployeeData();
  }

  Future<void> _fetchEmployeeData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? employeeId = prefs.getInt('idEmployee');

    if (employeeId == null || employeeId <= 0) {
      if (mounted) {
        _showErrorModal('ID karyawan tidak valid, silakan login ulang');
        Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    setState(() {
      isEmployeeDataLoading = true;
    });

    try {
      final response = await ApiService.get(
        '$baseUrl/api/Employees/$employeeId',
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        setState(() {
          employeeName =
              data['EmployeeName']?.toString() ?? 'Nama Tidak Diketahui';
          employeeNo = data['EmployeeNo']?.toString() ?? 'NIK Tidak Diketahui';
          idEmployee = employeeId;
          isEmployeeDataLoading = false;
        });

        await prefs.setInt('idEmployee', idEmployee!);
        await prefs.setString('employeeName', employeeName!);
        await prefs.setString('employeeNo', employeeNo!);
      } else {
        if (mounted) {
          _showErrorModal('Gagal memuat data karyawan: ${response.statusCode}');
          setState(() {
            isEmployeeDataLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Terjadi kesalahan: $e');
        setState(() {
          isEmployeeDataLoading = false;
        });
      }
    }
  }

  void _loadSkkData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? skkDataString = prefs.getString('skkData_$idEmployee');
    if (skkDataString != null) {
      try {
        final decodedData = jsonDecode(skkDataString);
        if (decodedData is List) {
          setState(() {
            skkData = List<Map<String, dynamic>>.from(decodedData)
                .where((data) => data['IdEmployee'] == idEmployee)
                .toList();
          });
        } else if (decodedData is Map) {
          if (decodedData['IdEmployee'] == idEmployee) {
            setState(() {
              skkData = [decodedData as Map<String, dynamic>];
            });
          } else {
            setState(() {
              skkData = [];
            });
          }
        }
      } catch (e) {
        setState(() {
          skkData = [];
        });
        print('Error decoding skkData: $e');
      }
    }
  }

  Future<void> _fetchSkkData() async {
    if (idEmployee == null) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await ApiService.get(
        '$baseUrl/api/skk?IdEmployee=$idEmployee',
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        if (data is List) {
          setState(() {
            skkData = List<Map<String, dynamic>>.from(data)
                .where((data) => data['IdEmployee'] == idEmployee)
                .toList();
            _saveSkkData();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorModal('Gagal mengambil data SKK: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _saveSkkData() async {
    if (idEmployee != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('skkData_$idEmployee', jsonEncode(skkData));
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

  Future<void> _submitSkk() async {
    if (idEmployee == null) {
      if (mounted) {
        _showErrorModal('ID karyawan tidak valid.');
      }
      return;
    }

    if (_keperluanController.text.isEmpty) {
      if (mounted) {
        _showErrorModal('Keperluan harus diisi.');
      }
      return;
    }

    if (_tempatLahirController.text.isEmpty) {
      if (mounted) {
        _showErrorModal('Tempat Lahir harus diisi.');
      }
      return;
    }

    setState(() {
      isLoading = true;
    });
    _showLoading(context);

    try {
      final response = await ApiService.post(
        '$baseUrl/api/skk',
        data: {
          'IdEmployee': idEmployee,
          'Keperluan': _keperluanController.text,
          'TempatLahir': _tempatLahirController.text,
        },
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          _showSuccessModal('Pengajuan SKK berhasil dikirim.');
          _keperluanController.clear();
          _tempatLahirController.clear();
          await _fetchSkkData();
        }
      } else {
        if (mounted) {
          _showErrorModal(
              'Gagal mengirim pengajuan: ${response.statusCode} - ${response.data}');
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        _showErrorModal('Terjadi kesalahan: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<bool> _requestStoragePermission() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final photos = await Permission.photos.request();
      final videos = await Permission.videos.request();
      final audio = await Permission.audio.request();
      if (!photos.isGranted || !videos.isGranted || !audio.isGranted) {
        _showPermissionDeniedDialog();
        return false;
      }
      return true;
    } else {
      final storage = await Permission.storage.request();
      if (!storage.isGranted) {
        _showPermissionDeniedDialog();
        return false;
      }
      return true;
    }
  }

  void _showPermissionDeniedDialog() {
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
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Izin Ditolak',
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
                  'Izin penyimpanan ditolak. Silakan aktifkan izin di Pengaturan > Aplikasi > indocement_apk > Izin > Penyimpanan, lalu coba lagi.',
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
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      openAppSettings();
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Buka Pengaturan',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Batal',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
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

  Future<void> _downloadSkk(String? noSkk, String? urlSkk) async {
    if (noSkk == null || urlSkk == null) {
      if (mounted) {
        _showErrorModal('Data file tidak lengkap.');
      }
      return;
    }

    final String fullUrl = '$baseUrl$urlSkk';
    final hasPermission = await _requestStoragePermission();
    if (!hasPermission) {
      return;
    }

    _showLoading(context);

    try {
      final response = await ApiService.get(
        fullUrl,
        responseType: ResponseType.bytes, // Specify binary response
      );

      Navigator.pop(context); // Close loading dialog

      if (response.statusCode == 200) {
        if (response.data is List<int>) {
          Directory dir;
          if (Platform.isAndroid) {
            dir = await getExternalStorageDirectory() ??
                await getTemporaryDirectory();
          } else {
            dir = await getApplicationDocumentsDirectory();
          }

          String ext = '.pdf';
          if (urlSkk.contains('.')) {
            ext = urlSkk.substring(urlSkk.lastIndexOf('.'));
          }

          final filePath = '${dir.path}/skk-$noSkk$ext';
          final file = File(filePath);

          await file.writeAsBytes(response.data as List<int>);

          final result = await OpenFile.open(filePath);
          if (result.type != ResultType.done) {
            if (mounted) {
              _showErrorModal('Tidak dapat membuka file: ${result.message}');
            }
            return;
          }

          if (mounted) {
            _showSuccessModal('File berhasil diunduh ke:\n$filePath');
          }
        } else {
          String errorMessage =
              'Format data tidak valid: Diharapkan byte array, diterima ${response.data.runtimeType}';
          if (response.data is String) {
            try {
              final jsonError = jsonDecode(response.data);
              errorMessage = jsonError['error'] ?? response.data;
            } catch (_) {
              errorMessage = response.data;
            }
          }
          if (mounted) {
            _showErrorModal('Gagal mengunduh: $errorMessage');
          }
        }
      } else {
        String errorMessage =
            'File tidak ditemukan di server: ${response.statusCode}';
        if (response.data is String) {
          try {
            final jsonError = jsonDecode(response.data);
            errorMessage = jsonError['error'] ?? response.data;
          } catch (_) {
            errorMessage = response.data;
          }
        }
        if (mounted) {
          _showErrorModal(errorMessage);
        }
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        _showErrorModal('Gagal mengunduh file: $e');
      }
    }
  }
  
  void _showReturnModal(BuildContext context, String keperluan) {
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
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.red,
                  size: 54,
                ),
                const SizedBox(height: 18),
                Text(
                  'Pengajuan Ditolak',
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
                  'Silahkan mengajukan ulang permintaan SKK ini',
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
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      setState(() {
                        _keperluanController.text = keperluan;
                      });
                    },
                    child: Text(
                      'Ajukan Ulang',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 16.5,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      'Batal',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
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

  Future<void> _refreshData() async {
    await _fetchSkkData();
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
        title: Text(
          'Pengajuan SKK',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: MediaQuery.of(context).size.width * 0.05,
          ),
        ),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1572E8),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.description,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Surat Keterangan Kerja',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Ajukan surat keterangan kerja untuk keperluan Anda.',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Form Pengajuan',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Nama Karyawan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      isEmployeeDataLoading
                          ? Text(
                              'Memuat...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            )
                          : Text(
                              employeeName ?? 'Nama Tidak Diketahui',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                      const SizedBox(height: 16),
                      Text(
                        'NIK',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      isEmployeeDataLoading
                          ? Text(
                              'Memuat...',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            )
                          : Text(
                              employeeNo ?? 'NIK Tidak Diketahui',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: Colors.grey[700],
                              ),
                            ),
                      const SizedBox(height: 16),
                      Text(
                        'Keperluan',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _keperluanController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1572E8), width: 2),
                          ),
                          hintText: 'Masukkan keperluan SKK',
                          hintStyle: GoogleFonts.poppins(),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tempat Lahir',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _tempatLahirController,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey[400]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF1572E8), width: 2),
                          ),
                          hintText: 'Masukkan tempat lahir',
                          hintStyle: GoogleFonts.poppins(),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 16),
                        ),
                        style: GoogleFonts.poppins(),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: isEmployeeDataLoading ? null : _submitSkk,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1572E8),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: isEmployeeDataLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : Text(
                                'Ajukan SKK',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Riwayat Pengajuan SKK',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (isLoading && skkData.isEmpty)
                        const Center(child: CircularProgressIndicator())
                      else if (skkData.isEmpty)
                        Text(
                          'Anda belum mengajukan SKK apapun.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: skkData.length,
                          separatorBuilder: (context, index) => const Divider(
                            height: 24,
                            thickness: 1,
                            color: Colors.grey,
                          ),
                          itemBuilder: (context, index) {
                            final data = skkData[index];
                            print(
                                'Keperluan [$index]: ${data['Keperluan']?.toString() ?? 'Tidak diketahui'}');
                            print(
                                'Status [$index]: ${data['Status']?.toString() ?? 'Tidak diketahui'}');
                            print(
                                'UrlSkk [$index]: ${data['UrlSkk']?.toString() ?? 'Tidak ada'}');

                            Color statusColor;
                            bool isClickable = false;
                            switch (data['Status']?.toString().toLowerCase()) {
                              case 'diajukan':
                                statusColor = Colors.grey;
                                break;
                              case 'diapprove':
                                statusColor = Colors.green;
                                break;
                              case 'return':
                                statusColor = Colors.red;
                                isClickable = true;
                                break;
                              default:
                                statusColor = Colors.grey;
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Tooltip(
                                        message:
                                            data['Keperluan']?.toString() ??
                                                'Tidak diketahui',
                                        child: Text(
                                          'Keperluan: ${data['Keperluan']?.toString() ?? 'Tidak diketahui'}',
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (data['Status']?.toLowerCase() ==
                                            'diapprove' &&
                                        data['UrlSkk'] != null)
                                      IconButton(
                                        icon: const Icon(
                                          Icons.download,
                                          color: Color(0xFF1572E8),
                                        ),
                                        onPressed: () => _downloadSkk(
                                            data['NoSkk'], data['UrlSkk']),
                                        tooltip: 'Download SKK',
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onTap: isClickable
                                      ? () => _showReturnModal(context,
                                          data['Keperluan']?.toString() ?? '')
                                      : null,
                                  child: Text(
                                    'Status: ${data['Status'] ?? 'Tidak diketahui'}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: statusColor,
                                      fontWeight: isClickable
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      decoration: isClickable
                                          ? TextDecoration.underline
                                          : TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
