import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:indocement_apk/pages/layanan_menu.dart' show LayananMenuPage;
import 'package:indocement_apk/service/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class InternalRecruitmentPage extends StatefulWidget {
  const InternalRecruitmentPage({super.key});

  @override
  State<InternalRecruitmentPage> createState() => _InternalRecruitmentPageState();
}

class _InternalRecruitmentPageState extends State<InternalRecruitmentPage> {
  List<dynamic> _lowongan = [];
  bool _isLoading = false;
  String? _pengumuman;
  String? _jadwalWawancara;
  int? _idEmployee;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final prefs = await SharedPreferences.getInstance();
    final idEmployee = prefs.getInt('idEmployee');
    setState(() {
      _idEmployee = idEmployee;
    });
    if (idEmployee != null) {
      await _fetchLowongan();
      await _fetchPengumuman();
      await _fetchJadwalWawancara();
    }
  }

  Future<void> _fetchLowongan() async {
    setState(() => _isLoading = true);
    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Recruitment/lowongan',
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        setState(() {
          final now = DateTime.now();
          final allLowongan = response.data is String ? json.decode(response.data) : response.data;
          _lowongan = allLowongan.where((l) {
            final tglSelesai = l['TanggalSelesai'];
            if (tglSelesai == null) return false;
            try {
              final selesai = DateTime.parse(tglSelesai);
              // Tampilkan jika tanggal selesai >= hari ini (tanpa jam)
              return selesai.isAfter(DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)));
            } catch (_) {
              return false;
            }
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal memuat lowongan')),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat lowongan: $e')),
      );
    }
  }

  // Tambahkan fungsi untuk menampilkan loading modern
  void _showLoading(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF1976D2),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 18),
                const Text(
                  "Mengirim Pendaftaran...",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Mohon tunggu sebentar",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Tambahkan fungsi untuk modal sukses
  void _showSuccessModal(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF1976D2), size: 60),
                const SizedBox(height: 18),
                const Text(
                  "Pendaftaran Berhasil!",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Data pendaftaran Anda sudah terkirim.\nSilakan tunggu proses seleksi berikutnya.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushReplacementNamed('/master');
                    },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    label: const Text('Kembali ke Beranda', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 0,
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

  Future<void> _daftarLowongan(Map<String, dynamic> formData) async {
    _showLoading(context);
    final prefs = await SharedPreferences.getInstance();
    final idEmployee = prefs.getInt('idEmployee');
    if (idEmployee == null) {
      Navigator.pop(context); // Tutup loading
      return;
    }

    final l = formData['Lowongan'];
    try {
      // Cek apakah ada file surat izin
      MultipartFile? suratIzinFile;
      if (formData['SuratIzinAtasan'] != null && formData['SuratIzinAtasan'].toString().isNotEmpty) {
        suratIzinFile = await MultipartFile.fromFile(
          formData['SuratIzinAtasan'],
          filename: formData['SuratIzinAtasan'].split('/').last,
        );
      }

      final formDataToSend = FormData.fromMap({
        "IdLowongan": l['Id'],
        "IdEmployee": idEmployee,
        "NamaLengkap": formData['NamaLengkap'],
        "PlantAsal": formData['PlantAsal'],
        "DivisiAsal": formData['DivisiAsal'],
        "AlasanPindah": formData['AlasanPindah'],
        "TanggalDaftar": formData['TanggalDaftar'],
        if (suratIzinFile != null) "SuratIjinAtasan": suratIzinFile,
      });

      final response = await ApiService.post(
        'http://34.50.112.226:5555/api/Recruitment/upload',
        data: formDataToSend,
        headers: {
          'accept': '*/*',
          // Jangan set Content-Type, biarkan Dio mengatur multipart otomatis!
        },
      );
      Navigator.pop(context); // Tutup loading
      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSuccessModal(context);
        _fetchPengumuman();
        _fetchJadwalWawancara();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal daftar: ${response.data}')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal daftar: $e')),
      );
    }
  }

  Future<void> _fetchPengumuman() async {
    final prefs = await SharedPreferences.getInstance();
    final idEmployee = prefs.getInt('idEmployee');
    if (idEmployee == null) return;

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Recruitment/pengumuman-seleksi',
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = response.data is String ? json.decode(response.data) : response.data;
        setState(() {
          if (decoded is List && decoded.isNotEmpty) {
            final pengumumanUser = decoded.firstWhere(
              (item) =>
                  item['FormPendaftaran'] != null &&
                  item['FormPendaftaran']['IdEmployee'] == idEmployee,
              orElse: () => null,
            );
            if (pengumumanUser != null) {
              _pengumuman =
                  "Status: ${pengumumanUser['StatusLolos'] ?? '-'}\n"
                  "Catatan: ${pengumumanUser['Catatan'] ?? '-'}\n"
                  "Tanggal: ${pengumumanUser['TanggalPengumuman'] ?? '-'}";
            } else {
              _pengumuman = null;
            }
          } else {
            _pengumuman = null;
          }
        });
      }
    } catch (e) {
      // Optional: tampilkan error jika perlu
    }
  }

  Future<void> _fetchJadwalWawancara() async {
    final prefs = await SharedPreferences.getInstance();
    final idEmployee = prefs.getInt('idEmployee');
    if (idEmployee == null) return;

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Recruitment/jadwal-wawancara',
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final decoded = response.data is String ? json.decode(response.data) : response.data;
        setState(() {
          if (decoded is List && decoded.isNotEmpty) {
            final jadwalUser = decoded.firstWhere(
              (item) =>
                  item['FormPendaftaran'] != null &&
                  item['FormPendaftaran']['IdEmployee'] == idEmployee,
              orElse: () => null,
            );
            if (jadwalUser != null) {
              _jadwalWawancara =
                  "Tanggal: ${jadwalUser['TanggalWawancara'] ?? '-'}\n"
                  "Lokasi: ${jadwalUser['Lokasi'] ?? '-'}\n"
                  "User Wawancara: ${jadwalUser['UserWawancara'] ?? '-'}";
            } else {
              _jadwalWawancara = null;
            }
          } else {
            _jadwalWawancara = null;
          }
        });
      }
    } catch (e) {
      // Optional: tampilkan error jika perlu
    }
  }

  Future<void> _simpanIdEmployee(int idEmployee) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('idEmployee', idEmployee);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LayananMenuPage()),
        );
        return false; // cegah pop default
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1976D2),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LayananMenuPage()),
              );
            },
          ),
          title: const Text(
            'Internal Recruitment',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
          elevation: 2,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Card Lowongan - dengan icon dan warna biru
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFFE3F2FD),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.work_outline, color: Color(0xFF1976D2), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Lowongan Tersedia',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF1976D2)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 1.5, color: Color(0xFF1976D2)), // Batas visual antara judul card dan daftar lowongan
                      const SizedBox(height: 12),
                      _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _lowongan.isEmpty
                              ? const Text('Tidak ada lowongan tersedia.', style: TextStyle(color: Colors.black54))
                              : ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _lowongan.length,
                                  separatorBuilder: (_, __) => const Divider(),
                                  itemBuilder: (context, i) {
                                    final l = _lowongan[i];
                                    return RecruitmentDropdownForm(
                                      lowongan: l,
                                      onSubmit: (formData) => _daftarLowongan(formData),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Card Pengumuman Seleksi - layout modern mirip Lowongan Tersedia
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFFE8F5E9),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.announcement_outlined, color: Color(0xFF388E3C), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Pengumuman Seleksi',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFF388E3C)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 1.5, color: Color(0xFF388E3C)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFF388E3C), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.info_outline, color: Color(0xFF388E3C), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _pengumuman != null
                                ? _pengumumanWidget(_pengumuman!)
                                : const Text(
                                    'Belum ada pengumuman seleksi.',
                                    style: TextStyle(fontSize: 16, color: Color(0xFF388E3C)),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              // Card Jadwal Wawancara - layout modern mirip Lowongan Tersedia
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                color: const Color(0xFFFFF3E0),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.schedule, color: Color(0xFFF57C00), size: 28),
                          SizedBox(width: 10),
                          Text(
                            'Jadwal Wawancara',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19, color: Color(0xFFF57C00)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(thickness: 1.5, color: Color(0xFFF57C00)),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Color(0xFFF57C00), width: 1),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.event_available, color: Color(0xFFF57C00), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _jadwalWawancara != null
                                ? _jadwalWawancaraWidget(_jadwalWawancara!)
                                : const Text(
                                    'Belum ada jadwal wawancara.',
                                    style: TextStyle(fontSize: 16, color: Color(0xFFF57C00)),
                                  ),
                            ),
                          ],
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

  // Tambahkan fungsi widget modern untuk jadwal wawancara
  Widget _jadwalWawancaraWidget(String jadwal) {
    // Contoh parsing jadwal: "Tanggal: 2025-07-16T09:00:00\nLokasi: Ruang HR\nUser Wawancara: Budi"
    final lines = jadwal.split('\n');
    String tanggal = '-';
    String jam = '-';
    String lokasi = '-';
    String user = '-';

    for (var line in lines) {
      if (line.startsWith('Tanggal:')) {
        final value = line.replaceFirst('Tanggal:', '').trim();
        try {
          final dt = DateTime.parse(value);
          tanggal = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
          jam = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } catch (_) {
          tanggal = value;
        }
      }
      if (line.startsWith('Lokasi:')) {
        lokasi = line.replaceFirst('Lokasi:', '').trim();
      }
      if (line.startsWith('User Wawancara:')) {
        user = line.replaceFirst('User Wawancara:', '').trim();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            Text('Tanggal: $tanggal', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            Text('Jam: $jam', style: const TextStyle(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            Text('Lokasi: $lokasi', style: const TextStyle(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: Color(0xFFF57C00)),
            const SizedBox(width: 6),
            Text('User Wawancara: $user', style: const TextStyle(fontSize: 15)),
          ],
        ),
      ],
    );
  }

  // Tambahkan fungsi widget modern untuk pengumuman seleksi
  Widget _pengumumanWidget(String pengumuman) {
    // Contoh parsing: "Status: Lolos\nCatatan: Selamat!\nTanggal: 2025-07-16T05:06:36.639Z"
    final lines = pengumuman.split('\n');
    String status = '-';
    String catatan = '-';
    String tanggal = '-';

    for (var line in lines) {
      if (line.startsWith('Status:')) {
        status = line.replaceFirst('Status:', '').trim();
      }
      if (line.startsWith('Catatan:')) {
        catatan = line.replaceFirst('Catatan:', '').trim();
      }
      if (line.startsWith('Tanggal:')) {
        final value = line.replaceFirst('Tanggal:', '').trim();
        try {
          final dt = DateTime.parse(value);
          tanggal = '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
        } catch (_) {
          tanggal = value;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified, size: 18, color: Color(0xFF388E3C)),
            const SizedBox(width: 6),
            Text('Status: $status', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.note_alt, size: 18, color: Color(0xFF388E3C)),
            const SizedBox(width: 6),
            Text('Catatan: $catatan', style: const TextStyle(fontSize: 15)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF388E3C)),
            const SizedBox(width: 6),
            Text('Tanggal: $tanggal', style: const TextStyle(fontSize: 15)),
          ],
        ),
      ],
    );
  }
}

