/// Local career and save features use the same four content locales as the app.
String featureCopy(String locale, String key) {
  final values = _copy[key];
  if (values == null) {
    throw ArgumentError.value(key, 'key', 'Unknown feature copy');
  }
  final index = switch (locale) {
    'es' => 1,
    'pt-BR' || 'pt' => 2,
    'fr' => 3,
    _ => 0,
  };
  return values[index];
}

String formatFeatureCopy(
  String locale,
  String key,
  Map<String, Object> values,
) {
  var result = featureCopy(locale, key);
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', '${entry.value}');
  }
  return result;
}

const _copy = <String, List<String>>{
  'resolveConflictFirst': [
    'Resolve this slot’s cloud conflict before deleting or replacing its career.',
    'Resuelve el conflicto de este espacio con la nube antes de eliminar o reemplazar su carrera.',
    'Resolva o conflito deste espaço com a nuvem antes de excluir ou substituir sua carreira.',
    'Résolvez le conflit cloud de cet emplacement avant de supprimer ou remplacer sa carrière.',
  ],
  'careerChangedBeforeDeletion': [
    'This career changed while deletion was being confirmed. Review the current slot before deleting it.',
    'Esta carrera cambió mientras se confirmaba su eliminación. Revisa el espacio actual antes de eliminarla.',
    'Esta carreira mudou durante a confirmação da exclusão. Revise o espaço atual antes de excluí-la.',
    'Cette carrière a changé pendant la confirmation de sa suppression. Vérifiez l’emplacement actuel avant de la supprimer.',
  ],
  'slotOccupied': [
    'This slot is no longer empty. Refresh your careers before creating a new one.',
    'Este espacio ya no está vacío. Actualiza tus carreras antes de crear una nueva.',
    'Este espaço não está mais vazio. Atualize suas carreiras antes de criar uma nova.',
    'Cet emplacement n’est plus vide. Actualisez vos carrières avant d’en créer une nouvelle.',
  ],

  'useCloudDeletion': [
    'Keep cloud deletion',
    'Conservar eliminación en la nube',
    'Manter exclusão na nuvem',
    'Conserver la suppression cloud',
  ],
  'availableFunds': [
    'Available money',
    'Dinero disponible',
    'Dinheiro disponível',
    'Argent disponible',
  ],
  'accountRestore': [
    'Account / Restore',
    'Cuenta / Restaurar',
    'Conta / Restaurar',
    'Compte / Restaurer',
  ],
  'hallOfFame': [
    'Hall of Fame',
    'Salón de la Fama',
    'Salão da Fama',
    'Panthéon',
  ],
  'hallBody': [
    'Retired careers saved on this device, separate from playable slots.',
    'Carreras retiradas guardadas en este dispositivo, aparte de las ranuras de juego.',
    'Carreiras encerradas salvas neste aparelho, separadas dos espaços de jogo.',
    'Carrières terminées enregistrées sur cet appareil, indépendantes des emplacements jouables.',
  ],
  'hallEmpty': [
    'Retire a career to keep its record here.',
    'Retira una carrera para conservar su historial aquí.',
    'Encerre uma carreira para guardar seu histórico aqui.',
    'Terminez une carrière pour conserver son bilan ici.',
  ],
  'archiveCareer': [
    'Save to Hall of Fame',
    'Guardar en el Salón de la Fama',
    'Salvar no Salão da Fama',
    'Enregistrer au Panthéon',
  ],
  'deleteArchive': [
    'Remove archived career?',
    '¿Eliminar la carrera archivada?',
    'Remover carreira arquivada?',
    'Supprimer cette carrière archivée ?',
  ],
  'deleteArchiveBody': [
    'This removes the Hall of Fame record. Its cloud copy is removed when signed into the account that owns it. Playable careers are kept.',
    'Elimina el registro del Salón de la Fama. Su copia en la nube se elimina si has iniciado sesión en la cuenta a la que pertenece. Se conservan las carreras jugables.',
    'Remove o registro do Salão da Fama. A cópia na nuvem é removida quando você está conectado à conta proprietária. As carreiras jogáveis são mantidas.',
    'Le bilan du Panthéon sera supprimé. Sa copie cloud est supprimée lorsque vous êtes connecté au compte qui la possède. Les carrières jouables sont conservées.',
  ],
  'archiveBackupPending': [
    'Local archives remain available. Cloud sync needs retry.',
    'Los archivos locales siguen disponibles. Reintenta la sincronización en la nube.',
    'Os arquivos locais continuam disponíveis. Tente sincronizar com a nuvem novamente.',
    'Les archives locales restent disponibles. Relancez la synchronisation cloud.',
  ],
  'archiveDeleteFailed': [
    'The archived record was kept because cloud removal could not be confirmed. Try again.',
    'Se conservó el registro porque no se confirmó la eliminación en la nube. Inténtalo de nuevo.',
    'O registro foi mantido porque a remoção na nuvem não foi confirmada. Tente novamente.',
    'L’archive est conservée car la suppression cloud n’a pas été confirmée. Réessayez.',
  ],
  'choiceEffects': [
    'Saved effects',
    'Efectos guardados',
    'Efeitos salvos',
    'Effets enregistrés',
  ],
  'remove': ['Remove', 'Eliminar', 'Remover', 'Supprimer'],
  'loadFailed': [
    'Unable to load. Your saved records are safe. Try again.',
    'No se pudo cargar. Tus registros están a salvo. Inténtalo de nuevo.',
    'Não foi possível carregar. Seus registros estão seguros. Tente novamente.',
    'Chargement impossible. Vos données sont conservées. Réessayez.',
  ],
  'deviceOnly': [
    'Saved on this device',
    'Guardado en este dispositivo',
    'Salvo neste aparelho',
    'Enregistré sur cet appareil',
  ],
  'backupPending': [
    'Saved here · backup pending',
    'Guardado aquí · copia pendiente',
    'Salvo aqui · cópia pendente',
    'Enregistré ici · sauvegarde en attente',
  ],
  'backedUp': [
    'Saved here and backed up',
    'Guardado aquí y en la nube',
    'Salvo aqui e na nuvem',
    'Enregistré ici et sauvegardé',
  ],
  'backupConflict': [
    'Saved here · choose a cloud copy',
    'Guardado aquí · elige una copia',
    'Salvo aqui · escolha uma cópia',
    'Enregistré ici · choisissez une copie',
  ],
  'backupFailed': [
    'Saved here · backup needs retry',
    'Guardado aquí · reintenta la copia',
    'Salvo aqui · tente copiar novamente',
    'Enregistré ici · relancez la sauvegarde',
  ],
  'lastBackup': [
    'Last backup: {time}',
    'Última copia: {time}',
    'Última cópia: {time}',
    'Dernière sauvegarde : {time}',
  ],
  'backupAccountBody': [
    'Signing in enables cloud backup. Local progress remains available offline.',
    'Iniciar sesión permite copias en la nube. El progreso local sigue disponible sin conexión.',
    'Entrar permite cópias na nuvem. O progresso local continua disponível offline.',
    'La connexion active la sauvegarde cloud. La progression locale reste disponible hors ligne.',
  ],
  'history': [
    'Career journal',
    'Diario de carrera',
    'Diário da carreira',
    'Journal de carrière',
  ],
  'historyBody': [
    'Revisit recent matches and the choices that shaped your career.',
    'Repasa los partidos recientes y las decisiones de tu carrera.',
    'Relembre jogos recentes e decisões que marcaram sua carreira.',
    'Revivez les derniers matchs et les choix de votre carrière.',
  ],
  'recentMatches': [
    'Recent matches',
    'Partidos recientes',
    'Jogos recentes',
    'Derniers matchs',
  ],
  'careerChoices': [
    'Career choices',
    'Decisiones de carrera',
    'Decisões da carreira',
    'Choix de carrière',
  ],
  'historyEmpty': [
    'New matches and choices will appear here. Earlier saves do not invent past records.',
    'Los nuevos partidos y decisiones aparecerán aquí. Las partidas antiguas no inventan registros pasados.',
    'Novos jogos e decisões aparecerão aqui. Saves antigos não inventam registros passados.',
    'Les nouveaux matchs et choix apparaîtront ici. Les anciennes sauvegardes ne recréent pas de passé.',
  ],
  'historyLimit': [
    'The journal retains your latest 40 matches and 40 decisions.',
    'El diario conserva tus últimos 40 partidos y 40 decisiones.',
    'O diário guarda seus últimos 40 jogos e 40 decisões.',
    'Le journal conserve vos 40 derniers matchs et 40 derniers choix.',
  ],
  'matchDetail': [
    'Match detail',
    'Detalle del partido',
    'Detalhes do jogo',
    'Détail du match',
  ],
  'didNotAppear': [
    'Did not appear',
    'No participó',
    'Não entrou em campo',
    'Aucune apparition',
  ],
  'roleContributions': [
    'Role contributions',
    'Aportes por posición',
    'Contribuições da posição',
    'Contributions du poste',
  ],
  'keyPasses': ['Key passes', 'Pases clave', 'Passes decisivos', 'Passes clés'],
  'chancesCreated': [
    'Chances created',
    'Ocasiones creadas',
    'Chances criadas',
    'Occasions créées',
  ],
  'successfulDribbles': [
    'Successful dribbles',
    'Regates completados',
    'Dribles certos',
    'Dribbles réussis',
  ],
  'tackles': ['Tackles', 'Entradas', 'Desarmes', 'Tacles'],
  'interceptions': [
    'Interceptions',
    'Intercepciones',
    'Interceptações',
    'Interceptions',
  ],
  'cleanSheets': [
    'Clean sheets',
    'Porterías a cero',
    'Jogos sem sofrer gols',
    'Matchs sans but encaissé',
  ],
  'playerOfMatchAwards': [
    'Player of the match',
    'Jugador del partido',
    'Melhor em campo',
    'Joueur du match',
  ],
  'legacyReasons': [
    'What shapes your legacy',
    'Qué define tu legado',
    'O que define seu legado',
    'Ce qui construit votre héritage',
  ],
  'careerAmbition': [
    'Career ambition',
    'Ambición de carrera',
    'Ambição da carreira',
    'Ambition de carrière',
  ],
  'chooseAmbition': [
    'Choose an ambition',
    'Elige una ambición',
    'Escolha uma ambição',
    'Choisir une ambition',
  ],
  'changeAmbition': [
    'Change ambition',
    'Cambiar ambición',
    'Mudar ambição',
    'Changer d’ambition',
  ],
  'ambitionBody': [
    'Choose a personal direction. Progress uses saved results and awards no extra rewards.',
    'Elige una dirección personal. Usa los resultados guardados y no concede premios extra.',
    'Escolha um objetivo pessoal. Usa resultados salvos e não concede recompensas extras.',
    'Choisissez un objectif personnel. Il suit vos résultats sans récompense supplémentaire.',
  ],
  'ambitionComplete': [
    'Ambition achieved',
    'Ambición cumplida',
    'Ambição alcançada',
    'Ambition réalisée',
  ],
  'goalAppearances': [
    'Make {target} more appearances',
    'Jugar {target} partidos más',
    'Disputar mais {target} jogos',
    'Disputer {target} matchs de plus',
  ],
  'goalGoals': [
    'Score {target} more goals',
    'Marcar {target} goles más',
    'Marcar mais {target} gols',
    'Marquer {target} buts de plus',
  ],
  'goalAssists': [
    'Provide {target} more assists',
    'Dar {target} asistencias más',
    'Dar mais {target} assistências',
    'Faire {target} passes décisives de plus',
  ],
  'goalCleanSheets': [
    'Keep {target} more clean sheets',
    'Lograr {target} porterías a cero más',
    'Ficar mais {target} jogos sem sofrer gols',
    'Réussir {target} matchs de plus sans but encaissé',
  ],
  'goalNationalSelection': [
    'Earn national selection',
    'Llegar a la selección',
    'Chegar à seleção',
    'Rejoindre la sélection nationale',
  ],
  'goalTrophy': [
    'Win a major trophy',
    'Ganar un gran título',
    'Ganhar um grande título',
    'Gagner un grand trophée',
  ],
  'goalPromotion': [
    'Earn promotion',
    'Lograr el ascenso',
    'Conquistar o acesso',
    'Obtenir la promotion',
  ],
  'goalProgress': [
    '{current} / {target}',
    '{current} / {target}',
    '{current} / {target}',
    '{current} / {target}',
  ],
  'mentorStory': [
    'Mentor story',
    'Historia del mentor',
    'História do mentor',
    'Histoire du mentor',
  ],
  'mentorWaiting': [
    'Your mentor story will unfold through career choices.',
    'La historia de tu mentor avanzará con tus decisiones.',
    'A história do mentor avança com suas decisões.',
    'L’histoire de votre mentor évoluera avec vos choix.',
  ],
  'mentorAccepted': [
    'You chose to learn from a senior teammate.',
    'Elegiste aprender de un compañero veterano.',
    'Você escolheu aprender com um colega experiente.',
    'Vous avez choisi d’apprendre d’un coéquipier expérimenté.',
  ],
  'mentorIndependent': [
    'You chose to develop independently.',
    'Elegiste desarrollarte por tu cuenta.',
    'Você escolheu evoluir por conta própria.',
    'Vous avez choisi de progresser seul.',
  ],
  'mentorShared': [
    'You shared the mentor’s lessons with teammates.',
    'Compartiste las lecciones con tus compañeros.',
    'Você compartilhou as lições com os colegas.',
    'Vous avez partagé ses leçons avec l’équipe.',
  ],
  'mentorFocused': [
    'You focused on your own progress.',
    'Te centraste en tu propio progreso.',
    'Você se concentrou na própria evolução.',
    'Vous vous êtes concentré sur vos progrès.',
  ],
  'mentorAlliance': [
    'You and your mentor formed an alliance.',
    'Tú y tu mentor formasteis una alianza.',
    'Você e seu mentor formaram uma aliança.',
    'Vous et votre mentor avez formé une alliance.',
  ],
  'mentorRespect': [
    'You earned mutual respect while keeping your independence.',
    'Ganaste respeto mutuo manteniendo tu independencia.',
    'Você conquistou respeito mútuo mantendo sua independência.',
    'Vous avez gagné un respect mutuel en restant indépendant.',
  ],
  'mentorRivalry': [
    'Your choices created a lasting rivalry.',
    'Tus decisiones crearon una rivalidad duradera.',
    'Suas decisões criaram uma rivalidade duradoura.',
    'Vos choix ont créé une rivalité durable.',
  ],
  'clubStyle': [
    'Club style',
    'Estilo del club',
    'Estilo do clube',
    'Style du club',
  ],
  'ageDevelopment': [
    'Development and age',
    'Desarrollo y edad',
    'Evolução e idade',
    'Progression et âge',
  ],
  'ageDevelopmentBody': [
    'At age {age}, training development uses a {factor}× age factor. Your preview includes this factor.',
    'A los {age} años, el desarrollo usa un factor de edad de {factor}×. La vista previa lo incluye.',
    'Aos {age} anos, a evolução usa um fator de idade de {factor}×. A prévia já o inclui.',
    'À {age} ans, la progression utilise un facteur de {factor}×. Il est inclus dans l’aperçu.',
  ],
  'stylePossession': ['Possession', 'Posesión', 'Posse de bola', 'Possession'],
  'stylePressing': ['Pressing', 'Presión', 'Pressão', 'Pressing'],
  'styleCounter': [
    'Counterattack',
    'Contraataque',
    'Contra-ataque',
    'Contre-attaque',
  ],
  'styleDirect': ['Direct', 'Directo', 'Direto', 'Jeu direct'],
  'styleDefensive': [
    'Defensive structure',
    'Estructura defensiva',
    'Estrutura defensiva',
    'Structure défensive',
  ],
  'clubStyleBody': [
    'Your position and attributes shape your fit in this club’s system.',
    'Tu posición y atributos determinan tu encaje en este sistema.',
    'Sua posição e atributos definem seu encaixe neste sistema.',
    'Votre poste et vos attributs déterminent votre adéquation au système.',
  ],
  'averageRating': [
    'Average season rating',
    'Valoración media por temporada',
    'Nota média por temporada',
    'Note moyenne par saison',
  ],
  'mentorStage': [
    'Story chapter {stage}',
    'Capítulo {stage}',
    'Capítulo {stage}',
    'Chapitre {stage}',
  ],
  'loan': [
    'One-season loan',
    'Cesión de una temporada',
    'Empréstimo de uma temporada',
    'Prêt d’une saison',
  ],
  'loanBody': [
    'Play one season at another club while your parent contract continues. The host pays your wages; you return next offseason.',
    'Juega una temporada en otro club manteniendo tu contrato. El club de destino paga tu sueldo; vuelves la próxima pretemporada.',
    'Jogue uma temporada em outro clube mantendo seu contrato. O destino paga seu salário; você retorna na próxima pré-temporada.',
    'Jouez une saison ailleurs en conservant votre contrat. Le club d’accueil paie le salaire ; retour à la prochaine intersaison.',
  ],
  'acceptLoan': [
    'Accept loan',
    'Aceptar cesión',
    'Aceitar empréstimo',
    'Accepter le prêt',
  ],
  'confirmLoan': [
    'Confirm one-season loan?',
    '¿Confirmar cesión de una temporada?',
    'Confirmar empréstimo de uma temporada?',
    'Confirmer le prêt d’une saison ?',
  ],
  'loanReturn': [
    'Return to {club} in season {season}',
    'Vuelve a {club} en la temporada {season}',
    'Retorne a {club} na temporada {season}',
    'Retour à {club} à la saison {season}',
  ],
  'loanNone': [
    'No eligible loan offers this offseason.',
    'No hay cesiones disponibles esta pretemporada.',
    'Nenhum empréstimo disponível nesta pré-temporada.',
    'Aucune offre de prêt admissible cette intersaison.',
  ],
  'loanRole': [
    'Role: {role} · tactical fit {fit}%',
    'Rol: {role} · encaje táctico {fit}%',
    'Função: {role} · encaixe tático {fit}%',
    'Rôle : {role} · adéquation tactique {fit} %',
  ],
  'support': [
    'Feedback and support',
    'Comentarios y ayuda',
    'Feedback e suporte',
    'Avis et assistance',
  ],
  'friends': ['Friends', 'Amigos', 'Amigos', 'Amis'],
  'friendsBody': [
    'Compare careers with people you know.',
    'Compara carreras con tus amigos.',
    'Compare carreiras com pessoas que conhece.',
    'Comparez vos carrières avec vos proches.',
  ],
  'weeklyChallenge': [
    'Weekly challenge',
    'Desafío semanal',
    'Desafio semanal',
    'Défi hebdomadaire',
  ],
  'challengeBody': [
    'Play a shared scenario with the same starting conditions.',
    'Juega un escenario con las mismas condiciones iniciales.',
    'Jogue um cenário com as mesmas condições iniciais.',
    'Jouez un scénario avec les mêmes conditions de départ.',
  ],
};
