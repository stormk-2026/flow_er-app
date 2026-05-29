import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/app_database.dart';
import '../../models/thought_capture_mode.dart';
import '../../providers/app_providers.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _inputController = TextEditingController();

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(intentControllerProvider, (_, next) {
      next.whenOrNull(
        error: (error, _) => ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString()))),
      );
    });

    final controllerState = ref.watch(intentControllerProvider);
    final intents = ref.watch(intentsProvider);
    final focusState = ref.watch(focusStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons/flow_er_icon_trans.png', height: 28),
            const SizedBox(width: 8),
            const Text('流境'),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                focusState.maybeWhen(
                  data: (state) => state.label,
                  orElse: () => 'Sensor...',
                ),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _inputController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '记下一条心笺',
                labelText: '心笺',
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: controllerState.isLoading ? null : _submit,
                child: controllerState.isLoading
                    ? const Text('Saving...')
                    : const Text('Save Journal'),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: intents.when(
                data: _IntentList.new,
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(child: Text(error.toString())),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    await ref
        .read(intentControllerProvider.notifier)
        .saveJournal(
          mode: ThoughtCaptureMode.quick,
          quickText: _inputController.text,
          title: '',
          body: '',
        );

    if (mounted && !ref.read(intentControllerProvider).hasError) {
      _inputController.clear();
    }
  }
}

class _IntentList extends StatelessWidget {
  const _IntentList(this.intents);

  final List<FlowIntent> intents;

  @override
  Widget build(BuildContext context) {
    if (intents.isEmpty) {
      return const Center(child: Text('No intents yet.'));
    }

    return ListView.separated(
      itemCount: intents.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final intent = intents[index];

        return ListTile(
          title: Text(intent.title),
          subtitle: Text(intent.note ?? intent.rawInput),
          trailing: Text(intent.priority),
        );
      },
    );
  }
}
