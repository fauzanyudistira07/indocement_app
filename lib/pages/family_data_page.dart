import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/service/api_service.dart';

class FamilyDataPage extends StatefulWidget {
  const FamilyDataPage({super.key});

  @override
  _FamilyDataPageState createState() => _FamilyDataPageState();
}

class _FamilyDataPageState extends State<FamilyDataPage> {
  List<dynamic> _familyData = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _employeeId;

  @override
  void initState() {
    super.initState();
    _fetchEmployeeIdAndData();
  }

  Future<void> _fetchEmployeeIdAndData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _employeeId = prefs.getInt('idEmployee');
      print('Employee ID from SharedPreferences: $_employeeId');

      if (_employeeId == null || _employeeId! <= 0) {
        setState(() {
          _errorMessage = 'ID karyawan tidak ditemukan, silakan login ulang';
          _isLoading = false;
        });
        return;
      }

      await _fetchFamilyData();
    } catch (e) {
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat ID karyawan: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFamilyData() async {
    try {
      final stopwatch = Stopwatch()..start();
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/FamilyEmployees',
        params: {'IdEmployee': _employeeId},
        headers: {'Content-Type': 'application/json'},
      );

      stopwatch.stop();
      print('Fetch Family Data took ${stopwatch.elapsedMilliseconds}ms');
      print('Fetch Family Data Status: ${response.statusCode}');
      print('Fetch Family Data Body: ${response.data}');

      if (response.statusCode == 200) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        List<dynamic> familyData = [];

        // Handle different response formats
        if (data is List) {
          familyData = data;
        } else if (data is Map && data.isNotEmpty) {
          familyData = [data];
        }

        // Filter data by IdEmployee to ensure only relevant data is displayed
        familyData = familyData.where((member) {
          final memberId = member['IdEmployee'] != null
              ? int.tryParse(member['IdEmployee'].toString())
              : null;
          final isMatch = memberId == _employeeId;
          if (!isMatch) {
            print(
                'Filtered out member with IdEmployee: $memberId, expected: $_employeeId');
          }
          return isMatch;
        }).toList();

        print('Filtered Family Data Count: ${familyData.length}');

        setState(() {
          _familyData = familyData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Gagal memuat data keluarga: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching family data: $e');
      setState(() {
        _errorMessage = 'Terjadi kesalahan saat memuat data: Data Keluarga Belum Tersedia, pastikan data telah di input oleh PIC';
        _isLoading = false;
      });
    }
  }

  Widget _buildFamilySection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF1572E8), size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1572E8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'Tidak tersedia',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildFamilyMemberWidgets(Map<String, dynamic> member) {
    return [
      if (member['NamaPasangan'] != null)
        _buildFamilySection(
          title: 'Pasangan (${member['StatusPasangan'] ?? 'Istri/Suami'})',
          icon: Icons.person,
          children: [
            _buildInfoRow('Nama', member['NamaPasangan']),
            _buildInfoRow('Jenis Kelamin',
                member['JkPasangan'] == 'P' ? 'Perempuan' : 'Laki-laki'),
            _buildInfoRow('Tanggal Lahir', member['TglLahirPasangan']),
            _buildInfoRow('Pendidikan', member['PendidikanPasangan']),
            _buildInfoRow('No. BPJS', member['NoBpjsPasangan']),
            _buildInfoRow('NIK', member['NikPasangan']),
            _buildInfoRow('No. KK', member['NoKkPasangan']),
            _buildInfoRow('Telepon', member['TeleponPasangan']),
            _buildInfoRow('Email', member['EmailPasangan']),
            _buildInfoRow('Alamat', member['AlamatPasangan']),
          ],
        ),
      if (member['NamaAnak'] != null)
        _buildFamilySection(
          title: 'Anak (${member['StatusAnak'] ?? 'Kandung'})',
          icon: Icons.child_care,
          children: [
            _buildInfoRow('Nama', member['NamaAnak']),
            _buildInfoRow('Jenis Kelamin',
                member['JkAnak'] == 'L' ? 'Laki-laki' : 'Perempuan'),
            _buildInfoRow('Tanggal Lahir', member['TglLahirAnak']),
            _buildInfoRow('Pendidikan', member['PendidikanAnak']),
            _buildInfoRow('No. BPJS', member['NoBpjsAnak']),
            _buildInfoRow('NIK', member['NikAnak']),
            _buildInfoRow('No. KK', member['NoKkAnak']),
          ],
        ),
      if (member['NamaAyah'] != null || member['NamaIbu'] != null)
        _buildFamilySection(
          title: 'Orang Tua',
          icon: Icons.family_restroom,
          children: [
            if (member['NamaAyah'] != null) ...[
              Text(
                'Ayah',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              _buildInfoRow('Nama', member['NamaAyah']),
              _buildInfoRow('Status', member['StatusAyah']),
              _buildInfoRow('Tanggal Lahir', member['TglLahirAyah']),
              _buildInfoRow('Pendidikan', member['PendidikanAyah']),
              _buildInfoRow('No. BPJS', member['NoBpjsAyah']),
              _buildInfoRow('NIK', member['NikAyah']),
              _buildInfoRow('No. KK', member['NoKkAyah']),
              _buildInfoRow('Telepon', member['TeleponAyah']),
              _buildInfoRow('Email', member['EmailAyah']),
              _buildInfoRow('Alamat', member['AlamatAyah']),
              const SizedBox(height: 12),
            ],
            if (member['NamaIbu'] != null) ...[
              Text(
                'Ibu',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              _buildInfoRow('Nama', member['NamaIbu']),
              _buildInfoRow('Status', member['StatusIbu']),
              _buildInfoRow('Tanggal Lahir', member['TglLahirIbu']),
              _buildInfoRow('Pendidikan', member['PendidikanIbu']),
              _buildInfoRow('No. BPJS', member['NoBpjsIbu']),
              _buildInfoRow('NIK', member['NikIbu']),
              _buildInfoRow('No. KK', member['NoKkIbu']),
              _buildInfoRow('Telepon', member['TeleponIbu']),
              _buildInfoRow('Email', member['EmailIbu']),
              _buildInfoRow('Alamat', member['AlamatIbu']),
            ],
          ],
        ),
      if (member['NamaAyahMertua'] != null || member['NamaIbuMertua'] != null)
        _buildFamilySection(
          title: 'Mertua',
          icon: Icons.family_restroom,
          children: [
            if (member['NamaAyahMertua'] != null) ...[
              Text(
                'Ayah Mertua',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              _buildInfoRow('Nama', member['NamaAyahMertua']),
              _buildInfoRow('Status', member['StatusAyahMertua']),
              _buildInfoRow('Tanggal Lahir', member['TglLahirAyahMertua']),
              _buildInfoRow('Pendidikan', member['PendidikanAyahMertua']),
              _buildInfoRow('No. BPJS', member['NoBpjsAyahMertua']),
              _buildInfoRow('NIK', member['NikAyahMertua']),
              _buildInfoRow('No. KK', member['NoKkAyahMertua']),
              _buildInfoRow('Telepon', member['TeleponAyahMertua']),
              _buildInfoRow('Email', member['EmailAyahMertua']),
              _buildInfoRow('Alamat', member['AlamatAyahMertua']),
              const SizedBox(height: 12),
            ],
            if (member['NamaIbuMertua'] != null) ...[
              Text(
                'Ibu Mertua',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              _buildInfoRow('Nama', member['NamaIbuMertua']),
              _buildInfoRow('Status', member['StatusIbuMertua']),
              _buildInfoRow('Tanggal Lahir', member['TglLahirIbuMertua']),
              _buildInfoRow('Pendidikan', member['PendidikanIbuMertua']),
              _buildInfoRow('No. BPJS', member['NoBpjsIbuMertua']),
              _buildInfoRow('NIK', member['NikIbuMertua']),
              _buildInfoRow('No. KK', member['NoKkIbuMertua']),
              _buildInfoRow('Telepon', member['TeleponIbuMertua']),
              _buildInfoRow('Email', member['EmailIbuMertua']),
              _buildInfoRow('Alamat', member['AlamatIbuMertua']),
            ],
          ],
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        backgroundColor: const Color(0xFF1572E8),
        title: Text(
          'Data Keluarga',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _isLoading = true;
                            _errorMessage = null;
                          });
                          _fetchFamilyData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1572E8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Coba Lagi',
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _familyData.isEmpty
                  ? Center(
                      child: Text(
                        'Belum ada data keluarga',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.black54,
                        ),
                      ),
                    )
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _familyData
                            .expand(
                                (member) => _buildFamilyMemberWidgets(member))
                            .toList(),
                      ),
                    ),
    );
  }
}
