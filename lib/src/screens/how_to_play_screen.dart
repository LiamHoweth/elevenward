import 'package:flutter/material.dart';

import '../l10n_context.dart';
import '../theme.dart';
import '../ui_copy.dart';

final class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = contentLocale(context);
    return Scaffold(
      appBar: AppBar(title: Text(uiCopy(locale, 'howToPlay'))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              key: const Key('how-to-play-scroll'),
              padding: const EdgeInsets.all(18),
              children: [
                BroadcastPanel(
                  accent: ElevenwardColors.sky,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          _copy(locale, 'weeklyRhythm'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      for (final step in ['prepare', 'play', 'review']) ...[
                        const SizedBox(height: 12),
                        Text(
                          _copy(locale, step),
                          key: Key('how-to-play-step-$step'),
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Semantics(
                  header: true,
                  child: Text(
                    _copy(locale, 'topics'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 10),
                for (final topic in _topics)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(
                          ElevenwardRadii.control,
                        ),
                        border: Border.all(color: ElevenwardColors.line),
                      ),
                      child: ExpansionTile(
                        key: PageStorageKey('how-to-play-topic-${topic.id}'),
                        maintainState: true,
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          14,
                          0,
                          14,
                          16,
                        ),
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(
                          _copy(locale, '${topic.id}Title'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        children: [
                          if (topic.tipKey != null) ...[
                            Text(
                              uiCopy(locale, topic.tipKey!),
                              style: const TextStyle(height: 1.4),
                            ),
                            const SizedBox(height: 12),
                          ],
                          Text(
                            _copy(locale, '${topic.id}Body'),
                            key: Key('how-to-play-body-${topic.id}'),
                            style: const TextStyle(height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _topics = <({String id, String? tipKey})>[
  (id: 'training', tipKey: 'focusTip'),
  (id: 'spotlight', tipKey: 'spotlightHelp'),
  (id: 'decisions', tipKey: null),
  (id: 'contracts', tipKey: null),
  (id: 'world', tipKey: 'worldHelp'),
  (id: 'numbers', tipKey: null),
];

String _copy(String locale, String key) =>
    _guideCopy[key]![switch (locale) {
      'es' => 1,
      'pt' || 'pt-BR' => 2,
      'fr' => 3,
      _ => 0,
    }];

// Keep advice descriptive: old careers retain their original gameplay rules.
const _guideCopy = <String, List<String>>{
  'weeklyRhythm': [
    'Your weekly rhythm',
    'Tu rutina semanal',
    'Sua rotina semanal',
    'Votre rythme hebdomadaire',
  ],
  'prepare': [
    '1. Prepare: choose a training focus and load. Check the attribute and fitness preview before continuing.',
    '1. Prepárate: elige el enfoque y la carga de entrenamiento. Revisa la previsión de atributos y estado físico antes de continuar.',
    '1. Prepare-se: escolha o foco e a carga de treino. Confira a prévia de atributos e condição física antes de continuar.',
    '1. Préparez-vous : choisissez l’objectif et la charge d’entraînement. Consultez les prévisions d’attributs et de condition physique avant de continuer.',
  ],
  'play': [
    '2. Play: compare the spotlight options, select an approach, then confirm your choice.',
    '2. Juega: compara las opciones de la jugada clave, elige un enfoque y confirma tu decisión.',
    '2. Jogue: compare as opções do lance de destaque, escolha uma abordagem e confirme sua decisão.',
    '2. Jouez : comparez les options du moment décisif, choisissez une approche, puis confirmez votre décision.',
  ],
  'review': [
    '3. Review: read your saved match recap. Resolve any off-pitch decision before the next matchweek.',
    '3. Revisa: lee el resumen del partido guardado. Resuelve las decisiones fuera del campo antes de la próxima jornada.',
    '3. Confira: leia o resumo da partida salva. Resolva as decisões fora de campo antes da próxima rodada.',
    '3. Faites le point : lisez le récapitulatif du match enregistré. Résolvez les décisions hors terrain avant la prochaine journée.',
  ],
  'topics': [
    'Explore a topic',
    'Explora un tema',
    'Explore um tema',
    'Explorer un sujet',
  ],
  'trainingTitle': [
    'Training and recovery',
    'Entrenamiento y recuperación',
    'Treino e recuperação',
    'Entraînement et récupération',
  ],
  'trainingBody': [
    'The preview shows training only; match fatigue is applied afterward. Fractional development carries forward, so +0 can still mean progress toward the next attribute point. Use the preview for your own career rather than expecting the same gain at every age. Club training pauses during the national-team tournament. A saved training preset changes your choices only when you apply it.',
    'La previsión muestra solo el entrenamiento; el cansancio del partido se aplica después. El desarrollo fraccionado se acumula, así que +0 puede indicar progreso hacia el próximo punto de atributo. Usa la previsión de tu carrera; la mejora no tiene por qué ser igual a todas las edades. El entrenamiento del club se pausa durante el torneo de selecciones. Un entrenamiento guardado cambia tus elecciones solo cuando lo aplicas.',
    'A prévia mostra apenas o treino; o desgaste da partida é aplicado depois. O desenvolvimento fracionado se acumula, então +0 ainda pode significar avanço rumo ao próximo ponto de atributo. Use a prévia da sua carreira; o ganho pode variar com a idade. O treino do clube pausa durante o torneio de seleções. Um treino favorito muda suas escolhas somente quando você o aplica.',
    'La prévision concerne uniquement l’entraînement ; la fatigue du match s’applique ensuite. La progression fractionnaire se cumule : +0 peut donc représenter une avancée vers le prochain point d’attribut. Consultez la prévision de votre carrière, car le gain peut varier selon l’âge. L’entraînement en club est suspendu pendant le tournoi des nations. Une séance favorite ne modifie vos choix que lorsque vous l’appliquez.',
  ],
  'spotlightTitle': [
    'Match choices and selection',
    'Decisiones y selección para el partido',
    'Decisões e escalação',
    'Choix et sélection pour le match',
  ],
  'spotlightBody': [
    'Check the matchup and the explanation of your chances. Fitness, form, manager trust, tactical fit and player level affect selection. A strong overall rating alone does not guarantee a starting place. Your spotlight choice shapes one moment; the match result also depends on both teams.',
    'Revisa la previa y la explicación de tus probabilidades. El estado físico, la forma, la confianza del entrenador, el encaje táctico y tu nivel influyen en la selección. Una valoración general alta no garantiza la titularidad. Tu decisión afecta una jugada; el resultado también depende de ambos equipos.',
    'Confira a prévia e a explicação das suas chances. Condição física, fase, confiança do treinador, ajuste tático e nível do jogador influenciam a escalação. Um nível geral alto não garante a titularidade. Sua escolha afeta um lance; o resultado também depende das duas equipes.',
    'Consultez l’avant-match et l’explication de vos chances. La condition physique, la dynamique, la confiance de l’entraîneur, l’adéquation tactique et votre niveau influencent la sélection. Un niveau général élevé ne garantit pas une titularisation. Votre choix agit sur un moment ; le résultat dépend aussi des deux équipes.',
  ],
  'decisionsTitle': [
    'Recaps and off-pitch decisions',
    'Resúmenes y decisiones fuera del campo',
    'Resumos e decisões fora de campo',
    'Récapitulatifs et décisions hors terrain',
  ],
  'decisionsBody': [
    'After confirming a match choice, the recap appears once the result is saved. Review your contribution and the actual changes to your player. If an off-pitch decision follows, read its consequences and choose before advancing. The career journal records recent matches and decisions, so you can revisit what happened. If saving fails, keep your choice and use Retry.',
    'Tras confirmar tu decisión, el resumen aparece cuando el resultado está guardado. Revisa tu contribución y los cambios reales de tu jugador. Si hay una decisión fuera del campo, lee sus consecuencias y elige antes de avanzar. El diario registra partidos y decisiones recientes para que puedas revisarlos. Si falla el guardado, conserva tu elección y usa Reintentar.',
    'Após confirmar sua escolha, o resumo aparece quando o resultado é salvo. Confira sua contribuição e as mudanças reais do jogador. Se houver uma decisão fora de campo, leia as consequências e escolha antes de avançar. O diário registra jogos e decisões recentes para você consultar. Se o salvamento falhar, mantenha sua escolha e use Tentar novamente.',
    'Après confirmation de votre choix, le récapitulatif apparaît une fois le résultat enregistré. Consultez votre contribution et les changements réels de votre joueur. Si une décision hors terrain suit, lisez ses conséquences et choisissez avant d’avancer. Le journal conserve les matchs et décisions récents. Si l’enregistrement échoue, conservez votre choix et utilisez Réessayer.',
  ],
  'contractsTitle': [
    'Contracts and career moves',
    'Contratos y cambios de club',
    'Contratos e mudanças de clube',
    'Contrats et changements de club',
  ],
  'contractsBody': [
    'In the offseason, compare an offer with your current contract: weekly wage, appearance bonus, promised role, league and tactical fit. A promised role helps you weigh a move; it does not guarantee selection every week. Where offered, a loan lasts one season and returns you to your parent club the next offseason. Read the confirmation before accepting a move or retiring.',
    'Al terminar la temporada, compara cada oferta con tu contrato actual: sueldo semanal, prima por partido, rol prometido, liga y encaje táctico. El rol prometido ayuda a valorar un cambio, pero no garantiza jugar cada semana. Si se ofrece una cesión, dura una temporada y vuelves a tu club de origen al finalizarla. Lee la confirmación antes de aceptar un cambio o retirarte.',
    'No fim da temporada, compare a oferta com seu contrato atual: salário semanal, bônus por jogo, função prometida, liga e ajuste tático. A função prometida ajuda a avaliar uma mudança, mas não garante jogar toda semana. Quando disponível, o empréstimo dura uma temporada e você volta ao clube de origem no próximo fim de temporada. Leia a confirmação antes de aceitar uma mudança ou se aposentar.',
    'À l’intersaison, comparez l’offre à votre contrat actuel : salaire hebdomadaire, prime de match, rôle promis, championnat et adéquation tactique. Le rôle promis aide à évaluer un départ, sans garantir une sélection chaque semaine. Lorsqu’il est proposé, un prêt dure une saison et vous ramène au club d’origine à l’intersaison suivante. Lisez la confirmation avant d’accepter un départ ou de prendre votre retraite.',
  ],
  'worldTitle': [
    'Finding your way around',
    'Orientarte en el juego',
    'Encontre o que precisa',
    'Se repérer dans le jeu',
  ],
  'worldBody': [
    'Player shows your attributes and career record. Legacy shows your career score and its breakdown. Use the journal to review recent results rather than relying on a single match. Favorites in the world browser help you return to clubs and leagues you follow.',
    'Jugador muestra tus atributos y trayectoria. Legado muestra tu puntuación de carrera y su desglose. Usa el diario para revisar resultados recientes sin basarte solo en un partido. Los favoritos del explorador del mundo te ayudan a volver a los clubes y ligas que sigues.',
    'Jogador mostra seus atributos e histórico. Legado mostra a pontuação da carreira e seu detalhamento. Use o diário para conferir resultados recentes sem depender de uma única partida. Os favoritos no mundo ajudam você a voltar aos clubes e ligas que acompanha.',
    'Joueur présente vos attributs et votre parcours. Légende affiche votre score de carrière et son détail. Consultez le journal pour revoir les résultats récents sans vous limiter à un seul match. Les favoris du monde vous aident à retrouver les clubs et championnats que vous suivez.',
  ],
  'numbersTitle': [
    'Understanding your numbers',
    'Entender tus estadísticas',
    'Entenda seus números',
    'Comprendre vos statistiques',
  ],
  'numbersBody': [
    'Overall summarizes the attributes relevant to your position. Fitness is your physical readiness; form is your current momentum. Manager trust reflects the club manager’s confidence, while tactical fit describes how well you suit the setup. These measures work together. Tap the information icons beside trust, form, fit or legacy score in the game for detailed explanations that follow your career’s rules.',
    'La valoración general resume los atributos relevantes para tu posición. El estado físico indica tu preparación física; la forma, tu dinámica actual. La confianza refleja el apoyo del entrenador del club; el encaje táctico, cómo te adaptas al planteamiento. Estos factores actúan juntos. Toca los iconos de información junto a confianza, forma, encaje o legado para leer explicaciones según las reglas de tu carrera.',
    'O nível geral resume os atributos importantes para sua posição. Condição física é seu preparo físico; fase é seu momento atual. Confiança representa o apoio do treinador do clube, e ajuste tático indica como você combina com o esquema. Esses fatores atuam juntos. Toque nos ícones de informação junto à confiança, fase, ajuste ou legado para ler explicações que seguem as regras da sua carreira.',
    'Le niveau général résume les attributs utiles à votre poste. La condition physique représente votre préparation ; la dynamique, votre forme du moment. La confiance reflète le soutien de l’entraîneur du club et l’adéquation tactique, votre compatibilité avec le dispositif. Ces facteurs agissent ensemble. Touchez les icônes d’information près de la confiance, de la dynamique, de l’adéquation ou du score de légende pour consulter les explications adaptées aux règles de votre carrière.',
  ],
};
