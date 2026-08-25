import 'dart:io' show Platform;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:native_device_orientation/native_device_orientation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/memory_record.dart';
import '../services/notification_service.dart';
import '../services/photo_store.dart';
import '../services/record_store.dart';
import '../services/stt/stt_service.dart';
import 'capture_review_screen.dart';
import 'record_detail_screen.dart';
import 'records_screen.dart';
import 'settings_screen.dart';

/// Daily home: live camera preview with a big bottom shutter. Opening the app
/// shows the camera directly (the elderly point and shoot). Tapping the
/// shutter captures a still and moves to the capture-review flow.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.stt});

  final SttService stt;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _initInProgress = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    // Guard against concurrent inits (e.g. a resumed lifecycle event firing
    // while the first init is still awaiting the permission dialog), which
    // would open the camera twice and leave a black preview.
    if (_initInProgress) return;
    _initInProgress = true;
    try {
      await _controller?.dispose();
      _controller = null;
      if (!mounted) return;
      setState(() {
        _initializing = true;
        _error = null;
      });
      // Android needs an explicit runtime request. On iOS the camera plugin
      // triggers the system NSCameraUsageDescription prompt on initialize(),
      // so requesting via permission_handler there is unnecessary (and needs
      // extra Podfile macros to work at all).
      if (Platform.isAndroid) {
        final status = await Permission.camera.request();
        if (!status.isGranted) {
          _fail('需要相機權限');
          return;
        }
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail('找不到相機');
        return;
      }
      final controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      _fail('相機開啟失敗');
    } finally {
      _initInProgress = false;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _initializing = false;
      _error = message;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Stop any ringing reminder FIRST, before the heavy camera init — the
      // foreground window after a notification tap can be very short, so the
      // cancel messages must be posted before iOS may suspend us again.
      NotificationService.stopActive();
      // Always re-init on resume (the controller may have been released by a
      // transient inactive at cold start); the concurrency guard prevents a
      // double open.
      _initCamera();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      final controller = _controller;
      _controller = null;
      controller?.dispose();
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture) {
      return;
    }
    try {
      // Orient the photo to how the phone is physically held (works even with
      // the OS rotation lock on, since the UI itself stays portrait).
      final native = await NativeDeviceOrientationCommunicator().orientation(
        useSensor: true,
      );
      await controller.lockCaptureOrientation(_captureOrientation(native));
      final file = await controller.takePicture();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (routeContext) => CaptureReviewScreen(
            photoPath: file.path,
            stt: widget.stt,
            onRetake: () => Navigator.of(routeContext).pop(),
            onSave: (record) async {
              final reminderAt = record.isReminder ? record.reminderAt : null;
              if (reminderAt != null &&
                  !await NotificationService.requestSchedulePermission()) {
                if (routeContext.mounted) {
                  ScaffoldMessenger.of(routeContext).showSnackBar(
                    const SnackBar(content: Text('提醒權限尚未開啟，這筆記錄還沒有儲存')),
                  );
                }
                return;
              }

              var notificationScheduled = false;
              String? importedPhotoPath;
              try {
                if (reminderAt != null) {
                  await NotificationService.scheduleSeries(
                    recordId: record.id,
                    body: record.text,
                    at: reminderAt,
                  );
                  notificationScheduled = true;
                }
                importedPhotoPath = await PhotoStore.importPhoto(file.path);
                record.photoPath = importedPhotoPath;
                await RecordStore.save(record);
                try {
                  await PhotoStore.deleteTemporaryFile(file.path);
                } catch (_) {
                  // NOTE(ceiling): A failed cleanup can leave one camera temp
                  // file. Add startup temp cleanup if this appears in practice.
                }
                if (routeContext.mounted) Navigator.of(routeContext).pop();
              } catch (_) {
                if (notificationScheduled) {
                  await NotificationService.cancelSeries(record.id);
                }
                if (importedPhotoPath != null) {
                  await PhotoStore.deleteStoredFile(importedPhotoPath);
                }
                if (routeContext.mounted) {
                  ScaffoldMessenger.of(routeContext).showSnackBar(
                    const SnackBar(content: Text('記錄沒有儲存，請確認提醒時間與權限後再試')),
                  );
                }
              }
            },
          ),
        ),
      );
      // The preview can freeze/black out after takePicture on iOS; restart it
      // when returning from the review (whether saved or retaken).
      if (mounted) await _initCamera();
    } catch (_) {
      // Capture can fail transiently (e.g. focus); the user can retry.
    }
  }

  DeviceOrientation _captureOrientation(NativeDeviceOrientation native) {
    switch (native) {
      case NativeDeviceOrientation.landscapeLeft:
        return DeviceOrientation.landscapeLeft;
      case NativeDeviceOrientation.landscapeRight:
        return DeviceOrientation.landscapeRight;
      case NativeDeviceOrientation.portraitDown:
        return DeviceOrientation.portraitDown;
      case NativeDeviceOrientation.portraitUp:
      case NativeDeviceOrientation.unknown:
        return DeviceOrientation.portraitUp;
    }
  }

  void _openRecords() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _RecordsPage()));
  }

  void _openSettings() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildPreview(),
          SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _SettingsButton(onTap: _openSettings),
                  ),
                ),
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _RecordsButton(onTap: _openRecords),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: _ShutterButton(onTap: _capture),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_initializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return Center(
        child: Text(
          _error ?? '相機無法使用',
          style: const TextStyle(color: Colors.white, fontSize: 26),
        ),
      );
    }
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    // Fill the screen without distortion. previewSize is in the sensor's
    // landscape orientation, so swap width/height for the portrait layout.
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// Large white shutter button (camera-app convention, bottom-centre).
class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.white70, width: 6),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 8)],
        ),
        child: const Icon(Icons.camera_alt, size: 40, color: Colors.black87),
      ),
    );
  }
}

