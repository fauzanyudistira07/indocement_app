import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:indocement_apk/service/api_service.dart';

int? _lastKnownId; // Simpan ID terakhir yang sudah dikirim notif

Future<void> uploadBpjsDocument({
  required int idEmployee,
  required String anggotaBpjs,
  required String fieldName, // contoh: urlKk atau urlSuratNikah
  required File file,
}) async {
  final uri = Uri.parse('http://34.50.112.226:5555/api/Bpjs/upload');

  var request = http.MultipartRequest('POST', uri);
  request.fields['idEmployee'] = idEmployee.toString();
  request.fields['anggotaBpjs'] = anggotaBpjs;
  request.fields[fieldName] = file.path;

  request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

  print("Fields: ${request.fields}");
  print("Files: ${request.files.map((f) => f.filename).toList()}");

  var response = await request.send();

  if (response.statusCode == 200) {
    print("Upload berhasil!");
  } else {
    print("Gagal upload: ${response.statusCode}");
  }
}

Future<void> uploadBpjsDocumentAsPdf({
  required int idEmployee,
  required String anggotaBpjs,
  required String fieldName, // contoh: urlKk atau urlSuratNikah
  required File file,
}) async {
  try {
    // 1. Kompres gambar
    final compressedImage = await _compressImage(file);

    // Konversi XFile menjadi File
    final compressedFile = File(compressedImage.path);

    // 2. Konversi gambar menjadi PDF
    final pdfFile = await _convertImageToPdf(compressedFile);

    // 3. Kirim PDF ke API
    final uri = Uri.parse('http://34.50.112.226:5555/api/Bpjs/upload');
    var request = http.MultipartRequest('POST', uri);
    request.fields['idEmployee'] = idEmployee.toString();
    request.fields['anggotaBpjs'] = anggotaBpjs;
    request.fields['tglPengajuan'] = DateTime.now().toIso8601String();
    request.files
        .add(await http.MultipartFile.fromPath(fieldName, pdfFile.path));

    print("Fields: ${request.fields}");
    print("Files: ${request.files.map((f) => f.filename).toList()}");

    var response = await request.send();

    if (response.statusCode == 200) {
      print("✅ Upload berhasil!");
    } else {
      print("❌ Gagal upload: ${response.statusCode}");
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
  }
}

// Contoh refactor uploadBpjsDocumentCompressed agar pakai ApiService (token otomatis)
Future<void> uploadBpjsDocumentCompressed({
  required int idEmployee,
  required String anggotaBpjs,
  required String fieldName,
  required File file,
}) async {
  try {
    // Kompres gambar (jika perlu)
    final compressedImage = await _compressImage(file);
    final compressedFile = File(compressedImage.path);

    final formData = FormData.fromMap({
      'idEmployee': idEmployee.toString(),
      'anggotaBpjs': anggotaBpjs,
      'fieldName': fieldName,
      'Files': await MultipartFile.fromFile(compressedFile.path, filename: basename(compressedFile.path)),
      'FileTypes': fieldName,
    });

    final response = await ApiService.post(
      'http://34.50.112.226:5555/api/Bpjs/upload',
      data: formData,
      headers: {
        'Content-Type': 'multipart/form-data',
      },
    );

    if (response.statusCode == 200) {
      print("✅ Upload berhasil!");
      // Ambil ID BPJS terbaru untuk idSource
      final bpjsResp = await ApiService.get(
        'http://34.50.112.226:5555/api/Bpjs',
        params: {'idEmployee': idEmployee},
      );
      if (bpjsResp.statusCode == 200) {
        final List<dynamic> bpjsData = bpjsResp.data;
        final matchingEntry = bpjsData.lastWhere(
          (item) =>
              item['IdEmployee'] == idEmployee &&
              item['AnggotaBpjs'] == anggotaBpjs,
          orElse: () => null,
        );
        if (matchingEntry != null) {
          final matchingId = matchingEntry['Id'];
          await sendBpjsNotification(
            idEmployee: idEmployee,
            idSource: matchingId,
          );
        }
      }
    } else {
      print("❌ Gagal upload: ${response.statusCode}");
      print("Respons: ${response.data}");
      throw Exception("Gagal upload: ${response.data}");
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
    rethrow;
  }
}

Future<void> uploadBpjsDocumentsCompressed({
  required int idEmployee,
  required String anggotaBpjs,
  required List<String> fieldNames,
  required List<File> files,
  String? anakKe,
}) async {
  try {
    if (files.isEmpty || fieldNames.isEmpty) {
      throw Exception("Files dan FileTypes tidak boleh kosong.");
    }

    if (files.length != fieldNames.length) {
      throw Exception("Jumlah Files dan FileTypes harus sama.");
    }

    final uri = Uri.parse('http://34.50.112.226:5555/api/Bpjs/upload');
    var request = http.MultipartRequest('POST', uri);

    // Tambahkan field ke request
    request.fields['IdEmployee'] = idEmployee.toString();
    request.fields['AnggotaBpjs'] = anggotaBpjs;
    request.fields['TglPengajuan'] = DateTime.now().toIso8601String();

    if (anakKe != null) {
      request.fields['AnakKe'] = anakKe;
    }

    // Tambahkan file dan tipe file
    for (int i = 0; i < files.length; i++) {
      request.files
          .add(await http.MultipartFile.fromPath('Files', files[i].path));
      request.fields['FileTypes[$i]'] =
          fieldNames[i]; // Format array untuk FileTypes
    }

    print("Fields: ${request.fields}");
    print("Files: ${request.files.map((f) => f.filename).toList()}");

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print("✅ Upload berhasil!");
    } else {
      print("❌ Gagal upload: ${response.statusCode}");
      print("Respons: $responseBody");
      throw Exception("Gagal upload: $responseBody");
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
    rethrow;
  }
}

Future<void> uploadBpjsDocuments({
  required int idEmployee,
  required String anggotaBpjs,
  required List<Map<String, dynamic>> documents,
  String? anakKe,
}) async {
  try {
    // Ambil data dari API untuk mendapatkan ID yang sesuai
    final response = await ApiService.get(
      'http://34.50.112.226:5555/api/Bpjs',
      params: {'idEmployee': idEmployee},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = response.data;

      // Cari ID yang sesuai dengan AnggotaBpjs dan AnakKe (jika ada)
      final matchingEntry = data.firstWhere(
        (item) =>
            item['IdEmployee'] == idEmployee &&
            item['AnggotaBpjs'] == anggotaBpjs &&
            (anakKe == null || item['AnakKe'] == anakKe),
        orElse: () => null,
      );

      if (matchingEntry == null) {
        throw Exception(
            'Data untuk ID Employee dan kategori BPJS tidak ditemukan.');
      }

      final matchingId = matchingEntry['Id']; // Ambil ID yang sesuai

      // Siapkan data untuk dikirim ke API
      final formData = FormData();
      for (var doc in documents) {
        formData.files.add(MapEntry(
          doc['fieldName'],
          await MultipartFile.fromFile(
            (doc['file'] as File).path,
            filename: basename((doc['file'] as File).path),
          ),
        ));
      }
      formData.fields.add(MapEntry('idEmployee', idEmployee.toString()));
      formData.fields.add(MapEntry('anggotaBpjs', anggotaBpjs));
      if (anakKe != null) {
        formData.fields.add(MapEntry('anakKe', anakKe));
      }

      // Kirim data ke API dengan endpoint dinamis
      final uploadResponse = await ApiService.put(
        'http://34.50.112.226:5555/api/Bpjs/upload/$matchingId',
        data: formData,
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      );

      if (uploadResponse.statusCode == 200) {
        print("✅ Dokumen berhasil diunggah ke ID $matchingId");
        await sendBpjsNotification(
          idEmployee: idEmployee,
          idSource: matchingId,
        );
      } else {
        throw Exception(
            "Gagal upload: ${uploadResponse.statusCode}, Respons: ${uploadResponse.data}");
      }
    } else {
      throw Exception('Gagal memuat data dari API: ${response.statusCode}');
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
    rethrow;
  }
}

Future<void> uploadBpjsDocumentsMultipart({
  required int idEmployee,
  required String anggotaBpjs,
  String? anakKe,
  File? urlKk,
  File? urlSuratNikah,
  File? urlAkteLahir,
  File? urlSuratPotongGaji,
}) async {
  try {
    final uri = Uri.parse('http://34.50.112.226:5555/api/Bpjs/upload');
    var request = http.MultipartRequest('POST', uri);

    // Tambahkan field ke request
    request.fields['IdEmployee'] = idEmployee.toString();
    request.fields['AnggotaBpjs'] = anggotaBpjs;
    request.fields['TglPengajuan'] = DateTime.now().toIso8601String();
    request.fields['AnakKe'] = anakKe ?? "";

    // Tambahkan file jika ada
    if (urlKk != null) {
      request.files.add(await http.MultipartFile.fromPath('UrlKk', urlKk.path));
    }
    if (urlSuratNikah != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'UrlSuratNikah', urlSuratNikah.path));
    }
    if (urlAkteLahir != null) {
      request.files.add(
          await http.MultipartFile.fromPath('UrlAkteLahir', urlAkteLahir.path));
    }
    if (urlSuratPotongGaji != null) {
      request.files.add(await http.MultipartFile.fromPath(
          'UrlSuratPotongGaji', urlSuratPotongGaji.path));
    }

    print("Fields: ${request.fields}");
    print("Files: ${request.files.map((f) => f.filename).toList()}");

    var response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      print("✅ Upload berhasil!");
    } else {
      print("❌ Gagal upload: ${response.statusCode}");
      print("Respons: $responseBody");
      throw Exception("Gagal upload: $responseBody");
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
    rethrow;
  }
}

Future<void> updateBpjsDocuments({
  required int idEmployee,
  String? anggotaBpjs,
  String? anakKe,
  String? urlKk,
  String? urlSuratNikah,
  String? urlAkteLahir,
  String? urlSuratPotongGaji,
}) async {
  try {
    final uri = Uri.parse('http://34.50.112.226:5555/api/Bpjs/update');
    final body = {
      "IdEmployee": idEmployee,
      "AnggotaBpjs": anggotaBpjs ?? "",
      "AnakKe": anakKe ?? "",
      "UrlKk": urlKk ?? "",
      "UrlSuratNikah": urlSuratNikah ?? "",
      "UrlAkteLahir": urlAkteLahir ?? "",
      "UrlSuratPotongGaji": urlSuratPotongGaji ?? "",
      "UpdatedAt": DateTime.now().toIso8601String(),
    };

    print("Payload: ${jsonEncode(body)}");

    final response = await http.put(
      uri,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      print("✅ Update berhasil!");
    } else {
      print("❌ Gagal update: ${response.statusCode}");
      print("Respons: ${response.body}");
      throw Exception("Gagal update: ${response.body}");
    }
  } catch (e) {
    print("❌ Terjadi kesalahan: $e");
    rethrow;
  }
}

// Fungsi untuk mengompres gambar
Future<XFile> _compressImage(File file) async {
  final dir = await getTemporaryDirectory();
  final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

  final compressedFile = await FlutterImageCompress.compressAndGetFile(
    file.absolute.path,
    targetPath,
    quality: 70, // Sesuaikan kualitas kompresi
  );

  if (compressedFile == null) {
    throw Exception("Gagal mengompres gambar");
  }

  return compressedFile;
}

// Fungsi untuk mengonversi gambar menjadi PDF
Future<File> _convertImageToPdf(File imageFile) async {
  final pdf = pw.Document();

  final image = pw.MemoryImage(imageFile.readAsBytesSync());
  pdf.addPage(
    pw.Page(
      build: (pw.Context context) => pw.Center(
        child: pw.Image(image),
      ),
    ),
  );

  final dir = await getTemporaryDirectory();
  final pdfPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.pdf';
  final pdfFile = File(pdfPath);

  await pdfFile.writeAsBytes(await pdf.save());
  return pdfFile;
}

Future<void> sendBpjsNotification({
  required int idEmployee,
  required int idSource,
}) async {
  // Ambil IdSection dari Employees
  final empResponse = await http.get(
    Uri.parse('http://34.50.112.226:5555/api/Employees?id=$idEmployee'),
  );
  if (empResponse.statusCode == 200) {
    final List<dynamic> empData = jsonDecode(empResponse.body);
    if (empData.isNotEmpty) {
      final idSection = empData[0]['IdSection'];
      final notifBody = jsonEncode({
        "IdSection": idSection,
        "IdSource": idSource,
        "Status": "Diajukan",
        "Source": "Bpjs",
        "CreatedAt": DateTime.now().toIso8601String(), // Tambahkan tanggal kirim
      });
      print("🔔 Mengirim notifikasi BPJS: $notifBody");
      final notifResp = await http.post(
        Uri.parse('http://34.50.112.226:5555/api/Notifications'),
        headers: {
          'accept': 'text/plain',
        },
        body: notifBody,
      );
      print(
          "🔔 Response notifikasi: ${notifResp.statusCode} - ${notifResp.body}");
      if (notifResp.statusCode == 200 || notifResp.statusCode == 201) {
        print("✅ Notifikasi BPJS terkirim!");
      } else {
        print("❌ Gagal kirim notifikasi: ${notifResp.statusCode}");
      }
    }
  }
}

Future<void> startBpjsWatcher() async {
  print("⏳ BPJS Watcher dimulai...");
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    try {
      print("🔎 Mengecek data BPJS terbaru di /api/Bpjs/29 ...");
      final resp =
          await http.get(Uri.parse('http://34.50.112.226:5555/api/Bpjs/29'));
      print("📥 Response watcher: ${resp.statusCode} - ${resp.body}");
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        if (data is Map && data['Id'] != null) {
          final int currentId = data['Id'];
          print("🆔 Ditemukan Id BPJS: $currentId (lastKnown: $_lastKnownId)");
          // Filter: hanya untuk pasangan atau anak ke
          final anggotaBpjs = data['AnggotaBpjs']?.toString().toLowerCase();
          final anakKe = data['AnakKe'];
          final isPasangan = anggotaBpjs == 'pasangan';
          final isAnak = anggotaBpjs == 'anak' &&
              anakKe != null &&
              anakKe.toString().isNotEmpty &&
              anakKe.toString() != '0';

          if ((isPasangan || isAnak) &&
              (_lastKnownId == null || currentId != _lastKnownId)) {
            _lastKnownId = currentId;
            print(
                "🔔 Ada data BPJS baru untuk pasangan/anak dengan Id: $currentId, mengirim notifikasi...");
            await sendBpjsNotificationWatcher(data);
          } else {
            print(
                "ℹ️ Data BPJS bukan pasangan/anak atau belum ada data baru, tidak mengirim notifikasi.");
          }
        } else {
          print("⚠️ Data BPJS tidak valid atau tidak ada Id.");
        }
      } else {
        print("❌ Gagal mendapatkan data BPJS: ${resp.statusCode}");
      }
    } catch (e) {
      print("❌ Error watcher BPJS: $e");
    }
  });
}

