import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:call_tracker/ui/views/login/login_view.dart';

/// The login screen loads the launcher icon by path, so a rename or a dropped
/// `assets:` entry in pubspec.yaml would only show up as a grey box at runtime
/// — nothing here fails to compile. This is the guard for that.
void main() {
  testWidgets('the login screen shows the app logo asset', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginView()));

    final image = tester.widget<Image>(
      find.descendant(of: find.byType(ClipRRect), matching: find.byType(Image)),
    );
    expect((image.image as AssetImage).assetName, 'assets/icon/app_icon.png');

    // Loading it for real is what proves it is actually bundled.
    await tester.runAsync(
      () => precacheImage(image.image, tester.element(find.byType(LoginView))),
    );
  });
}
