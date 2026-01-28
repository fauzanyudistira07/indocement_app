import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:retry/retry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../service/api_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  Map<String, dynamic>? opponent;
  String? roomId;
  String? konsultasiId;
  int? idEmployee;
  HubConnection? _hubConnection;
  bool _isLoading = true;
  String? _errorMessage;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _saveMessagesTimer;
  Timer? _reconnectTimer;
  bool _isDisposed = false;
  bool _showConnectedMessage = false;
  bool _firstRoomLoad = true;

  DateTime? _parseChatDateTime(String value) {
    try {
      return DateTime.parse(value);
    } catch (_) {}
    final formats = [
      DateFormat('dd/MM/yy HH.mm'),
      DateFormat('dd MMMM yyyy HH.mm', 'id_ID'),
      DateFormat('dd MMM yyyy', 'id_ID'),
    ];
    for (final format in formats) {
      try {
        return format.parseLoose(value);
      } catch (_) {}
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      if (mounted && !_isDisposed) {
        _loadChatRoom();
      }
    }).catchError((e) {
      print('Error initializing locale: $e');
      if (mounted && !_isDisposed) {
        setState(
            () => _errorMessage = 'Gagal menginisialisasi format tanggal: $e');
      }
    });
  }

  /// Initializes SignalR connection and joins the chat room.
  Future<void> _initializeSignalR() async {
    if (roomId == null || _isDisposed) {
      print('Cannot initialize SignalR: roomId is null or page is disposed');
      return;
    }

    try {
      print(
          'Initializing SignalR for room: $roomId (Attempt ${_reconnectAttempts + 1})');
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            'http://34.50.112.226:5555/chatHub',
            options: HttpConnectionOptions(
              requestTimeout: 30000,
              transport: HttpTransportType.WebSockets,
            ),
          )
          .withAutomaticReconnect()
          .build();

      if (_hubConnection != null) {
        _hubConnection!.onclose(({Exception? error}) {
          print('SignalR Connection Closed: $error');
          if (mounted && !_isDisposed) {
            setState(() {
              _errorMessage =
                  'Koneksi SignalR terputus: ${error?.toString() ?? "Tidak diketahui"}';
            });
            _scheduleReconnect();
          }
        });

        _hubConnection!.on('ReceiveMessage', _handleMessage);
        _hubConnection!.on('receiveMessage', _handleMessage);
        _hubConnection!.on('NewMessage', _handleMessage);
        _hubConnection!.on('Message', _handleMessage);
        _hubConnection!.on('UpdateMessageStatus', _handleStatusUpdate);

        print('Starting SignalR connection...');
        await retry(
          () async => await _hubConnection!.start(),
          maxAttempts: 5,
          delayFactor: const Duration(seconds: 2),
          onRetry: (e) => print('Retrying SignalR start due to: $e'),
        );
        print('SignalR connection started. State: ${_hubConnection!.state}');

        print('Joining room: $roomId with idEmployee: $idEmployee');
        await _hubConnection!
            .invoke('JoinRoom', args: [roomId!, idEmployee.toString(), "user"]);
        print('Successfully joined room: $roomId');

        if (mounted && !_isDisposed) {
          setState(() {
            _errorMessage = null;
            _showConnectedMessage = true;
          });
          Timer(const Duration(seconds: 3), () {
            if (mounted && !_isDisposed) {
              setState(() => _showConnectedMessage = false);
            }
          });
        }
        _reconnectAttempts = 0;
      } else {
        print('Failed to initialize HubConnection');
        if (mounted && !_isDisposed) {
          setState(
              () => _errorMessage = 'Harap Tunggu Loading Hingga Selesai');
        }
      }
    } catch (e, stackTrace) {
      print('Error initializing SignalR: $e\nStack trace: $stackTrace');
      if (e.toString().contains('Invocation canceled')) {
        print('SignalR invocation canceled, falling back to HTTP...');
        await _joinRoomViaHttp();
      } else if (mounted && !_isDisposed) {
        // Jangan tampilkan error modal jika _firstRoomLoad masih true
        if (!_firstRoomLoad) {
          setState(() =>
              _errorMessage = 'Harap Tunggu Loading Hingga Selesai');
        }
        _scheduleReconnect();
      }
    } finally {
      if (mounted && !_isDisposed) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Joins the chat room via HTTP as a fallback.
  Future<void> _joinRoomViaHttp() async {
    if (roomId == null || idEmployee == null || _isDisposed) {
      print(
          'Cannot join room via HTTP: roomId or idEmployee is null or page is disposed');
      return;
    }

    try {
      final response = await retry(
        () => ApiService.post(
          'http://34.50.112.226:5555/api/ChatMessages/join-room',
          data: {'roomId': roomId, 'userId': idEmployee},
          contentType: 'application/json',
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Joining room via HTTP: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200 && mounted && !_isDisposed) {
        setState(() {
          _errorMessage = null;
          _showConnectedMessage = true;
        });
        Timer(const Duration(seconds: 3), () {
          if (mounted && !_isDisposed) {
            setState(() => _showConnectedMessage = false);
          }
        });
      } else if (mounted && !_isDisposed) {
        setState(() => _errorMessage =
            'Gagal bergabung ke room via HTTP: ${response.data}');
        _scheduleReconnect();
      }
    } catch (e) {
      print('Error joining room via HTTP: $e');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Harap Tunggu Loading Hingga Selesai');
        _scheduleReconnect();
      }
    }
  }

  /// Schedules a reconnection attempt for SignalR.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _isDisposed) {
      print(
          'Max reconnect attempts reached or page is disposed. Stopping reconnection.');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage =
            'Gagal menghubungkan setelah beberapa percobaan. Silakan coba lagi nanti.');
      }
      return;
    }

    final delay = Duration(seconds: _reconnectAttempts + 1);
    _reconnectAttempts++;
    print(
        'Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds} seconds...');
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      if (mounted &&
          !_isDisposed &&
          _hubConnection?.state != HubConnectionState.Connected) {
        print('Attempting to reconnect to SignalR...');
        try {
          await _initializeSignalR();
          if (_hubConnection?.state == HubConnectionState.Connected &&
              mounted &&
              !_isDisposed) {
            print('Reconnection successful.');
            setState(() => _errorMessage = null);
          } else {
            print('Reconnection failed, scheduling next attempt...');
            _scheduleReconnect();
          }
        } catch (e) {
          print('Reconnection error: $e');
          _scheduleReconnect();
        }
      } else if (_hubConnection?.state == HubConnectionState.Connected &&
          mounted &&
          !_isDisposed) {
        print('Connection already established, skipping reconnect.');
        _reconnectAttempts = 0;
        setState(() => _errorMessage = null);
      }
    });
  }

  /// Handles incoming messages from SignalR.
  void _handleMessage(List<dynamic>? arguments) {
    if (_isDisposed) {
      print('Skipping handleMessage: Page is disposed');
      return;
    }
    if (arguments == null || arguments.isEmpty) {
      print('Empty or invalid SignalR message');
      return;
    }

    var message = arguments[0] is List ? arguments[0][0] : arguments[0];
    if (message is! Map<String, dynamic>) {
      print('Invalid message format: $message');
      return;
    }

    if (message['roomId']?.toString() == roomId ||
        message['RoomId']?.toString() == roomId) {
      final messageId = message['Id'] ?? message['id'];
      if (messageId != null &&
          !_messages.any((msg) => msg['Id'] == messageId)) {
        final createdAt = message['CreatedAt'] ?? message['createdAt'];
        final timestamp = _formatTimestamp(createdAt);
        var sender = message['Sender'] is Map
            ? Map<String, dynamic>.from(message['Sender'] as Map)
            : {};
        if (sender.isEmpty &&
            opponent != null &&
            message['SenderId'] == opponent!['Id']) {
          sender = {
            'Id': opponent!['Id'],
            'EmployeeName': opponent!['Name'],
            'Email': opponent!['Email'],
            'ProfilePhoto': opponent!['ProfilePhoto'],
          };
        }

        final messageStatus =
            message['Status'] ?? message['status'] ?? 'Terkirim';
        print(
            'Adding message with messageId: $messageId, SenderId: ${message['SenderId']}, Status: $messageStatus');

        if (mounted && !_isDisposed) {
          setState(() {
            final tempIndex = _messages
                .indexWhere((msg) => msg['Id'].toString().startsWith('temp_'));
            if (tempIndex != -1 &&
                _messages[tempIndex]['Message'] == message['Message'] &&
                _messages[tempIndex]['SenderId'] == message['SenderId']) {
              _messages[tempIndex] = {
                'Id': messageId,
                'Message': message['Message'] ??
                    message['message'] ??
                    message['Content'] ??
                    '',
                'SenderId': message['SenderId'] ?? message['senderId'],
                'CreatedAt': createdAt,
                'FormattedTime': timestamp['time'],
                'FormattedDate': timestamp['date'],
                'Status': messageStatus,
                'Sender': sender,
                'roomId': message['roomId'] ?? message['RoomId'],
              };
            } else {
              _messages.add({
                'Id': messageId,
                'Message': message['Message'] ??
                    message['message'] ??
                    message['Content'] ??
                    '',
                'SenderId': message['SenderId'] ?? message['senderId'],
                'CreatedAt': createdAt,
                'FormattedTime': timestamp['time'],
                'FormattedDate': timestamp['date'],
                'Status': messageStatus,
                'Sender': sender,
                'roomId': message['roomId'] ?? message['RoomId'],
              });
            }
          });
          _triggerSaveMessages();
          _scrollToBottom();
        }
      }
    }
  }

  /// Handles status updates from SignalR.
  void _handleStatusUpdate(List<dynamic>? arguments) {
    if (_isDisposed) {
      print('Skipping handleStatusUpdate: Page is disposed');
      return;
    }
    if (arguments != null && arguments.isNotEmpty) {
      final statusUpdate = arguments[0] as Map<String, dynamic>?;
      if (statusUpdate != null) {
        final messageId = statusUpdate['id'] ?? statusUpdate['Id'];
        final newStatus = statusUpdate['status'] ?? statusUpdate['Status'];
        print('Updating status for messageId: $messageId to $newStatus');
        if (messageId != null && newStatus != null && mounted && !_isDisposed) {
          setState(() {
            final index = _messages.indexWhere((msg) => msg['Id'] == messageId);
            if (index != -1) {
              _messages[index]['Status'] = newStatus;
              print(
                  'Real-time status updated in _messages at index $index: ${_messages[index]}');
            } else {
              print(
                  'MessageId $messageId not found in _messages, reloading messages...');
              _loadMessages();
            }
          });
          _triggerSaveMessages();
          _scrollToBottom();
        }
      }
    }
  }

  /// Fixes message status on the server.
  Future<void> _fixServerStatus(int messageId, String correctStatus) async {
    if (_isDisposed) {
      print('Skipping fixServerStatus: Page is disposed');
      return;
    }
    try {
      final response = await retry(
        () => ApiService.put(
          'http://34.50.112.226:5555/api/ChatMessages/update-status/$messageId',
          data: {'status': correctStatus},
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Fixing server status for messageId $messageId to $correctStatus: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200 && mounted && !_isDisposed) {
        print('Successfully fixed server status for messageId $messageId');
      } else if (mounted && !_isDisposed) {
        setState(() => _errorMessage =
            'Gagal memperbaiki status pesan di server: ${response.data}');
      }
    } catch (e) {
      print('Error fixing server status for messageId $messageId: $e');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Gagal memperbaiki status pesan: $e');
      }
    }
  }

  /// Scrolls the chat to the bottom.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && mounted && !_isDisposed) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    print('Disposing ChatPageState...');
    _isDisposed = true;
    _saveMessagesTimer?.cancel();
    _reconnectTimer?.cancel();
    _hubConnection?.stop();
    _hubConnection = null;
    _scrollController.dispose();
    _messageController.dispose();
    super.dispose();
    print('ChatPageState disposed.');
  }

  /// Loads the chat room and initializes necessary data.
  Future<void> _loadChatRoom() async {
    if (!mounted || _isDisposed) {
      print('Skipping loadChatRoom: Page is disposed');
      return;
    }
    setState(() => _isLoading = true);
    final prefs = await SharedPreferences.getInstance();
    idEmployee = prefs.getInt('idEmployee');
    print('idEmployee: $idEmployee');
    if (idEmployee == null) {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'ID karyawan tidak ditemukan. Silakan login ulang.';
        });
      }
      return;
    }

    roomId = prefs.getString('roomId');
    konsultasiId = prefs.getString('konsultasiId');

    if (roomId != null) {
      final isRoomValid = await _verifyRoomExists(roomId!);
      if (!isRoomValid) {
        print('Room $roomId is no longer valid. Clearing local data.');
        await _clearLocalChatData(prefs);
        roomId = null;
        konsultasiId = null;
      }
    }

    if (roomId == null || konsultasiId == null) {
      final existingConsultation =
          await _checkExistingConsultation(idEmployee!);
      if (existingConsultation != null && mounted && !_isDisposed) {
        setState(() {
          konsultasiId = existingConsultation['KonsultasiId']?.toString() ??
              existingConsultation['Id']?.toString();
          roomId = existingConsultation['ChatRoomId']?.toString() ??
              existingConsultation['ChatRoom']?['Id']?.toString();
          opponent = existingConsultation['Opponent'] is Map
              ? Map<String, dynamic>.from(existingConsultation['Opponent'])
              : null;
        });
        await prefs.setString('konsultasiId', konsultasiId!);
        if (roomId != null) await prefs.setString('roomId', roomId!);
      } else {
        await _createKonsultasi(idEmployee!);
      }
    }

    if (roomId != null) {
      print('Loading messages for room: $roomId');
      await _loadMessages();
      print('Loading local messages...');
      await _loadLocalMessages();
      print('Initializing SignalR...');
      await _initializeSignalR();
      if (mounted &&
          !_isDisposed &&
          _hubConnection?.state == HubConnectionState.Connected) {
        setState(() => _errorMessage = null);
      }
    } else {
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          if (!_firstRoomLoad) {
            _errorMessage = 'Gagal memuat room chat. Silakan coba lagi.';
          }
          // Jika _firstRoomLoad true, biarkan loading spinner saja
        });
      }
    }
    setState(() {
      _firstRoomLoad = false;
    });
  }

  /// Verifies if the chat room exists.
  Future<bool> _verifyRoomExists(String roomId) async {
    if (_isDisposed) {
      print('Skipping verifyRoomExists: Page is disposed');
      return false;
    }
    try {
      final response = await retry(
        () => ApiService.get(
          'http://34.50.112.226:5555/api/ChatMessages/room/$roomId',
          params: {'currentUserId': idEmployee.toString()},
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Verifying room $roomId: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        if (mounted && !_isDisposed) {
          setState(() {
            opponent = data['Opponent'] is Map
                ? Map<String, dynamic>.from(data['Opponent'] as Map)
                : opponent;
          });
        }
        return true;
      } else {
        if (mounted && !_isDisposed) {
          setState(() => _errorMessage =
              'Harap Tunggu Loading Hingga Selesai');
        }
        return false;
      }
    } catch (e) {
      print('Error verifying room $roomId: $e');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Harap Tunggu Loading Hingga Selesai');
      }
      return false;
    }
  }

  /// Clears local chat data from SharedPreferences.
  Future<void> _clearLocalChatData(SharedPreferences prefs) async {
    if (_isDisposed) {
      print('Skipping clearLocalChatData: Page is disposed');
      return;
    }
    await prefs.remove('roomId');
    await prefs.remove('konsultasiId');
    if (roomId != null) await prefs.remove('messages_$roomId');
    if (mounted && !_isDisposed) {
      setState(() {
        _messages.clear();
        roomId = null;
        konsultasiId = null;
        opponent = null;
      });
    }
    print('Cleared local chat data.');
  }

  /// Loads messages from local storage.
  Future<void> _loadLocalMessages() async {
    if (_isDisposed) {
      print('Skipping loadLocalMessages: Page is disposed');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final messagesJson = prefs.getString('messages_$roomId');
    if (messagesJson != null) {
      try {
        final messages = jsonDecode(messagesJson) as List<dynamic>;
        if (mounted && !_isDisposed) {
          setState(() {
            _messages.clear();
            _messages.addAll(messages
                .where((msg) => msg['Id'] != null && msg['CreatedAt'] != null)
                .map((msg) {
              final timestamp = _formatTimestamp(msg['CreatedAt']);
              var sender = msg['Sender'] is Map
                  ? Map<String, dynamic>.from(msg['Sender'] as Map)
                  : {};
              if (sender.isEmpty &&
                  opponent != null &&
                  msg['SenderId'] == opponent!['Id']) {
                sender = {
                  'Id': opponent!['Id'],
                  'EmployeeName': opponent!['Name'],
                  'Email': opponent!['Email'],
                  'ProfilePhoto': opponent!['ProfilePhoto'],
                };
              }
              final status = msg['Status']?.toString() ?? 'Terkirim';
              print(
                  'Loading local message Id: ${msg['Id']}, SenderId: ${msg['SenderId']}, Status: $status');
              return {
                ...msg as Map<String, dynamic>,
                'FormattedTime': timestamp['time'],
                'FormattedDate': timestamp['date'],
                'Sender': sender,
              };
            }));
          });
          print('Loaded ${_messages.length} messages from local storage');
          _scrollToBottom();
          _loadMessages();
        }
      } catch (e) {
        print('Error loading local messages: $e');
        await prefs.remove('messages_$roomId');
        if (mounted && !_isDisposed) {
          setState(() => _errorMessage = 'Gagal memuat pesan lokal: $e');
        }
      }
    }
  }

  /// Saves messages to local storage with a debounce.
  Future<void> _saveMessagesLocally() async {
    _saveMessagesTimer?.cancel();
    _saveMessagesTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted || _isDisposed) {
        print('Skipping saveMessagesLocally: State is not mounted or disposed');
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      try {
        final validMessages = _messages
            .where((msg) => msg['Id'] != null && msg['CreatedAt'] != null)
            .map((msg) {
          String formattedCreatedAt;
          try {
            final parsed = _parseChatDateTime(msg['CreatedAt']);
            if (parsed != null) {
              formattedCreatedAt =
                  DateFormat('dd/MM/yy HH.mm').format(parsed.toLocal());
            } else {
              formattedCreatedAt = msg['CreatedAt'];
            }
          } catch (e) {
            formattedCreatedAt = msg['CreatedAt'];
          }
          return {
            'Id': msg['Id'],
            'Message': msg['Message'],
            'SenderId': msg['SenderId'],
            'CreatedAt': formattedCreatedAt,
            'FormattedTime': msg['FormattedTime'],
            'FormattedDate': msg['FormattedDate'],
            'Status': msg['Status'],
            'Sender': msg['Sender'],
            'roomId': msg['roomId'],
          };
        }).toList();
        await prefs.setString('messages_$roomId', jsonEncode(validMessages));
        print('Saved ${validMessages.length} messages to local storage');
      } catch (e) {
        print('Error saving messages: $e');
        if (mounted && !_isDisposed) {
          setState(() => _errorMessage = 'Gagal menyimpan pesan lokal: $e');
        }
      }
    });
  }

  /// Triggers saving messages to local storage.
  void _triggerSaveMessages() {
    if (!_isDisposed) {
      _saveMessagesLocally();
    }
  }

  /// Checks for an existing consultation for the employee.
  Future<Map<String, dynamic>?> _checkExistingConsultation(
      int idEmployee) async {
    if (_isDisposed) {
      print('Skipping checkExistingConsultation: Page is disposed');
      return null;
    }
    try {
      final response = await retry(
        () => ApiService.get(
          'http://34.50.112.226:5555/api/Konsultasis/employee/$idEmployee',
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Checking consultation for idEmployee $idEmployee: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        final consultation = (data is List && data.isNotEmpty)
            ? Map<String, dynamic>.from(data[0] as Map)
            : (data is Map ? Map<String, dynamic>.from(data) : null);
        if (consultation != null && mounted && !_isDisposed) {
          setState(() {
            opponent = consultation['Opponent'] is Map
                ? Map<String, dynamic>.from(consultation['Opponent'])
                : null;
          });
        }
        return consultation;
      }
      return null;
    } catch (e) {
      print('Error checking consultation: $e');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Harap Tunggu Loading Hingga Selesai');
      }
      return null;
    }
  }

  /// Creates a new consultation for the employee.
  Future<void> _createKonsultasi(int idEmployee) async {
    if (_isDisposed) {
      print('Skipping createKonsultasi: Page is disposed');
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await retry(
        () => ApiService.post(
          'http://34.50.112.226:5555/api/Konsultasis/create-consultation',
          data: {'idEmployee': idEmployee},
          contentType: 'application/json',
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Creating consultation for idEmployee $idEmployee: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        if (mounted && !_isDisposed) {
          setState(() {
            konsultasiId =
                data['KonsultasiId']?.toString() ?? data['Id']?.toString();
            roomId = data['ChatRoomId']?.toString() ??
                data['ChatRoom']?['Id']?.toString();
            opponent = data['Opponent'] is Map
                ? Map<String, dynamic>.from(data['Opponent'])
                : null;
            _errorMessage = null;
          });
        }
        await prefs.setString('konsultasiId', konsultasiId!);
        if (roomId != null) await prefs.setString('roomId', roomId!);
      } else if (response.statusCode == 409) {
        final error =
            response.data is String ? jsonDecode(response.data) : response.data;
        if (error['Message'] == 'Room chat sudah ada.') {
          if (mounted && !_isDisposed) {
            setState(() {
              roomId = error['ChatRoomId']?.toString();
              _errorMessage = null;
            });
          }
          if (roomId != null) await prefs.setString('roomId', roomId!);
          final existingConsultation =
              await _checkExistingConsultation(idEmployee);
          if (existingConsultation != null && mounted && !_isDisposed) {
            setState(() {
              konsultasiId = existingConsultation['KonsultasiId']?.toString() ??
                  existingConsultation['Id']?.toString();
              opponent = existingConsultation['Opponent'] is Map
                  ? Map<String, dynamic>.from(existingConsultation['Opponent'])
                  : null;
            });
            if (konsultasiId != null) {
              await prefs.setString('konsultasiId', konsultasiId!);
            }
          }
        }
      } else {
        if (mounted && !_isDisposed) {
          setState(() => _errorMessage =
              'Gagal membuat konsultasi: Status ${response.statusCode}, ${response.data}');
        }
      }
    } catch (e) {
      print('Error creating consultation: $e');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Harap Tungu Loading Hingga Selesai');
      }
    }
  }

  /// Loads messages from the server.
  Future<void> _loadMessages() async {
    if (roomId == null || idEmployee == null || _isDisposed) {
      print('Error: roomId or idEmployee is null or page is disposed');
      return;
    }

    try {
      final response = await retry(
        () => ApiService.get(
          'http://34.50.112.226:5555/api/ChatMessages/room/$roomId',
          params: {'currentUserId': idEmployee.toString()},
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Loading messages for room $roomId: Status: ${response.statusCode}, Body: ${response.data}');

      if (response.statusCode == 200) {
        final data =
            response.data is String ? jsonDecode(response.data) : response.data;
        final messages = data['Messages'] as List<dynamic>? ?? [];
        print('Raw messages from server: $messages');

        final messagesToUpdate = messages
            .whereType<Map>()
            .where((msg) =>
                msg['SenderId'] != idEmployee && msg['Status'] != 'Dibaca')
            .toList();

        for (var msg in messagesToUpdate) {
          final messageId = msg['Id'];
          if (messageId != null) {
            final statusCode = await _updateMessageStatus(messageId, 'Dibaca');
            if (statusCode != 200) {
              print(
                  'Failed to update status for message $messageId, retrying...');
              await _fixServerStatus(messageId, 'Dibaca');
            }
          }
        }

        if (mounted && !_isDisposed) {
          setState(() {
            _messages.clear();
            _messages.addAll(messages.whereType<Map>().map((msg) {
              final msgMap = Map<String, dynamic>.from(msg);
              final timestamp = _formatTimestamp(msgMap['CreatedAt']);
              var sender = msgMap['Sender'] is Map
                  ? Map<String, dynamic>.from(msgMap['Sender'] as Map)
                  : {};
              if (sender.isEmpty &&
                  opponent != null &&
                  msgMap['SenderId'] == opponent!['Id']) {
                sender = {
                  'Id': opponent!['Id'],
                  'EmployeeName': opponent!['Name'],
                  'Email': opponent!['Email'],
                  'ProfilePhoto': opponent!['ProfilePhoto'],
                };
              }
              final status = msgMap['Status']?.toString() ?? 'Terkirim';
              print(
                  'Loading server message Id: ${msgMap['Id']}, SenderId: ${msgMap['SenderId']}, Status: $status, Sender: $sender');
              return {
                ...msgMap,
                'FormattedTime': timestamp['time'],
                'FormattedDate': timestamp['date'],
                'Sender': sender,
                'Status': status,
              };
            }).toList());
            opponent = data['Opponent'] is Map
                ? Map<String, dynamic>.from(data['Opponent'] as Map)
                : opponent ??
                    {
                      'Id': 50,
                      'Name': 'Agung',
                      'Email': 'agung@gmail.com',
                      'ProfilePhoto':
                          '/uploads/employees/employee_50_1ed5f218-7df7-4511-834f-abc0cb9f9c75.jpg'
                    };
          });
          print('Loaded ${_messages.length} messages, Opponent: $opponent');
          _triggerSaveMessages();
          _scrollToBottom();
          if (mounted && !_isDisposed) {
            setState(() => _errorMessage = null);
          }
        }
      } else if (response.statusCode == 404) {
        print(
            'Room not found, clearing local data and creating new consultation');
        final prefs = await SharedPreferences.getInstance();
        await _clearLocalChatData(prefs);
        await _createKonsultasi(idEmployee!);
        await _loadChatRoom();
      } else if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Gagal memuat pesan: Status ${response.statusCode}, ${response.data}';
        });
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted && !_isDisposed) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Gagal memuat pesan: $e';
        });
      }
    }
  }

  /// Sends a message via SignalR or HTTP.
  Future<void> _sendMessage() async {
    if (_isDisposed) {
      print('Skipping sendMessage: Page is disposed');
      return;
    }
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || idEmployee == null || roomId == null) {
      print('Cannot send message: empty message or invalid roomId/idEmployee');
      if (mounted && !_isDisposed) {
        setState(() => _errorMessage = 'Pesan kosong atau room tidak valid.');
      }
      return;
    }

    final now = DateTime.now();
    final formattedCreatedAt = DateFormat('dd/MM/yy HH.mm').format(now);
    final timestamp = _formatTimestamp(formattedCreatedAt);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = {
      'Id': tempId,
      'Message': messageText,
      'SenderId': idEmployee,
      'CreatedAt': formattedCreatedAt,
      'FormattedTime': timestamp['time'],
      'FormattedDate': timestamp['date'],
      'Status': 'Mengirim',
      'Sender': {
        'Id': idEmployee,
        'EmployeeName': 'Saka',
        'Email': null,
        'ProfilePhoto': null,
      },
      'roomId': roomId,
    };

    if (mounted && !_isDisposed) {
      setState(() {
        _messages.add(tempMessage);
      });
      _scrollToBottom();
    }

    bool sentSuccessfully = false;
    try {
      if (_hubConnection?.state == HubConnectionState.Connected) {
        final messageArgs = {
          'roomId': roomId,
          'senderId': idEmployee,
          'message': messageText,
        };
        print('Sending SignalR message with args: $messageArgs');
        await _hubConnection!.invoke('SendMessage', args: [messageArgs]);
        print('Message sent via SignalR: $messageText');
        sentSuccessfully = true;
      } else {
        print('SignalR not connected, falling back to HTTP');
      }
    } catch (e, stackTrace) {
      print('Error sending message via SignalR: $e\nStack trace: $stackTrace');
    }

    if (!sentSuccessfully) {
      try {
        final response = await retry(
          () => ApiService.post(
            'http://34.50.112.226:5555/api/ChatMessages/send-message',
            data: {
              'roomId': roomId,
              'senderId': idEmployee,
              'message': messageText,
            },
            contentType: 'application/json',
          ),
          maxAttempts: 3,
          delayFactor: const Duration(seconds: 1),
          onRetry: (e) => print('Retrying HTTP send message due to: $e'),
        );
        print(
            'Sending message via HTTP: Status: ${response.statusCode}, Body: ${response.data}');
        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          sentSuccessfully = true;
          if (mounted && !_isDisposed) {
            setState(() {
              final index = _messages.indexWhere((msg) => msg['Id'] == tempId);
              if (index != -1) {
                _messages[index]['Status'] = 'Terkirim';
              }
            });
            _messageController.clear();
            _triggerSaveMessages();
            await _loadMessages();
          }
        } else if (response.data is Map &&
            response.data['Message'] == 'Chat room tidak ditemukan.') {
          final prefs = await SharedPreferences.getInstance();
          await _clearLocalChatData(prefs);
          await _createKonsultasi(idEmployee!);
          await _loadChatRoom();
          await _sendMessage();
        } else if (mounted && !_isDisposed) {
          setState(() {
            final index = _messages.indexWhere((msg) => msg['Id'] == tempId);
            if (index != -1) {
              _messages[index]['Status'] = 'Gagal';
            }
            _errorMessage = 'Gagal mengirim pesan: ${response.data}';
          });
        }
      } catch (e) {
        print('Error sending message via HTTP: $e');
        if (mounted && !_isDisposed) {
          setState(() {
            final index = _messages.indexWhere((msg) => msg['Id'] == tempId);
            if (index != -1) {
              _messages[index]['Status'] = 'Gagal';
            }
            _errorMessage = 'Gagal mengirim pesan: $e';
          });
        }
      }
    }

    if (sentSuccessfully && mounted && !_isDisposed) {
      setState(() {
        final index = _messages.indexWhere((msg) => msg['Id'] == tempId);
        if (index != -1) {
          _messages[index]['Status'] = 'Terkirim';
        }
      });
      _messageController.clear();
      _triggerSaveMessages();
    }
  }

  /// Updates the status of a message on the server.
  Future<int> _updateMessageStatus(int messageId, String status) async {
    if (_isDisposed) {
      print('Skipping updateMessageStatus: Page is disposed');
      return 500;
    }
    try {
      final response = await retry(
        () => ApiService.put(
          'http://34.50.112.226:5555/api/ChatMessages/update-status/$messageId',
          data: {'status': status},
        ),
        maxAttempts: 3,
        delayFactor: const Duration(seconds: 1),
      );
      print(
          'Updating message status for messageId $messageId to $status: Status: ${response.statusCode}, Body: ${response.data}');
      if (response.statusCode == 200 && mounted && !_isDisposed) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg['Id'] == messageId);
          if (index != -1) {
            _messages[index]['Status'] = status;
            print(
                'Updated status in _messages at index $index: ${_messages[index]}');
          }
        });
        _triggerSaveMessages();
        return response.statusCode ?? 500;
      } else {
        print('Failed to update message status: ${response.data}');
        return response.statusCode ?? 500;
      }
    } catch (e) {
      print('Error updating message status for messageId $messageId: $e');
      return 500;
    }
  }

  /// Formats a timestamp for display.
  Map<String, String> _formatTimestamp(String? timeString) {
    if (timeString == null || timeString.isEmpty) {
      print('Warning: timeString is null or empty');
      return {'time': '--:--', 'date': 'Unknown Date'};
    }

    print('Parsing timestamp: $timeString');
    try {
      final parsedDateTime = _parseChatDateTime(timeString);
      if (parsedDateTime == null) {
        return {'time': '--:--', 'date': 'Unknown Date'};
      }
      final dateTime = parsedDateTime.toLocal();
      final now = DateTime.now();
      final isToday = dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day;
      return {
        'time':
            "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}",
        'date': isToday ? '' : DateFormat('dd/MM/yy').format(dateTime),
      };
    } catch (e) {
      print('Error parsing timestamp: $timeString, Error: $e');
      return {'time': '--:--', 'date': 'Unknown Date'};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1572E8),
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.grey[300],
              backgroundImage: (opponent != null &&
                      opponent!['ProfilePhoto'] != null)
                  ? NetworkImage(
                      'http://34.50.112.226:5555${opponent!['ProfilePhoto']}')
                  : null,
              child: (opponent == null || opponent!['ProfilePhoto'] == null)
                  ? const Icon(Icons.person, color: Colors.grey, size: 28)
                  : null,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    opponent != null && opponent!['Name'] != null
                        ? opponent!['Name'].toString()
                        : 'Memuat...',
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    opponent != null && opponent!['Department'] != null
                        ? opponent!['Department'].toString()
                        : '',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/chat_background.jpg'),
                fit: BoxFit.cover,
                opacity: 0.1,
              ),
            ),
            child: Column(
              children: [
                if (_showConnectedMessage)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    color: Colors.grey[200],
                    child: const Center(
                      child: Text(
                        'Terhubung',
                        style: TextStyle(color: Colors.green, fontSize: 12),
                      ),
                    ),
                  ),
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];
                      final isMe = msg['SenderId'] == idEmployee;
                      final message =
                          msg['Message']?.toString() ?? '[Pesan kosong]';
                      final sender = msg['Sender'] is Map
                          ? Map<String, dynamic>.from(msg['Sender'] as Map)
                          : {};
                      final senderName = sender['EmployeeName']?.toString() ??
                          (opponent != null &&
                                  msg['SenderId'] == opponent!['Id']
                              ? opponent!['Name']?.toString() ?? 'Unknown'
                              : 'Saka');
                      final formattedTime =
                          msg['FormattedTime']?.toString() ?? '--:--';
                      final formattedDate =
                          msg['FormattedDate']?.toString() ?? '';
                      final status = msg['Status']?.toString() ?? 'Mengirim';
                      print(
                          'Rendering message $index: isMe=$isMe, messageId=${msg['Id']}, status=$status, sender=$senderName');

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: isMe
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width *
                                            0.7),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                margin: EdgeInsets.only(
                                    left: isMe ? 50 : 8, right: isMe ? 8 : 50),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? const Color(0xFFE1FFC7)
                                      : Colors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(12),
                                    topRight: const Radius.circular(12),
                                    bottomLeft: isMe
                                        ? const Radius.circular(12)
                                        : Radius.zero,
                                    bottomRight: isMe
                                        ? Radius.zero
                                        : const Radius.circular(12),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 2,
                                        offset: Offset(0, 1)),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe)
                                      Text(
                                        senderName,
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                            fontWeight: FontWeight.bold),
                                      ),
                                    if (!isMe) const SizedBox(height: 4),
                                    Text(message,
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      alignment: WrapAlignment.end,
                                      spacing: 4,
                                      children: [
                                        Text(
                                          formattedDate.isNotEmpty
                                              ? '$formattedDate $formattedTime'
                                              : formattedTime,
                                          style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[600]),
                                        ),
                                        if (isMe)
                                          Icon(
                                            status == 'Dibaca'
                                                ? Icons.done_all
                                                : status == 'Terkirim'
                                                    ? Icons.done
                                                    : status == 'Gagal'
                                                        ? Icons.error_outline
                                                        : Icons.access_time,
                                            size: 14,
                                            color: status == 'Dibaca'
                                                ? Colors.blue
                                                : status == 'Gagal'
                                                    ? Colors.red
                                                    : Colors.grey,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: TextField(
                            controller: _messageController,
                            decoration: const InputDecoration(
                              hintText: 'Ketik pesan...',
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: const BoxDecoration(
                            color: Color(0xFF1572E8), shape: BoxShape.circle),
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: _sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
if (_errorMessage != null)
Positioned(
  top: 10,
  left: 10,
  right: 10,
  child: Material(
    color: Colors.red,
    borderRadius: BorderRadius.circular(8),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          Expanded(
            child: Text(_errorMessage!,
              style: const TextStyle(color: Colors.white))),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () {
              if (mounted && !_isDisposed) {
                setState(() => _errorMessage = null);
              }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
