import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../l10n/l10n.dart';

class ProService {
  static const String proKey = 'proUnlocked';
  static const int templateLimit = 5;

  static bool isPro(Box settings) => (settings.get(proKey) as bool?) ?? false;

  static ValueListenable<Box> listenable(Box settings) {
    return settings.listenable(keys: [proKey]);
  }

  static Future<void> setPro(Box settings, bool value) async {
    await settings.put(proKey, value);
  }

  static Future<bool> ensureTemplateCapacity(
    BuildContext context,
    Box settings,
    int currentCount,
  ) async {
    if (isPro(settings) || currentCount < templateLimit) return true;
    await showUpsell(context, settings, feature: AppLocalizations.of(context).proFeatureTemplates);
    return false;
  }

  static Future<void> showUpsell(
    BuildContext context,
    Box settings, {
    String? feature,
  }) async {
    final s = AppLocalizations.of(context);
    final unlocked = isPro(settings);
    final body = <Widget>[
      Text(unlocked ? s.proActiveBody : s.proBody),
      if (feature != null) ...[
        const SizedBox(height: 12),
        Text('${s.proFeatureLocked} $feature'),
      ],
    ];

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(unlocked ? s.proActiveTitle : s.proTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: body,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(unlocked ? s.close : s.proNotNow)),
          if (!unlocked)
            FilledButton(
              onPressed: () async {
                await setPro(settings, true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.proUnlockedSnack)));
                }
              },
              child: Text(s.proEnableTest),
            ),
          if (unlocked)
            FilledButton.tonal(
              onPressed: () async {
                await setPro(settings, false);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(s.proLockedSnack)));
                }
              },
              child: Text(s.proDisableTest),
            ),
        ],
      ),
    );
  }
}
