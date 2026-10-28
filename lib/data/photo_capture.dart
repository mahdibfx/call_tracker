import 'package:image_picker/image_picker.dart';

/// Taking the one photo a report is allowed.
///
/// Both sources are offered, matching the dashboard's report form: a problem
/// is often photographed before anyone opens the app.
class PhotoCapture {
  static final _picker = ImagePicker();

  /// Opens the camera. Null if the user backed out or there is no usable
  /// camera.
  static Future<String?> takePhoto() => _pick(ImageSource.camera);

  /// Opens the gallery. Null if the user backed out.
  static Future<String?> choosePhoto() => _pick(ImageSource.gallery);

  /// Downscaled on the way out: phone cameras produce 5–12MB frames and the
  /// backend refuses anything over 10MB, so a full-resolution image would fail
  /// in the field rather than in testing.
  static Future<String?> _pick(ImageSource source) async {
    try {
      final shot = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1920,
      );
      return shot?.path;
    } catch (_) {
      // No camera, or permission refused. The caller treats it as "no photo".
      return null;
    }
  }
}