// Tambahkan widget RecruitmentDropdownForm di bawah kelas utama
class RecruitmentDropdownForm extends StatefulWidget {
  final Map lowongan;
  final Function(Map<String, dynamic>) onSubmit;

  const RecruitmentDropdownForm({
    super.key,
    required this.lowongan,
    required this.onSubmit,
  });

  @override
  State<RecruitmentDropdownForm> createState() => _RecruitmentDropdownFormState();
}

class _RecruitmentDropdownFormState extends State<RecruitmentDropdownForm> {
  bool _expanded = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController namaController = TextEditingController();
  final TextEditingController plantController = TextEditingController();
  final TextEditingController divisiController = TextEditingController();
  final TextEditingController alasanController = TextEditingController();
  String? suratIzinPath;
  DateTime tanggalDaftar = DateTime.now();

  @override
  void dispose() {
    namaController.dispose();
    plantController.dispose();
    divisiController.dispose();
    alasanController.dispose();
    super.dispose();
  }

  Future<void> _pickSuratIzin() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        suratIzinPath = picked.path;
      });
    }
  }

  String _formatTanggal(String? tanggal) {
    if (tanggal == null || tanggal.isEmpty) return '-';
    try {
      final dt = DateTime.parse(tanggal);
      return '${dt.day.toString().padLeft(2, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
    } catch (_) {
      return tanggal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.lowongan;
    return ExpansionTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.work, color: Color(0xFF1976D2), size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l['Judul'] ?? '-',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF1976D2),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l['Deskripsi'] ?? '-',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Chip(
                label: Text('PlantDiv: ${l['PlantDiv'] ?? '-'}'),
                backgroundColor: Colors.blue[100],
                labelStyle: const TextStyle(fontSize: 12),
              ),
              Chip(
                label: Text('Kriteria: ${l['Kriteria'] ?? '-'}'),
                backgroundColor: Colors.orange[100],
                labelStyle: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Tanggal mulai dan selesai atas bawah
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              const Text('Mulai:', style: TextStyle(fontSize: 13)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              _formatTanggal(l['TanggalMulai']),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.visible,
            ),
          ),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              const Text('Selesai:', style: TextStyle(fontSize: 13)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Text(
              _formatTanggal(l['TanggalSelesai']),
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.visible,
            ),
          ),
        ],
      ),
      initiallyExpanded: _expanded,
      onExpansionChanged: (val) => setState(() => _expanded = val),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: namaController,
                  decoration: const InputDecoration(labelText: 'Nama Lengkap', prefixIcon: Icon(Icons.person)),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: plantController,
                  decoration: const InputDecoration(labelText: 'Plant Asal', prefixIcon: Icon(Icons.factory)),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: divisiController,
                  decoration: const InputDecoration(labelText: 'Divisi Asal', prefixIcon: Icon(Icons.apartment)),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: alasanController,
                  decoration: const InputDecoration(labelText: 'Alasan Pindah', prefixIcon: Icon(Icons.question_answer)),
                  validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickSuratIzin,
                      icon: const Icon(Icons.upload_file, color: Colors.white),
                      label: const Text('Upload Surat Izin Atasan', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        elevation: 2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (suratIzinPath != null)
                      Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.green, size: 22),
                          const SizedBox(width: 6),
                          Text(
                            'File terupload',
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    if (suratIzinPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.insert_drive_file, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                suratIzinPath!.split('/').last, // hanya nama file
                                style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                              tooltip: 'Hapus file',
                              onPressed: () {
                                setState(() {
                                  suratIzinPath = null;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18, color: Colors.blueGrey),
                    const SizedBox(width: 8),
                    Text(
                      'Tanggal Daftar: ${tanggalDaftar.day.toString().padLeft(2, '0')}-${tanggalDaftar.month.toString().padLeft(2, '0')}-${tanggalDaftar.year}',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false && suratIzinPath != null) {
                        widget.onSubmit({
                          'NamaLengkap': namaController.text,
                          'PlantAsal': plantController.text,
                          'DivisiAsal': divisiController.text,
                          'AlasanPindah': alasanController.text,
                          'SuratIzinAtasan': suratIzinPath,
                          'TanggalDaftar': tanggalDaftar.toIso8601String(),
                          'Lowongan': {
                            'Id': l['Id'],
                            'Judul': l['Judul'],
                            'Deskripsi': l['Deskripsi'],
                            'PlantDiv': l['PlantDiv'],
                            'Kriteria': l['Kriteria'],
                            'TanggalMulai': l['TanggalMulai'],
                            'TanggalSelesai': l['TanggalSelesai'],
                          }
                        });
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Semua field dan surat izin wajib diisi!')),
                        );
                      }
                    },
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: const Text('Kirim Pendaftaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Divider(thickness: 1.2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}