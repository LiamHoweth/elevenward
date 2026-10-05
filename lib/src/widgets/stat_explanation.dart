import 'package:elevenward_core/elevenward_core.dart';
import 'package:flutter/material.dart';

import '../l10n_context.dart';

enum ExplainedStat { managerTrust, form, tacticalFit, legacyScore }

String explainedStatLabel(String locale, ExplainedStat stat) =>
    _copy(locale, '${stat.name}Title');

String explainedStatHelpLabel(String locale, ExplainedStat stat) => _copy(
  locale,
  'explain',
).replaceAll('{stat}', explainedStatLabel(locale, stat));

/// Help reads the career's rules without changing its state or progression.
final class StatExplanationButton extends StatelessWidget {
  const StatExplanationButton({super.key, required this.stat, this.career});

  final ExplainedStat stat;
  final CareerSnapshot? career;

  @override
  Widget build(BuildContext context) => _statIconAction(
    key: Key('stat-help-${stat.name}'),
    label: explainedStatHelpLabel(contentLocale(context), stat),
    iconSize: 19,
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    onPressed: () => showStatExplanation(context, stat, career: career),
    icon: Icons.info_outline_rounded,
  );
}

// Expose one named action on both platforms. A visual tooltip is kept separate
// so VoiceOver does not append the same words to the button label twice.
Widget _statIconAction({
  required Key key,
  required String label,
  required IconData icon,
  required VoidCallback onPressed,
  double iconSize = 24,
  Color? color,
}) => Semantics(
  key: key,
  container: true,
  label: label,
  button: true,
  enabled: true,
  focusable: true,
  onTap: onPressed,
  excludeSemantics: true,
  child: Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      iconSize: iconSize,
      color: color,
      onPressed: onPressed,
      icon: Icon(icon),
    ),
  ),
);

