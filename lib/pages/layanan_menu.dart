import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:indocement_apk/pages/absensi_page.dart';
import 'package:indocement_apk/pages/beasiswa.dart';
import 'package:indocement_apk/pages/master.dart';
import 'package:indocement_apk/pages/schedule_shift.dart';
import 'package:indocement_apk/pages/dispensasi_page.dart';
import 'package:indocement_apk/pages/uang_duka_page.dart';
import 'package:indocement_apk/pages/internal_recruitment.dart';
import 'package:indocement_apk/pages/masa_kerja.dart';
import 'package:indocement_apk/pages/file_aktif_page.dart';

class LayananMenuPage extends StatefulWidget {
  const LayananMenuPage({super.key});

  @override
  State<LayananMenuPage> createState() => _LayananMenuPageState();
}

class _LayananMenuPageState extends State<LayananMenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  late List<Map<String, dynamic>> _menuItems;

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

    _menuItems = [
      {
        'icon': Icons.monetization_on,
        'title': 'Uang Duka',
        'color': Colors.blue,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const UangDukaPage()),
          );
        },
      },
      {
        'icon': Icons.schedule,
        'title': 'Schedule Shift',
        'color': Colors.orange,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ScheduleShiftPage()),
          );
        },
      },
      {
        'icon': Icons.fingerprint,
        'title': 'Absensi',
        'color': Colors.purple,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EventMenuPage()),
          );
        },
      },
      {
        'icon': Icons.account_balance_wallet,
        'title': 'Dispensasi/Kompensasi',
        'color': Colors.teal,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DispensasiPage()),
          );
        },
      },
      {
        'icon': Icons.folder,
        'title': 'File Aktif',
        'color': Colors.blueGrey,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const FileAktifPage()),
          );
        },
      },
      {
        'icon': Icons.school,
        'title': 'Beasiswa',
        'color': Colors.red,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BeasiswaPage()),
          );
        } 
      },
      {
        'icon': Icons.star,
        'title': 'Penghargaan Masa Kerja',
        'color': Colors.amber,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MasaKerjaPage()),
          );
        },
      },
      {
        'icon': Icons.group,
        'title': 'Internal Recruitment',
        'color': Colors.indigo,
        'onTap': () {
        
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const InternalRecruitmentPage()),
          );
        },
      },
    ];
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateToFeature(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Menu $feature belum tersedia')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;
        final double screenHeight = constraints.maxHeight;
        final double paddingValue = screenWidth * 0.04;
        final double baseFontSize = screenWidth * 0.04;

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
              "Layanan Karyawan",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: baseFontSize * 1.25,
                color: Colors.white,
              ),
            ),
            backgroundColor: const Color(0xFF1572E8),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(paddingValue),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 240, // Tinggi banner (sesuaikan dengan kebutuhan Anda)
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
                        'assets/images/banner_layanan.png',
                        width: double.infinity,
                        fit: BoxFit.cover, // Gambar akan menyesuaikan ukuran tanpa terdistorsi
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "Selamat datang di Layanan Karyawan. Pilih salah satu menu di bawah untuk informasi lebih lanjut.",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: baseFontSize * 0.9,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.builder(
                    shrinkWrap: true, // Pastikan GridView tidak mengambil seluruh tinggi
                    physics: const NeverScrollableScrollPhysics(), // Nonaktifkan scroll GridView
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Dua kolom
                      crossAxisSpacing: 16, // Jarak horizontal antar kotak
                      mainAxisSpacing: 16, // Jarak vertikal antar kotak
                      childAspectRatio: 1, // Rasio aspek kotak (lebar = tinggi)
                    ),
                    padding: const EdgeInsets.all(16),
                    itemCount: _menuItems.length,
                    itemBuilder: (context, index) {
                      final menuItem = _menuItems[index];
                      return _buildMenuItem(
                        icon: menuItem['icon'] as IconData,
                        title: menuItem['title'] as String,
                        color: menuItem['color'] as Color,
                        onTap: menuItem['onTap'] as VoidCallback,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
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
                                icon: Icons.monetization_on,
                                question: 'Apa itu menu Uang Duka?',
                                answer:
                                    'Menu Uang Duka disediakan untuk mengajukan bantuan atau klaim terkait musibah duka. Fitur ini akan tersedia pada pembaruan selanjutnya.',
                              ),
                              _buildFAQItem(
                                icon: Icons.schedule,
                                question: 'Apa itu menu Schedule Shift?',
                                answer:
                                    'Menu Schedule Shift berfungsi untuk melihat jadwal kerja atau shift Anda setiap harinya. Fitur ini sudah aktif dan dapat digunakan.',
                              ),
                              _buildFAQItem(
                                icon: Icons.fingerprint,
                                question: 'Apa itu menu Absensi?',
                                answer:
                                    'Menu Absensi ditujukan untuk melihat riwayat kehadiran dan melakukan proses absensi secara digital. Fitur ini akan tersedia di versi mendatang.',
                              ),
                              _buildFAQItem(
                                icon: Icons.account_balance_wallet,
                                question: 'Apa itu menu Dispensasi/Kompensasi?',
                                answer:
                                    'Menu ini digunakan untuk mengajukan dispensasi atau kompensasi waktu kerja. Fitur ini masih dalam tahap pengembangan.',
                              ),
                              _buildFAQItem(
                                icon: Icons.folder,
                                question: 'Apa itu menu File Aktif?',
                                answer:
                                    'Menu File Aktif akan menampilkan dokumen penting terkait karyawan yang sedang aktif. Fitur ini akan segera tersedia.',
                              ),
                              _buildFAQItem(
                                icon: Icons.school,
                                question: 'Apa itu menu Bea Siswa?',
                                answer:
                                    'Menu Bea Siswa disiapkan untuk pengajuan beasiswa karyawan atau keluarga karyawan. Fitur ini belum tersedia dan masih dikembangkan.',
                              ),
                              _buildFAQItem(
                                icon: Icons.star,
                                question:
                                    'Apa itu menu Penghargaan Masa Kerja?',
                                answer:
                                    'Menu ini akan digunakan untuk melihat dan mengajukan penghargaan berdasarkan masa kerja karyawan. Akan tersedia dalam pembaruan berikutnya.',
                              ),
                              _buildFAQItem(
                                icon: Icons.group,
                                question: 'Apa itu menu Internal Recruitment?',
                                answer:
                                    'Menu Internal Recruitment memungkinkan karyawan melamar posisi yang tersedia di lingkungan perusahaan. Fitur ini masih dalam proses pengembangan.',
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
        );
      },
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
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
          padding: const EdgeInsets.all(8.0), // Tambahkan padding di dalam kotak
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 40), // Ikon di tengah
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                softWrap: true, // Pastikan teks melanjutkan ke baris berikutnya
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
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