Future<void> sendBpjsNotificationWatcher(Map data) async {
  final idEmployee = data['IdEmployee'];
  if (idEmployee == null) {
    print(
        "❌ [Watcher] Tidak ada IdEmployee pada data BPJS, notifikasi dibatalkan.");
    return;
  }

  // Ambil IdSection dari Employees sesuai idEmployee pada data BPJS
  final empResponse = await http.get(
    Uri.parse('http://34.50.112.226:5555/api/Employees?id=$idEmployee'),
  );
  if (empResponse.statusCode == 200) {
    final List<dynamic> empData = jsonDecode(empResponse.body);
    if (empData.isNotEmpty) {
      final idSection = empData[0]['IdSection'];
      final notifBody = jsonEncode({
        "IdSection": idSection,
        "IdSource": data['Id'],
        "Status": "Diajukan",
        "Source": "Bpjs",
        "CreatedAt": DateTime.now().toIso8601String(), // Tambahkan tanggal kirim
      });
      print("🔔 [Watcher] Mengirim notifikasi BPJS: $notifBody");
      final notifResp = await http.post(
        Uri.parse('http://34.50.112.226:5555/api/Notifications'),
        headers: {
          'accept': 'text/plain',
        },
        body: notifBody,
      );
      print(
          "🔔 [Watcher] Response notifikasi: ${notifResp.statusCode} - ${notifResp.body}");
      if (notifResp.statusCode == 200 || notifResp.statusCode == 201) {
        print("✅ [Watcher] Notifikasi BPJS terkirim!");
      } else {
        print("❌ [Watcher] Gagal kirim notifikasi: ${notifResp.statusCode}");
      }
    } else {
      print(
          "❌ [Watcher] Data Employees tidak ditemukan untuk idEmployee: $idEmployee");
    }
  } else {
    print(
        "❌ [Watcher] Gagal mengambil data Employees: ${empResponse.statusCode}");
  }
}