Future<void> showStatExplanation(
  BuildContext context,
  ExplainedStat stat, {
  CareerSnapshot? career,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  sheetAnimationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => _StatExplanationSheet(stat: stat, career: career),
);

final class _StatExplanationSheet extends StatelessWidget {
  const _StatExplanationSheet({required this.stat, this.career});

  final ExplainedStat stat;
  final CareerSnapshot? career;

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    final modern = career?.usesModernCareerRules ?? false;
    final detailKey = switch (stat) {
      ExplainedStat.tacticalFit when modern => 'tacticalFitModernBody',
      ExplainedStat.legacyScore when modern => 'legacyScoreModernBody',
      _ => '${stat.name}Body',
    };
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        key: Key('stat-explanation-${stat.name}'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        explainedStatLabel(locale, stat),
                        key: const Key('stat-explanation-title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ),
                  _statIconAction(
                    key: const Key('stat-explanation-close'),
                    label: MaterialLocalizations.of(context).closeButtonTooltip,
                    onPressed: () => Navigator.pop(context),
                    icon: Icons.close_rounded,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                key: const Key('stat-explanation-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                child: Text(
                  _copy(locale, detailKey),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(height: 1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _copy(String locale, String key) =>
    _statCopy[key]![switch (locale) {
      'es' => 1,
      'pt' || 'pt-BR' => 2,
      'fr' => 3,
      _ => 0,
    }];

const _statCopy = <String, List<String>>{
  'explain': [
    'Explain {stat}',
    'Explicar {stat}',
    'Explicar {stat}',
    'Expliquer {stat}',
  ],
  'managerTrustTitle': [
    'Manager trust',
    'Confianza del entrenador',
    'Confiança do treinador',
    'Confiance de l’entraîneur',
  ],
  'managerTrustBody': [
    'The club manager’s confidence in you, shown out of 100.\n\nIt helps determine whether you start, make the bench or miss out. Club match performances and some off-pitch decisions can change it. Fitness, form and tactical fit also affect selection.',
    'La confianza del entrenador del club en ti, sobre 100.\n\nAyuda a decidir si eres titular, suplente o quedas fuera. Tu rendimiento en los partidos del club y algunas decisiones fuera del campo pueden cambiarla. El estado físico, la forma y el encaje táctico también influyen en la selección.',
    'A confiança do treinador do clube em você, de 0 a 100.\n\nAjuda a definir se você será titular, reserva ou ficará de fora. Seu desempenho nos jogos do clube e algumas decisões fora de campo podem alterá-la. Condição física, fase e ajuste tático também influenciam a escalação.',
    'La confiance que vous accorde l’entraîneur du club, sur 100.\n\nElle aide à déterminer si vous êtes titulaire, remplaçant ou non retenu. Vos performances en club et certains choix hors du terrain peuvent la modifier. La condition physique, la dynamique et l’adéquation tactique influencent aussi la sélection.',
  ],
  'formTitle': [
    'Current form',
    'Forma actual',
    'Fase atual',
    'Dynamique actuelle',
  ],
  'formBody': [
    'Your current momentum, shown out of 100.\n\nSuccessful spotlight moments raise it; unsuccessful moments and missed appearances can lower it. Higher form helps selection, spotlight chances and your team’s attacking performance. Training changes attributes and fitness rather than directly changing form.',
    'Tu dinámica actual, sobre 100.\n\nLos momentos decisivos exitosos la aumentan; los fallidos y quedarte sin jugar pueden reducirla. Una mejor forma ayuda a la selección, a tus opciones en los momentos decisivos y al ataque del equipo. El entrenamiento cambia atributos y estado físico, sin cambiar directamente la forma.',
    'Seu momento atual, de 0 a 100.\n\nAcertar momentos decisivos melhora a fase; errar ou ficar sem jogar pode reduzi-la. Uma boa fase ajuda na escalação, nas chances dos momentos decisivos e no ataque da equipe. O treino muda atributos e condição física, sem alterar diretamente a fase.',
    'Votre dynamique actuelle, sur 100.\n\nRéussir les moments décisifs l’améliore ; les rater ou ne pas jouer peut la réduire. Une bonne dynamique favorise la sélection, les chances de réussite et l’attaque de l’équipe. L’entraînement modifie les attributs et la condition physique, sans changer directement la dynamique.',
  ],
  'tacticalFitTitle': [
    'Tactical fit',
    'Encaje táctico',
    'Ajuste tático',
    'Adéquation tactique',
  ],
  'tacticalFitBody': [
    'How well you suit the tactical setup, shown out of 100.\n\nIt contributes to selection, spotlight chances and the team’s attacking performance. Review the matchup preview before choosing your approach. A high fit helps, but does not guarantee a start or a successful moment.',
    'Tu encaje en el planteamiento táctico, sobre 100.\n\nInfluye en la selección, las opciones de los momentos decisivos y el ataque del equipo. Revisa la previa antes de elegir tu enfoque. Un buen encaje ayuda, pero no garantiza ser titular ni tener éxito.',
    'Quanto você combina com o esquema tático, de 0 a 100.\n\nContribui para a escalação, as chances nos momentos decisivos e o ataque da equipe. Confira a prévia antes de escolher sua abordagem. Um bom ajuste ajuda, mas não garante a titularidade nem o sucesso.',
    'Votre compatibilité avec le dispositif tactique, sur 100.\n\nElle contribue à la sélection, aux chances de réussite et à l’attaque de l’équipe. Consultez l’avant-match avant de choisir votre approche. Une bonne adéquation aide, sans garantir une titularisation ni une réussite.',
  ],
  'tacticalFitModernBody': [
    'How well your skills suit the club’s playing style, shown out of 100. Your level compared with the club’s squad also matters.\n\nDeveloping the skills suited to that style can improve fit. Fit contributes to selection, spotlight chances and the team’s attacking performance; it does not guarantee selection or success.',
    'El encaje de tus habilidades con el estilo del club, sobre 100. También importa tu nivel respecto a la plantilla.\n\nDesarrollar las habilidades adecuadas para ese estilo puede mejorar el encaje. Influye en la selección, los momentos decisivos y el ataque del equipo, sin garantizar la titularidad ni el éxito.',
    'Quanto suas habilidades combinam com o estilo do clube, de 0 a 100. Seu nível em comparação ao elenco também conta.\n\nDesenvolver as habilidades adequadas ao estilo pode melhorar o ajuste. Ele contribui para a escalação, os momentos decisivos e o ataque da equipe, sem garantir titularidade ou sucesso.',
    'La compatibilité de vos compétences avec le style du club, sur 100. Votre niveau par rapport à l’effectif compte aussi.\n\nDévelopper les compétences adaptées à ce style peut améliorer l’adéquation. Elle contribue à la sélection, aux moments décisifs et à l’attaque de l’équipe, sans garantir une titularisation ni une réussite.',
  ],
  'legacyScoreTitle': [
    'Legacy score',
    'Puntuación de legado',
    'Pontuação de legado',
    'Score de légende',
  ],
  'legacyScoreBody': [
    'A career-wide measure of what you have achieved. Appearances, goals, assists, trophies, reputation, overall ability and completed-season ratings all contribute.\n\nThe active value is a projection. Retirement fixes the final score. The breakdown shows where your points come from.',
    'Una medida de lo que has logrado en toda tu carrera. Suman los partidos, goles, asistencias, trofeos, reputación, nivel general y valoraciones de temporadas completas.\n\nDurante la carrera, el valor es una proyección. Al retirarte se fija la puntuación final. El desglose muestra de dónde salen tus puntos.',
    'Uma medida das suas conquistas ao longo da carreira. Jogos, gols, assistências, troféus, reputação, nível geral e notas das temporadas concluídas contribuem.\n\nDurante a carreira, o valor é uma projeção. A aposentadoria fixa a pontuação final. O detalhamento mostra de onde vêm seus pontos.',
    'Une mesure de vos accomplissements sur toute la carrière. Les matchs, buts, passes décisives, trophées, réputation, niveau général et notes des saisons terminées contribuent au score.\n\nPendant la carrière, il s’agit d’une projection. La retraite fixe le score final. Le détail indique l’origine des points.',
  ],
  'legacyScoreModernBody': [
    'A career-wide measure of what you have achieved. Appearances, goals, assists, trophies, reputation, overall ability and completed-season ratings all contribute. It also rewards contributions for your position, such as chances created or defensive work.\n\nThe active value is a projection. Retirement fixes the final score. The breakdown shows where your points come from.',
    'Una medida de lo que has logrado en toda tu carrera. Suman los partidos, goles, asistencias, trofeos, reputación, nivel general y valoraciones de temporadas completas. También se premian las aportaciones de tu posición, como crear ocasiones o defender.\n\nDurante la carrera, el valor es una proyección. Al retirarte se fija la puntuación final. El desglose muestra de dónde salen tus puntos.',
    'Uma medida das suas conquistas ao longo da carreira. Jogos, gols, assistências, troféus, reputação, nível geral e notas das temporadas concluídas contribuem. Também conta o trabalho da sua posição, como criar chances ou defender.\n\nDurante a carreira, o valor é uma projeção. A aposentadoria fixa a pontuação final. O detalhamento mostra de onde vêm seus pontos.',
    'Une mesure de vos accomplissements sur toute la carrière. Les matchs, buts, passes décisives, trophées, réputation, niveau général et notes des saisons terminées contribuent au score. Les contributions propres à votre poste, comme les occasions créées ou le travail défensif, comptent aussi.\n\nPendant la carrière, il s’agit d’une projection. La retraite fixe le score final. Le détail indique l’origine des points.',
  ],
};
