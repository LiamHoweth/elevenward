import '../model/enums.dart';
import 'content_models.dart';

ContentCatalog buildLaunchContent() => ContentCatalog(
      version: '2026.2.0',
      matchSituations: _buildMatchSituations(),
      careerEvents: _buildCareerEvents(),
      lifestyleItems: _buildLifestyleItems(),
    );

List<String> validateContentCatalog(ContentCatalog catalog) {
  final errors = <String>[];
  final ids = <String>{};
  final playerFacingEnglish = <String>{};
  void checkId(String id, String kind) {
    if (!ids.add(id)) errors.add('Duplicate $kind id: $id');
  }

  void checkText(LocalizedText text, String path, {bool unique = false}) {
    for (final locale in supportedLocales) {
      final value = text.values[locale];
      if (value == null || value.trim().isEmpty) {
        errors.add('$path is missing locale $locale');
      }
    }
    final english = text.values['en']?.trim() ?? '';
    if (RegExp(r'\[[a-z]+\]', caseSensitive: false).hasMatch(english)) {
      errors.add('$path contains an authoring marker');
    }
    if (unique && !playerFacingEnglish.add(english)) {
      errors.add('$path duplicates another English string');
    }
  }

  for (final situation in catalog.matchSituations) {
    checkId(situation.id, 'situation');
    checkText(situation.prompt, '${situation.id}.prompt', unique: true);
    if (situation.minuteFrom < 1 ||
        situation.minuteTo > 90 ||
        situation.minuteFrom > situation.minuteTo) {
      errors.add('${situation.id} has an invalid minute range');
    }
    if (situation.options.length != 3)
      errors.add('${situation.id} must have three choices');
    for (final option in situation.options) {
      checkText(option.title, '${situation.id}.${option.approach.name}');
      if (option.primaryAttributes.length != 2) {
        errors.add(
            '${situation.id}.${option.approach.name} needs two attributes');
      }
    }
  }
  for (final event in catalog.careerEvents) {
    checkId(event.id, 'event');
    checkText(event.title, '${event.id}.title', unique: true);
    checkText(event.body, '${event.id}.body');
    if (event.choices.length < 2)
      errors.add('${event.id} needs at least two choices');
    for (final choice in event.choices) {
      checkText(choice.label, '${event.id}.${choice.id}');
    }
  }
  for (final item in catalog.lifestyleItems) {
    checkId(item.id, 'item');
    checkText(item.name, '${item.id}.name', unique: true);
    checkText(item.description, '${item.id}.description');
    if (item.price < 0) errors.add('${item.id} has a negative price');
  }
  return errors;
}

List<MatchSituationDefinition> _buildMatchSituations() {
  final situations = <MatchSituationDefinition>[];
  for (final position in PositionFamily.values) {
    for (var index = 0; index < 40; index++) {
      final zone = index % 4;
      final phase = (index ~/ 4) % 5;
      final matchState = index ~/ 20;
      situations.add(MatchSituationDefinition(
        id: 'match-${position.name}-${(index + 1).toString().padLeft(2, '0')}',
        position: position,
        archetypeTags: Archetype.values
            .where((value) => value.positionFamily == position)
            .toList(),
        minuteFrom: 8 + phase * 15,
        minuteTo: 20 + phase * 15,
        prompt: _situationPrompt(position, zone, phase, matchState),
        options: _situationOptions(position),
      ));
    }
  }
  return List.unmodifiable(situations);
}

