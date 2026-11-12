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

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:wger/core/snackbar.dart';
import 'package:wger/core/wide_screen_wrapper.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/features/script_import/models/script_import_data.dart';
import 'package:wger/features/script_import/models/script_import_error.dart';
import 'package:wger/features/script_import/models/script_validator.dart';
import 'package:wger/features/script_import/providers/script_import_repository.dart';
import 'package:wger/features/script_import/widgets/ai_prompt_card.dart';
import 'package:wger/l10n/generated/app_localizations.dart';

/// Screen allowing the user to paste a JSON routine / nutrition script,
/// validate its structure and catalog references, preview the changes,
/// and commit them transactionally to the local Drift database.
class ScriptImportScreen extends ConsumerStatefulWidget {
  const ScriptImportScreen({super.key});

  static const routeName = '/script-import';

  @override
  ConsumerState<ScriptImportScreen> createState() => _ScriptImportScreenState();
}

class _ScriptImportScreenState extends ConsumerState<ScriptImportScreen> {
  late final TextEditingController _controller;
  bool _isValidating = false;
  bool _isSaving = false;
  List<ScriptImportError> _errors = const [];
  List<String> _warnings = const [];
  ScriptImportPayload? _validatedPayload;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _validate() async {
    setState(() {
      _isValidating = true;
      _errors = const [];
      _warnings = const [];
      _validatedPayload = null;
    });

    final text = _controller.text;
    final syntaxResult = ScriptValidator.validateString(text);

    if (!syntaxResult.isValid) {
      setState(() {
        _isValidating = false;
        _errors = syntaxResult.errors;
        _warnings = syntaxResult.warnings;
      });
      return;
    }

    final payload = syntaxResult.payload!;
    final repo = ref.read(scriptImportRepositoryProvider);
    final semanticErrors = await repo.resolveReferences(payload);

    setState(() {
      _isValidating = false;
      _warnings = syntaxResult.warnings;
      if (semanticErrors.isNotEmpty) {
        _errors = semanticErrors;
      } else {
        _errors = const [];
        _validatedPayload = payload;
      }
    });
  }

  Future<void> _confirmAndSave() async {
    final payload = _validatedPayload;
    if (payload == null) {
      return;
    }

    final i18n = AppLocalizations.of(context);

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.confirmImportTitle),
        content: Text(
          i18n.confirmImportBody(payload.routines.length, payload.nutritionPlans.length),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(MaterialLocalizations.of(ctx).cancelButtonLabel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(i18n.save),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repo = ref.read(scriptImportRepositoryProvider);
      final result = await repo.savePayload(payload);

      // Non-blocking offline media cache prefetch for every imported routine
      final routinesNotifier = ref.read(routinesRiverpodProvider.notifier);
      for (final r in result.importedRoutines) {
        unawaited(routinesNotifier.prefetchRoutineMedia(r));
      }

      if (mounted) {
        showSnackbar(context, i18n.importSuccess);
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context, 'Import failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.importScript),
      ),
      body: WidescreenWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const AiPromptCard(),
            const SizedBox(height: 16),
            TextField(
              key: const Key('script_input_field'),
              controller: _controller,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: i18n.pasteJsonHere,
                hintText: '{\n  "schema_version": 1,\n  "routines": [...]\n}',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    key: const Key('validate_script_button'),
                    icon: _isValidating
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(i18n.validateScript),
                    onPressed: _isValidating || _isSaving ? null : _validate,
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _isValidating || _isSaving
                      ? null
                      : () {
                          _controller.clear();
                          setState(() {
                            _errors = const [];
                            _warnings = const [];
                            _validatedPayload = null;
                          });
                        },
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_errors.isNotEmpty) ...[
              Card(
                color: theme.colorScheme.errorContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: theme.colorScheme.error),
                          const SizedBox(width: 8),
                          Text(
                            i18n.scriptErrorsFound(_errors.length),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._errors.map(
                        (err) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            '• ${err.formattedMessage}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Card(
                color: Colors.amber.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.amber.shade900),
                          const SizedBox(width: 8),
                          Text(
                            'Warnings (${_warnings.length})',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._warnings.map(
                        (w) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2.0),
                          child: Text(
                            '• $w',
                            style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_validatedPayload != null && _errors.isEmpty) ...[
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(
                            i18n.previewImport,
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      if (_validatedPayload!.routines.isNotEmpty) ...[
                        Text(
                          'Routines (${_validatedPayload!.routines.length}):',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ..._validatedPayload!.routines.map(
                          (r) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Text(
                              '• [${r.action.name.toUpperCase()}] "${r.name}" '
                              '(${r.days.length} days, ${r.totalExercises} exercises)',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (_validatedPayload!.nutritionPlans.isNotEmpty) ...[
                        Text(
                          'Nutrition Plans (${_validatedPayload!.nutritionPlans.length}):',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        ..._validatedPayload!.nutritionPlans.map(
                          (p) => Padding(
                            padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                            child: Text(
                              '• [${p.action.name.toUpperCase()}] "${p.description}" '
                              '(${p.meals.length} meals, ${p.totalIngredients} items)',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          key: const Key('save_imported_script_button'),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(i18n.saveToDatabase),
                          onPressed: _isSaving ? null : _confirmAndSave,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
