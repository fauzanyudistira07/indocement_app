import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'dart:math';
import 'dart:convert';
// Ensure this import is present
import 'package:shared_preferences/shared_preferences.dart';
// Tambahkan di bagian import jika belum
import 'package:file_picker/file_picker.dart';
import 'package:indocement_apk/service/api_service.dart';

class MedicPasutriPage extends StatefulWidget {
  const MedicPasutriPage({super.key});

  @override
  State<MedicPasutriPage> createState() => _MedicPasutriPageState();
}

class _MedicPasutriPageState extends State<MedicPasutriPage> {
  final String fileUrl =
      'http://34.50.112.226:5555/templates/medical.pdf'; // URL file
  bool isLoadingDownload =
      false; // Untuk menampilkan indikator loading download
  bool isDownloaded = false; // Status apakah file sudah didownload
  File? uploadedFile; // Menyimpan file yang diunggah
  bool isUploading = false; // Status apakah sedang mengunggah file
  bool isDownloadEnabled = false; // Status apakah tombol download diaktifkan
  String? selectedJenisSuratUpload;
  // Tambahkan variabel state untuk loading kirim surat
  bool isSending = false;
  bool isDropdownEnabled = false;
  String? employeeGender;
  bool isJenisSuratLoading = false;
  bool isGenderDialogShowing = false;
  String? selectedAlamatPerusahaan;
  final List<String> alamatPerusahaanOptions = [
    'Jl. Mayor Oking Jayaatmaja, Citeureup, Kec. Gn. Putri, Kabupaten Bogor, Jawa Barat 16810',
    'Citeureup, Kec. Citeureup, Kabupaten Bogor, Jawa Barat',
    'Wisma Indocement, Lt. 13, Jl. Jenderal Sudirman No.71 Kav. 70, Kecamatan Setiabudi, Daerah Khusus Ibukota Jakarta 12910',
    'Jalan Mayor Oking Jayaatmaja, Citeureup, Kec. Citeureup, Kabupaten Bogor, Jawa Barat 16810',
    'Tj. Priok, Kec. Tj. Priok, Jkt Utara, Daerah Khusus Ibukota Jakarta 14310',
  ];

  @override
  void initState() {
    super.initState();

    // Set tanggal surat otomatis saat init
    final now = DateTime.now();
    tanggalSuratController.text =
        "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
    tahunController.text = now.year.toString();
    namaPerusahaanController.text = 'PT Indocement Tunggal Prakarsa Tbk';

    // Panggil fungsi untuk menyimpan IdSection dan IdEsl ke SharedPreferences
  }

  Future<void> downloadFile() async {
    final dio = Dio();

    try {
      // Ambil IdEmployee dari SharedPreferences
      final idEmployee = await getIdEmployee();
      if (idEmployee == null) {
        throw Exception('ID Employee tidak ditemukan. Harap login ulang.');
      }

      // Tampilkan popup dengan progress bar
      showDialog(
        context: this.context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Mengunduh File'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                LinearProgressIndicator(),
                SizedBox(height: 16),
                Text('Sedang mengunduh file, harap tunggu...'),
              ],
            ),
          );
        },
      );

final url = 'http://34.50.112.226:5555/api/Medical/generate-medical-document/$idEmployee';

// Define the data to be sent in the request body
final Map<String, dynamic> data = {
  "idEmployee": idEmployee,
  // Add other required fields here if needed
};

final response = await ApiService.post(
  url,
  data: data,
  headers: {
    'accept': '*/*',
    'Content-Type': 'application/json',
    // Tidak perlu responseType, ApiService akan handle response.data
  },
);

      Navigator.of(this.context).pop(); // Tutup popup setelah selesai

      if (response.statusCode == 200) {
        final directory = Directory('/storage/emulated/0/Download');
        if (!directory.existsSync()) {
          directory.createSync(recursive: true);
        }

        final filePath = '${directory.path}/medical_$idEmployee.pdf';
        final file = File(filePath);
        await file.writeAsBytes(response.data!);

        // Tandai bahwa file sudah diunduh
        setState(() {
          isDownloaded = true;
        });

        // Tutup dropdown jika masih terbuka
        FocusScope.of(this.context).unfocus();

        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(content: Text('File berhasil didownload ke $filePath')),
        );

        // Reload halaman setelah download selesai
        Navigator.of(this.context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const MedicPasutriPage(),
          ),
        );
      } else {
        throw Exception('Gagal mengunduh file: ${response.statusCode}');
      }
    } catch (e) {
      Navigator.of(this.context).pop(); // Tutup popup jika terjadi kesalahan
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Gagal download file: $e')),
      );
    }
  }

  Future<void> pickFile() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        uploadedFile = File(pickedFile.path);
      });
    }
  }

  Future<void> uploadFile() async {
    if (uploadedFile == null) {
      showDialog(
        context: this.context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Peringatan'),
            content: const Text('Anda harus memilih file terlebih dahulu.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    setState(() {
      isUploading = true; // Mulai proses upload
    });

    try {
      // Ambil IdEmployee dari SharedPreferences
      final idEmployee = await getIdEmployee();
      if (idEmployee == null) {
        throw Exception('ID Employee tidak ditemukan. Harap login ulang.');
      }

      final dio = Dio();
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          uploadedFile!.path,
          filename: basename(uploadedFile!.path),
        ),
        'idEmployee': idEmployee,
      });

      final response = await dio.post(
        'http://34.50.112.226:5555/api/Medical/upload',
        data: formData,
        options: Options(
          headers: {
            'accept': '*/*',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('File berhasil diupload!')),
        );
      } else {
        throw Exception('Gagal mengunggah file: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Gagal upload file: $e')),
      );
    } finally {
      setState(() {
        isUploading = false; // Selesai proses upload
      });
    }
  }

