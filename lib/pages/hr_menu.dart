import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/bpjs_page.dart';
import 'package:indocement_apk/pages/master.dart';
import 'chat.dart';
import 'form.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HRCareMenuPage extends StatefulWidget {
  const HRCareMenuPage({super.key});

  @override
  State<HRCareMenuPage> createState() => _HRCareMenuPageState();
}

class _HRCareMenuPageState extends State<HRCareMenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAccess(BuildContext context) async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final int? idEmployee = prefs.getInt('idEmployee');

      if (idEmployee == null) {
        throw Exception('ID pengguna tidak ditemukan. Silakan login ulang.');
      }

      final employeeResponse = await http.get(
        Uri.parse('http://34.50.112.226:5555/api/Employees/$idEmployee'),
      );

      if (employeeResponse.statusCode == 200) {
        final employeeData = json.decode(employeeResponse.body);
        final int idEsl = employeeData['IdEsl'];

        if (idEsl >= 1 && idEsl <= 4) {
          _showLoading(context);
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BPJSPage()),
            );
          });
        } else if (idEsl == 5 || idEsl == 6) {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, color: Colors.red, size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      "Akses Belum Diberikan",
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Anda memerlukan izin dari PIC untuk mengakses halaman ini.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text("Tutup",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('IdEsl tidak valid')),
          );
        }
      } else {
        throw Exception('Gagal memuat data Employee dari API');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        final double paddingValue = screenWidth * 0.04; // 4% of screen width
        final double baseFontSize = screenWidth * 0.04; // 4% for font scaling

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MasterScreen()),
                );
              },
            ),
            title: Text(
              "HR Chat",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: baseFontSize * 1.25,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF1572E8),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(paddingValue),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: EdgeInsets.only(bottom: paddingValue),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/banner_hrmenu.png',
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Text(
                      "Selamat datang di HR Chat. Pilih salah satu menu di bawah untuk informasi lebih lanjut.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: baseFontSize * 0.9,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    SizedBox(height: paddingValue * 0.5),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: paddingValue,
                          mainAxisSpacing: paddingValue,
                          childAspectRatio: 1,
                        ),
                        padding: EdgeInsets.zero,
                        itemCount: 2,
                        itemBuilder: (context, index) {
                          final items = [
                            {
                              'icon': Icons.message,
                              'title': 'Konsultasi Dengan HR',
                              'color': Colors.blue,
                              'onTap': () {
                                showModalBottomSheet(
                                  context: context,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                  ),
                                  builder: (context) {
                                    return Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            "Pilih Layanan Konsultasi",
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ListTile(
                                            leading: Icon(Icons.chat, color: Colors.blue),
                                            title: const Text("HR HelpDesk Via Aplikasi"),
                                            onTap: () {
                                              Navigator.pop(context);
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => const ChatPage(), // sama seperti sebelumnya
                                                ),
                                              );
                                            },
                                          ),
                                          ListTile(
                                            leading: Icon(FontAwesomeIcons.whatsapp, color: Colors.green),
                                            title: const Text("HR HelpDesk Via WhatsApp"),
                                            onTap: () async {
                                              Navigator.pop(context);
                                              final waUrl = Uri.parse(
                                                "https://wa.me/628111991110?text=Halo%20HR%20HelpDesk%2C%20saya%20ingin%20konsultasi."
                                              );
                                              try {
                                                bool launched = await launchUrl(
                                                  waUrl,
                                                  mode: LaunchMode.externalApplication,
                                                );
                                                if (!launched) {
                                                  // Fallback ke mode default jika gagal
                                                  await launchUrl(waUrl, mode: LaunchMode.platformDefault);
                                                }
                                              } catch (e) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text("Tidak dapat membuka WhatsApp")),
                                                );
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            },
                            {
                              'icon': Icons.group_add,
                              'title': 'Permintaan Karyawan',
                              'color': Colors.green,
                              'onTap': () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const KeluhanPage(),
                                  ),
                                );
                              },
                            },
                          ];
                          final item = items[index];
                          return _buildMenuItem(
                            context,
                            icon: item['icon'] as IconData,
                            title: item['title'] as String,
                            color: item['color'] as Color,
                            onTap: item['onTap'] as VoidCallback,
                          );
                        },
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 20,
                right: 20,
                child: FloatingActionButton.extended(
                  onPressed: () {
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
                                      icon: Icons.support_agent,
                                      question:
                                          'Apa saja fitur yang tersedia di HR Chat?',
                                      answer:
                                          'Terdapat dua fitur utama di HR Chat: Konsultasi dan Permintaan Karyawan. Masing-masing memiliki fungsi dan alur yang berbeda.',
                                    ),
                                    _buildFAQItem(
                                      icon: Icons.chat_bubble_outline,
                                      question: 'Apa itu fitur Konsultasi?',
                                      answer:
                                          'Fitur Konsultasi memungkinkan Anda melakukan percakapan langsung (real-time) dengan HR melalui chat. Jika HR sudah membalas pesan Anda dan Anda belum membacanya, maka balasan tersebut akan muncul di Inbox Konsultasi sebagai pesan baru.',
                                    ),
                                    _buildFAQItem(
                                      icon: Icons.assignment_outlined,
                                      question:
                                          'Apa itu fitur Permintaan Karyawan?',
                                      answer:
                                          'Fitur ini menyediakan form untuk mengajukan permintaan kepada HR. Silakan isi form sesuai ketentuan yang berlaku. Anda juga dapat mengunggah gambar sebagai pendukung, namun hal ini bersifat opsional.',
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
              SlideTransition(
                position: _slideAnimation,
                child: Align(
                  alignment: Alignment.topRight,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.7,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(20),
                        bottomLeft: Radius.circular(20),
                      ),
                      border: Border.all(
                        color: Colors.black.withOpacity(0.1),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(-4, 0),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                softWrap: true,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
