import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:indocement_apk/pages/bpjs_page.dart';
import 'package:indocement_apk/pages/id_card.dart';
import 'package:indocement_apk/pages/layanan_menu.dart';
import 'package:indocement_apk/pages/profile.dart';
import 'package:indocement_apk/pages/hr_menu.dart';
import 'package:indocement_apk/pages/edit_profile.dart';
import 'package:indocement_apk/pages/skkmedic_page.dart';
import 'package:indocement_apk/pages/inbox.dart';
import 'package:indocement_apk/pages/error.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:indocement_apk/service/api_service.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key});

  @override
  _MasterScreenState createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int? _employeeId;
  final Set<String> _processedVerifIds = {};
  Timer? _pollingTimer;
  bool _isFetchingVerifData = false;
  bool _isLoadingDialogVisible = false;
  bool _isInitialLoadComplete = false;

  final List<Widget> _pages = [
    const MasterContent(),
    const InboxPage(),
    const ProfilePage(),
  ];

  Future<bool> _isProfileIncomplete() async {
    final prefs = await SharedPreferences.getInstance();
    final requiredFields = [
      'employeeName',
      'jobTitle',
      'birthDate',
      'gender',
      'education',
      'serviceDate',
      'workLocation',
      'section',
      'telepon',
      'email',
      'livingArea',
    ];
    for (final field in requiredFields) {
      final value = prefs.getString(field);
      print('$field: "$value"');
      if (value == null || value.trim().isEmpty) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _checkAndRequestAllPermissions();
    _loadEmployeeId();
    // Hapus: _checkProfileAndShowModal();
  }

  Future<void> _loadEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _employeeId = prefs.getInt('idEmployee');
    });
    if (_employeeId != null) {
      await _loadProcessedVerifIds(); // Load persisted verification IDs
      _startPolling();
    }
  }

  Future<void> _loadProcessedVerifIds() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds =
        prefs.getStringList('processedVerifIds_$_employeeId') ?? [];
    setState(() {
      _processedVerifIds.addAll(storedIds);
    });
  }

  Future<void> _saveProcessedVerifIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        'processedVerifIds_$_employeeId', _processedVerifIds.toList());
  }

  Future<void> _fetchVerifData() async {
    if (!mounted ||
        _employeeId == null ||
        _isFetchingVerifData ||
        !_isInitialLoadComplete) {
      return;
    }

    setState(() {
      _isFetchingVerifData = true;
    });

    try {
      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/VerifData/requests',
        params: {'employeeId': _employeeId},
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        final approvedRequests =
            data.cast<Map<String, dynamic>>().where((verif) {
          final matches =
              verif['EmployeeId']?.toString() == _employeeId.toString();
          final isApproved = verif['Status']?.toString() == 'Approved';
          final verifId = verif['Id']?.toString();
          return matches &&
              isApproved &&
              verifId != null &&
              !_processedVerifIds.contains(verifId);
        }).toList();

        for (var verif in approvedRequests) {
          final verifId = verif['Id']?.toString();
          final fieldName = verif['FieldName']?.toString();
          if (verifId != null && fieldName != null && mounted) {
            await _showVerificationApprovedModal(fieldName, verifId);
            setState(() {
              _processedVerifIds.add(verifId);
            });
            await _saveProcessedVerifIds();
          }
        }
      }
    } catch (e) {
      print('Error fetching verification data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingVerifData = false;
        });
      }
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (mounted && !_isLoadingDialogVisible && _isInitialLoadComplete) {
        await _fetchVerifData();
      }
    });
  }

  void _closeLoadingDialog() {
    if (!_isLoadingDialogVisible) return;
    if (!mounted) {
      _isLoadingDialogVisible = false;
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
    setState(() {
      _isLoadingDialogVisible = false;
    });
  }

  Future<void> _showVerificationApprovedModal(
      String fieldName, String verifId) async {
    _closeLoadingDialog();

    // Simpan ke SharedPreferences bahwa modal untuk verifId sudah pernah ditampilkan
    final prefs = await SharedPreferences.getInstance();
    final shownIds =
        prefs.getStringList('shownVerifModalIds_$_employeeId') ?? [];
    if (shownIds.contains(verifId)) {
      return; // Sudah pernah, jangan tampilkan lagi
    }

    // Tampilkan modal
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(16.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text(
                  "Perubahan data Anda untuk $fieldName telah disetujui. Silakan cek kembali di halaman Profil.",
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Setelah modal ditutup, simpan verifId ke SharedPreferences
                    final prefs = await SharedPreferences.getInstance();
                    final updatedIds = prefs
                            .getStringList('shownVerifModalIds_$_employeeId') ??
                        [];
                    if (!updatedIds.contains(verifId)) {
                      updatedIds.add(verifId);
                      await prefs.setStringList(
                          'shownVerifModalIds_$_employeeId', updatedIds);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1572E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 24),
                  ),
                  child: const Text(
                    'Tutup',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
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

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      return false;
    }
    // Jangan cek ke API yang butuh token di sini!
    return true;
  }

  void _showLoading(BuildContext context) {
    if (!mounted || _isLoadingDialogVisible) return;

    setState(() {
      _isLoadingDialogVisible = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Memuat halaman...",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Harap tunggu sebentar",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() {
          _isLoadingDialogVisible = false;
        });
      }
    });
  }

  void _onItemTapped(int index) async {
    if (_selectedIndex == index) return;
    final hasNetwork = await _checkNetwork();
    if (!hasNetwork) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const Error404Screen()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
    _animationController.forward().then((_) => _animationController.reverse());
  }

  Future<void> _checkAndRequestAllPermissions() async {
    // Daftar permission yang umum untuk aplikasi HR/employee
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.mediaLibrary,
      Permission.microphone,
      Permission.location,
      Permission.notification,
      Permission.contacts,
      Permission.sms,
      Permission.calendar,
      Permission.sensors,
      Permission.bluetooth,
      Permission.accessMediaLocation,
      Permission.manageExternalStorage,
      Permission.activityRecognition,
      Permission.ignoreBatteryOptimizations,
      Permission.appTrackingTransparency,
      Permission.accessNotificationPolicy,
    ];

    List<Permission> notGranted = [];
    bool anyGranted = false;
    for (final perm in permissions) {
      final status = await perm.status;
      if (status == PermissionStatus.granted) {
        anyGranted = true;
      } else {
        notGranted.add(perm);
      }
    }

    // Jika sudah ada yang diizinkan, jangan tampilkan dialog lagi
    if (anyGranted || notGranted.isEmpty) return;

    // Tampilkan dialog permintaan izin jika semua belum diizinkan
    if (notGranted.isNotEmpty && mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.privacy_tip, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                "Izin Aplikasi Diperlukan",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Agar aplikasi berjalan optimal, mohon aktifkan semua izin yang diperlukan.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text(
                  "Aktifkan Izin",
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1572E8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  // Request semua izin yang belum aktif
                  for (final perm in notGranted) {
                    await perm.request();
                  }
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: const Text("Lewati"),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pollingTimer?.cancel();
    _closeLoadingDialog();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: ScaleTransition(
              scale: _selectedIndex == 0
                  ? Tween<double>(begin: 1.0, end: 1.2).animate(_scaleAnimation)
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(
                    0, _selectedIndex == 0 ? -10 : 0, 0),
                transformAlignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _selectedIndex == 0
                      ? BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    Icons.home,
                    color: _selectedIndex == 0 ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: ScaleTransition(
              scale: _selectedIndex == 1
                  ? Tween<double>(begin: 1.0, end: 1.2).animate(_scaleAnimation)
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(
                    0, _selectedIndex == 1 ? -10 : 0, 0),
                transformAlignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _selectedIndex == 1
                      ? BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    Icons.inbox,
                    color: _selectedIndex == 1 ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            label: 'Inbox',
          ),
          BottomNavigationBarItem(
            icon: ScaleTransition(
              scale: _selectedIndex == 2
                  ? Tween<double>(begin: 1.0, end: 1.2).animate(_scaleAnimation)
                  : const AlwaysStoppedAnimation(1.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                transform: Matrix4.translationValues(
                    0, _selectedIndex == 2 ? -10 : 0, 0),
                transformAlignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: _selectedIndex == 2
                      ? BoxDecoration(
                          color: const Color(0xFF1E88E5),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E88E5).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        )
                      : null,
                  child: Icon(
                    Icons.person,
                    color: _selectedIndex == 2 ? Colors.white : Colors.grey,
                  ),
                ),
              ),
            ),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: const Color(0xFF1E88E5),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w400,
          fontSize: 12,
        ),
        elevation: 8,
        onTap: _onItemTapped,
      ),
    );
  }
}