Future<void> uploadSuratMedic(String jenisSurat) async {
  if (uploadedFile == null) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      const SnackBar(content: Text('Silakan pilih file terlebih dahulu')),
    );
    return;
  }
  setState(() {
    isUploading = true;
  });
  try {
    final idEmployee = await getIdEmployee();
    if (idEmployee == null) {
      throw Exception('ID Employee tidak ditemukan. Harap login ulang.');
    }
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        uploadedFile!.path,
        filename: basename(uploadedFile!.path),
      ),
      'idEmployee': idEmployee,
      'jenisSurat': jenisSurat,
    });
    final response = await ApiService.post(
      'http://34.50.112.226:5555/api/Medical/upload',
      data: formData,
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    );
    if (response.statusCode == 200) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('File $jenisSurat berhasil diupload!')),
      );
      setState(() {
        uploadedFile = null;
      });
    } else {
      throw Exception('Gagal mengunggah file: ${response.statusCode}');
    }
  } catch (e) {
    ScaffoldMessenger.of(this.context).showSnackBar(
      SnackBar(content: Text('Gagal upload file: $e')),
    );
  } finally {
    setState(() {
      isUploading = false;
    });
  }
}

  Future<void> requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      // Izin diberikan
    } else {
      throw Exception('Izin penyimpanan tidak diberikan.');
    }
  }

  // Fungsi untuk menyimpan id employee ke SharedPreferences
  Future<void> saveIdEmployeeToPrefs(int idEmployee) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('idEmployee', idEmployee);
  }

  Future<int?> getIdEmployee() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getInt('idEmployee');
  }

  Future<void> fetchAndSaveIdEmployee() async {
    try {
      // Panggil API untuk mendapatkan idEmployee
final response = await ApiService.get(
  'http://34.50.112.226:5555/api/Employees/get-id',
  headers: {'accept': 'application/json'},
);

      print('Response data: ${response.data}');

      if (response.statusCode == 200) {
        final idEmployee = response.data['idEmployee'];
        if (idEmployee != null) {
          // Simpan idEmployee ke SharedPreferences
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt('idEmployee', idEmployee);

          setState(() {
            // Perbarui state jika diperlukan
          });

          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
                content: Text('ID Employee berhasil disimpan: $idEmployee')),
          );
        } else {
          throw Exception('ID Employee tidak ditemukan di respons API.');
        }
      } else {
        throw Exception(
            'Gagal mendapatkan ID Employee: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan ID Employee: $e')),
      );
    }
  }

  Future<void> fetchAndSaveIdEmployeeFromMedical() async {
    try {
      // Panggil API untuk mendapatkan data Medical
      final response = await ApiService.get(
  'http://34.50.112.226:5555/api/Medical',
  headers: {'accept': 'application/json'},
);

      if (response.statusCode == 200) {
        // Periksa apakah respons adalah array
        if (response.data is List && response.data.isNotEmpty) {
          // Ambil elemen pertama dari array
          final firstItem = response.data[0];
          final idEmployee = firstItem['IdEmployee'];

          if (idEmployee != null) {
            // Simpan IdEmployee ke SharedPreferences
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setInt('idEmployee', idEmployee);

            setState(() {
              // Perbarui state jika diperlukan
            });
          } else {
            throw Exception('ID Employee tidak ditemukan di respons API.');
          }
        } else {
          throw Exception('Respons API kosong atau tidak valid.');
        }
      } else {
        throw Exception(
            'Gagal mendapatkan ID Employee: ${response.statusCode}');
      }
    } catch (e) {
      print('Error: $e'); // Log kesalahan
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(content: Text('Gagal mendapatkan ID Employee: $e')),
      );
    }
  }

  // Tambahkan fungsi untuk fetch data employee dan isi otomatis form

  Future<void> fetchAndFillEmployeeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) return;

      // Ambil semua data employee
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees',
        headers: {'accept': 'application/json'},
      );

      if (response.statusCode == 200 && response.data is List) {
        final List employees = response.data;

        // Temukan data employee user
        final user = employees.firstWhere(
          (e) => e['Id'] == idEmployee,
          orElse: () => null,
        );
        if (user == null) return;

        // Simpan IdSection user untuk kebutuhan lain
        final idSection = user['IdSection'];
        if (idSection != null) {
          await prefs.setInt('idSection', idSection);
          await fetchSectionAndUnitBySectionId(idSection);
        }

        // Cari atasan dengan IdSection sama dan IdEsl == 3
        final atasan = employees.firstWhere(
          (e) => e['IdSection'] == idSection && e['IdEsl'] == 3,
          orElse: () => null,
        );

        setState(() {
          // Isi otomatis nama atasan dan jabatan atasan jika ditemukan
          namaAtasanController.text =
              atasan != null ? (atasan['EmployeeName'] ?? '') : '';
          jabatanAtasanController.text =
              atasan != null ? (atasan['JobTitle'] ?? '') : '';
          // Field lain tidak diisi otomatis
        });
      }
    } catch (e) {
      print('Gagal fetch data employee: $e');
    }
  }

  String _firstString(Map data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null) {
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
    }
    return '';
  }

  String _normalizeGender(String? raw) {
    if (raw == null) return '';
    final text = raw.toString().trim().toLowerCase();
    if (text.isEmpty) return '';
    if (text.startsWith('l') || text.contains('laki')) return 'L';
    if (text.startsWith('p') || text.startsWith('w') || text.contains('perem')) {
      return 'W';
    }
    return text.toUpperCase();
  }

  Future<void> _showGenderWarningDialog() async {
    if (isGenderDialogShowing) return;
    if (!mounted) return;
    setState(() {
      isGenderDialogShowing = true;
    });
    await showDialog(
      context: this.context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3CD),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFF856404),
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Peringatan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Surat Pernyataan hanya untuk karyawan wanita.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(this.context).pop();
                    },
                    child: const Text('OKE'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (mounted) {
      setState(() {
        isGenderDialogShowing = false;
      });
    }
  }

  DateTime? _parseDateFlexible(String? raw) {
    if (raw == null) return null;
    var text = raw.toString().trim();
    if (text.isEmpty) return null;
    if (text.contains('T')) {
      text = text.split('T').first;
    } else if (text.contains(' ')) {
      text = text.split(' ').first;
    }
    try {
      if (text.contains('-')) {
        final parts = text.split('-');
        if (parts.length == 3) {
          final year = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          final day = int.tryParse(parts[2]);
          if (year != null && month != null && day != null) {
            return DateTime(year, month, day);
          }
        }
      }
      if (text.contains('.') || text.contains('/')) {
        final separator = text.contains('.') ? '.' : '/';
        final parts = text.split(separator);
        if (parts.length == 3) {
          final day = int.tryParse(parts[0]);
          final month = int.tryParse(parts[1]);
          var year = int.tryParse(parts[2]);
          if (day != null && month != null && year != null) {
            if (parts[2].length == 2) {
              final currentTwoDigit = DateTime.now().year % 100;
              year = year <= currentTwoDigit ? 2000 + year : 1900 + year;
            }
            if (year < 1900) return null;
            return DateTime(year, month, day);
          }
        }
      }
      final parsed = DateTime.tryParse(text);
      if (parsed != null && parsed.year >= 1900) return parsed;
      return null;
    } catch (_) {
      return null;
    }
  }

  String _formatDateForDisplay(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    return "$day.$month.$year";
  }

  String _formatDateFromString(String? raw) {
    final date = _parseDateFlexible(raw);
    if (date == null) return '';
    return _formatDateForDisplay(date);
  }

  Future<void> fetchAndFillKaryawanData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) return;

      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/Employees/$idEmployee',
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode != 200 || response.data == null) return;
      final data =
          response.data is String ? jsonDecode(response.data) : response.data;
      if (data is! Map) return;

      final nama = _firstString(data, ['EmployeeName', 'Nama', 'Name']);
      final nik =
          _firstString(data, ['EmployeeNo', 'NIK', 'Nik', 'EmployeeNumber']);
      final tempatLahir =
          _firstString(data, ['TempatLahir', 'BirthPlace', 'PlaceOfBirth']);
      final tanggalLahir = _formatDateFromString(_firstString(
          data, ['TanggalLahir', 'BirthDate', 'DateOfBirth']));
      final alamat =
          _firstString(data, ['Alamat', 'Address', 'AlamatKaryawan']);
      final tglMulaiKerja = _formatDateFromString(_firstString(data, [
        'TanggalMulaiKerja',
        'TglMulaiKerja',
        'TanggalMulai',
        'JoinDate',
        'TanggalMasuk'
      ]));
      final jabatanTerakhir = _firstString(
          data, ['JobTitle', 'PositionName', 'JabatanTerakhir']);
      final idSection = data['IdSection'];
      final sectionName =
          _firstString(data, ['NamaSection', 'SectionName']);
      final genderRaw =
          _firstString(data, ['Gender', 'JenisKelamin', 'Jk', 'Sex']);
      final gender = _normalizeGender(genderRaw);

      setState(() {
        if (nama.isNotEmpty) namaKaryawanController.text = nama;
        if (nik.isNotEmpty) nikController.text = nik;
        if (tempatLahir.isNotEmpty) {
          tempatLahirKaryawanController.text = tempatLahir;
        }
        if (tanggalLahir.isNotEmpty) {
          tanggalLahirKaryawanController.text = tanggalLahir;
        }
        if (alamat.isNotEmpty) alamatKaryawanController.text = alamat;
        if (tglMulaiKerja.isNotEmpty) {
          tglMulaiKerjaController.text = tglMulaiKerja;
        }
        if (jabatanTerakhir.isNotEmpty) {
          jabatanTerakhirController.text = jabatanTerakhir;
        }
        if (gender.isNotEmpty) {
          employeeGender = gender;
        }
      });

      if (idSection is int) {
        await fetchPlantDivAndDepartementBySectionId(idSection, sectionName);
      } else if (idSection != null) {
        final parsed = int.tryParse(idSection.toString());
        if (parsed != null) {
          await fetchPlantDivAndDepartementBySectionId(parsed, sectionName);
        }
      }

      final family = data['FamilyEmployees'];
      if (family is List) {
        final pasangan = family.cast<dynamic>().firstWhere(
              (e) => e is Map && (e['NamaPasangan'] != null || e['StatusPasangan'] != null),
              orElse: () => null,
            );
        if (pasangan is Map) {
          final namaPasangan =
              _firstString(pasangan, ['NamaPasangan', 'NamaIstri', 'NamaSuami']);
          final statusPasangan =
              _firstString(pasangan, ['StatusPasangan', 'Status']);
          final tempatLahirPasangan = _firstString(
              pasangan, ['TempatLahirPasangan', 'TempatLahir']);
          final tanggalLahirPasangan = _formatDateFromString(_firstString(
              pasangan, ['TglLahirPasangan', 'TanggalLahirPasangan']));

          setState(() {
            if (namaPasangan.isNotEmpty) {
              namaPasanganController.text = namaPasangan;
            }
            if (statusPasangan.isNotEmpty) {
              statusPasanganController.text = statusPasangan;
            }
            if (tempatLahirPasangan.isNotEmpty) {
              tempatLahirPasanganController.text = tempatLahirPasangan;
            }
            if (tanggalLahirPasangan.isNotEmpty) {
              tanggalLahirPasanganController.text = tanggalLahirPasangan;
            }
          });
        }

        final children = family
            .where((e) => e is Map && e['NamaAnak'] != null)
            .cast<Map>()
            .toList();
        if (children.isNotEmpty) {
          void fillChild(int index, Map child) {
            final nama = _firstString(child, ['NamaAnak']);
            final tempatLahir = _firstString(
                child, ['TempatLahirAnak', 'TempatLahir']);
            final tanggalLahir = _formatDateFromString(
                _firstString(child, ['TglLahirAnak', 'TanggalLahirAnak']));
            final pendidikan = _firstString(child, ['PendidikanAnak']);

            setState(() {
              if (index == 0) {
                if (nama.isNotEmpty) namaAnak1Controller.text = nama;
                if (tempatLahir.isNotEmpty) {
                  tempatLahirAnak1Controller.text = tempatLahir;
                }
                if (tanggalLahir.isNotEmpty) {
                  ttlAnak1Controller.text = tanggalLahir;
                }
                if (pendidikan.isNotEmpty) {
                  pendidikanAnak1Controller.text = pendidikan;
                }
              } else if (index == 1) {
                if (nama.isNotEmpty) namaAnak2Controller.text = nama;
                if (tempatLahir.isNotEmpty) {
                  tempatLahirAnak2Controller.text = tempatLahir;
                }
                if (tanggalLahir.isNotEmpty) {
                  ttlAnak2Controller.text = tanggalLahir;
                }
                if (pendidikan.isNotEmpty) {
                  pendidikanAnak2Controller.text = pendidikan;
                }
              } else if (index == 2) {
                if (nama.isNotEmpty) namaAnak3Controller.text = nama;
                if (tempatLahir.isNotEmpty) {
                  tempatLahirAnak3Controller.text = tempatLahir;
                }
                if (tanggalLahir.isNotEmpty) {
                  ttlAnak3Controller.text = tanggalLahir;
                }
                if (pendidikan.isNotEmpty) {
                  pendidikanAnak3Controller.text = pendidikan;
                }
              }
            });
          }

          for (var i = 0; i < children.length && i < 3; i++) {
            fillChild(i, children[i]);
          }
        }
      }
    } catch (e) {
      print('Gagal fetch data karyawan: $e');
    }
  }

  Future<void> fetchSectionAndUnitBySectionId(int idSection) async {
    try {
      final sectionsResponse = await ApiService.get(
        'http://34.50.112.226:5555/api/Sections',
        headers: {'accept': 'application/json'},
      );
      if (sectionsResponse.statusCode == 200 &&
          sectionsResponse.data is List) {
        final List sections = sectionsResponse.data;
        final section = sections.firstWhere(
          (s) => s['Id'] == idSection,
          orElse: () => null,
        );
        final sectionName = section != null ? section['NamaSection'] : null;
        final normalizedSectionName = sectionName != null
            ? sectionName.toString().trim().toLowerCase()
            : null;
        if (sectionName != null && sectionName.toString().isNotEmpty) {
          setState(() {
            sectionController.text = sectionName.toString();
          });
        }

        final unitsResponse = await ApiService.get(
          'http://34.50.112.226:5555/api/Units',
          headers: {'accept': 'application/json'},
        );
        if (unitsResponse.statusCode == 200 && unitsResponse.data is List) {
          final List units = unitsResponse.data;
          Map<String, dynamic>? matchedUnit;

          for (final unit in units) {
            final plantDivisions = unit['PlantDivisions'];
            if (plantDivisions is! List) continue;
            for (final pd in plantDivisions) {
              final departements = pd['Departements'];
              if (departements is! List) continue;
              for (final dept in departements) {
                final sections = dept['Sections'];
                if (sections is! List) continue;
                for (final sec in sections) {
                  if (sec['Id'] == idSection) {
                    matchedUnit = unit;
                    break;
                  }
                  final secName = sec['NamaSection'];
                  final normalizedSecName = secName != null
                      ? secName.toString().trim().toLowerCase()
                      : null;
                  if (normalizedSectionName != null &&
                      normalizedSecName != null &&
                      normalizedSecName == normalizedSectionName) {
                    matchedUnit = unit;
                    break;
                  }
                }
                if (matchedUnit != null) break;
              }
              if (matchedUnit != null) break;
            }
            if (matchedUnit != null) break;
          }

          final unitName =
              matchedUnit != null ? matchedUnit['NamaUnit'] : null;
          if (unitName != null && unitName.toString().isNotEmpty) {
            setState(() {
              unitController.text = unitName.toString();
            });
          }
        }
      }
    } catch (e) {
      print('Gagal fetch section/unit: $e');
    }
  }

  Future<void> fetchPlantDivAndDepartementBySectionId(
    int idSection,
    String? sectionName,
  ) async {
    try {
      final response = await ApiService.get(
        'http://34.50.112.226:5555/api/PlantDivisions',
        headers: {'accept': 'application/json'},
      );
      if (response.statusCode != 200 || response.data is! List) return;
      final List plantDivs = response.data;
      final normalizedSectionName =
          sectionName != null ? sectionName.trim().toLowerCase() : null;

      String? matchedPlantDiv;
      String? matchedDept;

      for (final pd in plantDivs) {
        final departements = pd['Departements'];
        if (departements is! List) continue;
        for (final dept in departements) {
          final sections = dept['Sections'];
          if (sections is! List) continue;
          for (final sec in sections) {
            if (sec['Id'] == idSection) {
              matchedPlantDiv = pd['NamaPlantDivision']?.toString();
              matchedDept = dept['NamaDepartement']?.toString();
              break;
            }
            final secName = sec['NamaSection'];
            final normalizedSecName = secName != null
                ? secName.toString().trim().toLowerCase()
                : null;
            if (normalizedSectionName != null &&
                normalizedSecName != null &&
                normalizedSecName == normalizedSectionName) {
              matchedPlantDiv = pd['NamaPlantDivision']?.toString();
              matchedDept = dept['NamaDepartement']?.toString();
              break;
            }
          }
          if (matchedPlantDiv != null || matchedDept != null) break;
        }
        if (matchedPlantDiv != null || matchedDept != null) break;
      }

      if ((matchedPlantDiv ?? '').isNotEmpty || (matchedDept ?? '').isNotEmpty) {
        setState(() {
          if ((matchedPlantDiv ?? '').isNotEmpty) {
            plandivController.text = matchedPlantDiv!;
          }
          if ((matchedDept ?? '').isNotEmpty) {
            departementController.text = matchedDept!;
          }
        });
      }
    } catch (e) {
      print('Gagal fetch plandiv/departement: $e');
    }
  }

  String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random();
    return String.fromCharCodes(
      Iterable.generate(
          length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }

  Future<void> cekStatusPasanganDanSetDropdown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idEmployee = prefs.getInt('idEmployee');
      if (idEmployee == null) return;

final response = await ApiService.get(
  'http://34.50.112.226:5555/api/Employees/$idEmployee',
  headers: {'accept': 'application/json'},
);

      if (response.statusCode == 200 && response.data != null) {
        final List familyEmployees = response.data['FamilyEmployees'] ?? [];
        final pasangan = familyEmployees.firstWhere(
          (e) => e['StatusPasangan'] != null,
          orElse: () => null,
        );
        if (pasangan != null && pasangan['StatusPasangan'] == 'Suami') {
          setState(() {
            isDropdownEnabled = true;
          });
        } else {
          setState(() {
            isDropdownEnabled = false;
          });
        }
      } else {
        setState(() {
          isDropdownEnabled = false;
        });
      }
    } catch (e) {
      print('Gagal cek status pasangan: $e');
      setState(() {
        isDropdownEnabled = false;
      });
    }
  }

  String? selectedJenisSurat;
  final _formKey = GlobalKey<FormState>();

  // Controller untuk field wajib
  final TextEditingController namaAtasanController = TextEditingController();
  final TextEditingController jabatanAtasanController = TextEditingController();
  final TextEditingController namaPerusahaanController =
      TextEditingController();
  final TextEditingController alamatPerusahaanController =
      TextEditingController();
  final TextEditingController namaKaryawanController = TextEditingController();
  final TextEditingController tempatLahirKaryawanController =
      TextEditingController();
  final TextEditingController tanggalLahirKaryawanController =
      TextEditingController();
  final TextEditingController alamatKaryawanController =
      TextEditingController();
  final TextEditingController tglMulaiKerjaController = TextEditingController();
  final TextEditingController jabatanTerakhirController =
      TextEditingController();
  final TextEditingController sectionController = TextEditingController();

  // Controller untuk pasangan & anak (opsional)
  final TextEditingController namaPasanganController = TextEditingController();
  final TextEditingController statusPasanganController =
      TextEditingController();
  final TextEditingController tempatLahirPasanganController =
      TextEditingController();
  final TextEditingController tanggalLahirPasanganController =
      TextEditingController();

  final TextEditingController namaAnak1Controller = TextEditingController();
  final TextEditingController ttlAnak1Controller = TextEditingController();
  final TextEditingController namaAnak2Controller = TextEditingController();
  final TextEditingController ttlAnak2Controller = TextEditingController();
  final TextEditingController namaAnak3Controller = TextEditingController();
  final TextEditingController ttlAnak3Controller = TextEditingController();

  // Tambahkan controller baru untuk Unit dan Tanggal Surat
  final TextEditingController unitController = TextEditingController();
  final TextEditingController tanggalSuratController = TextEditingController();

  // Controller tambahan untuk Surat Pernyataan
  final TextEditingController nikController = TextEditingController();
  final TextEditingController plandivController = TextEditingController();
  final TextEditingController departementController = TextEditingController();
  final TextEditingController tahunController = TextEditingController();
  final TextEditingController namaSuamiController = TextEditingController();
  final TextEditingController tempatLahirSuamiController =
      TextEditingController();
  final TextEditingController tanggalLahirSuamiController =
      TextEditingController();
  final TextEditingController bidangUsahaController = TextEditingController();
  final TextEditingController tempatLahirAnak1Controller =
      TextEditingController();
  final TextEditingController pendidikanAnak1Controller =
      TextEditingController();
  final TextEditingController tempatLahirAnak2Controller =
      TextEditingController();
  final TextEditingController pendidikanAnak2Controller =
      TextEditingController();
  final TextEditingController tempatLahirAnak3Controller =
      TextEditingController();
  final TextEditingController pendidikanAnak3Controller =
      TextEditingController();

  @override
  void dispose() {
    // Dispose semua controller
    namaAtasanController.dispose();
    jabatanAtasanController.dispose();
    namaPerusahaanController.dispose();
    alamatPerusahaanController.dispose();
    nikController.dispose();
    namaKaryawanController.dispose();
    tempatLahirKaryawanController.dispose();
    tanggalLahirKaryawanController.dispose();
    alamatKaryawanController.dispose();
    tglMulaiKerjaController.dispose();
    jabatanTerakhirController.dispose();
    sectionController.dispose();
    namaPasanganController.dispose();
    statusPasanganController.dispose();
    tempatLahirPasanganController.dispose();
    tanggalLahirPasanganController.dispose();
    namaAnak1Controller.dispose();
    ttlAnak1Controller.dispose();
    namaAnak2Controller.dispose();
    ttlAnak2Controller.dispose();
    namaAnak3Controller.dispose();
    ttlAnak3Controller.dispose();
    // Dispose controller baru
    unitController.dispose();
    tanggalSuratController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF1572E8),
        title: const Text(
          'Pembuatan Surat Medic',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container dengan Icon dan Teks
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.note,
                      size: 40,
                      color: Color(0xFF1572E8),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Instruksi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Silakan pilih jenis surat pada dropdown di bawah, kemudian isi data yang diperlukan pada form sesuai jenis surat yang dipilih.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Card berisi dua menu
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Judul dengan icon di kiri
                      Row(
                        children: const [
                          Icon(Icons.edit_document,
                              color: Color(0xFF1572E8), size: 28),
                          SizedBox(width: 8),
                          Text(
                            'Pembuatan Surat Medis',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1572E8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Dropdown pengganti menu
                      Row(
                        children: [
                          const Icon(Icons.menu_book, color: Color(0xFF1572E8)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Pilih Jenis Surat',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                              ),
                              value: selectedJenisSurat,
                              onTap: () async {
                                if (selectedJenisSurat == 'keterangan') {
                                  await fetchAndFillEmployeeData();
                                }
                                if (selectedJenisSurat == 'keterangan' ||
                                    selectedJenisSurat == 'pernyataan') {
                                  await fetchAndFillKaryawanData();
                                }
                              },
                              items: [
                                const DropdownMenuItem(
                                  value: 'keterangan',
                                  child: Text('Surat Keterangan'),
                                ),
                                DropdownMenuItem(
                                  value: 'pernyataan',
                                  enabled: employeeGender != 'L',
                                  child: const Text('Surat Pernyataan'),
                                ),
                              ],
                              onChanged: (value) async {
                                if (value == null) return;
                                setState(() {
                                  isJenisSuratLoading = true;
                                });

                                if (value == 'pernyataan') {
                                  await fetchAndFillKaryawanData();
                                  if (employeeGender == 'L') {
                                    if (mounted) {
                                      setState(() {
                                        selectedJenisSurat = null;
                                        isJenisSuratLoading = false;
                                      });
                                    }
                                    FocusScope.of(this.context).unfocus();
                                    await _showGenderWarningDialog();
                                    return;
                                  }
                                  setState(() {
                                    selectedJenisSurat = value;
                                  });
                                } else if (value == 'keterangan') {
                                  setState(() {
                                    selectedJenisSurat = value;
                                  });
                                  await fetchAndFillEmployeeData();
                                  await fetchAndFillKaryawanData();
                                }

                                if (mounted) {
                                  setState(() {
                                    isJenisSuratLoading = false;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (isJenisSuratLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 20),

                      // =====================
                      // FORM SURAT KETERANGAN
                      // =====================
                      if (selectedJenisSurat == 'keterangan')
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === Data Atasan ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.person,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Atasan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAtasanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Atasan *',
                                          prefixIcon:
                                              Icon(Icons.badge_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        autovalidateMode:
                                            AutovalidateMode.onUserInteraction,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: jabatanAtasanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Jabatan Atasan *',
                                          prefixIcon: Icon(Icons.work_outline),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Perusahaan ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.business,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Perusahaan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaPerusahaanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Perusahaan *',
                                          prefixIcon: Icon(Icons.apartment),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        decoration: const InputDecoration(
                                          labelText: 'Alamat Perusahaan *',
                                          border: OutlineInputBorder(),
                                          prefixIcon:
                                              Icon(Icons.location_on_outlined),
                                        ),
                                        value: selectedAlamatPerusahaan,
                                        isExpanded: true,
                                        items: alamatPerusahaanOptions
                                            .map(
                                              (alamat) => DropdownMenuItem(
                                                value: alamat,
                                                child: Text(
                                                  alamat,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        selectedItemBuilder: (context) {
                                          return alamatPerusahaanOptions
                                              .map(
                                                (alamat) => Align(
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    alamat,
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              )
                                              .toList();
                                        },
                                        onChanged: (value) {
                                          setState(() {
                                            selectedAlamatPerusahaan = value;
                                            alamatPerusahaanController.text =
                                                value ?? '';
                                          });
                                        },
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: unitController,
                                        decoration: const InputDecoration(
                                          labelText: 'Unit *',
                                          prefixIcon:
                                              Icon(Icons.account_tree_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Karyawan ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.account_circle,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Data Karyawan',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Color(0xFF1572E8),
                                              ),
                                              maxLines: 2, // Maksimal 2 baris
                                              overflow: TextOverflow.ellipsis,
                                              // Jika lebih dari 2 baris, tampilkan ...
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaKaryawanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Karyawan *',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        autovalidateMode: AutovalidateMode
                                            .onUserInteraction, // Tambahkan ini
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller:
                                            tempatLahirKaryawanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tempat Lahir Karyawan *',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller:
                                            tanggalLahirKaryawanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Lahir Karyawan *',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _parseDateFlexible(
                                                        tanggalLahirKaryawanController
                                                            .text) ??
                                                    DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                            tanggalLahirKaryawanController
                                                    .text =
                                                _formatDateForDisplay(picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: alamatKaryawanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Alamat Karyawan *',
                                          prefixIcon: Icon(Icons.home_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tglMulaiKerjaController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Mulai Kerja *',
                                          prefixIcon:
                                              Icon(Icons.date_range_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: jabatanTerakhirController,
                                        decoration: const InputDecoration(
                                          labelText: 'Jabatan Terakhir *',
                                          prefixIcon:
                                              Icon(Icons.work_history_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: sectionController,
                                        decoration: const InputDecoration(
                                          labelText: 'Section *',
                                          prefixIcon:
                                              Icon(Icons.layers_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tanggalSuratController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Surat',
                                          prefixIcon:
                                              Icon(Icons.event_note_outlined),
                                        ),
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Pasangan (WAJIB) ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.family_restroom,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Pasangan',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaPasanganController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Pasangan *',
                                          prefixIcon:
                                              Icon(Icons.person_2_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: statusPasanganController,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Status Pasangan (Suami/Istri) *',
                                          prefixIcon: Icon(Icons.transgender),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller:
                                            tempatLahirPasanganController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tempat Lahir Pasangan *',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller:
                                            tanggalLahirPasanganController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Lahir Pasangan *',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _parseDateFlexible(
                                                        tanggalLahirPasanganController
                                                            .text) ??
                                                    DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                            tanggalLahirPasanganController
                                                    .text =
                                                _formatDateForDisplay(picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 1 (Opsional) ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'Data Anak Pertama (Opsional)',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Color(0xFF1572E8),
                                              ),
                                              maxLines: 2, // Maksimal 2 baris
                                              overflow: TextOverflow.ellipsis,
                                              // Jika lebih dari 2 baris, tampilkan ...
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak1Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Pertama',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: TextEditingController(
                                            text: 'Anak Pertama'),
                                        decoration: const InputDecoration(
                                          labelText: 'Hubungan Anak Pertama',
                                          prefixIcon:
                                              Icon(Icons.group_outlined),
                                        ),
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: ttlAnak1Controller,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Tanggal Lahir Anak Pertama',
                                                prefixIcon:
                                                    Icon(Icons.cake_outlined),
                                              ),
                                              onTap: () async {
                                                FocusScope.of(context)
                                                    .requestFocus(FocusNode());
                                                DateTime? picked =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (picked != null) {
                                                  ttlAnak1Controller.text =
                                                      _formatDateForDisplay(
                                                          picked);
                                                }
                                              },
                                              readOnly: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 2 (Opsional) ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Anak Kedua (Opsional)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak2Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Kedua',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: TextEditingController(
                                            text: 'Anak Kedua'),
                                        decoration: const InputDecoration(
                                          labelText: 'Hubungan Anak Kedua',
                                          prefixIcon:
                                              Icon(Icons.group_outlined),
                                        ),
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: ttlAnak2Controller,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Tanggal Lahir Anak Kedua',
                                                prefixIcon:
                                                    Icon(Icons.cake_outlined),
                                              ),
                                              onTap: () async {
                                                FocusScope.of(context)
                                                    .requestFocus(FocusNode());
                                                DateTime? picked =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (picked != null) {
                                                  ttlAnak2Controller.text =
                                                      _formatDateForDisplay(
                                                          picked);
                                                }
                                              },
                                              readOnly: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 3 (Opsional) ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Anak Ketiga (Opsional)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak3Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Ketiga',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: TextEditingController(
                                            text: 'Anak Ketiga'),
                                        decoration: const InputDecoration(
                                          labelText: 'Hubungan Anak Ketiga',
                                          prefixIcon:
                                              Icon(Icons.group_outlined),
                                        ),
                                        enabled: false,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: ttlAnak3Controller,
                                              decoration: const InputDecoration(
                                                labelText:
                                                    'Tanggal Lahir Anak Ketiga',
                                                prefixIcon:
                                                    Icon(Icons.cake_outlined),
                                              ),
                                              onTap: () async {
                                                FocusScope.of(context)
                                                    .requestFocus(FocusNode());
                                                DateTime? picked =
                                                    await showDatePicker(
                                                  context: context,
                                                  initialDate: DateTime.now(),
                                                  firstDate: DateTime(1900),
                                                  lastDate: DateTime.now(),
                                                );
                                                if (picked != null) {
                                                  ttlAnak3Controller.text =
                                                      _formatDateForDisplay(
                                                          picked);
                                                }
                                              },
                                              readOnly: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Tombol Kirim Data
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: isSending
                                    ? null
                                    : () async {
                                        if (_formKey.currentState?.validate() ??
                                            false) {
                                          setState(() {
                                            isSending = true;
                                          });
                                          try {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            final idEmployee =
                                                prefs.getInt('idEmployee');
                                            if (idEmployee == null) {
                                              throw Exception(
                                                  'ID Employee tidak ditemukan. Harap login ulang.');
                                            }

                                            // --- Ganti showDialog loading menjadi versi normal bawaan Flutter ---
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => AlertDialog(
                                                content: Row(
                                                  children: const [
                                                    SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                    SizedBox(width: 20),
                                                    Expanded(
                                                      child: Text(
                                                        'Mohon tunggu, surat sedang diproses...',
                                                        style: TextStyle(
                                                            fontSize: 15),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );

final response = await ApiService.post(
  'http://34.50.112.226:5555/api/Medical/generate-medical-document?jenisSurat=keterangan',
  data: {
    "{{id_employee}}": idEmployee.toString(),
    "{{nama_pemberi_keterangan}}": namaAtasanController.text,
    "{{jabatan_pemberi_keterangan}}": jabatanAtasanController.text,
    "{{nama_perusahaan}}": namaPerusahaanController.text,
    "{{alamat_perusahaan}}": alamatPerusahaanController.text,
    "{{nama_pegawai}}": namaKaryawanController.text,
    "{{tempat_lahir_pegawai}}": tempatLahirKaryawanController.text,
    "{{tanggal_lahir_pegawai}}": tanggalLahirKaryawanController.text,
    "{{alamat_pegawai}}": alamatKaryawanController.text,
    "{{tanggal_mulai_kerja}}": tglMulaiKerjaController.text,
    "{{jabatan_terakhir}}": jabatanTerakhirController.text,
    "{{section}}": sectionController.text,
    "{{status_pasangan}}": statusPasanganController.text,
    "{{nama_suami}}": statusPasanganController.text.toLowerCase() == "istri" ? "" : namaPasanganController.text,
    "{{ttl_suami}}": statusPasanganController.text.toLowerCase() == "istri" ? "" : tanggalLahirPasanganController.text,
    "{{nama_pasangan}}": statusPasanganController.text.toLowerCase() == "istri" ? namaPasanganController.text : "",
    "{{ttl_pasangan}}": statusPasanganController.text.toLowerCase() == "istri" ? tanggalLahirPasanganController.text : "",
    "{{nama_anak1}}": namaAnak1Controller.text,
    "{{ttl_anak1}}": ttlAnak1Controller.text,
    "{{nama_anak2}}": namaAnak2Controller.text,
    "{{ttl_anak2}}": ttlAnak2Controller.text,
    "{{nama_anak3}}": namaAnak3Controller.text,
    "{{ttl_anak3}}": ttlAnak3Controller.text,
    "{{Unit}}": unitController.text,
    "{{departement}}": sectionController.text,
  },
  headers: {
    'accept': '*/*',
    'Content-Type': 'application/json',
  },
  responseType: ResponseType.bytes,
);

                                            Navigator.of(context)
                                                .pop(); // Tutup dialog loading

if (response.statusCode == 200) {
  // Gunakan nama file unik, misal: medical_{idEmployee}_{timestamp}.pdf
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final fileName = 'medical_${idEmployee}_$timestamp.pdf';

  // Gunakan path_provider agar aman di Android 13-15
  final directory = Directory('/storage/emulated/0/Download');
  if (!directory.existsSync()) {
    directory.createSync(recursive: true);
  }
  final filePath = '${directory.path}/$fileName';
  final file = File(filePath);
  await file.writeAsBytes(response.data!);

  setState(() {
    isDownloaded = true;
    isLoadingDownload = false;
    isDownloadEnabled = true;
  });

  FocusScope.of(context).unfocus();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('File berhasil didownload ke $filePath')),
  );

  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (context) => const MedicPasutriPage(),
    ),
  );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Gagal mengirim data: ${response.statusCode}')),
                                              );
                                            }
                                          } catch (e) {
                                            Navigator.of(context)
                                                .pop(); // Tutup dialog loading jika error
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Terjadi kesalahan: $e')),
                                            );
                                          } finally {
                                            setState(() {
                                              isSending = false;
                                            });
                                          }
                                        } else {
                                          // Tampilkan popup jika ada field wajib yang belum diisi
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title:
                                                  const Text('Lengkapi Data'),
                                              content: const Text(
                                                  'Silakan lengkapi semua data yang wajib diisi sebelum mengirim.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('OK'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.description,
                                    color: Colors.white),
                                label: const Text(
                                  'Buat Surat Keterangan',
                                  style: TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Keterangan di bawah tombol kirim data
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Data yang Anda isi akan dimasukkan ke dalam surat keterangan.',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // =====================
                      // FORM SURAT PERNYATAAN
                      // =====================
                      if (selectedJenisSurat == 'pernyataan')
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // === Data Pegawai ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.account_circle,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              'Data Pegawai',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 17,
                                                color: Color(0xFF1572E8),
                                              ),
                                              maxLines: 2, // Maksimal 2 baris
                                              overflow: TextOverflow.ellipsis,
                                              // Jika lebih dari 2 baris, tampilkan ...
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaKaryawanController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Pegawai *',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller:
                                            nikController, // <- Buat controller baru di atas, ya!
                                        decoration: const InputDecoration(
                                          labelText: 'NIK *',
                                          prefixIcon:
                                              Icon(Icons.badge_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: plandivController,
                                        decoration: const InputDecoration(
                                          labelText: 'Plandiv *',
                                          prefixIcon: Icon(Icons.business),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: departementController,
                                        decoration: const InputDecoration(
                                          labelText: 'Departement *',
                                          prefixIcon: Icon(Icons.apartment),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tahunController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tahun',
                                          prefixIcon:
                                              Icon(Icons.calendar_today),
                                        ),
                                        readOnly: true,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Suami ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.family_restroom,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Suami',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaSuamiController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Suami *',
                                          prefixIcon:
                                              Icon(Icons.person_2_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tempatLahirSuamiController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tempat Lahir Suami *',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tanggalLahirSuamiController,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Lahir Suami *',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: _parseDateFlexible(
                                                    tanggalLahirSuamiController
                                                        .text) ??
                                                DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                            tanggalLahirSuamiController.text =
                                                _formatDateForDisplay(picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: bidangUsahaController,
                                        decoration: const InputDecoration(
                                          labelText: 'Bidang Usaha/Jasa *',
                                          prefixIcon: Icon(Icons.work_outline),
                                        ),
                                        validator: (v) => v == null || v.isEmpty
                                            ? 'Wajib diisi'
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 1 ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Anak Pertama',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak1Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Pertama',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tempatLahirAnak1Controller,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Tempat Lahir Anak Pertama',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: ttlAnak1Controller,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Tanggal Lahir Anak Pertama',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                                ttlAnak1Controller.text =
                                                    _formatDateForDisplay(
                                                        picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: pendidikanAnak1Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Pendidikan Anak Pertama',
                                          prefixIcon:
                                              Icon(Icons.school_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 2 ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Anak Kedua',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak2Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Kedua',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tempatLahirAnak2Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Tempat Lahir Anak Kedua',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: ttlAnak2Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Tanggal Lahir Anak Kedua',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                                ttlAnak2Controller.text =
                                                    _formatDateForDisplay(
                                                        picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: pendidikanAnak2Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Pendidikan Anak Kedua',
                                          prefixIcon:
                                              Icon(Icons.school_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // === Data Anak 3 ===
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: const [
                                          Icon(Icons.child_care,
                                              color: Color(0xFF1572E8)),
                                          SizedBox(width: 8),
                                          Text(
                                            'Data Anak Ketiga',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                              color: Color(0xFF1572E8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Divider(height: 24),
                                      TextFormField(
                                        controller: namaAnak3Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Nama Anak Ketiga',
                                          prefixIcon:
                                              Icon(Icons.person_outline),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: tempatLahirAnak3Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Tempat Lahir Anak Ketiga',
                                          prefixIcon:
                                              Icon(Icons.place_outlined),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: ttlAnak3Controller,
                                        decoration: const InputDecoration(
                                          labelText:
                                              'Tanggal Lahir Anak Ketiga',
                                          prefixIcon: Icon(Icons.cake_outlined),
                                        ),
                                        onTap: () async {
                                          FocusScope.of(context)
                                              .requestFocus(FocusNode());
                                          DateTime? picked =
                                              await showDatePicker(
                                            context: context,
                                            initialDate: DateTime.now(),
                                            firstDate: DateTime(1900),
                                            lastDate: DateTime.now(),
                                          );
                                          if (picked != null) {
                                                ttlAnak3Controller.text =
                                                    _formatDateForDisplay(
                                                        picked);
                                          }
                                        },
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        controller: pendidikanAnak3Controller,
                                        decoration: const InputDecoration(
                                          labelText: 'Pendidikan Anak Ketiga',
                                          prefixIcon:
                                              Icon(Icons.school_outlined),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Tombol Kirim Data
                              const SizedBox(height: 20),
                              ElevatedButton.icon(
                                onPressed: isSending
                                    ? null
                                    : () async {
                                        if (_formKey.currentState?.validate() ??
                                            false) {
                                          setState(() {
                                            isSending = true;
                                          });
                                          try {
                                            final prefs =
                                                await SharedPreferences
                                                    .getInstance();
                                            final idEmployee =
                                                prefs.getInt('idEmployee');
                                            if (idEmployee == null) {
                                              throw Exception(
                                                  'ID Employee tidak ditemukan. Harap login ulang.');
                                            }

                                            // Tampilkan loading dialog
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (context) => AlertDialog(
                                                content: Row(
                                                  children: const [
                                                    SizedBox(
                                                      width: 28,
                                                      height: 28,
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                    SizedBox(width: 20),
                                                    Expanded(
                                                      child: Text(
                                                        'Mohon tunggu, surat sedang diproses...',
                                                        style: TextStyle(
                                                            fontSize: 15),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );

                                            // Tentukan endpoint dan data sesuai jenis surat
                                            String jenisSurat =
                                                selectedJenisSurat ??
                                                    'keterangan';
                                            String url =
                                                'http://34.50.112.226:5555/api/Medical/generate-medical-document?jenisSurat=$jenisSurat';

Map<String, dynamic> data;
if (jenisSurat == 'pernyataan') {
  data = {
    "{{nama_pegawai}}": namaKaryawanController.text.trim().isEmpty ? "{{}}" : namaKaryawanController.text.trim(),
    "{{nik_pegawai}}": nikController.text.trim().isEmpty ? "{{}}" : nikController.text.trim(),
    "{{plandiv}}": plandivController.text.trim().isEmpty ? "{{}}" : plandivController.text.trim(),
    "{{departement}}": departementController.text.trim().isEmpty ? "{{}}" : departementController.text.trim(),
    "{{tanggal_suami}}": tanggalLahirSuamiController.text.trim().isEmpty ? "{{}}" : tanggalLahirSuamiController.text.trim(),
    "{{nama_suami}}": namaSuamiController.text.trim().isEmpty ? "{{}}" : namaSuamiController.text.trim(),
    "{{tempat_lahir_suami}}": tempatLahirSuamiController.text.trim().isEmpty ? "{{}}" : tempatLahirSuamiController.text.trim(),
    "{{ttl_suami}}": tanggalLahirSuamiController.text.trim().isEmpty ? "{{}}" : tanggalLahirSuamiController.text.trim(),
    "{{usaha_suami}}": bidangUsahaController.text.trim().isEmpty ? "{{}}" : bidangUsahaController.text.trim(),
    "{{nama_anak1}}": namaAnak1Controller.text.trim().isEmpty ? "" : namaAnak1Controller.text.trim(),
    "{{tempat_lahir_anak1}}": tempatLahirAnak1Controller.text.trim().isEmpty ? "" : tempatLahirAnak1Controller.text.trim(),
    "{{ttl_anak1}}": ttlAnak1Controller.text.trim().isEmpty ? "" : ttlAnak1Controller.text.trim(),
    "{{Pendidikan_anak1}}": pendidikanAnak1Controller.text.trim().isEmpty ? "" : pendidikanAnak1Controller.text.trim(),
    "{{nama_anak2}}": namaAnak2Controller.text.trim().isEmpty ? "" : namaAnak2Controller.text.trim(),
    "{{tempat_lahir_anak2}}": tempatLahirAnak2Controller.text.trim().isEmpty ? "" : tempatLahirAnak2Controller.text.trim(),
    "{{ttl_anak2}}": ttlAnak2Controller.text.trim().isEmpty ? "" : ttlAnak2Controller.text.trim(),
    "{{Pendidikan_anak2}}": pendidikanAnak2Controller.text.trim().isEmpty ? "" : pendidikanAnak2Controller.text.trim(),
    "{{nama_anak3}}": namaAnak3Controller.text.trim().isEmpty ? "" : namaAnak3Controller.text.trim(),
    "{{tempat_lahir_anak3}}": tempatLahirAnak3Controller.text.trim().isEmpty ? "" : tempatLahirAnak3Controller.text.trim(),
    "{{ttl_anak3}}": ttlAnak3Controller.text.trim().isEmpty ? "" : ttlAnak3Controller.text.trim(),
    "{{Pendidikan_anak3}}": pendidikanAnak3Controller.text.trim().isEmpty ? "" : pendidikanAnak3Controller.text.trim(),
    "{{Unit}}": unitController.text.trim().isEmpty ? "       " : unitController.text.trim(),
  };
} else {
  data = {
    // ...mapping untuk keterangan seperti sebelumnya
  };
}

final response = await ApiService.post(
  url,
  data: data,
  headers: {
    'accept': '*/*',
    'Content-Type': 'application/json',
  },
  responseType: ResponseType.bytes, // <-- Tambahkan ini
);

                                            Navigator.of(context)
                                                .pop(); // Tutup dialog loading

                                            if (response.statusCode == 200) {
                                              final directory = Directory(
                                                  '/storage/emulated/0/Download');
                                              if (!directory.existsSync()) {
                                                directory.createSync(
                                                    recursive: true);
                                              }
                                              // --- Ganti baris ini:
                                              final filePath =
                                                  '${directory.path}/medical_${randomString(8)}.pdf';
                                              final file = File(filePath);
                                              await file
                                                  .writeAsBytes(response.data!);

                                              setState(() {
                                                isDownloaded = true;
                                                isLoadingDownload = false;
                                                isDownloadEnabled = true;
                                              });

                                              FocusScope.of(context).unfocus();

                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'File berhasil didownload ke $filePath')),
                                              );

                                              // Reload halaman setelah download selesai
                                              Navigator.of(context)
                                                  .pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const MedicPasutriPage(),
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text(
                                                        'Gagal mengirim data: ${response.statusCode}')),
                                              );
                                            }
                                          } catch (e) {
                                            Navigator.of(context)
                                                .pop(); // Tutup dialog loading jika error
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Terjadi kesalahan: $e')),
                                            );
                                          } finally {
                                            setState(() {
                                              isSending = false;
                                            });
                                          }
                                        } else {
                                          // Tampilkan popup jika ada field wajib yang belum diisi
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title:
                                                  const Text('Lengkapi Data'),
                                              content: const Text(
                                                  'Silakan lengkapi semua data yang wajib diisi sebelum mengirim.'),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(),
                                                  child: const Text('OK'),
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                icon: const Icon(Icons.description,
                                    color: Colors.white),
                                label: Text(
                                  selectedJenisSurat == 'pernyataan'
                                      ? 'Buat Surat Pernyataan'
                                      : 'Buat Surat Keterangan',
                                  style: const TextStyle(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size(double.infinity, 50),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 8),

                              // Keterangan di bawah tombol kirim data
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Icon(Icons.info_outline,
                                      color: Colors.blue, size: 18),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Data yang Anda isi akan dimasukkan ke dalam surat pernyataan.',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                      // Card untuk upload file PDF
Card(
  margin: const EdgeInsets.only(bottom: 16),
  elevation: 2,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  child: Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: const [
            Icon(Icons.upload_file, color: Color(0xFF1572E8)),
            SizedBox(width: 8),
            Text(
              'Upload Surat Medic',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17,
                color: Color(0xFF1572E8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: selectedJenisSuratUpload,
          decoration: InputDecoration(
            labelText: 'Pilih Jenis Surat untuk Upload',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            prefixIcon: const Icon(Icons.description),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: const [
            DropdownMenuItem(
              value: 'pernyataan',
              child: Text('Surat Pernyataan'),
            ),
            DropdownMenuItem(
              value: 'keterangan',
              child: Text('Surat Keterangan'),
            ),
          ],
          onChanged: isUploading
              ? null
              : (value) {
                  setState(() {
                    selectedJenisSuratUpload = value;
                  });
                },
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: isUploading
              ? null
              : () async {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
                  );
                  if (result != null && result.files.single.path != null) {
                    setState(() {
                      uploadedFile = File(result.files.single.path!);
                    });
                  }
                },
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: uploadedFile != null ? Colors.green : const Color(0xFF1572E8),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1572E8),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: uploadedFile == null
                      ? const Icon(Icons.upload_file, size: 30, color: Colors.white)
                      : (uploadedFile!.path.toLowerCase().endsWith('.pdf')
                          ? const Icon(Icons.picture_as_pdf, size: 30, color: Colors.white)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                uploadedFile!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              ),
                            )),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        uploadedFile != null
                            ? basename(uploadedFile!.path)
                            : 'Belum ada file yang dipilih',
                        style: TextStyle(
                          fontSize: 15,
                          color: uploadedFile != null ? Colors.black87 : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (uploadedFile != null)
                        const Text(
                          'File siap diunggah',
                          style: TextStyle(fontSize: 12, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload, color: Colors.white),
            label: Text(
              isUploading ? 'Mengunggah...' : 'Upload File',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1572E8),
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 2,
            ),
onPressed: isUploading
    ? null
    : () async {
        if (uploadedFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Silakan pilih file terlebih dahulu')),
          );
          return;
        }
        if (selectedJenisSuratUpload == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pilih jenis surat terlebih dahulu')),
          );
          return;
        }
        setState(() {
          isUploading = true;
        });
        try {
          final idEmployee = await getIdEmployee();
          if (idEmployee == null) {
            throw Exception('ID Employee tidak ditemukan. Harap login ulang.');
          }
          final formData = FormData.fromMap({
            'file': await MultipartFile.fromFile(
              uploadedFile!.path,
              filename: basename(uploadedFile!.path),
            ),
            'idEmployee': idEmployee,
            'jenisSurat': selectedJenisSuratUpload,
          });
          final response = await ApiService.post(
            'http://34.50.112.226:5555/api/Medical/upload',
            data: formData,
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          );
          if (response.statusCode == 200) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Column(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.green, size: 48),
                    SizedBox(height: 8),
                    Text('Upload Berhasil'),
                  ],
                ),
                content: const Text(
                  'File berhasil diupload!',
                  textAlign: TextAlign.center,
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
            setState(() {
              uploadedFile = null;
              selectedJenisSuratUpload = null;
            });
          } else {
            throw Exception('Gagal mengunggah file: ${response.statusCode}');
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal upload file: $e')),
          );
        } finally {
          setState(() {
            isUploading = false;
          });
        }
      },
          ),
        ),
      ],
    ),
  ),
),
                    ],
                  ),
                ),
              ),
            ]),
          ),
        ));
  }
  }
  
