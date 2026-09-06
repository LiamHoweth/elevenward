import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../app_controller.dart';
import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class CreateCareerScreen extends StatefulWidget {
  const CreateCareerScreen({
    super.key,
    required this.controller,
    required this.slotIndex,
  });

  final AppController controller;
  final int slotIndex;

  @override
  State<CreateCareerScreen> createState() => _CreateCareerScreenState();
}

final class _CreateCareerScreenState extends State<CreateCareerScreen> {
  final _name = TextEditingController(text: 'Mika Vale');
  final _form = GlobalKey<FormState>();
  final _world = buildLaunchWorld();
  Archetype _archetype = Archetype.poacher;
  String _nationalTeam = 'united-states';
  late ClubDefinition _club;
  Difficulty _difficulty = Difficulty.professional;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _club = _world.clubs.first;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.createPlayer)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 36),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 24,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: context.l10n.playerName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                final text = value?.trim() ?? '';
                return text.length >= 2
                    ? null
                    : uiCopy(contentLocale(context), 'nameValidation');
              },
            ),
            const SizedBox(height: 16),
            _Label(context.l10n.positionAndStyle),
            const SizedBox(height: 9),
            DropdownButtonFormField<Archetype>(
              initialValue: _archetype,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: Archetype.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(
                        '${localizedPosition(contentLocale(context), value.positionFamily.name)} · ${localizedArchetype(contentLocale(context), value)}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _archetype = value!),
            ),
            const SizedBox(height: 20),
            _Label(context.l10n.nationalTeam),
            const SizedBox(height: 9),
            DropdownButtonFormField<String>(
              initialValue: _nationalTeam,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _world.nationalTeams
                  .map(
                    (team) => DropdownMenuItem(
                      value: team.id,
                      child: Text('${team.countryName} · ${team.region}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _nationalTeam = value!),
            ),
            const SizedBox(height: 20),
            _Label(context.l10n.startingClub),
            const SizedBox(height: 9),
            DropdownButtonFormField<ClubDefinition>(
              initialValue: _club,
              isExpanded: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: _world.clubs
                  .map(
                    (club) => DropdownMenuItem(
                      value: club,
                      child: Text(
                        '${club.name} · ${localizedFootballNation(contentLocale(context), club.nation)} ${club.division == DivisionLevel.first ? 'I' : 'II'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _club = value!),
            ),
            const SizedBox(height: 20),
            _Label(context.l10n.difficulty),
            const SizedBox(height: 9),
            SegmentedButton<Difficulty>(
              segments: [
                ButtonSegment(
                  value: Difficulty.story,
                  label: Text(context.l10n.story),
                ),
                ButtonSegment(
                  value: Difficulty.professional,
                  label: Text(context.l10n.professional),
                ),
                ButtonSegment(
                  value: Difficulty.worldClass,
                  label: Text(context.l10n.worldClass),
                ),
              ],
              selected: {_difficulty},
              showSelectedIcon: false,
              onSelectionChanged: (value) =>
                  setState(() => _difficulty = value.single),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.l10n.startCareer.toUpperCase()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await widget.controller.createCareer(
      slotIndex: widget.slotIndex,
      playerName: _name.text,
      archetype: _archetype,
      nationalTeamId: _nationalTeam,
      club: _club,
      difficulty: _difficulty,
    );
    if (mounted) Navigator.of(context).pop();
  }
}

final class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: ElevenwardColors.grass,
      fontSize: 11,
      fontWeight: FontWeight.w900,
      letterSpacing: 1,
    ),
  );
}
