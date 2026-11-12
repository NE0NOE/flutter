/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (c) 2026 wger Team
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

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/core/snackbar.dart';
import 'package:wger/features/script_import/script_import_prompt.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Instructional card displaying guidance on how to generate compatible JSON
/// scripts with an LLM, along with a one-click button to copy the prompt to clipboard.
class AiPromptCard extends StatelessWidget {
  const AiPromptCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final i18n = AppLocalizations.of(context);

    return Card(
      elevation: 1,
      color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: theme.colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    i18n.aiPromptInstructionTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              i18n.aiPromptInstructionBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                key: const Key('copy_ai_prompt_button'),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(i18n.copyAiPrompt),
                onPressed: () async {
                  await Clipboard.setData(
                    const ClipboardData(text: aiScriptImportPrompt),
                  );
                  if (context.mounted) {
                    showSnackbar(context, i18n.aiPromptCopied);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