LocalizedText _situationPrompt(
  PositionFamily position,
  int zone,
  int phase,
  int matchState,
) {
  final positionText = switch (position) {
    PositionFamily.striker => [
        'The back line parts and the final pass arrives',
        'La defensa se abre y llega el último pase',
        'A defesa se abre e o último passe chega',
        'La défense s’ouvre et la dernière passe arrive'
      ],
    PositionFamily.winger => [
        'The fullback is isolated and space opens outside',
        'El lateral queda aislado y aparece espacio por fuera',
        'O lateral fica isolado e surge espaço por fora',
        'Le latéral est isolé et l’espace s’ouvre à l’extérieur'
      ],
    PositionFamily.midfielder => [
        'The press breaks and the center of the pitch opens',
        'La presión cede y se abre el centro del campo',
        'A pressão quebra e o meio-campo se abre',
        'Le pressing cède et le centre du terrain s’ouvre'
      ],
    PositionFamily.defender => [
        'The runner turns toward goal with support arriving',
        'El atacante gira hacia la portería con apoyo',
        'O atacante gira para o gol com apoio',
        'L’attaquant se tourne vers le but avec du soutien'
      ],
  };
  const zones = [
    [
      'near the left channel.',
      'cerca del canal izquierdo.',
      'perto do corredor esquerdo.',
      'près du couloir gauche.'
    ],
    [
      'through the central lane.',
      'por el carril central.',
      'pelo corredor central.',
      'dans l’axe.'
    ],
    [
      'near the right touchline.',
      'cerca de la banda derecha.',
      'perto da lateral direita.',
      'près de la ligne droite.'
    ],
    [
      'as the shape is still recovering.',
      'mientras el bloque aún se recompone.',
      'enquanto o bloco ainda se recompõe.',
      'pendant que le bloc se replace.'
    ],
  ];
  const phases = [
    [
      'The match is still settling.',
      'El partido aún se está asentando.',
      'O jogo ainda está se ajustando.',
      'Le match se met encore en place.'
    ],
    [
      'The tempo is climbing.',
      'El ritmo está subiendo.',
      'O ritmo está aumentando.',
      'Le rythme s’accélère.'
    ],
    [
      'Neither side has control.',
      'Ningún equipo tiene el control.',
      'Nenhum dos lados tem o controle.',
      'Aucune équipe ne contrôle le match.'
    ],
    [
      'Fatigue is creating gaps.',
      'El cansancio está abriendo espacios.',
      'O cansaço está criando espaços.',
      'La fatigue crée des espaces.'
    ],
    [
      'The next action could decide it.',
      'La próxima acción puede decidirlo.',
      'A próxima jogada pode decidir tudo.',
      'La prochaine action peut être décisive.'
    ],
  ];
  const matchStates = [
    [
      'The score is level.',
      'El marcador está empatado.',
      'O placar está empatado.',
      'Le score est à égalité.'
    ],
    [
      'Your side needs the next goal.',
      'Tu equipo necesita el próximo gol.',
      'Seu time precisa do próximo gol.',
      'Votre équipe doit marquer le prochain but.'
    ],
  ];
  return LocalizedText({
    for (var locale = 0; locale < supportedLocales.length; locale++)
      supportedLocales[locale]:
          '${positionText[locale]} ${zones[zone][locale]} ${phases[phase][locale]} ${matchStates[matchState][locale]}',
  });
}

List<SituationOption> _situationOptions(PositionFamily position) {
  final attributes = switch (position) {
    PositionFamily.striker => [
        [PlayerAttribute.technique, PlayerAttribute.composure],
        [PlayerAttribute.finishing, PlayerAttribute.technique],
        [PlayerAttribute.finishing, PlayerAttribute.composure],
      ],
    PositionFamily.winger => [
        [PlayerAttribute.passing, PlayerAttribute.composure],
        [PlayerAttribute.pace, PlayerAttribute.technique],
        [PlayerAttribute.technique, PlayerAttribute.finishing],
      ],
    PositionFamily.midfielder => [
        [PlayerAttribute.passing, PlayerAttribute.composure],
        [PlayerAttribute.technique, PlayerAttribute.passing],
        [PlayerAttribute.stamina, PlayerAttribute.technique],
      ],
    PositionFamily.defender => [
        [PlayerAttribute.defending, PlayerAttribute.composure],
        [PlayerAttribute.defending, PlayerAttribute.strength],
        [PlayerAttribute.pace, PlayerAttribute.defending],
      ],
  };
  final labels = switch (position) {
    PositionFamily.striker => [
        _text('Lay it off', 'Descargar el balón', 'Tocar de lado',
            'Remettre le ballon'),
        _text('Create a shooting lane', 'Crear un ángulo de tiro',
            'Criar espaço para finalizar', 'Créer un angle de tir'),
        _text('Strike first time', 'Rematar de primera',
            'Finalizar de primeira', 'Frapper en première intention'),
      ],
    PositionFamily.winger => [
        _text('Recycle possession', 'Reiniciar la jugada', 'Reciclar a posse',
            'Recycler la possession'),
        _text('Attack the outside', 'Atacar por fuera', 'Atacar por fora',
            'Déborder à l’extérieur'),
        _text('Cut inside at speed', 'Recortar hacia dentro',
            'Cortar para dentro', 'Repiquer à pleine vitesse'),
      ],
    PositionFamily.midfielder => [
        _text('Keep the rhythm', 'Mantener el ritmo', 'Manter o ritmo',
            'Garder le rythme'),
        _text('Split the lines', 'Romper las líneas', 'Quebrar as linhas',
            'Casser les lignes'),
        _text('Carry through pressure', 'Conducir bajo presión',
            'Conduzir sob pressão', 'Porter sous pression'),
      ],
    PositionFamily.defender => [
        _text('Delay the runner', 'Frenar al atacante', 'Atrasar o atacante',
            'Retarder l’attaquant'),
        _text('Step in and challenge', 'Entrar al duelo', 'Entrar no duelo',
            'Intervenir dans le duel'),
        _text('Commit to the recovery', 'Apostar por la recuperación',
            'Apostar na recuperação', 'S’engager dans le repli'),
      ],
  };
  return List.generate(
      3,
      (index) => SituationOption(
            approach: SpotlightApproach.values[index],
            title: labels[index],
            primaryAttributes: attributes[index],
            trustRisk: [-1, -2, -4][index],
            ratingUpside: [0.4, 0.8, 1.3][index],
          ));
}

