import 'package:image_picker/image_picker.dart';

/// Taking the one photo a report is allowed.
///
/// Camera only, deliberately: a report is evidence of something happening now,
/// and letting an old screenshot in defeats the point. No gallery path exists.
class PhotoCapture {
  static final _picker = ImagePicker();

  /// Opens the camera and returns the file path, or null if the user backed
  /// out or the device has no usable camera.
  ///
  /// Downscaled on the way out: phone cameras produce 5–12MB frames and the
  /// backend refuses anything over 10MB, so a full-resolution capture would
  /// fail in the field rather than in testing.
  static Future<String?> takePhoto() async {
    try {
      final shot = await _picker.pickImage(
        source: ImageSource.camera,
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
