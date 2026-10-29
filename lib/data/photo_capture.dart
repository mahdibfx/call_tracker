import 'package:image_picker/image_picker.dart';

/// Taking the one photo a report is allowed.
///
/// Camera only, deliberately: a report has to be filed where the problem is,
/// not from a screenshot taken days ago. Do not add a gallery source.
class PhotoCapture {
  static final _picker = ImagePicker();

  /// Opens the camera. Null if the user backed out or there is no usable
  /// camera.
  static Future<String?> takePhoto() => _pick(ImageSource.camera);

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