List<CareerEventDefinition> _buildCareerEvents() {
  final events = <CareerEventDefinition>[];
  for (final category in CareerEventCategory.values) {
    for (var index = 0; index < 20; index++) {
      final number = index + 1;
      events.add(CareerEventDefinition(
        id: 'career-${category.name}-${number.toString().padLeft(2, '0')}',
        category: category,
        title: _eventTitle(category, index),
        body: _eventBody(category, index),
        choices: [
          EventChoiceDefinition(
            id: 'measured',
            label: _text('Take the measured path', 'Elegir el camino prudente',
                'Escolher o caminho equilibrado', 'Choisir la voie mesurée'),
            trustDelta: category == CareerEventCategory.manager ? 2 : 0,
            reputationDelta: 1,
            moneyDelta: 0,
            wellnessDelta: 1,
          ),
          EventChoiceDefinition(
            id: 'ambitious',
            label: _text('Back your ambition', 'Apostar por tu ambición',
                'Apostar na sua ambição', 'Assumer son ambition'),
            trustDelta: category == CareerEventCategory.manager ? -1 : 0,
            reputationDelta: 2,
            moneyDelta: category == CareerEventCategory.sponsor ? 750 : 0,
            wellnessDelta: -1,
          ),
        ],
      ));
    }
  }
  return List.unmodifiable(events);
}

