import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const int kCardCount = 8;
const String _kMessagesKey = 'cached_messages_v1';

void main() {
  runApp(const ExpenseTrackerApp());
}

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  debugPrint('[SMS][bg] received from=${message.address} body=${message.body}');
  await MessageStore.prepend(_StoredMessage.fromSms(message));
}

class _StoredMessage {
  _StoredMessage({required this.address, required this.body, required this.date});

  final String address;
  final String body;
  final int date;

  factory _StoredMessage.fromSms(SmsMessage m) => _StoredMessage(
        address: m.address ?? '',
        body: m.body ?? '',
        date: m.date ?? DateTime.now().millisecondsSinceEpoch,
      );

  factory _StoredMessage.fromJson(Map<String, dynamic> j) => _StoredMessage(
        address: j['address'] as String? ?? '',
        body: j['body'] as String? ?? '',
        date: j['date'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'address': address,
        'body': body,
        'date': date,
      };
}

class MessageStore {
  static Future<List<_StoredMessage>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kMessagesKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _StoredMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static Future<void> save(List<_StoredMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((m) => m.toJson()).toList());
    await prefs.setString(_kMessagesKey, encoded);
  }

  static Future<List<_StoredMessage>> prepend(_StoredMessage message) async {
    final current = await load();
    final updated = [message, ...current].take(kCardCount).toList();
    await save(updated);
    return updated;
  }
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final Telephony _telephony = Telephony.instance;
  List<_StoredMessage> _messages = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncFromInbox();
    }
  }

  Future<void> _bootstrap() async {
    if (kIsWeb || !Platform.isAndroid) {
      setState(() {
        _loading = false;
        _error = (!kIsWeb && Platform.isIOS)
            ? 'iOS does not allow apps to read SMS messages.'
            : 'SMS is only supported on Android.';
      });
      return;
    }

    try {
      final cached = await MessageStore.load();
      if (mounted && cached.isNotEmpty) {
        setState(() {
          _messages = cached;
          _loading = false;
        });
      }

      final granted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;
      debugPrint('[SMS] permission granted=$granted');
      if (!granted) {
        setState(() {
          _loading = false;
          _error = 'SMS permission denied. Enable it in Settings → Apps → expense_tracker → Permissions.';
        });
        return;
      }

      await _syncFromInbox();

      _telephony.listenIncomingSms(
        onNewMessage: _onForegroundSms,
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
      debugPrint('[SMS] listener registered');
    } catch (e, st) {
      debugPrint('[SMS] bootstrap error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to initialize SMS: $e';
      });
    }
  }

  Future<void> _syncFromInbox() async {
    try {
      final inbox = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final latest = inbox
          .take(kCardCount)
          .map(_StoredMessage.fromSms)
          .toList();

      debugPrint('[SMS] inbox sync: pulled ${latest.length} messages');

      await MessageStore.save(latest);
      if (!mounted) return;
      setState(() {
        _messages = latest;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('[SMS] inbox sync error: $e');
    }
  }

  Future<void> _onForegroundSms(SmsMessage message) async {
    debugPrint('[SMS][fg] received from=${message.address} body=${message.body}');
    final updated = await MessageStore.prepend(_StoredMessage.fromSms(message));
    if (!mounted) return;
    setState(() => _messages = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _bootstrap,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: kCardCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final message = index < _messages.length ? _messages[index] : null;
          return _MessageCard(index: index, message: message);
        },
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.index, required this.message});

  final int index;
  final _StoredMessage? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMessage = message != null;
    final sender = message?.address.isNotEmpty == true
        ? message!.address
        : (hasMessage ? 'Unknown' : 'Empty');
    final body = message?.body ?? 'No message';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasMessage ? () => _showMessage(context) : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.15),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sender,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Text(
                  body,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
              ),
              if (hasMessage && message!.date > 0)
                Text(
                  _formatDate(message!.date),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(message!.address.isNotEmpty ? message!.address : 'Message'),
        content: SingleChildScrollView(child: Text(message!.body)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
