/*
 * This file is part of wger Workout Manager <https://github.com/wger-project>.
 * Copyright (C) 2020, 2025 wger Team
 *
 * wger Workout Manager is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * wger Workout Manager is distributed in the hope that it will be useful,
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
import 'package:wger/core/network/network_provider.dart';
import 'package:wger/core/wide_screen_wrapper.dart';
import 'package:wger/core/widgets/async_value_widget.dart';
import 'package:wger/core/widgets/error.dart';
import 'package:wger/core/widgets/object_gone_redirect.dart';
import 'package:wger/features/routines/models/routine.dart';
import 'package:wger/features/routines/providers/routines_notifier.dart';
import 'package:wger/features/routines/widgets/app_bar.dart';
import 'package:wger/features/routines/widgets/routine_detail.dart';

class RoutineScreen extends ConsumerStatefulWidget {
  const RoutineScreen({super.key});

  static const routeName = '/routine-detail';

  @override
  ConsumerState<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends ConsumerState<RoutineScreen> {
  int? _prefetchedRoutineId;

  void _triggerPrefetchIfNeeded(Routine routine, bool isOnline) {
    if (isOnline && routine.isHydrated && _prefetchedRoutineId != routine.id) {
      _prefetchedRoutineId = routine.id;
      unawaited(ref.read(routinesRiverpodProvider.notifier).prefetchRoutineMedia(routine));
    }
  }

  @override
  Widget build(BuildContext context) {
    final routineId = ModalRoute.of(context)!.settings.arguments as int;
    final isOnline = ref.watch(networkStatusProvider);
    final asyncState = ref.watch(routinesRiverpodProvider);

    final routine = asyncState.value?.findByIdOrNull(routineId);
    if (isOnline && routine != null && !routine.isHydrated) {
      ref.watch(routineHydrationProvider(routineId));
    }
    if (routine != null) {
      _triggerPrefetchIfNeeded(routine, isOnline);
    }

    return AsyncValueWidget<RoutinesState>(
      value: asyncState,
      loggerName: 'RoutineScreen',
      loading: const Scaffold(body: Center(child: CircularProgressIndicator())),
      errorBuilder: (e, st) => Scaffold(
        body: Center(child: StreamErrorIndicator(e, stacktrace: st)),
      ),
      data: (state) {
        final currentRoutine = state.findByIdOrNull(routineId);
        if (currentRoutine == null) {
          return objectGoneRedirect(context);
        }
        return Scaffold(
          appBar: RoutineDetailAppBar(currentRoutine),
          body: WidescreenWrapper(
            child: SingleChildScrollView(
              child: RoutineDetail(currentRoutine),
            ),
          ),
        );
      },
    );
  }
}
