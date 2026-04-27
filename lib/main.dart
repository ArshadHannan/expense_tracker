import 'dart:io' show Platform;

import 'package:another_telephony/telephony.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExpenseTrackerApp());
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

class _HomePageState extends State<HomePage> {
  static const int _cardCount = 8;

  final Telephony _telephony = Telephony.instance;
  List<SmsMessage> _messages = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initSms();
  }

  Future<void> _initSms() async {
    if (kIsWeb || !Platform.isAndroid) {
      setState(() {
        _loading = false;
        _error = Platform.isIOS
            ? 'iOS does not allow apps to read SMS messages.'
            : 'SMS is only supported on Android.';
      });
      return;
    }

    try {
      final granted =
          await _telephony.requestPhoneAndSmsPermissions ?? false;
      if (!granted) {
        setState(() {
          _loading = false;
          _error = 'SMS permission denied.';
        });
        return;
      }

      await _loadInbox();

      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          if (!mounted) return;
          setState(() {
            _messages = [message, ..._messages].take(_cardCount).toList();
          });
        },
        listenInBackground: false,
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Failed to load SMS: $e';
      });
    }
  }

  Future<void> _loadInbox() async {
    final inbox = await _telephony.getInboxSms(
      columns: [
        SmsColumn.ADDRESS,
        SmsColumn.BODY,
        SmsColumn.DATE,
      ],
      sortOrder: [
        OrderBy(SmsColumn.DATE, sort: Sort.DESC),
      ],
    );

    if (!mounted) return;
    setState(() {
      _messages = inbox.take(_cardCount).toList();
      _loading = false;
      _error = null;
    });
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
            onPressed: _loading ? null : _initSms,
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
        itemCount: _cardCount,
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
  final SmsMessage? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasMessage = message != null;
    final sender = message?.address ?? 'Empty';
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
              if (message?.date != null)
                Text(
                  _formatDate(message!.date!),
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
        title: Text(message!.address ?? 'Message'),
        content: SingleChildScrollView(child: Text(message!.body ?? '')),
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
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }
}
