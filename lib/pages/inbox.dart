import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'chat.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotif() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}



class InboxPage extends StatefulWidget {
  const InboxPage({super.key});

  @override
  _InboxPageState createState() => _InboxPageState();
}

class _InboxPageState extends State<InboxPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  int? _employeeId;
  String _selectedTab = 'Lihat Semua';
  String? _selectedStatus; // null means no status filter
  final List<String> _tabs = [
    'Lihat Semua',
    'Keluhan',
    'Konsultasi',
    'BPJS',
    'VerifData',
    'SKK',
    'TUKAR_SCHEDULE',
    'IDCARD',
    'MEDICAL',
    'FileAktif',
    'Dispensasi',
  ];
  final List<String> _statusOptions = [
    'Semua Status',
    'Diajukan',
    'Disetujui',
    'Ditolak',
    'DiReturn',
    'Dilihat',
  ];
  bool _hasUnreadNotifications = false;
  List<String> _roomIds = [];
  final Map<String, Map<String, dynamic>> _roomOpponentCache = {};
  DateTime? _lastFetchTime;

  @override
  void initState() {
    super.initState();
    initNotif(); // Tambahkan ini
    _clearLocalData();
    _loadEmployeeId();
  }

  Future<void> _clearLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    final roomId = prefs.getString('roomId');
    if (roomId != null) {
      await prefs.remove('messages_$roomId');
    }
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Tidak ada koneksi internet. Silakan cek jaringan Anda.')),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _loadEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getInt('idEmployee');
      _isLoading = true;
    });
    if (_employeeId != null) {
      await _fetchNotifications();
      await _fetchRooms();
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Employee ID not found. Please log in again.')),
        );
      }
    }
  }

  Future<void> _fetchRooms() async {
    if (_employeeId == null || !mounted) return;
    if (!await _checkNetwork()) return;

    try {
      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/ChatRooms',
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        List<Map<String, dynamic>> rooms = [];
        if (data is List) {
          rooms = data.cast<Map<String, dynamic>>();
        }
        final myEmployeeId = _employeeId.toString();
        final myRooms = rooms.where((room) {
          final konsultasi = room['Konsultasi'];
          return konsultasi != null &&
              (konsultasi['IdEmployee']?.toString() == myEmployeeId ||
                  konsultasi['IdKaryawan']?.toString() == myEmployeeId);
        }).toList();
        setState(() {
          _roomIds = myRooms
              .map((room) => room['Id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
        });
      } else {
        print('Failed to fetch rooms: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching rooms: $e');
    }
  }

  Future<void> _fetchNotifications({bool forceFetch = false}) async {
    if (!mounted || _employeeId == null) return;

    if (!forceFetch &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!).inMinutes < 1) {
      return;
    }

    if (!await _checkNetwork()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/Notifications',
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;

        // --- Tambahan: deteksi notifikasi baru ---
        List<Map<String, dynamic>> newNotifications = (data as List)
            .cast<Map<String, dynamic>>()
            .where((notif) =>
                notif['IdEmployee']?.toString() == _employeeId.toString())
            .toList();

        // Ambil ID notifikasi lama
        final oldIds = _notifications.map((n) => n['Id']).toSet();
        // Cari notifikasi yang benar-benar baru
        final justArrived = newNotifications.where((n) => !oldIds.contains(n['Id'])).toList();

        // Tampilkan notifikasi lokal untuk setiap notifikasi baru
        for (final notif in justArrived) {
          final source = notif['Source']?.toString() ?? 'Notifikasi';
          final status = notif['Status']?.toString() ?? '';
          final title = 'Notifikasi Baru: $source';
          final body = 'Status: $status';
        }
        // --- Akhir tambahan ---

        if (mounted) {
          setState(() {
            _notifications = newNotifications
                .map((notif) {
                  final source = notif['Source']?.toString() ?? 'Unknown';
                  final status = notif['Status']?.toString() == 'Diajukan'
                      ? 'Diajukan'
                      : notif['Status']?.toString() == 'Disetujui'
                          ? 'Disetujui'
                          : notif['Status']?.toString() == 'DiSetujui'
                              ? 'Disetujui'
                              : notif['Status']?.toString() == 'Dilihat'
                                  ? 'Dilihat'
                                  : notif['Status']?.toString() == 'DiReturn'
                                      ? 'DiReturn'
                                      : notif['Status']?.toString() == 'Ditolak'
                                          ? 'Ditolak'
                                          : 'Pending';
                  return {
                    'Id': notif['Id']?.toString() ?? '',
                    'IdSource': notif['IdSource']?.toString() ?? 'N/A',
                    'source': source,
                    'Status': status,
                    'timestamp': notif['UpdatedAt']?.toString() ??
                        notif['CreatedAt']?.toString() ??
                        '',
                    'isRead': source == 'Konsultasi' ? false : true,
                  };
                }).toList()
              ..sort((a, b) => DateTime.parse('${b['timestamp']}')
                  .compareTo(DateTime.parse('${a['timestamp']}')));
            _hasUnreadNotifications = _notifications.any(
                (notif) => notif['source'] == 'Konsultasi' && !notif['isRead']);
            _isLoading = false;
            _lastFetchTime = DateTime.now();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to load notifications: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching notifications: $e')),
        );
      }
    }
  }

  Future<void> _fetchKonsultasiDetails(String roomId) async {
    if (_employeeId == null || !mounted) return;
    if (!await _checkNetwork()) return;

    try {
      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/ChatMessages/room/$roomId?currentUserId=$_employeeId',
        headers: {'Accept': 'application/json'},
      );
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        if (data is Map<String, dynamic> && data['Messages'] is List) {
          final messages = data['Messages'].cast<Map<String, dynamic>>();
          if (mounted) {
            setState(() {
              _notifications = _notifications.map((notif) {
                if (notif['source'] == 'Konsultasi' &&
                    notif['IdSource'] == roomId) {
                  final message = messages.isNotEmpty ? messages.last : null;
                  return {
                    ...notif,
                    'message': message?['Message']?.toString() ?? 'No message',
                    'senderName':
                        message?['Sender']?['EmployeeName']?.toString() ??
                            'HR Tidak Diketahui',
                    'senderId': message?['SenderId']?.toString() ?? '',
                    'isRead': message?['Status'] == 'Dibaca',
                    'Status': message?['Status']?.toString() ?? notif['Status'],
                  };
                }
                return notif;
              }).toList();
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching konsultasi details: $e');
    }
  }

  Future<void> _updateServerStatus(String messageId, String status) async {
    if (!await _checkNetwork()) return;

    try {
      final response = await ApiService.put(
        'http://103.31.235.237:5555/api/ChatMessages/update-status/$messageId',
        data: {'status': status},
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode != 200) {
        print('Failed to update server status: ${response.data}');
      }
    } catch (e) {
      print('Error updating server status: $e');
    }
  }

  Future<void> _navigateToChat(String roomId, String notificationId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('roomId', roomId);
    await _updateServerStatus(notificationId, 'Dibaca');
    if (mounted) {
      setState(() {
        _notifications = _notifications.map((notif) {
          if (notif['Id'] == notificationId) {
            return {...notif, 'isRead': true, 'Status': 'Dibaca'};
          }
          return notif;
        }).toList();
        _hasUnreadNotifications = _notifications.any(
            (notif) => notif['source'] == 'Konsultasi' && !notif['isRead']);
      });
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ChatPage()),
      ).then((_) async {
        await _fetchNotifications();
      });
    }
  }

  String _formatTimestamp(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      return 'Unknown Date';
    }
    try {
      final formatter = DateFormat('dd/MM/yy HH.mm');
      final dateTime = DateTime.parse(timeString).toLocal();
      return formatter.format(dateTime);
    } catch (e) {
      return timeString;
    }
  }

  Future<void> _refreshData() async {
    if (_employeeId == null) return;
    setState(() {
      _isLoading = true;
    });
    await _fetchNotifications(forceFetch: true);
    await _fetchRooms();
  }

  List<Map<String, dynamic>> _getFilteredNotifications(String source) {
    var filtered = _notifications;
    if (source != 'Lihat Semua') {
      filtered = filtered.where((notif) => notif['source'] == source).toList();
    }
    if (_selectedStatus != null && _selectedStatus != 'Semua Status') {
      filtered = filtered
          .where((notif) => notif['Status'] == _selectedStatus)
          .toList();
    }
    return filtered
      ..sort((a, b) => DateTime.parse(b['timestamp'])
          .compareTo(DateTime.parse(a['timestamp'])));
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double paddingValue = screenWidth < 400 ? 16.0 : 20.0;
    final double fontSizeLabel = screenWidth < 400 ? 14.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              "Inbox",
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  color: Colors.white),
            ),
            if (_hasUnreadNotifications)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                    color: Colors.red, shape: BoxShape.circle),
                child: Text(
                  _notifications
                      .where((notif) =>
                          notif['source'] == 'Konsultasi' && !notif['isRead'])
                      .length
                      .toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshData,
            tooltip: 'Refresh Data',
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(paddingValue),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedTab,
                  decoration: InputDecoration(
                    labelText: 'Pilih Kategori',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    labelStyle: GoogleFonts.poppins(fontSize: fontSizeLabel),
                  ),
                  items: _tabs.map((String tab) {
                    return DropdownMenuItem<String>(
                      value: tab,
                      child: Row(
                        children: [
                          Text(
                            tab == 'TUKAR_SCHEDULE'
                                ? 'Tukar Schedule'
                                : tab == 'VerifData'
                                    ? 'Verifikasi Data'
                                    : tab == 'Keluhan'
                                        ? 'Permintaan Karyawan'
                                        : tab == 'IDCARD'
                                            ? 'ID Card'
                                            : tab == 'MEDICAL'
                                                ? 'Medical'
                                                : tab,
                            style: GoogleFonts.poppins(
                                fontSize: fontSizeLabel * 0.9,
                                fontWeight: FontWeight.w500),
                          ),
                          if (tab == 'Konsultasi' && _hasUnreadNotifications)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: Text(
                                _notifications
                                    .where((notif) =>
                                        notif['source'] == 'Konsultasi' &&
                                        !notif['isRead'])
                                    .length
                                    .toString(),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedTab = value;
                        if (value == 'Konsultasi') {
                          _notifications = _notifications.map((notif) {
                            if (notif['source'] == 'Konsultasi') {
                              return {
                                ...notif,
                                'isRead': true,
                                'Status': 'Dibaca'
                              };
                            }
                            return notif;
                          }).toList();
                          _hasUnreadNotifications = false;
                        }
                      });
                    }
                  },
                ),
              ),
            ),
            SizedBox(height: paddingValue),
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedStatus ?? 'Semua Status',
                  decoration: InputDecoration(
                    labelText: 'Pilih Status',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    labelStyle: GoogleFonts.poppins(fontSize: fontSizeLabel),
                  ),
                  items: _statusOptions.map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(
                            fontSize: fontSizeLabel * 0.9,
                            fontWeight: FontWeight.w500),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value;
                    });
                  },
                ),
              ),
            ),
            SizedBox(height: paddingValue),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _getFilteredNotifications(_selectedTab).isEmpty
                      ? Center(
                          child: Text(
                            "Tidak ada notifikasi untuk ${_selectedTab == 'Lihat Semua' ? 'semua kategori' : _selectedTab == 'TUKAR_SCHEDULE' ? 'Tukar Jadwal' : _selectedTab}${_selectedStatus != null && _selectedStatus != 'Semua Status' ? ' dengan status $_selectedStatus' : ''}.",
                            style: GoogleFonts.poppins(
                                fontSize: fontSizeLabel, color: Colors.black87),
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              _getFilteredNotifications(_selectedTab).length,
                          itemBuilder: (context, index) {
                            final notif =
                                _getFilteredNotifications(_selectedTab)[index];
                            final source =
                                notif['source']?.toString() ?? 'Unknown';
                            final timestamp =
                                _formatTimestamp(notif['timestamp'] ?? '');
                            final isKonsultasi = source == 'Konsultasi';
                            final status =
                                notif['Status']?.toString() ?? 'Pending';

                            if (isKonsultasi && notif['message'] == null) {
                              _fetchKonsultasiDetails(notif['IdSource']);
                            }

                            return GestureDetector(
                              onTap: isKonsultasi
                                  ? () => _navigateToChat(
                                      notif['IdSource'], notif['Id'])
                                  : null,
                              child: Card(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                elevation: 3,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                color:
                                    isKonsultasi && !(notif['isRead'] ?? true)
                                        ? Colors.red[50]
                                        : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        source == 'TUKAR_SCHEDULE'
                                            ? 'Tukar Schedule'
                                            : source == 'Keluhan'
                                                ? 'Permintaan Karyawan'
                                                : source == 'VerifData'
                                                    ? 'Verifikasi Data'
                                                    : source,
                                        style: GoogleFonts.poppins(
                                          fontSize: fontSizeLabel,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF1E88E5),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (isKonsultasi) ...[
                                        Text(
                                          "Pesan dari ${notif['senderName'] ?? 'HR Tidak Diketahui'}",
                                          style: GoogleFonts.poppins(
                                              fontSize: fontSizeLabel,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.black87),
                                        ),
                                        Text(
                                          "Pesan: ${notif['message'] ?? 'No message'}",
                                          style: GoogleFonts.poppins(
                                              fontSize: fontSizeLabel - 2,
                                              color: Colors.black87),
                                        ),
                                      ],
                                      Text(
                                        "Status: $status",
                                        style: GoogleFonts.poppins(
                                          fontSize: fontSizeLabel - 2,
                                          color: status == 'Diajukan'
                                              ? Colors.orange
                                              : status == 'Ditolak' ||
                                                      status == 'DiReturn'
                                                  ? Colors.red
                                                  : Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Tanggal: $timestamp",
                                        style: GoogleFonts.poppins(
                                            fontSize: fontSizeLabel - 2,
                                            color: Colors.grey),
                                      ),
                                    ],
                                  ),
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
