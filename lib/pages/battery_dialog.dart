import 'package:flutter/material.dart';

import '../app/settings.dart';
import '../theme/deskmate_tokens.dart';

/// Asks for the two battery limits: plug in below the first, unplug above the second.
Future<void> editBatteryWarnings(BuildContext context, SettingsController settings) async {
  final t = DeskmateTokens.of(context);
  var range = RangeValues(settings.batteryLow.toDouble(), settings.batteryHigh.toDouble());
  final result = await showDialog<RangeValues>(
    context: context,
    builder:
        (context) => StatefulBuilder(
          builder:
              (context, setState) => AlertDialog(
                backgroundColor: t.panel,
                title: Text('Battery warnings', style: t.ui(16, weight: 600)),
                content: SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Plug in below ${range.start.round()}% · unplug above ${range.end.round()}%',
                        style: t.ui(13, color: t.muted),
                      ),
                      RangeSlider(
                        values: range,
                        min: 10,
                        max: 95,
                        divisions: 17,
                        activeColor: t.clay,
                        inactiveColor: t.track,
                        labels: RangeLabels('${range.start.round()}%', '${range.end.round()}%'),
                        onChanged: (v) => setState(() => range = v),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: t.ui(14, color: t.muted)),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, range),
                    child: Text('Save', style: t.ui(14, weight: 600, color: t.clay)),
                  ),
                ],
              ),
        ),
  );
  if (result != null) settings.setBatteryLimits(result.start.round(), result.end.round());
}