/// Utility upload dokumen BPJS sesuai kebutuhan backend.
/// - Untuk POST (Ortu/Mertua): key 'Files' dua kali jika dua file, 'FileTypes' satu string dipisah koma.
/// - Untuk POST satu file: key 'Files' sekali, 'FileTypes' satu value.
/// - Untuk PUT (Anak ke-4 dst): key harus 'UrlKk' dan 'UrlSuratPotongGaji' (bukan 'Files').
/// - Tidak boleh pakai array di field (seperti FileTypes) kecuali backend meminta.
/// - Validasi jumlah file dan fileTypes sebelum request.
/// - Setelah request, tampilkan body response backend di UI (return String).

Future<String> uploadBpjsDokumenUniversal({
  required String method, // 'POST' atau 'PUT'
  required String url, // endpoint lengkap
  required List<File> files, // urut: [suratPotongGaji, kk] atau satu file
  required List<String> fileTypes, // urut: ['UrlSuratPotongGaji', 'UrlKk'] atau satu value
  required int idEmployee,
  String? anggotaBpjs, // untuk POST
}) async {
  // Validasi jumlah file dan fileTypes
  if (files.isEmpty || fileTypes.isEmpty) {
    throw Exception('File dan FileTypes tidak boleh kosong.');
  }
  if (files.length != fileTypes.length) {
    throw Exception('Jumlah file dan FileTypes harus sama.');
  }

  final dio = Dio();
  FormData formData;

  if (method == 'POST') {
    formData = FormData();
    // Dua file: key 'Files' dua kali, FileTypes gabungan
    if (files.length == 2) {
      for (final file in files) {
        formData.files.add(
          MapEntry(
            "Files",
            await MultipartFile.fromFile(
              file.path,
              filename: basename(file.path),
            ),
          ),
        );
      }
      formData.fields.add(MapEntry("IdEmployee", idEmployee.toString()));
      formData.fields.add(MapEntry("FileTypes", fileTypes.join(',')));
      if (anggotaBpjs != null) {
        formData.fields.add(MapEntry("AnggotaBpjs", anggotaBpjs));
      }
    }
    // Satu file: key 'Files' sekali, FileTypes satu value
    else if (files.length == 1) {
      formData.files.add(
        MapEntry(
          "Files",
          await MultipartFile.fromFile(
            files[0].path,
            filename: basename(files[0].path),
          ),
        ),
      );
      formData.fields.add(MapEntry("IdEmployee", idEmployee.toString()));
      formData.fields.add(MapEntry("FileTypes", fileTypes[0]));
      if (anggotaBpjs != null) {
        formData.fields.add(MapEntry("AnggotaBpjs", anggotaBpjs));
      }
    } else {
      throw Exception('Jumlah file tidak didukung untuk mode POST.');
    }
  } else if (method == 'PUT') {
    // Untuk PUT: key sesuai FileTypes (bukan 'Files')
    final map = <String, dynamic>{
      "IdEmployee": idEmployee.toString(),
    };
    for (int i = 0; i < files.length; i++) {
      map[fileTypes[i]] = await MultipartFile.fromFile(
        files[i].path,
        filename: basename(files[i].path),
      );
    }
    formData = FormData.fromMap(map);
  } else {
    throw Exception('Method tidak didukung: $method');
  }

  try {
    final response = await (method == 'POST'
        ? dio.post(url, data: formData, options: Options(
            headers: {
              'accept': 'application/json',
            },
          ))
        : dio.put(url, data: formData, options: Options(
            headers: {
              'accept': 'application/json',
            },
          )));

    // Tampilkan body response backend
    return response.data?.toString() ?? 'No response body';
  } on DioException catch (e) {
    final backendMsg = e.response?.data?.toString() ?? '';
    throw Exception('Gagal upload file.\n$backendMsg\n$e');
  } catch (e) {
    throw Exception('Gagal upload file.\n$e');
  }
}