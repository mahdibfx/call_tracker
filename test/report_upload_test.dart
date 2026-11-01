import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/data/report_api.dart';

/// The backend refuses any upload that is not `image/*`, and
/// `MultipartFile.fromPath` labels a file `application/octet-stream` by
/// default — which silently broke every report that carried a photo.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('report_upload'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<String> fileNamed(String name) async {
    final file = File('${dir.path}/$name');
    await file.writeAsBytes([0xFF, 0xD8, 0xFF]);
    return file.path;
  }

  test('the part is always typed as an image, never octet-stream', () async {
    for (final name in ['shot.jpg', 'shot.JPEG', 'shot.png', 'shot.heic', 'shot.webp']) {
      final part = await ReportApi.imagePart('image', await fileNamed(name));
      expect(part.contentType.type, 'image', reason: name);
    }
  });

  test('the common camera formats keep their own subtype', () async {
    expect((await ReportApi.imagePart('image', await fileNamed('a.jpg'))).contentType.subtype, 'jpeg');
    expect((await ReportApi.imagePart('image', await fileNamed('a.png'))).contentType.subtype, 'png');
    expect((await ReportApi.imagePart('image', await fileNamed('a.heic'))).contentType.subtype, 'heic');
  });

  test('an extension we do not know falls back to jpeg, not octet-stream', () async {
    final part = await ReportApi.imagePart('image', await fileNamed('noextension'));
    expect(part.contentType.mimeType, 'image/jpeg');
  });

  test('the field name is carried through for the confirmation photo', () async {
    final part = await ReportApi.imagePart('confirmation_image', await fileNamed('a.jpg'));
    expect(part.field, 'confirmation_image');
  });
}