LocalizedText _eventTitle(CareerEventCategory category, int index) {
  final names = switch (category) {
    CareerEventCategory.manager => [
        'A word from the manager',
        'Una charla con el entrenador',
        'Uma conversa com o treinador',
        'Un mot de l’entraîneur'
      ],
    CareerEventCategory.teammate => [
        'A teammate needs you',
        'Un compañero te necesita',
        'Um companheiro precisa de você',
        'Un coéquipier a besoin de vous'
      ],
    CareerEventCategory.agent => [
        'Your agent calls',
        'Tu agente llama',
        'Seu agente liga',
        'Votre agent appelle'
      ],
    CareerEventCategory.sponsor => [
        'A brand makes an offer',
        'Una marca hace una oferta',
        'Uma marca faz uma proposta',
        'Une marque fait une offre'
      ],
    CareerEventCategory.press => [
        'The cameras are waiting',
        'Las cámaras esperan',
        'As câmeras estão esperando',
        'Les caméras attendent'
      ],
    CareerEventCategory.family => [
        'News from home',
        'Noticias de casa',
        'Notícias de casa',
        'Des nouvelles de la maison'
      ],
    CareerEventCategory.reputation => [
        'Your name is traveling',
        'Tu nombre empieza a sonar',
        'Seu nome está circulando',
        'Votre nom circule'
      ],
    CareerEventCategory.wellness => [
        'Listen to your body',
        'Escucha a tu cuerpo',
        'Escute o seu corpo',
        'Écoutez votre corps'
      ],
    CareerEventCategory.community => [
        'The neighborhood asks',
        'El barrio te llama',
        'A comunidade chama',
        'Le quartier vous sollicite'
      ],
    CareerEventCategory.contract => [
        'The club opens talks',
        'El club abre conversaciones',
        'O clube abre conversas',
        'Le club ouvre les discussions'
      ],
  };
  const moments = [
    [
      'after training',
      'después del entrenamiento',
      'depois do treino',
      'après l’entraînement'
    ],
    [
      'before selection',
      'antes de la convocatoria',
      'antes da convocação',
      'avant la sélection'
    ],
    [
      'on the journey home',
      'de camino a casa',
      'no caminho para casa',
      'sur le chemin du retour'
    ],
    [
      'at the training ground',
      'en el campo de entrenamiento',
      'no centro de treinamento',
      'au centre d’entraînement'
    ],
    [
      'during recovery',
      'durante la recuperación',
      'durante a recuperação',
      'pendant la récupération'
    ],
    [
      'before kickoff',
      'antes del inicio',
      'antes do jogo',
      'avant le coup d’envoi'
    ],
    [
      'after the final whistle',
      'tras el pitido final',
      'após o apito final',
      'après le coup de sifflet'
    ],
    [
      'on a quiet morning',
      'en una mañana tranquila',
      'em uma manhã tranquila',
      'par un matin calme'
    ],
    [
      'during a team meal',
      'durante una comida de equipo',
      'durante uma refeição do time',
      'pendant un repas d’équipe'
    ],
    ['between fixtures', 'entre partidos', 'entre jogos', 'entre deux matchs'],
    [
      'on your day off',
      'en tu día libre',
      'no seu dia de folga',
      'pendant votre jour de repos'
    ],
    [
      'after a difficult result',
      'tras un resultado difícil',
      'após um resultado difícil',
      'après un résultat difficile'
    ],
    [
      'after a strong performance',
      'tras una gran actuación',
      'após uma grande atuação',
      'après une grande performance'
    ],
    [
      'before the team meeting',
      'antes de la reunión',
      'antes da reunião',
      'avant la réunion d’équipe'
    ],
    [
      'late in the week',
      'al final de la semana',
      'no fim da semana',
      'en fin de semaine'
    ],
    [
      'as attention grows',
      'mientras crece la atención',
      'com a atenção crescendo',
      'alors que l’attention grandit'
    ],
    [
      'during a contract week',
      'durante una semana de contrato',
      'durante uma semana de contrato',
      'pendant une semaine de contrat'
    ],
    [
      'ahead of a derby',
      'antes de un derbi',
      'antes de um clássico',
      'avant un derby'
    ],
    [
      'after a milestone',
      'tras un hito',
      'após um marco',
      'après une étape importante'
    ],
    [
      'before the next chapter',
      'antes del próximo capítulo',
      'antes do próximo capítulo',
      'avant le prochain chapitre'
    ],
  ];
  return LocalizedText({
    for (var locale = 0; locale < supportedLocales.length; locale++)
      supportedLocales[locale]: '${names[locale]} ${moments[index][locale]}',
  });
}