class MasterContent extends StatefulWidget {
  const MasterContent({super.key});

  @override
  State<MasterContent> createState() => _MasterContentState();
}

class _MasterContentState extends State<MasterContent> {
  String? _urlFoto;
  String? _employeeName;
  String? _jobTitle;
  String? _email;
  String? _telepon;

  bool _isProfileIncompleteFlag = false;

  @override
  void initState() {
    super.initState();
    _requestAllPermissions(); // Tambahkan ini
    _loadProfileData();
    _checkProfileIncompleteFlag();
  }

  Future<void> _requestAllPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.storage,
      Permission.photos,
      Permission.mediaLibrary,
      Permission.location,
      Permission.notification,
      Permission.contacts,
      Permission.sms,
      Permission.calendar,
      Permission.sensors,
      Permission.accessMediaLocation,
      Permission.manageExternalStorage,
      Permission.activityRecognition,
      Permission.appTrackingTransparency,
      Permission.accessNotificationPolicy,
    ];

    for (final perm in permissions) {
      if (await perm.status != PermissionStatus.granted) {
        await perm.request();
      }
    }
  }

  Future<void> _checkProfileIncompleteFlag() async {
    final incomplete = await _isProfileIncomplete();
    if (mounted) {
      setState(() {
        _isProfileIncompleteFlag = incomplete;
      });
    }
  }

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      return false;
    }
    // Jangan cek ke API yang butuh token di sini!
    return true;
  }

  void _showLoading(BuildContext context) {
    final masterScreenState =
        context.findAncestorStateOfType<_MasterScreenState>();
    if (masterScreenState?._isLoadingDialogVisible ?? false) return;

    masterScreenState?.setState(() {
      masterScreenState._isLoadingDialogVisible = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                const Text(
                  "Memuat halaman...",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Harap tunggu sebentar",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        masterScreenState?.setState(() {
          masterScreenState._isLoadingDialogVisible = false;
        });
      }
    });
  }

  void _closeLoadingDialog() {
    final masterScreenState =
        context.findAncestorStateOfType<_MasterScreenState>();
    if (!(masterScreenState?._isLoadingDialogVisible ?? false)) return;
    if (!mounted) {
      masterScreenState?._isLoadingDialogVisible = false;
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
    masterScreenState?.setState(() {
      masterScreenState._isLoadingDialogVisible = false;
    });
  }

  Future<void> _fetchProfilePhoto() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('idEmployee');

      if (employeeId == null || employeeId <= 0) {
        print('Invalid or missing employeeId: $employeeId');
        setState(() {
          _urlFoto = null;
        });
        return;
      }

      _showLoading(context);
      final hasNetwork = await _checkNetwork();
      if (!hasNetwork) {
        _closeLoadingDialog();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Error404Screen()),
        );
        return;
      }

      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/Employees/$employeeId',
        headers: {'Content-Type': 'application/json'},
      );

      _closeLoadingDialog();

      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        setState(() {
          if (data['UrlFoto'] != null && data['UrlFoto'].isNotEmpty) {
            if (data['UrlFoto'].startsWith('/')) {
              _urlFoto = 'http://103.31.235.237:5555${data['UrlFoto']}';
            } else {
              _urlFoto = data['UrlFoto'];
            }
          } else {
            _urlFoto = null;
          }
        });
      } else {
        print('Failed to fetch profile photo: ${response.statusCode}');
        setState(() {
          _urlFoto = null;
        });
      }
    } catch (e) {
      print('Error fetching profile photo: $e');
      _closeLoadingDialog();
      setState(() {
        _urlFoto = null;
      });
    }
  }

  Future<void> _loadProfileData() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final employeeId = prefs.getInt('idEmployee');

      if (employeeId == null || employeeId <= 0) {
        setState(() {
          _employeeName = "Nama Tidak Tersedia";
          _jobTitle = "Departemen Tidak Tersedia";
          _email = "Email Tidak Tersedia";
          _telepon = "Telepon Tidak Tersedia";
        });
        return;
      }

      // Tampilkan loading hanya jika data belum ada
      if (_employeeName == null) {
        _showLoading(context);
      }
      final hasNetwork = await _checkNetwork();
      if (!hasNetwork) {
        _closeLoadingDialog();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Error404Screen()),
        );
        return;
      }

      final response = await ApiService.get(
        'http://103.31.235.237:5555/api/Employees/$employeeId',
        headers: {'Content-Type': 'application/json'},
      );

      _closeLoadingDialog();

      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        setState(() {
          _employeeName = data['EmployeeName'] ?? "Nama Tidak Tersedia";
          _jobTitle = data['JobTitle'] ?? "Departemen Tidak Tersedia";
          _urlFoto = data['UrlFoto'] != null && data['UrlFoto'].isNotEmpty
              ? (data['UrlFoto'].startsWith('/')
                  ? 'http://103.31.235.237:5555${data['UrlFoto']}'
                  : data['UrlFoto'])
              : null;
          _email = data['Email'] ?? "Email Tidak Tersedia";
          _telepon = data['Telepon'] ?? "Telepon Tidak Tersedia";
        });
      } else {
        setState(() {
          _employeeName = "Nama Tidak Tersedia";
          _jobTitle = "Departemen Tidak Tersedia";
          _email = "Email Tidak Tersedia";
          _telepon = "Telepon Tidak Tersedia";
        });
      }
    } catch (e) {
      _closeLoadingDialog();
      setState(() {
        _employeeName = "Nama Tidak Tersedia";
        _jobTitle = "Departemen Tidak Tersedia";
        _email = "Email Tidak Tersedia";
        _telepon = "Telepon Tidak Tersedia";
      });
    } finally {
      if (mounted) {
        final masterScreenState =
            context.findAncestorStateOfType<_MasterScreenState>();
        masterScreenState?.setState(() {
          masterScreenState._isInitialLoadComplete = true;
        });
      }
    }
  }

  Future<bool> _isProfileIncomplete() async {
    final prefs = await SharedPreferences.getInstance();
    final requiredFields = [
      'employeeName',
      'jobTitle',
      'employeeNo',
      'birthDate',
      'gender',
      'education',
      'serviceDate',
      'workLocation',
      'section',
      'telepon',
      'email',
      'livingArea',
    ];
    for (final field in requiredFields) {
      final value = prefs.getString(field);
      print('$field: "$value"');
      if (value == null || value.trim().isEmpty) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Stack(
        children: [
          Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HomeHeader(
                      urlFoto: _urlFoto,
                      onProfileTap: () async {
                        _showLoading(context);
                        final hasNetwork = await _checkNetwork();
                        _closeLoadingDialog(); // <-- pastikan ini selalu dipanggil
                        if (!hasNetwork) {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Error404Screen()),
                          );
                          return;
                        }
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const ProfilePage()),
                        );
                      },
                    ),
                    const BannerCarousel(),
                    Categories(checkNetwork: _checkNetwork),
                    if (_isProfileIncompleteFlag)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        child: Card(
                          color: Colors.orange.shade50,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 16),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.info_outline, color: Colors.orange, size: 36),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Profil Anda belum lengkap.",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        "Silakan lengkapi data profil Anda agar dapat menggunakan semua fitur aplikasi.",
                                        style: TextStyle(fontSize: 13, color: Colors.black54),
                                      ),
                                      const SizedBox(height: 8),
                                      ElevatedButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => const EditProfilePage(
                                                employeeName: '',
                                                jobTitle: '',
                                                employeeId: null,
                                                urlFoto: null,
                                              ),
                                            ),
                                          ).then((_) {
                                            _checkProfileIncompleteFlag();
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1572E8),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 20),
                                        ),
                                        child: const Text(
                                          'Lengkapi Profil',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.white,
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
                      ),
                    const DailyInfo(),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {
                _closeLoadingDialog();
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    final ScrollController scrollController =
                        ScrollController();
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.all(16.0),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.95,
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Scrollbar(
                          controller: scrollController,
                          thumbVisibility: false,
                          thickness: 3,
                          radius: const Radius.circular(10),
                          child: SingleChildScrollView(
                            controller: scrollController,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Frequently Asked Questions (FAQ)',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1572E8),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _buildFAQItem(
                                  icon: Icons.home,
                                  question: 'Apa fungsi halaman Home?',
                                  answer:
                                      'Halaman Home adalah tampilan awal aplikasi yang menyediakan akses cepat ke berbagai fitur utama seperti layanan karyawan, HR Chat, dan lainnya.',
                                ),
                                _buildFAQItem(
                                  icon: Icons.category,
                                  question: 'Apa saja menu yang tersedia?',
                                  answer:
                                      'Menu yang tersedia mencakup BPJS, ID Card, SK Kerja & Medical, Layanan Karyawan, HR Chat, dan lainnya.',
                                ),
                                _buildFAQItem(
                                  icon: Icons.mail,
                                  question: 'Apa fungsi halaman Inbox?',
                                  answer:
                                      'Halaman Inbox menampilkan riwayat aktivitas seperti pengajuan layanan dan pesan dari HR.',
                                ),
                                _buildFAQItem(
                                  icon: Icons.person,
                                  question: 'Apa fungsi halaman Profile?',
                                  answer:
                                      'Halaman Profile menampilkan informasi akun karyawan seperti nama, jabatan, dan kontak.',
                                ),
                                _buildFAQItem(
                                  icon: Icons.help_outline,
                                  question:
                                      'Di mana saya bisa melihat semua FAQ?',
                                  answer:
                                      'Seluruh FAQ dapat diakses melalui halaman Profile, pada bagian FAQ.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      actions: [
                        Center(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 12),
                            ),
                            child: const Text(
                              'Tutup',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.help_outline, color: Colors.white),
              label: const Text(
                "FAQ",
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }
}

class BannerCarousel extends StatefulWidget {
  const BannerCarousel({super.key});

  @override
  _BannerCarouselState createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final List<String> bannerImages = [
    'assets/images/banner1.jpg',
    'assets/images/banner2.jpg',
    'assets/images/banner3.jpg',
  ];

  int _currentIndex = 0;
  late PageController _pageController;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _timer = Timer.periodic(const Duration(seconds: 3), (Timer timer) {
      if (_currentIndex < bannerImages.length - 1) {
        _currentIndex++;
      } else {
        _currentIndex = 0;
      }
      _pageController.animateToPage(
        _currentIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _pageController,
            itemCount: bannerImages.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Image.asset(
                    bannerImages[index],
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            bannerImages.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 6.0,
              width: _currentIndex == index ? 16.0 : 6.0,
              decoration: BoxDecoration(
                color: _currentIndex == index ? Colors.blue : Colors.grey,
                borderRadius: BorderRadius.circular(3.0),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HomeHeader extends StatelessWidget {
  final String? urlFoto;
  final VoidCallback onProfileTap;

  const HomeHeader({super.key, this.urlFoto, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            'assets/images/logo2.png',
            width: 180,
            fit: BoxFit.contain,
          ),
          GestureDetector(
            onTap: onProfileTap,
            child: CircleAvatar(
              radius: 22,
              backgroundImage: urlFoto != null && urlFoto!.isNotEmpty
                  ? NetworkImage(urlFoto!)
                  : const AssetImage('assets/images/profile.png')
                      as ImageProvider,
              backgroundColor: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class Categories extends StatelessWidget {
  final Future<bool> Function() checkNetwork;

  const Categories({super.key, required this.checkNetwork});

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> categories = [
      {"icon": "assets/icons/bpjs.svg", "text": "BPJS"},
      {"icon": "assets/icons/id_card.svg", "text": "ID Card"},
      {"icon": "assets/icons/document.svg", "text": "SK Kerja & Medical"},
      {"icon": "assets/icons/service.svg", "text": "Layanan Karyawan"},
      {"icon": "assets/icons/hr_care.svg", "text": "HR Chat"},
      // Tambahkan satu item kosong agar jadi 6 menu (untuk grid 2x3)
      {"icon": "", "text": ""},
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3, // 3 kolom
          crossAxisSpacing: 24.0,
          mainAxisSpacing: 24.0,
          childAspectRatio: 0.85, // Supaya card lebih proporsional
          children: List.generate(
            categories.length,
            (index) {
              final category = categories[index];
              // Jika item dummy, tampilkan kotak kosong
              if (category["icon"] == "" && category["text"] == "") {
                return const SizedBox.shrink();
              }
              return CategoryCard(
                iconPath: category["icon"]!,
                text: category["text"]!,
                press: () async {
                  final masterScreenState =
                      context.findAncestorStateOfType<_MasterScreenState>();
                  try {
                    masterScreenState?._showLoading(context);
                    final hasNetwork = await checkNetwork();
                    if (!hasNetwork) {
                      masterScreenState?._closeLoadingDialog();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Error404Screen()),
                      );
                      return;
                    }
                    masterScreenState?._closeLoadingDialog();
                    if (category["text"] == "BPJS") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BPJSPage(),
                        ),
                      );
                    } else if (category["text"] == "HR Chat") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HRCareMenuPage(),
                        ),
                      );
                    } else if (category["text"] == "ID Card") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const IdCardUploadPage(),
                        ),
                      );
                    } else if (category["text"] == "SK Kerja & Medical") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SKKMedicPage(),
                        ),
                      );
                    } else if (category["text"] == "Layanan Karyawan") {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LayananMenuPage(),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content:
                              Text('Menu ${category["text"]} belum tersedia'),
                        ),
                      );
                    }
                  } finally {
                    masterScreenState?._closeLoadingDialog();
                  }
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final String text;
  final String iconPath;
  final VoidCallback press;

  const CategoryCard({
    super.key,
    required this.text,
    required this.iconPath,
    required this.press,
  });

  @override
  Widget build(BuildContext context) {
    final double fontSize = 13;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: press,
          child: Container(
            padding: const EdgeInsets.all(10),
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F6F9),
              borderRadius: BorderRadius.circular(15),
            ),
            child: iconPath.isNotEmpty
                ? SvgPicture.asset(
                    iconPath,
                    width: 32,
                    height: 32,
                  )
                : null,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: fontSize),
        ),
      ],
    );
  }
}

class DailyInfo extends StatelessWidget {
  const DailyInfo({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Hapus semua contoh InfoCard di bawah ini
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: const [
                // Tidak ada InfoCard di sini, kosongkan
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String description;

  const InfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: const TextStyle(color: Colors.blueGrey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            description,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    required this.press,
  });

  final String title;
  final GestureTapCallback press;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _buildFAQItem({
  required IconData icon,
  required String question,
  required String answer,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF1572E8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
