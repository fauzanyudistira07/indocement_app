import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:indocement_apk/pages/bpjs_page.dart';
import 'package:indocement_apk/pages/Chat.dart'; // Import halaman chat Anda
import 'package:shared_preferences/shared_preferences.dart';
import 'package:indocement_apk/service/api_service.dart';

class BPJSKetenagakerjaanPage extends StatefulWidget {
  const BPJSKetenagakerjaanPage({super.key});

  @override
  State<BPJSKetenagakerjaanPage> createState() =>
      _BPJSKetenagakerjaanPageState();
}

class _BPJSKetenagakerjaanPageState extends State<BPJSKetenagakerjaanPage> {
  String? atasanName;
  String? atasanPhone;

  @override
  void initState() {
    super.initState();
    _initAtasan();
  }

  Future<void> _initAtasan() async {
    final prefs = await SharedPreferences.getInstance();
    int? idSection;
    int? idEsl;

    try {
      // Pakai ApiService.get agar otomatis pakai token
      final response = await ApiService.get('http://34.50.112.226:5555/api/Employees');
      if (response.statusCode == 200) {
        final List data = response.data is String ? List<Map<String, dynamic>>.from(jsonDecode(response.data)) : response.data;

        final user = data.firstWhere(
          (e) => e['Id'] == prefs.getInt('idEmployee'),
          orElse: () => null,
        );
        if (user != null) {
          idSection = user['IdSection'];
          idEsl = user['IdEsl'];
          await prefs.setInt('idSection', idSection!);
          await prefs.setInt('idEsl', idEsl!);
        } else {
          idSection = prefs.getInt('idSection');
          idEsl = prefs.getInt('idEsl');
        }

        final atasan = data.firstWhere(
          (e) => e['IdSection'] == idSection && e['IdEsl'] == 3,
          orElse: () => null,
        );
        if (atasan != null) {
          setState(() {
            atasanName = atasan['EmployeeName'] ?? '-';
            atasanPhone = atasan['Telepon'] ?? '-';
          });
        } else {
          setState(() {
            atasanName = '-';
            atasanPhone = '-';
          });
        }
      }
    } catch (e) {
      setState(() {
        atasanName = '-';
        atasanPhone = '-';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BPJSPage()),
            );
          },
        ),
        backgroundColor: const Color(0xFF1572E8),
        title: const Text(
          "BPJS Ketenagakerjaan",
          style: TextStyle(
            fontFamily: 'Roboto',
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SizedBox(
        height:
            MediaQuery.of(context).size.height, // Gunakan tinggi layar penuh
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height -
                      kToolbarHeight -
                      MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Banner
                      Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
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
                            'assets/images/banner_ketenaga.png',
                            width: double.infinity,
                            height: 250,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      // Judul Informasi
                      const Text(
                        "Informasi",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1572E8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        "BPJS Ketenagakerjaan",
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1572E8),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),

                      // Kotak Informasi
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 12,
                              spreadRadius: 3,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Text(
                          "Untuk pertanyaan terkait akses aplikasi JMO, saldo BPJS Ketenagakerjaan, atau kartu BPJS Ketenagakerjaan, silakan hubungi petugas HR yang menangani klaim BPJS Ketenagakerjaan.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Kontak Atasan
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.person,
                                    color: Colors.blue),
                                title: Text(
                                  atasanName ?? 'Memuat...',
                                  style: const TextStyle(
                                    fontFamily: 'Roboto',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle:
                                    atasanPhone != null && atasanPhone != '-'
                                        ? Text(
                                            'No Telepon PIC: $atasanPhone',
                                            style: const TextStyle(
                                              fontFamily: 'Roboto',
                                              color: Colors.grey,
                                            ),
                                          )
                                        : null,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment
                                    .end, // Pindahkan tombol ke kanan
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const ChatPage(), // Ganti dengan halaman chat Anda
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.support_agent,
                                        size: 18),
                                    label: const Text(
                                      "Hubungi via Helpdesk",
                                      style: TextStyle(fontFamily: 'Roboto'),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Floating FAQ button
            Positioned(
              bottom: 20, // Perbaiki agar tombol FAQ benar-benar di bawah layar
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
                                      fontFamily: 'Roboto',
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1572E8),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildFAQItem(
                                    icon: Icons.question_answer,
                                    question:
                                        'Bagaimana cara mengakses aplikasi JMO?',
                                    answer:
                                        'Untuk akses aplikasi JMO, silakan hubungi Bpk. Heriyanto di No. Telp. Ext. +628882017549.',
                                  ),
                                  _buildFAQItem(
                                    icon: Icons.account_balance_wallet,
                                    question:
                                        'Bagaimana cara melihat saldo BPJS Ketenagakerjaan?',
                                    answer:
                                        'Untuk informasi saldo, hubungi Bpk. Heriyanto di No. Telp. Ext. +628882017549.',
                                  ),
                                  _buildFAQItem(
                                    icon: Icons.card_membership,
                                    question:
                                        'Bagaimana cara mendapatkan kartu BPJS Ketenagakerjaan?',
                                    answer:
                                        'Untuk kartu BPJS Ketenagakerjaan, silakan hubungi Bpk. Heriyanto di No. Telp. Ext. +628882017549.',
                                  ),
                                  _buildFAQItem(
                                    icon: Icons.support_agent,
                                    question:
                                        'Siapa yang menangani klaim BPJS Ketenagakerjaan?',
                                    answer:
                                        'Klaim BPJS Ketenagakerjaan ditangani oleh Bpk. Heriyanto. Silakan hubungi di No. Telp. Ext. +628882017549.',
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
                                  fontFamily: 'Roboto',
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
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    color: Colors.white,
                  ),
                ),
                backgroundColor: Colors.blue,
              ),
            ),
          ],
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
                    fontFamily: 'Roboto',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  answer,
                  style: const TextStyle(
                    fontFamily: 'Roboto',
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
