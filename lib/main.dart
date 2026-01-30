import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:indocement_apk/utils/constants.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/master.dart';
import 'package:indocement_apk/pages/login.dart';
import 'package:indocement_apk/pages/register.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indocement_apk/pages/error.dart';

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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final idEmployee = prefs.getInt('idEmployee');
    final isLoggedIn = token != null && token.trim().isNotEmpty;

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
