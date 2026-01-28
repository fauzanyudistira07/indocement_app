import 'package:flutter/material.dart';
import 'package:indocement_apk/pages/layanan_menu.dart' show LayananMenuPage;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:indocement_apk/service/api_service.dart';
 

// Tambahkan warna biru khusus di halaman ini
const Color customBlue = Color(0xFF1572E8);

class MasaKerjaPage extends StatefulWidget {
  const MasaKerjaPage({super.key});

  @override
  State<MasaKerjaPage> createState() => _MasaKerjaPageState();
}

class _MasaKerjaPageState extends State<MasaKerjaPage> {
  String _lamaKerja = '';
  String _serviceDate = '';
  bool _isLoading = true;

  bool _isAnniversary = false;
  String _anniversaryText = '';
  bool _isLoadingAnniversary = true;
  List<int> _milestoneYears = [];

  @override
  void initState() {
    super.initState();
    _fetchMasaKerja();
    _fetchAnniversary();
  }

  Future<void> _fetchMasaKerja() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) {
        setState(() {
          _lamaKerja = 'ID karyawan tidak ditemukan';
          _isLoading = false;
        });
        return;
      }

      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees',
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = response.data is String ? jsonDecode(response.data) : response.data;
        final user = data.firstWhere(
          (e) => e['Id'] == idEmployee,
          orElse: () => null,
        );
        if (user != null && user['ServiceDate'] != null) {
          _serviceDate = user['ServiceDate'];
          final startDate = DateTime.tryParse(_serviceDate);
          if (startDate != null) {
            final now = DateTime.now();
            final duration = now.difference(startDate);
            final years = duration.inDays ~/ 365;
            final months = (duration.inDays % 365) ~/ 30;
            final days = (duration.inDays % 365) % 30;
            setState(() {
              _lamaKerja =
                  '$years tahun, $months bulan, $days hari';
              _isLoading = false;
            });
          } else {
            setState(() {
              _lamaKerja = 'Tanggal mulai kerja tidak valid';
              _isLoading = false;
            });
          }
        } else {
          setState(() {
            _lamaKerja = 'Data masa kerja tidak ditemukan';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _lamaKerja = 'Gagal mengambil data karyawan';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _lamaKerja = 'Terjadi kesalahan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchAnniversary() async {
    setState(() {
      _isLoadingAnniversary = true;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) {
        setState(() {
          _isAnniversary = false;
          _anniversaryText = 'ID karyawan tidak ditemukan';
          _isLoadingAnniversary = false;
        });
        return;
      }

      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Notifications/Anniversary',
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List data = response.data is String ? jsonDecode(response.data) : response.data;
        final item = data.firstWhere(
          (e) => e['EmployeeId'] == idEmployee,
          orElse: () => null,
        );
        if (item != null) {
          // MilestoneYears bisa int atau List, handle keduanya
          final dynamic milestoneRaw = item['MilestoneYears'];
          List<int> milestoneYears = [];
          if (milestoneRaw is int) {
            milestoneYears = [milestoneRaw];
          } else if (milestoneRaw is List) {
            milestoneYears = milestoneRaw.map((e) => int.tryParse(e.toString()) ?? 0).where((e) => e > 0).toList();
          }
          final String message = item['Message'] ?? 'Selamat atas penghargaan masa kerja!';
          setState(() {
            _isAnniversary = milestoneYears.isNotEmpty;
            _anniversaryText = message;
            _milestoneYears = milestoneYears;
            _isLoadingAnniversary = false;
          });
        } else {
          setState(() {
            _isAnniversary = false;
            _isLoadingAnniversary = false;
          });
        }
      } else {
        setState(() {
          _isAnniversary = false;
          _anniversaryText = 'Gagal mengambil data penghargaan';
          _isLoadingAnniversary = false;
        });
      }
    } catch (e) {
      setState(() {
        _isAnniversary = false;
        _anniversaryText = 'Terjadi kesalahan: $e';
        _isLoadingAnniversary = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Helper untuk format tanggal: hari bulan tahun
    String formatTanggal(String dateStr) {
      try {
        final date = DateTime.parse(dateStr);
        return DateFormat('dd/MM/yy').format(date);
      } catch (_) {
        return dateStr;
      }
    }

    // Helper untuk format lama kerja: hari, bulan, tahun
    String formatLamaKerja(String serviceDate) {
      final startDate = DateTime.tryParse(serviceDate);
      if (startDate == null) return '-';
      final now = DateTime.now();
      final duration = now.difference(startDate);
      final years = duration.inDays ~/ 365;
      final months = (duration.inDays % 365) ~/ 30;
      final days = (duration.inDays % 365) % 30;
      return '$days hari, $months bulan, $years tahun';
    }

    // Helper untuk kotak penghargaan
    Widget buildAnniversaryCard({required int level, required String message}) {
      String title = '';
      IconData icon = Icons.star;
      Color color = customBlue;
      Color badgeColor = customBlue;
      String badgeText = '';
      Gradient gradient = LinearGradient(
        colors: [customBlue, customBlue.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

      if (level == 16) {
        title = 'Penghargaan 16 Tahun';
        icon = Icons.star;
        color = customBlue;
        badgeColor = customBlue;
        badgeText = '16 Tahun';
        gradient = LinearGradient(
          colors: [customBlue, Colors.blueAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (level == 24) {
        title = 'Penghargaan 24 Tahun';
        icon = Icons.workspace_premium;
        color = Colors.green;
        badgeColor = Colors.green;
        badgeText = '24 Tahun';
        gradient = LinearGradient(
          colors: [Colors.green, Colors.lightGreenAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      } else if (level == 32) {
        title = 'Penghargaan 32 Tahun';
        icon = Icons.emoji_events;
        color = Colors.orange;
        badgeColor = Colors.orange;
        badgeText = '32 Tahun';
        gradient = LinearGradient(
          colors: [Colors.orange, Colors.deepOrangeAccent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      }

      return Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(18),
                child: Icon(icon, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 14),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: badgeColor, size: 18),
                          const SizedBox(width: 7),
                          Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      message,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
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

    // Dummy: parsing tingkatan dari _anniversaryText (ganti sesuai data API Anda)
    List<Widget> anniversaryCards = [];
    if (_isAnniversary && _milestoneYears.isNotEmpty) {
      for (var year in _milestoneYears) {
        anniversaryCards.add(buildAnniversaryCard(level: year, message: _anniversaryText));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Masa Kerja',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: customBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => LayananMenuPage()),
            );
          },
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Card Lama Bekerja
              Card(
                color: Colors.white,
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: customBlue, width: 1.5),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [customBlue, customBlue.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: const Icon(
                          Icons.work_history_rounded,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Lama Bekerja',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: customBlue,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _isLoading
                                ? const CircularProgressIndicator(color: customBlue)
                                : Text(
                                    formatLamaKerja(_serviceDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 17,
                                      color: Colors.black,
                                    ),
                                  ),
                            if (_serviceDate.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Mulai: ${formatTanggal(_serviceDate)}',
                                  style: TextStyle(
                                    color: customBlue.withOpacity(0.7),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Card Penghargaan (bisa lebih dari satu)
              if (_isLoadingAnniversary)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator(color: customBlue)),
                )
              else ...anniversaryCards,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitItem({required IconData icon, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: customBlue, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: customBlue,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
