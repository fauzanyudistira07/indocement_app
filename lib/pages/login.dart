import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:indocement_apk/pages/register.dart';
import 'package:indocement_apk/pages/forgot.dart';
import 'package:indocement_apk/pages/master.dart';
import 'package:indocement_apk/service/api_service.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  _LoginState createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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

  void _showErrorModal(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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

  Future<bool> _checkNetwork() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) {
      print('No network connectivity');
      return false;
    }
    return true;
  }

  Future<Map<String, dynamic>?> _fetchIdEmployee(String email) async {
    try {
      _showLoading(context);
      final response = await http.get(
        Uri.parse('http://34.50.112.226:5555/api/Employees?email=$email'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      Navigator.pop(context); // Close loading dialog

      print('Fetch idEmployee Status: ${response.statusCode}');
      print('Fetch idEmployee Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is List && data.isNotEmpty) {
          final matchingEmployee = data.firstWhere(
            (employee) =>
                employee['Email']?.toLowerCase() == email.toLowerCase(),
            orElse: () => null,
          );

          if (matchingEmployee != null && matchingEmployee['Id'] != null) {
            print('Matching Employee Data: $matchingEmployee');
            return {
              'idEmployee': matchingEmployee['Id'] as int,
              'employeeName': matchingEmployee['EmployeeName'] ?? '',
              'jobTitle': matchingEmployee['JobTitle'] ?? '',
              'telepon': matchingEmployee['Telepon'] ?? '',
              'email': matchingEmployee['Email'] ?? email,
              'urlFoto': matchingEmployee['UrlFoto'],
              'livingArea': matchingEmployee['LivingArea'] ?? '',
            };
          }
          print('No matching employee found for email: $email');
          return null;
        }
        print('No valid employee data found in response: $data');
        return null;
      }
      print('Failed to fetch idEmployee: ${response.statusCode}');
      return null;
    } catch (e) {
      print('Error fetching idEmployee: $e');
      Navigator.pop(context); // Close loading dialog
      return null;
    }
  }

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text.trim();

    if (email.isEmpty) {
      _showErrorModal('Email harus diisi');
      return;
    }
    if (password.isEmpty) {
      _showErrorModal('Password harus diisi');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final hasNetwork = await _checkNetwork();
      if (!hasNetwork) {
        if (mounted) {
          _showErrorModal(
              'Tidak ada koneksi internet. Silakan cek jaringan Anda.');
        }
        setState(() => _isLoading = false);
        return;
      }

      _showLoading(context);

      final response = await ApiService.post(
        'http://34.50.112.226:5555/api/User/login',
        data: json.encode({
          'email': email,
          'password': password,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      Navigator.pop(context); // Close loading dialog

      print('Sending payload: ${json.encode({
            'email': email,
            'password': password
          })}');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.data}');

      if (response.statusCode == 200) {
        final user = response.data is String
            ? json.decode(response.data)
            : response.data;
        print('Parsed User: $user');

        if (response.statusCode == 200) {
          final token = user['Token'] ?? user['token'];
          // Simpan token
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('token', token);
          print('SAVED token: $token');
        }



        if (user is Map<String, dynamic> && user['Id'] != null) {
          // Check account status
          final String status = user['Status'] ?? 'Aktif';
          if (status.toLowerCase() == 'nonaktif') {
            if (mounted) {
              _showErrorModal(
                  'Akun Anda sudah tidak aktif lagi. Silakan hubungi admin.');
            }
            setState(() => _isLoading = false);
            return;
          }

          final String role = user['Role'] ?? '';
          if (role.toLowerCase() != 'karyawan') {
            if (mounted) {
              _showErrorModal(
                  'Akses ditolak. Hanya pengguna dengan role Karyawan yang dapat login.');
            }
            setState(() => _isLoading = false);
            return;
          }

          final employeeData = await _fetchIdEmployee(email) ?? {};

          if (employeeData.isEmpty && user['IdEmployee'] == null) {
            if (mounted) {
              _showErrorModal(
                  'Gagal mengambil data karyawan. Silakan coba lagi.');
            }
            setState(() => _isLoading = false);
            return;
          }

          SharedPreferences prefs = await SharedPreferences.getInstance();
          // Remove specific keys to avoid stale data
          await prefs.remove('id');
          await prefs.remove('idEmployee');
          await prefs.remove('email');
          await prefs.remove('employeeName');
          await prefs.remove('jobTitle');
          await prefs.remove('telepon');
          await prefs.remove('urlFoto');
          await prefs.remove('livingArea');
          await prefs.remove('employeeNo');
          await prefs.remove('section'); // Hapus key lama yang bertipe int
          await prefs.setString('section', employeeData['SectionName'] ?? user['SectionName'] ?? ''); // Simpan nama section (string)

          final int idEmployee =
              employeeData['idEmployee'] ?? user['IdEmployee'] ?? 0;
          final int section = employeeData['section'] ??
              user['section'] ??
              0; // Tambahkan baris ini

          if (idEmployee <= 0) {
            if (mounted) {
              _showErrorModal(
                  'ID karyawan tidak valid. Silakan hubungi admin.');
            }
            setState(() => _isLoading = false);
            return;
          }

          // Simpan ke SharedPreferences
          await prefs.setInt('id', user['Id'] as int);
          await prefs.setInt('idEmployee', idEmployee);
          await prefs.setInt('idSection', employeeData['IdSection'] ?? user['IdSection'] ?? 0); // Simpan IdSection (integer)
          await prefs.setString('employeeName', user['EmployeeName'] ?? '');
          await prefs.setString('jobTitle', user['Role'] ?? '');
          await prefs.setString('telepon', user['Telepon'] ?? '');
          await prefs.setString('email', user['Email'] ?? email);

          if (employeeData['urlFoto'] != null) {
            await prefs.setString('urlFoto', employeeData['urlFoto']);
          }

          final savedEmployeeName = prefs.getString('employeeName');
          print('Saved employeeName: $savedEmployeeName');
          print(
              'Saved to SharedPreferences: ${prefs.getKeys().map((k) => "$k=${prefs.get(k)}").join(", ")}');

          if (savedEmployeeName == null || savedEmployeeName.isEmpty) {
            if (mounted) {
              _showErrorModal(
                  'Nama karyawan tidak tersedia. Silakan hubungi admin.');
            }
          }

          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MasterScreen()),
              (route) => false,
            );
          }
        } else {
          if (mounted) {
            _showErrorModal('Akun tidak valid');
          }
        }
      } else {
        String errorMessage = 'Akun tidak valid';
        try {
          final responseBody = response.data is String
              ? json.decode(response.data)
              : response.data;
          errorMessage = responseBody['message'] ?? errorMessage;
        } catch (e) {
          errorMessage =
              response.data != null && response.data.toString().isNotEmpty
                  ? response.data.toString()
                  : errorMessage;
        }
        if (mounted) {
          _showErrorModal(errorMessage);
        }
      }
    } catch (e) {
      print('Error: $e');
      Navigator.pop(context); // Close loading dialog
      if (mounted) {
        _showErrorModal('Terjadi kesalahan. Silakan coba lagi.');
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Exit the app when back button is pressed
        exit(0);
        return false;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: Stack(
          children: [
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 100),
                    FadeInDown(
                      duration: const Duration(milliseconds: 800),
                      child: Center(
                        child: Image.asset(
                          'assets/images/logo2.png',
                          width: 200,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeInLeft(
                      duration: const Duration(milliseconds: 800),
                      child: Text(
                        'Login',
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1A2035),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _buildField('Email', 900, controller: _emailController),
                    _buildField('Password', 1100,
                        obscure: true, controller: _passwordController),
                    const SizedBox(height: 30),
                    FadeInLeft(
                      duration: const Duration(milliseconds: 1200),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot your password?',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF1A2035),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    FadeInUp(
                      duration: const Duration(milliseconds: 1300),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            backgroundColor: const Color(0xFF1572E8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white)
                              : Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    FadeInUp(
                      duration: const Duration(milliseconds: 1400),
                      child: Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const Register(),
                              ),
                            );
                          },
                          child: RichText(
                            text: TextSpan(
                              style: GoogleFonts.poppins(
                                color: Colors.black,
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(text: 'Belum punya akun? '),
                                TextSpan(
                                  text: 'Register',
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: WavePainter(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String hint, int duration,
      {bool obscure = false, required TextEditingController controller}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: FadeInLeft(
        duration: Duration(milliseconds: duration),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.grey)),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscure ? _obscurePassword : false,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              hintStyle: GoogleFonts.poppins(),
              suffixIcon: obscure
                  ? IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    )
                  : null,
            ),
            style: GoogleFonts.poppins(),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..style = PaintingStyle.fill;

    Path path = Path();
    Paint gradientPaint = Paint()
      ..shader = LinearGradient(
        colors: const [Color(0xFF0E5AB7), Color(0xFF1572E8), Color(0xFF5A9DF3)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.15));

    path.moveTo(0, size.height * 0.15);
    path.quadraticBezierTo(size.width * 0.25, size.height * 0.05,
        size.width * 0.5, size.height * 0.1);
    path.quadraticBezierTo(
        size.width * 0.75, size.height * 0.15, size.width, size.height * 0.1);
    path.lineTo(size.width, 0);
    path.lineTo(0, 0);
    path.close();

    canvas.drawPath(path, gradientPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