/// Transparent "設定" button over the preview, styled like the records button.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text('設定', style: TextStyle(color: Colors.white, fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Clearly labelled "看記錄" button over the preview.
class _RecordsButton extends StatelessWidget {
  const _RecordsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.photo_library, color: Colors.white, size: 28),
              SizedBox(width: 8),
              Text('看記錄', style: TextStyle(color: Colors.white, fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Records list page. Owns its data so it re-queries after a record is
/// edited or deleted in the detail screen (avoids showing a deleted ghost).
class _RecordsPage extends StatefulWidget {
  const _RecordsPage();

  @override
  State<_RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<_RecordsPage> {
  late List<MemoryRecord> _records = RecordStore.getAll();

  void _refresh() => setState(() => _records = RecordStore.getAll());

  @override
  Widget build(BuildContext context) {
    return RecordsScreen(
      records: _records,
      onTap: (r) async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (detailContext) => RecordDetailScreen(
              record: r,
              onEdit: (t) async {
                final oldText = r.text;
                final reminderAt = r.reminderAt;
                final updatesFutureReminder =
                    r.isReminder &&
                    reminderAt != null &&
                    reminderAt.isAfter(DateTime.now());

                if (updatesFutureReminder) {
                  try {
                    await NotificationService.scheduleSeries(
                      recordId: r.id,
                      body: t,
                      at: reminderAt,
                    );
                  } catch (_) {
                    await NotificationService.scheduleSeries(
                      recordId: r.id,
                      body: oldText,
                      at: reminderAt,
                    );
                    rethrow;
                  }
                }

                r.text = t;
                try {
                  await RecordStore.save(r);
                } catch (_) {
                  r.text = oldText;
                  if (updatesFutureReminder) {
                    await NotificationService.scheduleSeries(
                      recordId: r.id,
                      body: oldText,
                      at: reminderAt,
                    );
                  }
                  rethrow;
                }
              },
              onDelete: () async {
                await NotificationService.cancelSeries(r.id);
                await RecordStore.delete(r.id);
                if (detailContext.mounted) Navigator.of(detailContext).pop();
              },
            ),
          ),
        );
        _refresh();
      },
    );
  }
}
