import 'package:flutter/material.dart';
import 'package:indocement_apk/pages/bpjs_page.dart';
import 'bpjs_karyawan.dart'; // Import the BPJSKaryawanPage
import 'bpjs_tambahan.dart'; // Import the BPJSTambahanPage
import 'dart:convert';
import 'package:indocement_apk/service/api_service.dart';

class MenuPage extends StatefulWidget {
  const MenuPage({super.key});

  @override
  _MenuPageState createState() => _MenuPageState();
}

class _MenuPageState extends State<MenuPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  bool _isMenuVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start off-screen to the right
      end: Offset.zero, // End at the original position
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    ));
  }

  void _toggleMenu() {
    setState(() {
      _isMenuVisible = !_isMenuVisible;
      if (_isMenuVisible) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // Ikon back
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      const BPJSPage()), // Navigasi ke halaman BPJS
            );
          },
        ),
        backgroundColor: const Color(0xFF1572E8), // Warna latar belakang header
        title: const Text(
          "BPJS Kesehatan",
          style: TextStyle(
            color: Colors.white, // Warna putih untuk judul
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white, // Warna putih untuk ikon back
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Banner
                Container(
                  margin:
                      const EdgeInsets.only(bottom: 16.0), // Jarak bawah banner
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16), // Sudut melengkung
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2), // Warna bayangan
                        blurRadius: 8, // Radius blur bayangan
                        offset: const Offset(0, 4), // Posisi bayangan
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        16), // Sudut melengkung untuk gambar
                    child: Image.asset(
                      'assets/images/bpjs_kesehatan.png', // Path ke gambar banner
                      width: double.infinity, // Lebar penuh
                      height: 250, // Tinggi banner diubah menjadi 250
                      fit: BoxFit.cover, // Gambar menyesuaikan ukuran container
                    ),
                  ),
                ),

                // Deskripsi
                const Text(
                  "Selamat datang di halaman BPJS Kesehatan. Pilih salah satu menu di bawah untuk informasi lebih lanjut.",
                  textAlign: TextAlign.center, // Rata tengah
                  style: TextStyle(
                    fontSize: 16, // Perbesar ukuran teks
                    fontWeight: FontWeight.w500, // Tambahkan ketebalan teks
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16), // Jarak antara deskripsi dan menu

                // Menu
                Expanded(
                  child: GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2, // Dua kolom
                      crossAxisSpacing: 16, // Jarak horizontal antar kotak
                      mainAxisSpacing: 16, // Jarak vertikal antar kotak
                      childAspectRatio: 1, // Rasio aspek kotak (lebar = tinggi)
                    ),
                    itemCount: 2, // Jumlah menu
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildMenuBox(
                          icon: Icons.family_restroom,
                          title: 'BPJS Kesehatan Keluarga Karyawan',
                          color: Colors.blue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const BPJSKaryawanPage()),
                            );
                          },
                        );
                      } else if (index == 1) {
                        return _buildMenuBox(
                          icon: Icons.group_add,
                          title: 'BPJS Kesehatan Keluarga Tambahan',
                          color: Colors.green,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const BPJSTambahanPage()),
                            );
                          },
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ],
            ),
          ),

          // Floating FAQ button
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton.extended(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16), // Sudut melengkung
                      ),
                      contentPadding: const EdgeInsets.all(16.0),
                      content: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.9,
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: SingleChildScrollView(
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
                                question: 'Apa itu BPJS?',
                                answer:
                                    'BPJS adalah Badan Penyelenggara Jaminan Sosial yang menyediakan layanan kesehatan bagi masyarakat Indonesia.',
                              ),
                              _buildFAQItem(
                                question: 'Bagaimana cara mendaftar BPJS?',
                                answer:
                                    'Anda dapat mendaftar melalui aplikasi atau kantor BPJS terdekat.',
                              ),
                              _buildFAQItem(
                                question: 'Apa saja dokumen yang diperlukan?',
                                answer:
                                    'Dokumen yang diperlukan meliputi KTP, KK, dan dokumen pendukung lainnya.',
                              ),
                              _buildFAQItem(
                                question: 'Bagaimana cara mengajukan klaim?',
                                answer:
                                    'Klaim dapat diajukan melalui aplikasi atau langsung ke kantor BPJS.',
                              ),
                            ],
                          ),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text(
                            'Tutup',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
              icon: const Icon(Icons.help_outline,
                  color: Colors.white), // Ikon warna putih
              label: const Text(
                "FAQ",
                style: TextStyle(color: Colors.white), // Teks warna putih
              ),
              backgroundColor: Colors.blue, // Warna tombol tetap biru
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBox({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, // Background putih
          borderRadius: BorderRadius.circular(12), // Sudut melengkung
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1), // Bayangan lembut
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color), // Ikon berwarna di tengah
            const SizedBox(height: 8),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87, // Teks berwarna hitam
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({
    required String question,
    required String answer,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.question_answer,
                color: Color(0xFF1572E8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.arrow_right,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  answer,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        text,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
      ),
      onTap: onTap,
    );
  }
}

Future<bool> checkBpjsData(int idEmployee) async {
  try {
    final response = await ApiService.get('http://34.50.112.226:5555/api/Bpjs/$idEmployee');
    if (response.statusCode == 200) {
      final data = response.data is String
          ? jsonDecode(response.data)
          : response.data;

      // Periksa apakah UrlKk dan UrlSuratNikah sudah ada
      if (data['UrlKk'] != null && data['UrlSuratNikah'] != null) {
        return true; // Data sudah ada
      }
    }
    return false; // Data belum ada
  } catch (e) {
    print("❌ Error saat memeriksa data BPJS: $e");
    return false; // Anggap data belum ada jika terjadi kesalahan
  }
}