LocalizedText _eventBody(CareerEventCategory category, int index) {
  const openings = [
    [
      'A quiet decision could shape the weeks ahead.',
      'Una decisión discreta puede marcar las próximas semanas.',
      'Uma decisão discreta pode definir as próximas semanas.',
      'Une décision discrète peut façonner les semaines à venir.'
    ],
    [
      'There is an opportunity, but your time has a cost.',
      'Hay una oportunidad, pero tu tiempo tiene un coste.',
      'Há uma oportunidade, mas seu tempo tem um custo.',
      'Une occasion se présente, mais votre temps a un prix.'
    ],
    [
      'People around the club are watching how you respond.',
      'En el club observan cómo respondes.',
      'As pessoas no clube observam como você reage.',
      'Le club observe votre réaction.'
    ],
    [
      'The easy answer is not necessarily the right one.',
      'La respuesta fácil no siempre es la correcta.',
      'A resposta fácil nem sempre é a certa.',
      'La réponse facile n’est pas toujours la bonne.'
    ],
  ];
  final stakes = switch (category) {
    CareerEventCategory.manager => [
        'Your role and the manager’s trust are connected.',
        'Tu rol y la confianza del entrenador están conectados.',
        'Seu papel e a confiança do treinador estão ligados.',
        'Votre rôle et la confiance du coach sont liés.'
      ],
    CareerEventCategory.teammate => [
        'The dressing room will remember whether you made time.',
        'El vestuario recordará si dedicaste tiempo.',
        'O vestiário lembrará se você reservou tempo.',
        'Le vestiaire se souviendra du temps accordé.'
      ],
    CareerEventCategory.agent => [
        'The advice could widen your market or protect your focus.',
        'El consejo puede ampliar tu mercado o proteger tu concentración.',
        'O conselho pode ampliar seu mercado ou proteger seu foco.',
        'Ce conseil peut élargir votre marché ou protéger votre concentration.'
      ],
    CareerEventCategory.sponsor => [
        'The money comes with an obligation to show up.',
        'El dinero implica la obligación de estar presente.',
        'O dinheiro traz a obrigação de estar presente.',
        'L’argent implique une obligation de présence.'
      ],
    CareerEventCategory.press => [
        'Your answer will shape the next headline.',
        'Tu respuesta dará forma al próximo titular.',
        'Sua resposta definirá a próxima manchete.',
        'Votre réponse façonnera le prochain titre.'
      ],
    CareerEventCategory.family => [
        'People at home need clarity, not another promise.',
        'En casa necesitan claridad, no otra promesa.',
        'Em casa, precisam de clareza, não de outra promessa.',
        'Vos proches ont besoin de clarté, pas d’une nouvelle promesse.'
      ],
    CareerEventCategory.reputation => [
        'Visibility can open doors while raising expectations.',
        'La visibilidad abre puertas y aumenta las expectativas.',
        'A visibilidade abre portas e aumenta as expectativas.',
        'La visibilité ouvre des portes et augmente les attentes.'
      ],
    CareerEventCategory.wellness => [
        'Ignoring the warning may cost more later.',
        'Ignorar la señal puede costar más adelante.',
        'Ignorar o aviso pode custar mais depois.',
        'Ignorer le signal peut coûter plus cher ensuite.'
      ],
    CareerEventCategory.community => [
        'A small commitment could matter well beyond the club.',
        'Un pequeño compromiso puede importar mucho fuera del club.',
        'Um pequeno compromisso pode importar além do clube.',
        'Un petit engagement peut compter bien au-delà du club.'
      ],
    CareerEventCategory.contract => [
        'The terms affect money, minutes, and your next move.',
        'Las condiciones afectan dinero, minutos y tu próximo paso.',
        'Os termos afetam dinheiro, minutos e seu próximo passo.',
        'Les conditions touchent l’argent, le temps de jeu et la suite.'
      ],
  };
  return LocalizedText({
    for (var locale = 0; locale < supportedLocales.length; locale++)
      supportedLocales[locale]:
          '${openings[index % openings.length][locale]} ${stakes[locale]}',
  });
}

List<LifestyleItemDefinition> _buildLifestyleItems() {
  final items = <LifestyleItemDefinition>[];
  for (final category in LifestyleCategory.values) {
    for (var index = 0; index < 30; index++) {
      final rarity = ItemRarity.values[(index ~/ 6).clamp(0, 4)];
      final tier = index + 1;
      items.add(LifestyleItemDefinition(
        id: 'life-${category.name}-${tier.toString().padLeft(2, '0')}',
        category: category,
        rarity: rarity,
        name: _itemName(category, index),
        description: _itemDescription(category, index),
        price: (250 + tier * tier * 175) * (rarity.index + 1),
        reputationEffect:
            category == LifestyleCategory.style ? rarity.index : 0,
        wellnessEffect:
            category == LifestyleCategory.wellness ? rarity.index + 1 : 0,
      ));
    }
  }
  return List.unmodifiable(items);
}

