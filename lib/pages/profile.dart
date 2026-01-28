import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:indocement_apk/pages/edit_profile.dart';
import 'package:indocement_apk/pages/faq.dart';
import 'package:indocement_apk/service/api_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String _employeeName = "";
  String _jobTitle = "";
  String? _urlFoto;
  int? _employeeId;
  String _email = "";
  String _telepon = "";

  @override
  void initState() {
    super.initState();
    print('ProfilePage initState called');
    _loadProfileData();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('ProfilePage didUpdateWidget called');
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final employeeId = prefs.getInt('idEmployee');
    final token = prefs.getString('token');
    print('ProfilePage: employeeId=$employeeId, token=$token');

    if (employeeId == null || employeeId <= 0) {
      // Tampilkan error
      return;
    }

    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees/$employeeId',
        headers: {'Content-Type': 'application/json'},
      );
      print('ProfilePage: response status=${response.statusCode}');
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        print('ProfilePage: employee data keys=${data.keys}');
        setState(() {
          _employeeName = data['EmployeeName']?.isNotEmpty == true
              ? data['EmployeeName']
              : _employeeName;
          _jobTitle = data['JobTitle'] ?? _jobTitle;

          // Tambahkan URL dasar jika UrlFoto adalah path relatif
          if (data['UrlFoto'] != null && data['UrlFoto'].isNotEmpty) {
            if (data['UrlFoto'].startsWith('/')) {
              _urlFoto = 'http://34.50.112.226:5555${data['UrlFoto']}';
            } else {
              _urlFoto = data['UrlFoto'];
            }
          } else {
            _urlFoto = null;
          }

          _email = data['Email'] ?? _email;
          _telepon = data['Telepon'] ?? _telepon;
        });

        // Validasi apakah URL gambar dapat dimuat
        if (_urlFoto != null) {
          final imageResponse = await ApiService.get(_urlFoto!);
          if (imageResponse.statusCode != 200) {
            print('Image URL is invalid or not accessible: $_urlFoto');
            setState(() {
              _urlFoto = null; // Gunakan ikon profil jika URL tidak valid
            });
          }
        }

        await prefs.setString('employeeName', _employeeName);
        await prefs.setString('jobTitle', _jobTitle);
        await prefs.setString('email', _email);
        await prefs.setString('telepon', _telepon);
        if (_urlFoto != null) {
          await prefs.setString('urlFoto', _urlFoto!);
        } else {
          await prefs.remove('urlFoto');
        }

        print('Updated employeeName: $_employeeName');
      } else {
        print('Failed to fetch employee data: ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('Gagal memuat data: ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      print('Error fetching employee data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terjadi kesalahan: $e')),
        );
      }
    }
  }

  Future<void> _saveProfileData(String employeeName, String jobTitle,
      String? urlFoto, int? employeeId) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('employeeName', employeeName);
    await prefs.setString('jobTitle', jobTitle);
    if (urlFoto != null) {
      await prefs.setString('urlFoto', urlFoto);
    } else {
      await prefs.remove('urlFoto');
    }
    if (employeeId != null) {
      await prefs.setInt('idEmployee', employeeId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileImage = _urlFoto != null && _urlFoto!.isNotEmpty
        ? NetworkImage(_urlFoto!)
        : const AssetImage('assets/images/profile.png') as ImageProvider;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Profil Saya",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1572E8),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const SizedBox(height: 24),
              CircleAvatar(
                radius: 50,
                backgroundImage: profileImage,
                backgroundColor: Colors.grey[200],
              ),
              const SizedBox(height: 16),
              Text(
                _employeeName.isNotEmpty
                    ? _employeeName
                    : "Nama Tidak Tersedia",
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _jobTitle.isNotEmpty ? _jobTitle : "Departemen Tidak Tersedia",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _email.isNotEmpty ? _email : "Email Tidak Tersedia",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _telepon.isNotEmpty ? _telepon : "Telepon Tidak Tersedia",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),
              MenuItem(
                icon: 'assets/icons/account.svg',
                title: 'Info Profil',
                onTap: () async {
                  var updatedData = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditProfilePage(
                        employeeName: _employeeName,
                        jobTitle: _jobTitle,
                        urlFoto: _urlFoto,
                        employeeId: _employeeId,
                      ),
                    ),
                  );

                  if (updatedData != null) {
                    setState(() {
                      _employeeName =
                          updatedData['employeeName'] ?? _employeeName;
                      _jobTitle = updatedData['jobTitle'] ?? _jobTitle;
                      _urlFoto = updatedData['urlFoto'];
                      _employeeId = updatedData['employeeId'] ?? _employeeId;
                    });
                    await _saveProfileData(
                        _employeeName, _jobTitle, _urlFoto, _employeeId);
                  }
                },
              ),
              MenuItem(
                icon: 'assets/icons/faq.svg',
                title: 'FAQ',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FAQPage()),
                  );
                },
              ),
              MenuItem(
                icon: 'assets/icons/logout.svg',
                title: 'Logout',
                onTap: () async {
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.clear();
                  print(
                      'After logout - SharedPreferences: ${prefs.getKeys().map((k) => "$k=${prefs.get(k)}").join(", ")}');
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MenuItem extends StatelessWidget {
  final String icon;
  final String title;
  final VoidCallback onTap;

  const MenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: SvgPicture.asset(
          icon,
          width: 24,
        ),
      ),
      title: Text(title),
      onTap: onTap,
      trailing: const Icon(Icons.arrow_forward_ios, color: Colors.black),
    );
  }
}
