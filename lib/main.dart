import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:indocement_apk/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/master.dart';
import 'package:indocement_apk/pages/login.dart';
import 'package:indocement_apk/pages/register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:indocement_apk/pages/error.dart';
import 'package:indocement_apk/service/api_service.dart';
import 'dart:convert';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(375, 812),
      builder: (context, child) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: "Indocement_Apk",
        theme: ThemeData(
          scaffoldBackgroundColor: Constants.scaffoldBackgroundColor,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          // Atur font Poppins untuk semua teks
          textTheme: GoogleFonts.poppinsTextTheme(),
          // Pastikan TextField (input) menggunakan Poppins
          inputDecorationTheme: InputDecorationTheme(
            labelStyle: GoogleFonts.poppins(),
            hintStyle: GoogleFonts.poppins(),
            errorStyle: GoogleFonts.poppins(),
          ),
          // Pastikan tombol menggunakan Poppins
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              textStyle: GoogleFonts.poppins(),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              textStyle: GoogleFonts.poppins(),
            ),
          ),
        ),
        home: const SplashScreen(),
        onGenerateRoute: _onGenerateRoute,
        routes: {
          '/error404': (context) => Error404Screen(),
          // ...route lain...
        },
      ),
    );
  }
}

Route<dynamic> _onGenerateRoute(RouteSettings settings) {
  switch (settings.name) {
    case "/master":
      return MaterialPageRoute(builder: (BuildContext context) {
        return const MasterScreen();
      });
    case "/login":
      return MaterialPageRoute(builder: (BuildContext context) {
        return const Login();
      });
    case "/register":
      return MaterialPageRoute(builder: (BuildContext context) {
        return const Register();
      });
    default:
      return MaterialPageRoute(builder: (BuildContext context) {
        return const Login(); // Default ke Login untuk keamanan
      });
  }
}

// Tambahkan di atas _SplashScreenState
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> initNotif(BuildContext context) async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      Navigator.of(context).pushNamedAndRemoveUntil('/master', (route) => false);
    },
  );
}

Future<void> showNotif(String title, String body) async {
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
    'inbox_channel_id',
    'Inbox Notifications',
    channelDescription: 'Notifikasi untuk pesan Inbox',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformChannelSpecifics =
      NotificationDetails(android: androidPlatformChannelSpecifics);
  await flutterLocalNotificationsPlugin.show(
    0,
    title,
    body,
    platformChannelSpecifics,
    payload: 'inbox',
  );
}
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  Timer? _notifTimer;
  Set<String> _shownNotifIds = {};

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOut,
      ),
    );

    _fadeController.forward().then((_) {
      _scaleController.forward().then((_) {
        Future.delayed(const Duration(seconds: 1), () {
          _checkLoginStatus();
        });
      });
    });
    initNotif(context);
    _startNotifPolling();
  }

  void _startNotifPolling() async {
    final prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getInt('idEmployee');
    if (employeeId == null) return;
    _shownNotifIds = (prefs.getStringList('shownNotifIds') ?? []).toSet();

    _notifTimer = Timer.periodic(const Duration(minutes: 1), (_) async {
      try {
        final response = await ApiService.get(
          'http://103.31.235.237:5555/api/Notifications',
          headers: {'Accept': 'application/json'},
        );
        if (response.statusCode == 200) {
          final data = response.data is String ? jsonDecode(response.data) : response.data;
          final List<Map<String, dynamic>> notifications = (data as List)
              .cast<Map<String, dynamic>>()
              .where((notif) => notif['IdEmployee']?.toString() == employeeId.toString())
              .toList();

          // Cek notifikasi baru yang belum pernah ditampilkan (semua source)
          final allIds = notifications.map((n) => n['Id'].toString()).toSet();
          final newIds = allIds.difference(_shownNotifIds);

          if (newIds.isNotEmpty) {
            for (final notif in notifications) {
              final id = notif['Id']?.toString();
              if (id == null || !newIds.contains(id)) continue;
              final title = notif['Source']?.toString() ?? 'Notifikasi';
              final status = notif['Status']?.toString() ?? '-';
              final message = (notif['Message'] ?? notif['Keterangan'] ?? notif['Title'] ?? '').toString();
              final body = message.isNotEmpty ? '$status - $message' : 'Status: $status';
              await showNotif(title, body);
              _shownNotifIds.add(id);
            }
            await prefs.setStringList('shownNotifIds', _shownNotifIds.toList());
          }
        }
      } catch (e) {
        // Optional: print('Polling notif error: $e');
      }
    });
  }

  @override
  void dispose() {
    _notifTimer?.cancel();
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getInt('idEmployee') != null;

    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/master');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Constants.scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/images/logo_animasi.png',
              width: 200.w,
              height: 200.h,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
