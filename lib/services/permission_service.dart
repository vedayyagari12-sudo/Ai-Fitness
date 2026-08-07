import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';

class PermissionService {
  /// Runtime permissions only exist on mobile. On web/desktop the OS/browser
  /// handles access at pick time, so we skip permission_handler entirely
  /// (it returns denied or is unimplemented there, which silently blocked
  /// the camera/gallery buttons).
  static bool get _isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Camera only — used for photo capture.
  static Future<bool> requestCamera(BuildContext context) async {
    if (!_isMobile) return true;
    final status = await Permission.camera.request();
    if (status.isGranted) return true;
    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context);
    } else {
      await _showDeniedDialog(context);
    }
    return false;
  }

  /// Gallery / photo library only — used for picking existing photos.
  static Future<bool> requestGallery(BuildContext context) async {
    if (!_isMobile) return true;
    final status = await Permission.photos.request();
    if (status.isGranted || status.isLimited) return true;
    if (!context.mounted) return false;
    if (status.isPermanentlyDenied) {
      await _showSettingsDialog(context);
    } else {
      await _showDeniedDialog(context);
    }
    return false;
  }

  /// Both camera + media — used by physique scan (needs multi-photo).
  static Future<bool> requestCameraAndMedia(BuildContext context) async {
    if (!_isMobile) return true;
    final perms = await [Permission.camera, Permission.photos].request();

    final cameraStatus = perms[Permission.camera]!;
    final photosStatus = perms[Permission.photos]!;

    if (cameraStatus.isGranted && photosStatus.isGranted) return true;

    if (!context.mounted) return false;

    final isPermanent =
        cameraStatus.isPermanentlyDenied || photosStatus.isPermanentlyDenied;
    if (isPermanent) {
      await _showSettingsDialog(context);
      return false;
    }

    await _showDeniedDialog(context);
    return false;
  }

  static Future<void> _showDeniedDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Camera & Photos Access',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Physiqo AI needs camera and photo library access to scan meals and analyse your physique.\n\nPlease allow access when prompted.',
          style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: kBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showSettingsDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Permission Required',
          style: TextStyle(
            color: kTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
        content: Text(
          'Camera and photo access has been denied.\n\nTo use scanning features, please enable access in your device Settings → Apps → Physiqo AI → Permissions.',
          style: TextStyle(color: kTextSecondary, fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: kTextSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
            },
            child: const Text(
              'Open Settings',
              style: TextStyle(color: kBlue, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
