import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:indocement_apk/pages/absensi_lapangan_page.dart';
import 'package:indocement_apk/pages/layanan_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

// Import halaman AbsensiLapanganScreen

class EventMenuPage extends StatefulWidget {
  const EventMenuPage({super.key});

  @override
  State<EventMenuPage> createState() => _EventMenuPageState();
}

class _EventMenuPageState extends State<EventMenuPage> {
  int? _idEmployee;
  List<Map<String, dynamic>> _eventList = [];
  bool _eventLoading = true;
  bool _eventError = false;
  final Map<int, String> _placeNames = {}; // key: index, value: place name
  final Map<int, int> _absenCountByEvent = {}; // key: eventId, value: count (hari ini)
  bool _absenLoading = false;

  @override
  void initState() {
    super.initState();
    _loadIdEmployeeAndEvents();
  }

  Future<void> _loadIdEmployeeAndEvents() async {
    setState(() {
      _eventLoading = true;
      _eventError = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt('idEmployee');
      if (id != null) {
        _idEmployee = id;
        final events = await fetchEvents(_idEmployee!);
        setState(() {
          _eventList = events;
          _eventLoading = false;
        });
        await _loadAbsensiStatus();
      } else {
        setState(() {
          _eventList = [];
          _eventLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _eventError = true;
        _eventLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchEvents(int idEmployee) async {
    final response = await ApiService.get(
      'http://34.50.112.226:5555/api/Event',
      headers: {'accept': 'text/plain'},
    );
    print('Data event dari API: ${response.data}');
    if (response.statusCode == 200) {
      final List<dynamic> data = response.data is String
          ? json.decode(response.data)
          : response.data;
      final now = DateTime.now();
      return data.where((event) {
        final employees = event['Employees'] as List<dynamic>?;
        if (employees == null) return false;

        // Samakan tipe data
        final employeeIds = employees.map((e) => e.toString()).toList();
        if (!employeeIds.contains(idEmployee.toString())) return false;

        // Filter event berdasarkan rentang waktu (tanggal/jam jika tersedia)
        final tglMulai = _parseEventDateTime(event['TanggalMulai']);
        final tglSelesai = _parseEventDateTime(event['TanggalSelesai']);
        if (tglMulai != null && now.isBefore(tglMulai)) return false;
        if (tglSelesai != null && now.isAfter(tglSelesai)) return false;

        return true;
      }).map<Map<String, dynamic>>((event) => {
        'id': event['Id'],
        'nama': event['NamaEvent'],
        'lat': event['Latitude'],
        'long': event['Longitude'],
        'tglMulai': event['TanggalMulai'],
        'tglSelesai': event['TanggalSelesai'],
        'jamMasuk': event['JamMasuk'],
        'jamKeluar': event['JamKeluar'],
        'tglMulaiDt': _parseEventDateTime(event['TanggalMulai']),
        'tglSelesaiDt': _parseEventDateTime(event['TanggalSelesai']),
      }).toList();
    } else {
      throw Exception('Gagal memuat event');
    }
  }

  Future<void> _loadAbsensiStatus() async {
    if (_idEmployee == null) return;
    setState(() {
      _absenLoading = true;
    });
    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Absensi',
        headers: {'accept': 'text/plain'},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data is String
            ? json.decode(response.data)
            : response.data;
        final today = DateTime.now();
        final dateOnly = DateTime(today.year, today.month, today.day);
        final Map<int, int> temp = {};
        for (final absen in data) {
          if (absen['IdEmployee'] != _idEmployee) continue;
          final createdAtStr = absen['CreatedAt']?.toString();
          if (createdAtStr == null) continue;
          final createdAt = DateTime.tryParse(createdAtStr);
          if (createdAt == null) continue;
          final createdDate = DateTime(createdAt.year, createdAt.month, createdAt.day);
          if (createdDate != dateOnly) continue;
          final eventId = absen['EventId'];
          final parsedEventId = eventId is int ? eventId : int.tryParse(eventId.toString());
          if (parsedEventId == null) continue;
          temp[parsedEventId] = (temp[parsedEventId] ?? 0) + 1;
        }
        setState(() {
          _absenCountByEvent
            ..clear()
            ..addAll(temp);
        });
      }
    } catch (_) {
      // Biarkan status kosong jika gagal
    } finally {
      if (mounted) {
        setState(() {
          _absenLoading = false;
        });
      }
    }
  }

  DateTime? _parseEventDateTime(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString();
    final parsed = DateTime.tryParse(str);
    if (parsed != null) return parsed;
    // Fallback: tanggal saja "YYYY-MM-DD"
    final dateOnly = DateTime.tryParse(str.split('T').first);
    return dateOnly;
  }

  // Fungsi untuk dapatkan nama tempat dari lat long
  Future<void> _getPlaceName(double lat, double long, int index) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, long);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        // Tampilkan lokasi lengkap: nama, street, locality, subAdministrativeArea, administrativeArea, country
        final name = [
          place.locality,
          place.subAdministrativeArea,
          place.administrativeArea,
          place.country
        ].where((e) => e != null && e.isNotEmpty).join(', ');
        setState(() {
          _placeNames[index] = name;
        });
      }
    } catch (e) {
      setState(() {
        _placeNames[index] = "-";
      });
    }
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
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1572E8),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LayananMenuPage()),
            );
          },
        ),
        elevation: 0,
        title: null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Text(
                'Event yang tersedia',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1572E8),
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Expanded(
              child: _eventLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _eventError
                      ? const Center(
                          child: Text('Gagal memuat event',
                              style: TextStyle(color: Colors.red)))
                      : _eventList.isEmpty
                          ? const Center(child: Text('Tidak ada event untuk Anda'))
                          : ListView.builder(
                              itemCount: _eventList.length,
                              itemBuilder: (context, index) {
                                final event = _eventList[index];
                                final eventId = event['id'] is int
                                    ? event['id']
                                    : int.tryParse(event['id'].toString()) ?? 0;
                                final absenCount = _absenCountByEvent[eventId] ?? 0;
                                final statusLabel = absenCount == 0
                                    ? 'Belum Absen'
                                    : (absenCount == 1 ? 'Sudah Absen Masuk' : 'Sudah Absen Keluar');
                                final statusColor = absenCount == 0
                                    ? const Color(0xFF9E9E9E)
                                    : (absenCount == 1 ? const Color(0xFF1E88E5) : const Color(0xFF2E7D32));
                                final statusBg = absenCount == 0
                                    ? const Color(0xFFF2F2F2)
                                    : (absenCount == 1 ? const Color(0xFFE3F2FD) : const Color(0xFFE8F5E9));
                                // Ambil nama tempat jika belum ada
                                if (_placeNames[index] == null &&
                                    event['lat'] != null &&
                                    event['long'] != null) {
                                  _getPlaceName(
                                    double.tryParse(event['lat'].toString()) ?? 0.0,
                                    double.tryParse(event['long'].toString()) ?? 0.0,
                                    index,
                                  );
                                }
                                return Card(
                                  elevation: 10,
                                  margin: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  color: const Color(0xFFF9FAFB),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFD1F2EB),
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.all(14),
                                              child: const Icon(Icons.how_to_reg, color: Color(0xFF16A085), size: 36),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    event['nama'] ?? '-',
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 20,
                                                      color: Color(0xFF1572E8),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: statusBg,
                                                          borderRadius: BorderRadius.circular(20),
                                                          border: Border.all(color: statusColor, width: 1),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Container(
                                                              width: 8,
                                                              height: 8,
                                                              decoration: BoxDecoration(
                                                                color: statusColor,
                                                                shape: BoxShape.circle,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              statusLabel,
                                                              style: TextStyle(
                                                                color: statusColor,
                                                                fontWeight: FontWeight.w600,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      if (_absenLoading) ...[
                                                        const SizedBox(width: 10),
                                                        const SizedBox(
                                                          width: 14,
                                                          height: 14,
                                                          child: CircularProgressIndicator(strokeWidth: 2),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 18),
                                        Card(
                                          elevation: 0,
                                          color: const Color(0xFFEAF4FC),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    const Icon(Icons.place, size: 18, color: Color(0xFF1572E8)),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        _placeNames[index] ?? 'Mencari lokasi...',
                                                        style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                        maxLines: 4, // agar lokasi panjang tetap tampil
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month, size: 18, color: Color(0xFFF9A826)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Mulai: ${event['tglMulai']?.substring(0, 10) ?? '-'}',
                                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month, size: 18, color: Color(0xFFF9A826)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Selesai: ${event['tglSelesai']?.substring(0, 10) ?? '-'}',
                                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.schedule, size: 18, color: Color(0xFF5E35B1)),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Jam: ${event['jamMasuk'] ?? '-'} - ${event['jamKeluar'] ?? '-'}',
                                                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF16A085),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(14),
                                              ),
                                              padding: const EdgeInsets.symmetric(vertical: 16),
                                              elevation: 3,
                                            ),
                                            icon: const Icon(Icons.how_to_reg, color: Colors.white),
                                            label: Text(
                                              absenCount >= 2
                                                  ? 'Absensi Selesai'
                                                  : (absenCount == 0 ? 'Absen Masuk' : 'Absen Keluar'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                            onPressed: absenCount >= 2
                                                ? null
                                                : () {
                                              double lat = 0.0;
                                              double long = 0.0;
                                              int eventId = event['id'] is int
                                                  ? event['id']
                                                  : int.tryParse(event['id'].toString()) ?? 0;

                                              // Pastikan lat dan long valid, bisa dari double atau string
                                              if (event['lat'] != null) {
                                                if (event['lat'] is double) {
                                                  lat = event['lat'];
                                                } else if (event['lat'] is String) {
                                                  lat = double.tryParse(event['lat']) ?? 0.0;
                                                }
                                              }
                                              if (event['long'] != null) {
                                                if (event['long'] is double) {
                                                  long = event['long'];
                                                } else if (event['long'] is String) {
                                                  long = double.tryParse(event['long']) ?? 0.0;
                                                }
                                              }

                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => AbsensiLapanganScreen(
                                                    kantorLat: lat,
                                                    kantorLng: long,
                                                    eventId: eventId, // kirim event id ke halaman selanjutnya
                                                    eventMulai: event['tglMulaiDt'] as DateTime?,
                                                    eventSelesai: event['tglSelesaiDt'] as DateTime?,
                                                    eventJamMasuk: event['jamMasuk']?.toString(),
                                                    eventJamKeluar: event['jamKeluar']?.toString(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
