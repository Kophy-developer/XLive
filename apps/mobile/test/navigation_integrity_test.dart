import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/src/legal/legal_report_screens.dart';
import 'package:xlive_mobile/src/profile/creator_tools_screens.dart';
import 'package:xlive_mobile/src/profile/profile_screens.dart';

final _legacySectionRoute = RegExp(r'''['"](/sections(?:-hub)?|/section/[^'"]+)['"]''');

Set<String> _registeredRoutes() {
  final app = File('lib/src/app.dart').readAsStringSync();
  return RegExp(r"'(/[^']+)'\s*:").allMatches(app).map((m) => m.group(1)!).toSet();
}

Set<String> _namedNavTargets(String source) {
  final out = <String>{};
  for (final m in RegExp(
    r"Navigator\.(?:pushNamed(?:AndRemoveUntil)?|pushReplacementNamed)\(\s*[^,]+,\s*'(/[^']+)'",
  ).allMatches(source)) {
    out.add(m.group(1)!);
  }
  for (final m in RegExp(r"_go\(\s*context\s*,\s*'(/[^']+)'").allMatches(source)) {
    out.add(m.group(1)!);
  }
  return out;
}

void main() {
  test('source has no legacy /section demo routes', () {
    final hits = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final text = file.readAsStringSync();
      for (final m in _legacySectionRoute.allMatches(text)) {
        hits.add('${file.path}: ${m.group(1)}');
      }
    }
    expect(hits, isEmpty, reason: 'legacy section routes still referenced:\n${hits.join('\n')}');
  });

  test('app.dart registers remapped production routes and drops demo hubs', () {
    final app = File('lib/src/app.dart').readAsStringSync();
    for (final route in const [
      '/explore',
      '/chats',
      '/media/preview',
      '/profile/creator/earnings',
      '/profile/settings',
      '/profile/me',
      '/home',
      '/wallet/xlive',
      '/legal/report-issue',
      '/profile/creator/create-clip',
      '/profile/creator/tools',
      '/live/setup',
    ]) {
      expect(app.contains("'$route'"), isTrue, reason: 'missing route $route');
    }
    expect(app.contains('/sections-hub'), isFalse);
    expect(app.contains('/section/'), isFalse);
    expect(app.contains('SectionsHubScreen'), isFalse);
    expect(app.contains('FigmaSectionScreen'), isFalse);
    expect(app.contains('UserProfilePreviewHubScreen'), isFalse);
    expect(app.contains('UserLivePreviewHubScreen'), isFalse);
    expect(app.contains('PlanClipWalletHubScreen'), isFalse);
  });

  test('every named navigation target in lib is registered', () {
    final registered = _registeredRoutes();
    final missing = <String>{};
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final route in _namedNavTargets(file.readAsStringSync())) {
        if (!registered.contains(route)) missing.add('${file.path} -> $route');
      }
    }
    expect(missing, isEmpty, reason: missing.join('\n'));
  });

  test('profile settings tile routes all resolve', () {
    final registered = _registeredRoutes();
    final routes = _namedNavTargets(File('lib/src/profile/profile_screens.dart').readAsStringSync());
    expect(routes.difference(registered), isEmpty);
    expect(routes, containsAll([
      '/wallet/xlive',
      '/profile/gifts',
      '/profile/notifications',
      '/integration/push-inbox',
      '/profile/general-preference',
      '/social/blocked',
      '/social/stream-invites',
      '/social/hashtags',
      '/profile/security',
      '/profile/creator/tools',
      '/profile/creator/create-clip',
      '/profile/creator/created-clips',
      '/profile/creator/edit-clip',
      '/profile/creator/subscription',
      '/profile/creator/subscription-plan',
      '/integration/clip-marketplace',
      '/legal/report-issue',
      '/profile/me',
      '/auth/sign-in',
    ]));
  });

  test('creator tools menu routes all resolve including earnings remap', () {
    final registered = _registeredRoutes();
    final tools = File('lib/src/profile/creator_tools_screens.dart').readAsStringSync();
    final routes = RegExp(r"'(/profile/creator/[^']+)'").allMatches(tools).map((m) => m.group(1)!).toSet();
    expect(routes.difference(registered), isEmpty);
    expect(routes, contains('/profile/creator/earnings'));
  });

  test('bottom nav, create sheet, and media preview use remapped paths', () {
    final bottom = File('lib/src/app_bottom_nav.dart').readAsStringSync();
    expect(_namedNavTargets(bottom), containsAll(['/explore', '/chats', '/home', '/profile/me']));
    expect(bottom.contains('/section/'), isFalse);

    final create = File('lib/src/navigation/create_options_sheet.dart').readAsStringSync();
    expect(_namedNavTargets(create), containsAll(['/profile/creator/create-clip', '/live/setup']));

    final feed = File('lib/src/feed/feed_reel_viewer_screen.dart').readAsStringSync();
    expect(feed.contains("'/media/preview'"), isTrue);
    expect(feed.contains('/section/'), isFalse);

    final explore = File('lib/src/section/explore_menu_screens.dart').readAsStringSync();
    expect(explore.contains("'/media/preview'"), isTrue);
    expect(explore.contains('/section/'), isFalse);

    final chats = File('lib/src/chats/chats_hub_screen.dart').readAsStringSync();
    expect(chats.contains("'/explore'"), isTrue);
    expect(chats.contains('/section/'), isFalse);

    final profile = File('lib/src/profile/user_profile_preview_screens.dart').readAsStringSync();
    expect(profile.contains("'/media/preview'"), isTrue);
    expect(profile.contains("'/profile/settings'"), isTrue);
  });

  test('other-user and media preview reject empty arguments', () {
    final app = File('lib/src/app.dart').readAsStringSync();
    final other = app.indexOf("'/profile/other-user'");
    expect(other, greaterThan(0));
    final otherChunk = app.substring(other, other + 350);
    expect(otherChunk.contains('userId'), isTrue);
    expect(otherChunk.contains('SizedBox.shrink'), isTrue);

    final media = app.indexOf("'/media/preview'");
    expect(media, greaterThan(0));
    final mediaChunk = app.substring(media, media + 350);
    expect(mediaChunk.contains('VideoClipPreviewArgs'), isTrue);
    expect(mediaChunk.contains('SizedBox.shrink'), isTrue);
  });

  testWidgets('settings and report issue screens render', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProfileMainScreen()));
    await tester.pump();
    expect(find.byType(ProfileMainScreen), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Xlive Wallet'), findsOneWidget);
    await tester.drag(find.byType(ListView).first, const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(find.text('Report Issue'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: ReportIssueScreen()));
    await tester.pump();
    expect(find.byType(ReportIssueScreen), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: CreatorGate(child: CreatorToolsMenuScreen())));
    await tester.pump();
    expect(find.byType(CreatorGate), findsOneWidget);
    expect(find.textContaining('Creator'), findsWidgets);
  });
}
