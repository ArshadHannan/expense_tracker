import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

/// Entry point booted by `flutter_overlay_window` in its own engine.
/// Must be top-level + `vm:entry-point` so AOT keeps it alive.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _OverlayApp());
}

class _OverlayApp extends StatelessWidget {
  const _OverlayApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _OverlayRoot(),
    );
  }
}

class _OverlayRoot extends StatefulWidget {
  const _OverlayRoot();

  @override
  State<_OverlayRoot> createState() => _OverlayRootState();
}

class _OverlayRootState extends State<_OverlayRoot> {
  StreamSubscription<dynamic>? _sub;
  String _sender = '';
  String _body = '';

  @override
  void initState() {
    super.initState();
    _sub = FlutterOverlayWindow.overlayListener.listen(_onPayload);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onPayload(dynamic payload) {
    if (payload is Map) {
      setState(() {
        _sender = (payload['sender'] as String?) ?? '';
        _body = (payload['body'] as String?) ?? '';
      });
    }
  }

  Future<void> _close() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final initial = _sender.isNotEmpty ? _sender.characters.first.toUpperCase() : '?';
    final displaySender = _sender.isEmpty ? 'Unknown sender' : _sender;
    final displayBody = _body.isEmpty ? 'Waiting for message…' : _body;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1F1B2E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black54,
                  blurRadius: 18,
                  offset: Offset(0, 6),
                ),
              ],
              border: Border.all(color: Colors.deepPurpleAccent, width: 1.2),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.deepPurpleAccent,
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displaySender,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Text(
                            'New SMS · Expense Tracker',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _close,
                      icon: const Icon(Icons.close, color: Colors.white70),
                      tooltip: 'Dismiss',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  displayBody,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.35),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin wrapper around the plugin so the rest of the app stays platform-agnostic.
class OverlayPopupService {
  static const _overlayHeight = 220;
  static const _overlayWidth = WindowSize.matchParent;

  static Future<bool> isPermissionGranted() async {
    try {
      return (await FlutterOverlayWindow.isPermissionGranted()) ?? false;
    } catch (e) {
      debugPrint('[OVERLAY] perm check failed: $e');
      return false;
    }
  }

  static Future<bool> requestPermission() async {
    try {
      return (await FlutterOverlayWindow.requestPermission()) ?? false;
    } catch (e) {
      debugPrint('[OVERLAY] perm request failed: $e');
      return false;
    }
  }

  /// Show (or update if already showing) the Truecaller-style popup.
  static Future<void> showSmsPopup({
    required String sender,
    required String body,
  }) async {
    try {
      if (!await isPermissionGranted()) {
        debugPrint('[OVERLAY] skipped — SYSTEM_ALERT_WINDOW not granted');
        return;
      }

      final alreadyShown = (await FlutterOverlayWindow.isActive()) ?? false;
      if (!alreadyShown) {
        await FlutterOverlayWindow.showOverlay(
          height: _overlayHeight,
          width: _overlayWidth,
          alignment: OverlayAlignment.topCenter,
          flag: OverlayFlag.defaultFlag,
          enableDrag: true,
          overlayTitle: 'Expense Tracker',
          overlayContent: 'New message captured',
          positionGravity: PositionGravity.auto,
          visibility: NotificationVisibility.visibilityPublic,
        );
        // Give the overlay engine a beat to spin up and attach its listener.
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      await FlutterOverlayWindow.shareData({
        'sender': sender,
        'body': body,
      });
    } catch (e, st) {
      debugPrint('[OVERLAY] showSmsPopup failed: $e\n$st');
    }
  }
}
