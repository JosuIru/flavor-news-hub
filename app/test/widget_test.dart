import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flavor_news_hub/app.dart';
import 'package:flavor_news_hub/core/providers/preferences_provider.dart';

void main() {
  testWidgets('La app arranca y muestra la tab del feed', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
        ],
        child: const FlavorNewsHubApp(),
      ),
    );
    await tester.pumpAndSettle();

    // La shell monta 3 tabs con iconos característicos, sea cual sea el locale.
    expect(find.byIcon(Icons.article), findsOneWidget); // tab Feed, seleccionada
    expect(find.byIcon(Icons.groups_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });
}
