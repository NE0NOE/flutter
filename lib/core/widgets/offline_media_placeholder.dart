/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 - 2026 wger Team
 *
 * wger Workout Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import 'package:material_ui/material_ui.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Neutral placeholder shown when a media asset (image, GIF, video) is not
/// available in local cache and cannot be fetched because the device is offline.
class OfflineMediaPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  final IconData icon;
  final String? message;
  final BorderRadius? borderRadius;

  const OfflineMediaPlaceholder({
    super.key,
    this.width,
    this.height,
    this.icon = Icons.cloud_off,
    this.message,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message ?? AppLocalizations.of(context).mediaNotAvailableOffline;
    final color = theme.colorScheme.outline;

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = width ?? (constraints.hasBoundedWidth ? constraints.maxWidth : null);
        final h = height ?? (constraints.hasBoundedHeight ? constraints.maxHeight : null);
        final isCompact = (w != null && w < 60) || (h != null && h < 60);

        return Container(
          width: width,
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: borderRadius ?? BorderRadius.circular(4),
          ),
          child: isCompact
              ? Tooltip(
                  message: text,
                  child: Icon(icon, size: 20, color: color),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(icon, size: 32, color: color),
                    const SizedBox(height: 4),
                    Text(
                      text,
                      style: theme.textTheme.labelSmall?.copyWith(color: color),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