LocalizedText _itemName(LifestyleCategory category, int index) {
  final labels = switch (category) {
    LifestyleCategory.home => [
        'Haven Residence',
        'Residencia Refugio',
        'Residência Refúgio',
        'Résidence Havre'
      ],
    LifestyleCategory.transportation => [
        'Wayfinder',
        'Viajero',
        'Desbravador',
        'Éclaireur'
      ],
    LifestyleCategory.style => [
        'Touchline Collection',
        'Colección de Banda',
        'Coleção da Lateral',
        'Collection Ligne de Touche'
      ],
    LifestyleCategory.wellness => [
        'Recovery Studio',
        'Estudio de Recuperación',
        'Estúdio de Recuperação',
        'Studio de Récupération'
      ],
  };
  const qualities = [
    ['Quiet', 'Tranquilo', 'Tranquilo', 'Paisible'],
    ['Open', 'Abierto', 'Aberto', 'Ouvert'],
    ['City', 'Urbano', 'Urbano', 'Urbain'],
    ['Garden', 'Jardín', 'Jardim', 'Jardin'],
    ['Summit', 'Cumbre', 'Cume', 'Sommet'],
    ['Legacy', 'Legado', 'Legado', 'Héritage'],
  ];
  const editions = [
    ['Base', 'Base', 'Base', 'Essentiel'],
    ['Select', 'Selecto', 'Seleto', 'Sélection'],
    ['Signature', 'Distinción', 'Assinatura', 'Signature'],
    ['Premier', 'Premier', 'Premier', 'Premier'],
    ['Grand', 'Gran', 'Grand', 'Grand'],
  ];
  return LocalizedText({
    for (var locale = 0; locale < supportedLocales.length; locale++)
      supportedLocales[locale]:
          '${qualities[index % 6][locale]} ${labels[locale]} ${editions[index ~/ 6][locale]}',
  });
}

LocalizedText _itemDescription(LifestyleCategory category, int index) {
  final values = switch (category) {
    LifestyleCategory.home => [
        'A private place to reset between fixtures.',
        'Un lugar privado para descansar entre partidos.',
        'Um lugar privado para descansar entre jogos.',
        'Un lieu privé pour récupérer entre les matchs.'
      ],
    LifestyleCategory.transportation => [
        'Reliable movement with a little personality.',
        'Movilidad fiable con algo de personalidad.',
        'Mobilidade confiável com personalidade.',
        'Des déplacements fiables avec du caractère.'
      ],
    LifestyleCategory.style => [
        'A considered look for matchday and beyond.',
        'Un estilo cuidado para el partido y más allá.',
        'Um visual pensado para o jogo e além.',
        'Un style soigné pour les jours de match.'
      ],
    LifestyleCategory.wellness => [
        'A routine built around sustainable performance.',
        'Una rutina pensada para rendir a largo plazo.',
        'Uma rotina para desempenho sustentável.',
        'Une routine pensée pour durer.'
      ],
  };
  const details = [
    [
      'Built for a steady first step.',
      'Pensado para un primer paso estable.',
      'Feito para um primeiro passo seguro.',
      'Pensé pour un premier pas solide.'
    ],
    [
      'A practical upgrade for a growing career.',
      'Una mejora práctica para una carrera en ascenso.',
      'Uma melhoria prática para uma carreira em ascensão.',
      'Une amélioration pratique pour une carrière en plein essor.'
    ],
    [
      'Balances comfort with a visible sense of progress.',
      'Equilibra comodidad y una clara sensación de avance.',
      'Equilibra conforto e uma clara sensação de progresso.',
      'Équilibre confort et progression visible.'
    ],
    [
      'A refined choice for established professionals.',
      'Una opción refinada para profesionales consolidados.',
      'Uma escolha refinada para profissionais estabelecidos.',
      'Un choix raffiné pour les professionnels confirmés.'
    ],
    [
      'A rare statement earned late in a career.',
      'Una pieza excepcional ganada al final de la carrera.',
      'Uma peça rara conquistada no fim da carreira.',
      'Une pièce rare gagnée en fin de carrière.'
    ],
  ];
  return LocalizedText({
    for (var locale = 0; locale < supportedLocales.length; locale++)
      supportedLocales[locale]:
          '${values[locale]} ${details[index ~/ 6][locale]}',
  });
}

LocalizedText _text(String en, String es, String ptBr, String fr) =>
    LocalizedText({'en': en, 'es': es, 'pt-BR': ptBr, 'fr': fr});
