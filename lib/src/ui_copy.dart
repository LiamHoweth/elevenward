import 'package:elevenward_core/elevenward_core.dart';

const uiCopyTranslations = <String, Map<String, String>>{
  'contractExpired': {
    'en': 'Your contract has expired',
    'es': 'Tu contrato ha terminado',
    'pt-BR': 'Seu contrato terminou',
    'fr': 'Votre contrat est terminé',
  },
  'renewalOffered': {
    'en': 'The club offered a renewal',
    'es': 'El club ofreció una renovación',
    'pt-BR': 'O clube ofereceu uma renovação',
    'fr': 'Le club propose une prolongation',
  },
  'freeAgencyRequired': {
    'en': 'There is no renewal. Choose another offer to continue as a free agent.',
    'es': 'No hay renovación. Elige otra oferta para continuar como agente libre.',
    'pt-BR': 'Não há renovação. Escolha outra proposta para continuar como agente livre.',
    'fr': 'Aucune prolongation. Choisissez une autre offre pour continuer comme joueur libre.',
  },
  'acceptRenewal': {
    'en': 'Accept renewal',
    'es': 'Aceptar renovación',
    'pt-BR': 'Aceitar renovação',
    'fr': 'Accepter la prolongation',
  },
  'negotiate': {
    'en': 'Negotiate',
    'es': 'Negociar',
    'pt-BR': 'Negociar',
    'fr': 'Négocier',
  },
  'negotiatewage': {
    'en': 'Ask for higher wages',
    'es': 'Pedir un salario mayor',
    'pt-BR': 'Pedir salário maior',
    'fr': 'Demander un meilleur salaire',
  },
  'negotiaterole': {
    'en': 'Ask for a bigger role',
    'es': 'Pedir un rol mayor',
    'pt-BR': 'Pedir um papel maior',
    'fr': 'Demander un rôle plus important',
  },
  'negotiateterm': {
    'en': 'Ask for another year',
    'es': 'Pedir un año más',
    'pt-BR': 'Pedir mais um ano',
    'fr': 'Demander une année de plus',
  },
  'negotiationAccepted': {
    'en': 'Request accepted',
    'es': 'Petición aceptada',
    'pt-BR': 'Pedido aceito',
    'fr': 'Demande acceptée',
  },
  'negotiationDeclined': {
    'en': 'Original offer remains',
    'es': 'La oferta original sigue vigente',
    'pt-BR': 'A proposta original continua',
    'fr': 'L’offre initiale reste valable',
  },
  'equip': {
    'en': 'Equip',
    'es': 'Equipar',
    'pt-BR': 'Equipar',
    'fr': 'Équiper',
  },
  'equipped': {
    'en': 'Equipped',
    'es': 'Equipado',
    'pt-BR': 'Equipado',
    'fr': 'Équipé',
  },
  'notScheduledThisSeason': {
    'en': 'Not scheduled this season',
    'es': 'No programado esta temporada',
    'pt-BR': 'Não programado nesta temporada',
    'fr': 'Non programmé cette saison',
  },
  'winner': {
    'en': 'Winner',
    'es': 'Ganador',
    'pt-BR': 'Campeão',
    'fr': 'Vainqueur',
  },
  'stage': {'en': 'Stage', 'es': 'Fase', 'pt-BR': 'Fase', 'fr': 'Phase'},
  'noFixtures': {
    'en': 'No fixtures available.',
    'es': 'No hay partidos disponibles.',
    'pt-BR': 'Nenhum jogo disponível.',
    'fr': 'Aucun match disponible.',
  },
  'afterExtraTime': {
    'en': 'DECIDED AFTER EXTRA TIME',
    'es': 'DECIDIDO EN LA PRÓRROGA',
    'pt-BR': 'DECIDIDO NA PRORROGAÇÃO',
    'fr': 'DÉCIDÉ APRÈS PROLONGATION',
  },
  'afterPenalties': {
    'en': 'DECIDED ON PENALTIES',
    'es': 'DECIDIDO EN LOS PENALTIS',
    'pt-BR': 'DECIDIDO NOS PÊNALTIS',
    'fr': 'DÉCIDÉ AUX TIRS AU BUT',
  },
  'extraTimeShort': {
    'en': 'AET',
    'es': 'PRÓR.',
    'pt-BR': 'PROR.',
    'fr': 'A.P.',
  },
  'penaltiesShort': {'en': 'PENS', 'es': 'PEN.', 'pt-BR': 'PÊN.', 'fr': 'TAB'},
  'skip': {'en': 'Skip', 'es': 'Omitir', 'pt-BR': 'Pular', 'fr': 'Passer'},
  'continue': {
    'en': 'Continue',
    'es': 'Continuar',
    'pt-BR': 'Continuar',
    'fr': 'Continuer',
  },
  'startCareer': {
    'en': 'Start your career',
    'es': 'Comienza tu carrera',
    'pt-BR': 'Comece sua carreira',
    'fr': 'Commencez votre carrière',
  },
  'onboardingOfflineTitle': {
    'en': 'Your career lives on your device',
    'es': 'Tu carrera vive en tu dispositivo',
    'pt-BR': 'Sua carreira fica no seu dispositivo',
    'fr': 'Votre carrière reste sur votre appareil',
  },
  'onboardingOfflineBody': {
    'en': 'Play every season offline. Your saves use a recovery journal, and an account is optional.',
    'es': 'Juega cada temporada sin conexión. Tus partidas usan un registro de recuperación y la cuenta es opcional.',
    'pt-BR': 'Jogue todas as temporadas offline. Os saves usam um diário de recuperação e a conta é opcional.',
    'fr': 'Jouez chaque saison hors ligne. Les sauvegardes disposent d’un journal de récupération et le compte reste facultatif.',
  },
  'onboardingFocusTitle': {
    'en': 'Choose the week’s tradeoff',
    'es': 'Elige el equilibrio de la semana',
    'pt-BR': 'Escolha o equilíbrio da semana',
    'fr': 'Choisissez le compromis de la semaine',
  },
  'onboardingFocusBody': {
    'en': 'Light work restores fitness. Intense work improves faster but leaves less for matchday.',
    'es': 'El trabajo ligero recupera físico. El intenso mejora más rápido, pero deja menos para el partido.',
    'pt-BR': 'Treino leve recupera o físico. O intenso melhora mais rápido, mas cobra no jogo.',
    'fr': 'Un effort léger restaure la forme. Un effort intense progresse plus vite, mais coûte le jour du match.',
  },
  'onboardingSpotlightTitle': {
    'en': 'Every big moment explains itself',
    'es': 'Cada gran momento se explica',
    'pt-BR': 'Cada grande momento se explica',
    'fr': 'Chaque grand moment s’explique',
  },
  'onboardingSpotlightBody': {
    'en': 'See the odds, choose your risk, and read a receipt showing exactly what shaped the result.',
    'es': 'Consulta las probabilidades, elige el riesgo y revisa qué determinó el resultado.',
    'pt-BR': 'Veja as chances, escolha o risco e confira o que determinou o resultado.',
    'fr': 'Consultez les chances, choisissez le risque et découvrez ce qui a déterminé le résultat.',
  },
  'onboardingCloudTitle': {
    'en': 'Cloud features stay optional',
    'es': 'Las funciones en la nube son opcionales',
    'pt-BR': 'Os recursos de nuvem são opcionais',
    'fr': 'Les fonctions cloud restent facultatives',
  },
  'onboardingCloudBody': {
    'en': 'Sign in only when you want sync, purchase recovery, or prize-free leaderboards. Analytics is a separate choice.',
    'es': 'Inicia sesión solo para sincronizar, recuperar compras o usar clasificaciones sin premios. Las analíticas son opcionales aparte.',
    'pt-BR': 'Entre apenas para sincronizar, recuperar compras ou usar classificações sem prêmios. As análises são uma escolha separada.',
    'fr': 'Connectez-vous uniquement pour la synchronisation, les achats ou les classements sans prix. Les statistiques sont un choix distinct.',
  },
  'leaderboards': {
    'en': 'Leaderboards',
    'es': 'Clasificaciones',
    'pt-BR': 'Classificações',
    'fr': 'Classements',
  },
  'browseLeaderboards': {
    'en': 'Browse leaderboards',
    'es': 'Ver clasificaciones',
    'pt-BR': 'Ver classificações',
    'fr': 'Voir les classements',
  },
  'leaderboardNoPrizes': {
    'en': 'Generated aliases only. No prizes or public free text.',
    'es': 'Solo alias generados. Sin premios ni texto público libre.',
    'pt-BR': 'Apenas apelidos gerados. Sem prêmios ou texto público livre.',
    'fr': 'Alias générés uniquement. Aucun prix ni texte public libre.',
  },
  'shareRetiredCareer': {
    'en': 'Share completed careers',
    'es': 'Compartir carreras terminadas',
    'pt-BR': 'Compartilhar carreiras concluídas',
    'fr': 'Partager les carrières terminées',
  },
  'leaderboardPrivacy': {
    'en': 'Opt in before a retired career is submitted under your generated alias.',
    'es':
        'Actívalo antes de enviar una carrera retirada con tu alias generado.',
    'pt-BR':
        'Ative antes de enviar uma carreira encerrada com seu apelido gerado.',
    'fr': 'Activez cette option avant tout envoi sous votre alias généré.',
  },
  'submitCompletedCareer': {
    'en': 'Submit this completed career',
    'es': 'Enviar esta carrera terminada',
    'pt-BR': 'Enviar esta carreira concluída',
    'fr': 'Envoyer cette carrière terminée',
  },
  'noLeaderboardEntries': {
    'en': 'No submitted careers in this board yet.',
    'es': 'Aún no hay carreras enviadas a esta clasificación.',
    'pt-BR': 'Ainda não há carreiras enviadas nesta classificação.',
    'fr': 'Aucune carrière envoyée dans ce classement pour le moment.',
  },
  'leaderboardOffline': {
    'en': 'The board is unavailable. Check your connection and try again.',
    'es': 'La clasificación no está disponible. Revisa tu conexión e inténtalo de nuevo.',
    'pt-BR': 'A classificação está indisponível. Verifique a conexão e tente novamente.',
    'fr': 'Le classement est indisponible. Vérifiez votre connexion et réessayez.',
  },
  'storePrice': {
    'en': 'Store price',
    'es': 'Precio de la tienda',
    'pt-BR': 'Preço da loja',
    'fr': 'Prix en boutique',
  },
  'backFocus': {
    'en': 'Back to weekly focus',
    'es': 'Volver al enfoque semanal',
    'pt-BR': 'Voltar ao foco semanal',
    'fr': 'Retour à l’objectif hebdomadaire',
  },
  'workBeforeNoise': {
    'en': 'THE WORK BEFORE THE NOISE',
    'es': 'EL TRABAJO ANTES DEL RUIDO',
    'pt-BR': 'O TRABALHO ANTES DO BARULHO',
    'fr': 'LE TRAVAIL AVANT LE BRUIT',
  },
  'fitness': {
    'en': 'FITNESS',
    'es': 'FÍSICO',
    'pt-BR': 'FÍSICO',
    'fr': 'FORME',
  },
  'attribute': {
    'en': 'ATTRIBUTE',
    'es': 'ATRIBUTO',
    'pt-BR': 'ATRIBUTO',
    'fr': 'ATTRIBUT',
  },
  'form': {'en': 'FORM', 'es': 'FORMA', 'pt-BR': 'FORMA', 'fr': 'FORME'},
  'trust': {
    'en': 'TRUST',
    'es': 'CONFIANZA',
    'pt-BR': 'CONFIANÇA',
    'fr': 'CONFIANCE',
  },
  'reputation': {'en': 'REP', 'es': 'REP', 'pt-BR': 'REP', 'fr': 'RÉP'},
  'pay': {'en': 'PAY', 'es': 'PAGO', 'pt-BR': 'PAG.', 'fr': 'PAIE'},
  'scoreLevel': {
    'en': 'SCORE LEVEL',
    'es': 'EMPATE',
    'pt-BR': 'PLACAR EMPATADO',
    'fr': 'SCORE À ÉGALITÉ',
  },
  'lowRisk': {
    'en': 'LOW RISK',
    'es': 'RIESGO BAJO',
    'pt-BR': 'RISCO BAIXO',
    'fr': 'RISQUE FAIBLE',
  },
  'balanced': {
    'en': 'BALANCED',
    'es': 'EQUILIBRADO',
    'pt-BR': 'EQUILIBRADO',
    'fr': 'ÉQUILIBRÉ',
  },
  'highRisk': {
    'en': 'HIGH RISK',
    'es': 'RIESGO ALTO',
    'pt-BR': 'RISCO ALTO',
    'fr': 'RISQUE ÉLEVÉ',
  },
  'hideNumbers': {
    'en': 'HIDE THE NUMBERS',
    'es': 'OCULTAR LOS NÚMEROS',
    'pt-BR': 'OCULTAR OS NÚMEROS',
    'fr': 'MASQUER LES CHIFFRES',
  },
  'whyOdds': {
    'en': 'WHY THESE ODDS?',
    'es': '¿POR QUÉ ESTAS PROBABILIDADES?',
    'pt-BR': 'POR QUE ESSAS CHANCES?',
    'fr': 'POURQUOI CES CHANCES ?',
  },
  'commitDecision': {
    'en': 'COMMIT DECISION',
    'es': 'CONFIRMAR DECISIÓN',
    'pt-BR': 'CONFIRMAR DECISÃO',
    'fr': 'CONFIRMER LA DÉCISION',
  },
  'changeUntilCommit': {
    'en': 'You can change your choice until you commit.',
    'es': 'Puedes cambiar la elección hasta confirmarla.',
    'pt-BR': 'Você pode mudar a escolha até confirmar.',
    'fr': 'Vous pouvez modifier votre choix avant de confirmer.',
  },
  'starter': {
    'en': 'STARTING XI',
    'es': 'ONCE INICIAL',
    'pt-BR': 'TIME TITULAR',
    'fr': 'TITULAIRE',
  },
  'bench': {
    'en': 'ON THE BENCH',
    'es': 'EN EL BANQUILLO',
    'pt-BR': 'NO BANCO',
    'fr': 'SUR LE BANC',
  },
  'omitted': {
    'en': 'NOT SELECTED',
    'es': 'NO CONVOCADO',
    'pt-BR': 'FORA DA LISTA',
    'fr': 'NON RETENU',
  },
  'starterBody': {
    'en': 'The manager trusts you to start.',
    'es': 'El entrenador confía en ti como titular.',
    'pt-BR': 'O treinador confia em você como titular.',
    'fr': 'L’entraîneur vous fait confiance comme titulaire.',
  },
  'benchBody': {
    'en': 'You can still change the match from the bench.',
    'es': 'Aún puedes cambiar el partido desde el banquillo.',
    'pt-BR': 'Você ainda pode mudar o jogo saindo do banco.',
    'fr': 'Vous pouvez encore changer le match depuis le banc.',
  },
  'omittedBody': {
    'en': 'Fitness, form, and trust kept you out this week.',
    'es': 'El físico, la forma y la confianza te dejaron fuera esta semana.',
    'pt-BR': 'Físico, forma e confiança deixaram você fora nesta rodada.',
    'fr': 'La forme, la dynamique et la confiance vous écartent cette semaine.',
  },
  'coachTip': {
    'en': 'COACH: Read the odds, but play to your strengths. Bigger moments carry bigger downside.',
    'es': 'ENTRENADOR: Lee las probabilidades y juega con tus fortalezas. Los grandes momentos tienen más riesgo.',
    'pt-BR': 'TREINADOR: Leia as chances e jogue com seus pontos fortes. Grandes momentos trazem mais risco.',
    'fr': 'COACH : Lisez les chances et jouez sur vos forces. Les grands moments comportent plus de risques.',
  },
  'success': {
    'en': 'SUCCESS',
    'es': 'ÉXITO',
    'pt-BR': 'SUCESSO',
    'fr': 'RÉUSSITE',
  },
  'momentWon': {
    'en': 'MOMENT WON',
    'es': 'MOMENTO GANADO',
    'pt-BR': 'MOMENTO VENCIDO',
    'fr': 'MOMENT RÉUSSI',
  },
  'momentMissed': {
    'en': 'MOMENT MISSED',
    'es': 'MOMENTO PERDIDO',
    'pt-BR': 'MOMENTO PERDIDO',
    'fr': 'MOMENT MANQUÉ',
  },
  'matchRating': {
    'en': 'MATCH RATING',
    'es': 'NOTA DEL PARTIDO',
    'pt-BR': 'NOTA DA PARTIDA',
    'fr': 'NOTE DU MATCH',
  },
  'goals': {'en': 'GOALS', 'es': 'GOLES', 'pt-BR': 'GOLS', 'fr': 'BUTS'},
  'assists': {
    'en': 'ASSISTS',
    'es': 'ASIST.',
    'pt-BR': 'ASSIST.',
    'fr': 'PASSES D.',
  },
  'apps': {'en': 'APPS', 'es': 'PART.', 'pt-BR': 'JOGOS', 'fr': 'MATCHS'},
  'rating': {'en': 'RATING', 'es': 'NOTA', 'pt-BR': 'NOTA', 'fr': 'NOTE'},
  'whyHappened': {
    'en': 'WHY IT HAPPENED',
    'es': 'POR QUÉ OCURRIÓ',
    'pt-BR': 'POR QUE ACONTECEU',
    'fr': 'POURQUOI C’EST ARRIVÉ',
  },
  'seededRoll': {
    'en': 'Seeded match roll',
    'es': 'Tirada determinista',
    'pt-BR': 'Sorteio determinístico',
    'fr': 'Tirage déterministe',
  },
  'awayPitch': {
    'en': 'AWAY FROM THE PITCH',
    'es': 'FUERA DEL CAMPO',
    'pt-BR': 'FORA DE CAMPO',
    'fr': 'HORS DU TERRAIN',
  },
  'continueOffseason': {
    'en': 'CONTINUE TO OFFSEASON',
    'es': 'CONTINUAR A LA PRETEMPORADA',
    'pt-BR': 'IR PARA A INTERTEMPORADA',
    'fr': 'PASSER À L’INTERSAISON',
  },
  'legacyScore': {
    'en': 'LEGACY SCORE',
    'es': 'PUNTUACIÓN DE LEGADO',
    'pt-BR': 'PONTUAÇÃO DE LEGADO',
    'fr': 'SCORE D’HÉRITAGE',
  },
  'seasons': {
    'en': 'seasons',
    'es': 'temporadas',
    'pt-BR': 'temporadas',
    'fr': 'saisons',
  },
  'seasonLabel': {
    'en': 'Season',
    'es': 'Temporada',
    'pt-BR': 'Temporada',
    'fr': 'Saison',
  },
  'appearances': {
    'en': 'appearances',
    'es': 'partidos',
    'pt-BR': 'jogos',
    'fr': 'apparitions',
  },
  'trophies': {
    'en': 'major trophies',
    'es': 'títulos importantes',
    'pt-BR': 'títulos importantes',
    'fr': 'trophées majeurs',
  },
  'reputationLong': {
    'en': 'reputation',
    'es': 'reputación',
    'pt-BR': 'reputação',
    'fr': 'réputation',
  },
  'supporterCosmetics': {
    'en': 'Supporter cosmetics',
    'es': 'Cosméticos de Supporter',
    'pt-BR': 'Cosméticos de Supporter',
    'fr': 'Cosmétiques Supporter',
  },
  'system': {
    'en': 'System',
    'es': 'Sistema',
    'pt-BR': 'Sistema',
    'fr': 'Système',
  },
  'manager': {
    'en': 'Manager',
    'es': 'Entrenador',
    'pt-BR': 'Treinador',
    'fr': 'Entraîneur',
  },
  'teammates': {
    'en': 'Teammates',
    'es': 'Compañeros',
    'pt-BR': 'Companheiros',
    'fr': 'Coéquipiers',
  },
  'family': {
    'en': 'Family',
    'es': 'Familia',
    'pt-BR': 'Família',
    'fr': 'Famille',
  },
  'community': {
    'en': 'Community',
    'es': 'Comunidad',
    'pt-BR': 'Comunidade',
    'fr': 'Communauté',
  },
  'managerConsequence': {
    'en': 'Influences weekly selection',
    'es': 'Influye en la convocatoria',
    'pt-BR': 'Influencia a escalação',
    'fr': 'Influence la sélection',
  },
  'teammateConsequence': {
    'en': 'Influences team performance',
    'es': 'Influye en el rendimiento del equipo',
    'pt-BR': 'Influencia o desempenho do time',
    'fr': 'Influence la performance collective',
  },
  'agentConsequence': {
    'en': 'Influences transfer reach',
    'es': 'Influye en el alcance de fichajes',
    'pt-BR': 'Influencia o alcance no mercado',
    'fr': 'Influence la portée des transferts',
  },
  'familyConsequence': {
    'en': 'Influences weekly recovery',
    'es': 'Influye en la recuperación',
    'pt-BR': 'Influencia a recuperação',
    'fr': 'Influence la récupération',
  },
  'communityConsequence': {
    'en': 'Influences reputation and reach',
    'es': 'Influye en reputación y alcance',
    'pt-BR': 'Influencia reputação e alcance',
    'fr': 'Influence réputation et portée',
  },
  'wellnessConsequence': {
    'en': 'Your recovery reserve',
    'es': 'Tu reserva de recuperación',
    'pt-BR': 'Sua reserva de recuperação',
    'fr': 'Votre réserve de récupération',
  },
  'wellness': {
    'en': 'Wellness',
    'es': 'Bienestar',
    'pt-BR': 'Bem-estar',
    'fr': 'Bien-être',
  },
  'cloudConflicts': {
    'en': 'Cloud conflicts',
    'es': 'Conflictos en la nube',
    'pt-BR': 'Conflitos na nuvem',
    'fr': 'Conflits cloud',
  },
  'keepCloud': {
    'en': 'KEEP CLOUD',
    'es': 'CONSERVAR NUBE',
    'pt-BR': 'MANTER NUVEM',
    'fr': 'GARDER LE CLOUD',
  },
  'keepLocal': {
    'en': 'KEEP LOCAL',
    'es': 'CONSERVAR LOCAL',
    'pt-BR': 'MANTER LOCAL',
    'fr': 'GARDER LOCAL',
  },
  'keepDeleted': {
    'en': 'KEEP DELETED',
    'es': 'MANTENER BORRADA',
    'pt-BR': 'MANTER EXCLUÍDA',
    'fr': 'GARDER SUPPRIMÉE',
  },
  'theme': {'en': 'Theme', 'es': 'Tema', 'pt-BR': 'Tema', 'fr': 'Thème'},
  'avatar': {'en': 'Avatar', 'es': 'Avatar', 'pt-BR': 'Avatar', 'fr': 'Avatar'},
  'archive': {
    'en': 'Archive',
    'es': 'Archivo',
    'pt-BR': 'Arquivo',
    'fr': 'Archives',
  },
  'shareCard': {
    'en': 'Share card',
    'es': 'Tarjeta para compartir',
    'pt-BR': 'Cartão de compartilhamento',
    'fr': 'Carte de partage',
  },
  'completedSeasons': {
    'en': 'Completed seasons will appear here.',
    'es': 'Las temporadas terminadas aparecerán aquí.',
    'pt-BR': 'As temporadas concluídas aparecerão aqui.',
    'fr': 'Les saisons terminées apparaîtront ici.',
  },
  'deleteLocalTitle': {
    'en': 'Delete local career?',
    'es': '¿Eliminar la carrera local?',
    'pt-BR': 'Excluir carreira local?',
    'fr': 'Supprimer la carrière locale ?',
  },
  'deleteLocalBody': {
    'en': 'This removes the selected career from this device. Other slots are not affected.',
    'es': 'Esto elimina la carrera seleccionada de este dispositivo. Los demás espacios no cambian.',
    'pt-BR': 'Isso remove a carreira selecionada deste aparelho. Os outros espaços não são afetados.',
    'fr': 'Cette action supprime la carrière choisie de cet appareil. Les autres emplacements ne changent pas.',
  },
  'delete': {
    'en': 'DELETE',
    'es': 'ELIMINAR',
    'pt-BR': 'EXCLUIR',
    'fr': 'SUPPRIMER',
  },
  'deletedLocally': {
    'en': 'Deleted locally',
    'es': 'Eliminada localmente',
    'pt-BR': 'Excluída localmente',
    'fr': 'Supprimée localement',
  },
  'finishCloud': {
    'en': 'Tap to finish cloud reconciliation',
    'es': 'Toca para terminar la sincronización',
    'pt-BR': 'Toque para concluir a sincronização',
    'fr': 'Touchez pour terminer la synchronisation',
  },
  'saveNeedsRecovery': {
    'en': 'Save needs recovery',
    'es': 'La partida necesita recuperación',
    'pt-BR': 'O save precisa de recuperação',
    'fr': 'La sauvegarde doit être récupérée',
  },
  'restoreJournal': {
    'en': 'Tap to restore the latest readable journal entry.',
    'es': 'Toca para restaurar la última entrada legible del registro.',
    'pt-BR': 'Toque para restaurar a última entrada legível do diário.',
    'fr': 'Touchez pour restaurer la dernière entrée lisible du journal.',
  },
  'supportCode': {
    'en': 'Support code',
    'es': 'Código de soporte',
    'pt-BR': 'Código de suporte',
    'fr': 'Code d’assistance',
  },
  'slotLabel': {
    'en': 'Slot',
    'es': 'Espacio',
    'pt-BR': 'Espaço',
    'fr': 'Emplacement',
  },
  'recoverySlotSemantics': {
    'en': 'tap to restore from the recovery journal',
    'es': 'toca para restaurar desde el registro de recuperación',
    'pt-BR': 'toque para restaurar pelo diário de recuperação',
    'fr': 'touchez pour restaurer depuis le journal de récupération',
  },
  'deletionPendingSemantics': {
    'en': 'deletion waiting for cloud sync',
    'es': 'eliminación pendiente de sincronización',
    'pt-BR': 'exclusão aguardando sincronização',
    'fr': 'suppression en attente de synchronisation',
  },
  'tableColumns': {
    'en': 'P   GD   PTS',
    'es': 'PJ   DG   PTS',
    'pt-BR': 'J   SG   PTS',
    'fr': 'MJ   DB   PTS',
  },
  'clubMark': {
    'en': 'club mark',
    'es': 'emblema del club',
    'pt-BR': 'escudo do clube',
    'fr': 'emblème du club',
  },
  'versus': {'en': 'versus', 'es': 'contra', 'pt-BR': 'contra', 'fr': 'contre'},
  'countries': {
    'en': 'countries',
    'es': 'países',
    'pt-BR': 'países',
    'fr': 'pays',
  },
  'divisionOne': {
    'en': 'Division I',
    'es': 'División I',
    'pt-BR': 'Divisão I',
    'fr': 'Division I',
  },
  'divisionTwo': {
    'en': 'Division II',
    'es': 'División II',
    'pt-BR': 'Divisão II',
    'fr': 'Division II',
  },
  'deleteTooltip': {
    'en': 'Delete this local career',
    'es': 'Eliminar esta carrera local',
    'pt-BR': 'Excluir esta carreira local',
    'fr': 'Supprimer cette carrière locale',
  },
  'deletionConflict': {
    'en': 'This career was deleted here but changed on another device.',
    'es': 'Esta carrera se eliminó aquí, pero cambió en otro dispositivo.',
    'pt-BR': 'Esta carreira foi excluída aqui, mas mudou em outro aparelho.',
    'fr': 'Cette carrière a été supprimée ici, mais modifiée sur un autre appareil.',
  },
  'saveConflict': {
    'en': 'This career changed independently on two devices.',
    'es': 'Esta carrera cambió por separado en dos dispositivos.',
    'pt-BR': 'Esta carreira mudou separadamente em dois aparelhos.',
    'fr': 'Cette carrière a changé indépendamment sur deux appareils.',
  },
  'cupFormat': {
    'en': 'Twenty clubs · single-elimination national cup',
    'es': 'Veinte clubes · copa nacional de eliminación directa',
    'pt-BR': 'Vinte clubes · copa nacional eliminatória',
    'fr': 'Vingt clubs · coupe nationale à élimination directe',
  },
  'internationalFormat': {
    'en': '12 clubs · three groups · continental knockout rounds',
    'es': '12 clubes · tres grupos · eliminatorias continentales',
    'pt-BR': '12 clubes · três grupos · mata-mata continental',
    'fr': '12 clubs · trois groupes · phase finale continentale',
  },
  'knockoutBracket': {
    'en': 'Knockout bracket',
    'es': 'Cuadro eliminatorio',
    'pt-BR': 'Chave eliminatória',
    'fr': 'Tableau final',
  },
  'allFixtures': {
    'en': 'All fixtures',
    'es': 'Todos los partidos',
    'pt-BR': 'Todos os jogos',
    'fr': 'Tous les matchs',
  },
  'preliminaryRound': {
    'en': 'Preliminary round',
    'es': 'Ronda preliminar',
    'pt-BR': 'Fase preliminar',
    'fr': 'Tour préliminaire',
  },
  'groupStage': {
    'en': 'Group stage',
    'es': 'Fase de grupos',
    'pt-BR': 'Fase de grupos',
    'fr': 'Phase de groupes',
  },
  'internationalQualification': {
    'en':
        'The top two in each group and the two best third-place clubs advance.',
    'es': 'Avanzan los dos primeros de cada grupo y los dos mejores terceros.',
    'pt-BR':
        'Avançam os dois melhores de cada grupo e os dois melhores terceiros.',
    'fr': 'Les deux premiers de chaque groupe et les deux meilleurs troisièmes se qualifient.',
  },
  'nationalQualification': {
    'en': 'The top two in each group and the four best third-place teams advance.',
    'es':
        'Avanzan los dos primeros de cada grupo y los cuatro mejores terceros.',
    'pt-BR': 'Avançam os dois melhores de cada grupo e os quatro melhores terceiros.',
    'fr': 'Les deux premiers de chaque groupe et les quatre meilleurs troisièmes se qualifient.',
  },
  'groupTiebreaks': {
    'en': 'Group ties use points, goal difference, goals scored, then the stable tournament seed.',
    'es': 'Los empates usan puntos, diferencia de goles, goles marcados y luego el orden estable del torneo.',
    'pt-BR': 'Empates usam pontos, saldo de gols, gols marcados e depois a ordem estável do torneio.',
    'fr': 'Les égalités sont départagées par les points, la différence de buts, les buts marqués, puis l’ordre stable du tournoi.',
  },
  'roundOf16': {
    'en': 'Round of 16',
    'es': 'Octavos de final',
    'pt-BR': 'Oitavas de final',
    'fr': 'Huitièmes de finale',
  },
  'quarterfinals': {
    'en': 'Quarterfinals',
    'es': 'Cuartos de final',
    'pt-BR': 'Quartas de final',
    'fr': 'Quarts de finale',
  },
  'semifinals': {
    'en': 'Semifinals',
    'es': 'Semifinales',
    'pt-BR': 'Semifinais',
    'fr': 'Demi-finales',
  },
  'finalRound': {
    'en': 'Final',
    'es': 'Final',
    'pt-BR': 'Final',
    'fr': 'Finale',
  },
  'careerHonours': {
    'en': 'Career honours',
    'es': 'Palmarés de la carrera',
    'pt-BR': 'Títulos da carreira',
    'fr': 'Palmarès de carrière',
  },
  'noHonoursYet': {
    'en': 'No trophies yet. Every completed season remains in the archive.',
    'es': 'Aún no hay trofeos. Cada temporada terminada queda en el archivo.',
    'pt-BR': 'Ainda não há títulos. Toda temporada concluída fica no arquivo.',
    'fr':
        'Aucun trophée pour le moment. Chaque saison terminée reste archivée.',
  },
  'nameValidation': {
    'en': 'Enter at least two characters.',
    'es': 'Escribe al menos dos caracteres.',
    'pt-BR': 'Digite pelo menos dois caracteres.',
    'fr': 'Saisissez au moins deux caractères.',
  },
  'webDeletionCode': {
    'en': 'Get web deletion code',
    'es': 'Obtener código para la web',
    'pt-BR': 'Obter código para o site',
    'fr': 'Obtenir un code pour le web',
  },
  'webDeletionBody': {
    'en': 'Use this one-time code on the Elevenward deletion page.',
    'es': 'Usa este código único en la página de eliminación de Elevenward.',
    'pt-BR': 'Use este código único na página de exclusão do Elevenward.',
    'fr': 'Utilisez ce code unique sur la page de suppression Elevenward.',
  },
  'accountId': {
    'en': 'Account ID',
    'es': 'ID de cuenta',
    'pt-BR': 'ID da conta',
    'fr': 'ID du compte',
  },
  'code': {'en': 'Code', 'es': 'Código', 'pt-BR': 'Código', 'fr': 'Code'},
  'expires': {
    'en': 'Expires',
    'es': 'Caduca',
    'pt-BR': 'Expira',
    'fr': 'Expire',
  },
  'careerTeam': {
    'en': 'Career team',
    'es': 'Equipo profesional',
    'pt-BR': 'Equipe de carreira',
    'fr': 'Équipe de carrière',
  },
  'chooseAgent': {
    'en': 'Choose agent',
    'es': 'Elegir agente',
    'pt-BR': 'Escolher agente',
    'fr': 'Choisir un agent',
  },
  'active': {'en': 'ACTIVE', 'es': 'ACTIVO', 'pt-BR': 'ATIVO', 'fr': 'ACTIF'},
  'nationalEligible': {
    'en': 'National-team eligible',
    'es': 'Elegible para la selección',
    'pt-BR': 'Elegível para a seleção',
    'fr': 'Éligible en sélection',
  },
  'nationalNotEligible': {
    'en': 'National-team target: 68 OVR and 60 reputation',
    'es': 'Objetivo de selección: 68 GRL y 60 de reputación',
    'pt-BR': 'Meta da seleção: 68 GER e 60 de reputação',
    'fr': 'Objectif sélection : 68 GÉN et 60 de réputation',
  },
  'nationalCallUpArrived': {
    'en': 'Your national-team call-up has arrived',
    'es': 'Ha llegado tu convocatoria con la selección',
    'pt-BR': 'Sua convocação para a seleção chegou',
    'fr': 'Votre convocation en sélection est arrivée',
  },
  'nationalCallUpAccepted': {
    'en': 'Call-up accepted for this tournament',
    'es': 'Convocatoria aceptada para este torneo',
    'pt-BR': 'Convocação aceita para este torneio',
    'fr': 'Convocation acceptée pour ce tournoi',
  },
  'nationalCallUpDeclined': {
    'en': 'Call-up declined for this tournament',
    'es': 'Convocatoria rechazada para este torneo',
    'pt-BR': 'Convocação recusada para este torneio',
    'fr': 'Convocation refusée pour ce tournoi',
  },
  'nationalCallUpBody': {
    'en': 'Accept to make national-team fixtures your weekly spotlight. Declining keeps your club schedule active.',
    'es': 'Acepta para jugar los partidos de la selección como foco semanal. Si rechazas, seguirás con tu club.',
    'pt-BR': 'Aceite para jogar pela seleção no destaque semanal. Se recusar, você seguirá com o clube.',
    'fr': 'Acceptez pour jouer les matches internationaux en temps fort. Refusez pour rester avec votre club.',
  },
  'acceptCallUp': {
    'en': 'Accept call-up',
    'es': 'Aceptar',
    'pt-BR': 'Aceitar',
    'fr': 'Accepter',
  },
  'decline': {
    'en': 'Decline',
    'es': 'Rechazar',
    'pt-BR': 'Recusar',
    'fr': 'Refuser',
  },
  'nationalRecord': {
    'en': 'International record',
    'es': 'Registro internacional',
    'pt-BR': 'Histórico internacional',
    'fr': 'Bilan international',
  },
  'caps': {
    'en': 'caps',
    'es': 'partidos',
    'pt-BR': 'jogos',
    'fr': 'sélections',
  },
  'activeSponsors': {
    'en': 'Active sponsors',
    'es': 'Patrocinadores activos',
    'pt-BR': 'Patrocinadores ativos',
    'fr': 'Sponsors actifs',
  },
  'sponsorEarnings': {
    'en': 'Sponsor earnings',
    'es': 'Ingresos de patrocinio',
    'pt-BR': 'Receita de patrocínio',
    'fr': 'Revenus des sponsors',
  },
  'sponsorEnded': {
    'en': 'A sponsor term ended or its reputation obligation was not met.',
    'es': 'Terminó un patrocinio o no se cumplió su requisito de reputación.',
    'pt-BR': 'Um patrocínio terminou ou a meta de reputação não foi cumprida.',
    'fr': 'Un contrat a pris fin ou son exigence de réputation n’a pas été remplie.',
  },
  'lifestyleMarket': {
    'en': 'Lifestyle market',
    'es': 'Mercado de estilo de vida',
    'pt-BR': 'Mercado de estilo de vida',
    'fr': 'Marché du style de vie',
  },
  'transferFeedback': {
    'en': 'Recruitment feedback',
    'es': 'Evaluación de fichajes',
    'pt-BR': 'Avaliação de transferências',
    'fr': 'Avis du recrutement',
  },
  'noOffers': {
    'en': 'No club crossed the offer threshold this season. The reasons below show what held interest back.',
    'es': 'Ningún club superó el umbral de oferta esta temporada. Las razones indican qué frenó el interés.',
    'pt-BR': 'Nenhum clube superou o limite de proposta nesta temporada. Os motivos mostram o que conteve o interesse.',
    'fr': 'Aucun club n’a atteint le seuil d’offre cette saison. Les raisons ci-dessous expliquent les freins.',
  },
  'retrySync': {
    'en': 'Retry cloud sync',
    'es': 'Reintentar sincronización',
    'pt-BR': 'Tentar sincronizar novamente',
    'fr': 'Réessayer la synchronisation',
  },
  'syncPreparing': {
    'en': 'Comparing local and cloud careers…',
    'es': 'Comparando carreras locales y en la nube…',
    'pt-BR': 'Comparando carreiras locais e na nuvem…',
    'fr': 'Comparaison des carrières locales et cloud…',
  },
  'syncProgress': {
    'en': 'Syncing',
    'es': 'Sincronizando',
    'pt-BR': 'Sincronizando',
    'fr': 'Synchronisation',
  },
  'syncFailedSafe': {
    'en': 'Sync stopped. Your local careers are safe; tap to retry.',
    'es': 'La sincronización se detuvo. Tus carreras locales están seguras; toca para reintentar.',
    'pt-BR': 'A sincronização parou. Suas carreiras locais estão seguras; toque para tentar de novo.',
    'fr': 'La synchronisation s’est arrêtée. Vos carrières locales sont intactes ; touchez pour réessayer.',
  },
  'conflicts': {
    'en': 'conflicts',
    'es': 'conflictos',
    'pt-BR': 'conflitos',
    'fr': 'conflits',
  },
  'fit': {'en': 'FIT', 'es': 'ENCAJE', 'pt-BR': 'AJUSTE', 'fr': 'ADAPT.'},
  'interest': {
    'en': 'INTEREST',
    'es': 'INTERÉS',
    'pt-BR': 'INTERESSE',
    'fr': 'INTÉRÊT',
  },
  'season': {
    'en': 'Season',
    'es': 'Temporada',
    'pt-BR': 'Temporada',
    'fr': 'Saison',
  },
  'week': {'en': 'Week', 'es': 'Semana', 'pt-BR': 'Semana', 'fr': 'Semaine'},
  'legacy': {
    'en': 'Legacy',
    'es': 'Legado',
    'pt-BR': 'Legado',
    'fr': 'Héritage',
  },
  'points': {'en': 'points', 'es': 'puntos', 'pt-BR': 'pontos', 'fr': 'points'},
};

String uiCopy(String locale, String key) =>
    uiCopyTranslations[key]?[locale] ?? uiCopyTranslations[key]?['en'] ?? key;

String localizedPosition(String locale, String name) {
  const values = {
    'striker': {
      'en': 'Striker',
      'es': 'Delantero',
      'pt-BR': 'Atacante',
      'fr': 'Attaquant',
    },
    'winger': {
      'en': 'Winger',
      'es': 'Extremo',
      'pt-BR': 'Ponta',
      'fr': 'Ailier',
    },
    'midfielder': {
      'en': 'Midfielder',
      'es': 'Centrocampista',
      'pt-BR': 'Meio-campista',
      'fr': 'Milieu',
    },
    'defender': {
      'en': 'Defender',
      'es': 'Defensa',
      'pt-BR': 'Defensor',
      'fr': 'Défenseur',
    },
  };
  return values[name]?[locale] ?? values[name]?['en'] ?? name;
}

String localizedArchetype(String locale, Archetype archetype) {
  const values = <String, Map<String, String>>{
    'poacher': {
      'en': 'Poacher',
      'es': 'Cazagoles',
      'pt-BR': 'Finalizador',
      'fr': 'Renard des surfaces',
    },
    'targetForward': {
      'en': 'Target forward',
      'es': 'Delantero objetivo',
      'pt-BR': 'Centroavante pivô',
      'fr': 'Attaquant pivot',
    },
    'completeForward': {
      'en': 'Complete forward',
      'es': 'Delantero completo',
      'pt-BR': 'Atacante completo',
      'fr': 'Attaquant complet',
    },
    'touchlineWinger': {
      'en': 'Touchline winger',
      'es': 'Extremo de banda',
      'pt-BR': 'Ponta de linha',
      'fr': 'Ailier de débordement',
    },
    'invertedWinger': {
      'en': 'Inverted winger',
      'es': 'Extremo invertido',
      'pt-BR': 'Ponta invertido',
      'fr': 'Ailier inversé',
    },
    'wideCreator': {
      'en': 'Wide creator',
      'es': 'Creador abierto',
      'pt-BR': 'Criador aberto',
      'fr': 'Créateur excentré',
    },
    'playmaker': {
      'en': 'Playmaker',
      'es': 'Organizador',
      'pt-BR': 'Armador',
      'fr': 'Meneur de jeu',
    },
    'boxToBox': {
      'en': 'Box-to-box',
      'es': 'Todoterreno',
      'pt-BR': 'Meia de área a área',
      'fr': 'Milieu box-to-box',
    },
    'ballWinner': {
      'en': 'Ball winner',
      'es': 'Recuperador',
      'pt-BR': 'Volante marcador',
      'fr': 'Récupérateur',
    },
    'stopper': {
      'en': 'Stopper',
      'es': 'Central marcador',
      'pt-BR': 'Zagueiro de combate',
      'fr': 'Stoppeur',
    },
    'ballPlayingCentreBack': {
      'en': 'Ball-playing centre-back',
      'es': 'Central con salida',
      'pt-BR': 'Zagueiro construtor',
      'fr': 'Défenseur relanceur',
    },
    'attackingFullback': {
      'en': 'Attacking fullback',
      'es': 'Lateral ofensivo',
      'pt-BR': 'Lateral ofensivo',
      'fr': 'Latéral offensif',
    },
  };
  return values[archetype.name]?[locale] ??
      values[archetype.name]?['en'] ??
      archetype.name;
}

String localizedAgentName(String locale, String id) {
  const values = <String, Map<String, String>>{
    'agent-independent': {
      'en': 'Independent',
      'es': 'Independiente',
      'pt-BR': 'Independente',
      'fr': 'Indépendant',
    },
    'agent-player-first': {
      'en': 'Player First',
      'es': 'Jugador Primero',
      'pt-BR': 'Jogador Primeiro',
      'fr': 'Joueur d’abord',
    },
    'agent-global-network': {
      'en': 'Global Network',
      'es': 'Red Global',
      'pt-BR': 'Rede Global',
      'fr': 'Réseau mondial',
    },
    'agent-negotiator': {
      'en': 'The Negotiator',
      'es': 'El Negociador',
      'pt-BR': 'O Negociador',
      'fr': 'Le Négociateur',
    },
  };
  return values[id]?[locale] ?? values[id]?['en'] ?? id;
}

String localizedAgentDescription(String locale, AgentDefinition agent) {
  final values = switch (agent.id) {
    'agent-player-first' => {
      'en': 'Stronger personal trust, with modest market reach.',
      'es': 'Más confianza personal y un alcance de mercado modesto.',
      'pt-BR': 'Mais confiança pessoal e alcance de mercado moderado.',
      'fr': 'Plus de confiance personnelle et une portée modeste.',
    },
    'agent-global-network' => {
      'en': '+10 club interest through a wider network; lower personal trust.',
      'es': '+10 de interés de clubes por una red amplia; menor confianza personal.',
      'pt-BR': '+10 de interesse dos clubes por uma rede ampla; menos confiança pessoal.',
      'fr':
          '+10 d’intérêt club grâce au réseau ; confiance personnelle réduite.',
    },
    'agent-negotiator' => {
      'en': '+10% offered wages and +4 club interest; slightly lower trust.',
      'es': '+10 % de salario y +4 de interés; confianza algo menor.',
      'pt-BR': '+10% no salário e +4 de interesse; confiança um pouco menor.',
      'fr': '+10 % de salaire et +4 d’intérêt ; confiance légèrement réduite.',
    },
    _ => {
      'en': 'No bonuses or tradeoffs. You represent yourself.',
      'es': 'Sin ventajas ni contrapartidas. Te representas tú.',
      'pt-BR': 'Sem bônus ou contrapartidas. Você se representa.',
      'fr': 'Aucun bonus ni compromis. Vous vous représentez.',
    },
  };
  return values[locale] ?? values['en']!;
}

String localizedPromisedRole(String locale, String role) {
  const values = <String, Map<String, String>>{
    'important': {
      'en': 'important player',
      'es': 'jugador importante',
      'pt-BR': 'jogador importante',
      'fr': 'joueur important',
    },
    'rotation': {
      'en': 'rotation',
      'es': 'rotación',
      'pt-BR': 'rotação',
      'fr': 'rotation',
    },
    'prospect': {
      'en': 'prospect',
      'es': 'promesa',
      'pt-BR': 'promessa',
      'fr': 'espoir',
    },
  };
  return values[role]?[locale] ?? values[role]?['en'] ?? role;
}

String localizedTransferReason(String locale, String reason) {
  const values = <String, Map<String, String>>{
    'Your level and profile fit an immediate first-team need.': {
      'es':
          'Tu nivel y perfil cubren una necesidad inmediata del primer equipo.',
      'pt-BR': 'Seu nível e perfil atendem a uma necessidade imediata do time principal.',
      'fr': 'Votre niveau et votre profil répondent à un besoin immédiat de l’équipe première.',
    },
    'The manager believes your style fits the system.': {
      'es': 'El entrenador cree que tu estilo encaja en el sistema.',
      'pt-BR': 'O treinador acredita que seu estilo se encaixa no sistema.',
      'fr': 'L’entraîneur estime que votre style correspond au système.',
    },
    'The recruitment team sees room for you to grow.': {
      'es': 'El equipo de fichajes ve margen para que crezcas.',
      'pt-BR': 'A equipe de recrutamento vê espaço para você evoluir.',
      'fr':
          'La cellule de recrutement entrevoit votre potentiel de progression.',
    },
    'The club needs a higher current level for this role.': {
      'es': 'El club exige un nivel actual más alto para este rol.',
      'pt-BR': 'O clube exige um nível atual mais alto para esta função.',
      'fr': 'Le club exige un niveau actuel supérieur pour ce rôle.',
    },
    'Your reputation has not reached this recruitment network yet.': {
      'es': 'Tu reputación aún no ha llegado a esta red de fichajes.',
      'pt-BR': 'Sua reputação ainda não chegou a esta rede de recrutamento.',
      'fr': 'Votre réputation n’a pas encore atteint ce réseau de recrutement.',
    },
    'The manager sees a weak fit with the current system.': {
      'es': 'El entrenador ve poco encaje con el sistema actual.',
      'pt-BR': 'O treinador vê pouco encaixe com o sistema atual.',
      'fr': 'L’entraîneur voit une faible adéquation avec le système actuel.',
    },
    'The club chose a player with stronger recent form.': {
      'es': 'El club eligió a un jugador con mejor forma reciente.',
      'pt-BR': 'O clube escolheu um jogador em melhor fase recente.',
      'fr': 'Le club a choisi un joueur en meilleure forme récente.',
    },
    'Your level and profile meet an immediate first-team need.': {
      'es':
          'Tu nivel y perfil cubren una necesidad inmediata del primer equipo.',
      'pt-BR': 'Seu nível e perfil atendem a uma necessidade imediata do time principal.',
      'fr': 'Votre niveau et votre profil répondent à un besoin immédiat de l’équipe première.',
    },
    'Your form, reputation, and tactical fit cleared the club’s threshold.': {
      'es':
          'Tu forma, reputación y encaje táctico superaron el umbral del club.',
      'pt-BR':
          'Sua fase, reputação e ajuste tático superaram o limite do clube.',
      'fr': 'Votre forme, votre réputation et votre adéquation tactique ont franchi le seuil du club.',
    },
    'A second-division club offers a one-year route back through free agency.':
        {
          'es': 'Un club de segunda división ofrece una vía de regreso por un año como agente libre.',
          'pt-BR': 'Um clube da segunda divisão oferece um contrato de um ano pela agência livre.',
          'fr': 'Un club de deuxième division propose un contrat d’un an pour rebondir comme joueur libre.',
        },
  };
  if (locale == 'en') return reason;
  final direct = values[reason]?[locale];
  if (direct != null) return direct;
  for (final entry in values.entries) {
    if (!reason.startsWith(entry.key)) continue;
    final base = entry.value[locale] ?? entry.key;
    final priority = reason.contains('wage')
        ? {'es': 'salario', 'pt-BR': 'salário', 'fr': 'salaire'}[locale]!
        : reason.contains('role')
        ? {'es': 'rol', 'pt-BR': 'papel', 'fr': 'rôle'}[locale]!
        : {'es': 'duración', 'pt-BR': 'duração', 'fr': 'durée'}[locale]!;
    if (reason.contains('accepted your')) {
      return '$base ${{'es': 'El club aceptó tu petición sobre el $priority.', 'pt-BR': 'O clube aceitou seu pedido de $priority.', 'fr': 'Le club a accepté votre demande de $priority.'}[locale]}';
    }
    if (reason.contains('declined your')) {
      final leverage = RegExp(r'leverage was (\d+)')
          .firstMatch(reason)
          ?.group(1);
      return '$base ${{'es': 'El club rechazó tu petición sobre el $priority porque tu poder de negociación fue ${leverage ?? 'bajo'}.', 'pt-BR': 'O clube recusou seu pedido de $priority porque seu poder de negociação foi ${leverage ?? 'baixo'}.', 'fr': 'Le club a refusé votre demande de $priority car votre marge de négociation était de ${leverage ?? 'faible'}.'}[locale]}';
    }
  }
  return reason;
}

String localizedLegacyHeadline(String locale, LegacyTier tier) {
  const values = <LegacyTier, Map<String, String>>{
    LegacyTier.localFavorite: {
      'en': 'A career the local support will remember.',
      'es': 'Una carrera que la afición local recordará.',
      'pt-BR': 'Uma carreira que a torcida local vai lembrar.',
      'fr': 'Une carrière dont le public local se souviendra.',
    },
    LegacyTier.clubIcon: {
      'en': 'Your name belongs to the club now.',
      'es': 'Tu nombre ya forma parte del club.',
      'pt-BR': 'Seu nome agora pertence ao clube.',
      'fr': 'Votre nom appartient désormais au club.',
    },
    LegacyTier.nationalStar: {
      'en': 'You changed how a country saw the game.',
      'es': 'Cambiaste la forma en que un país veía el juego.',
      'pt-BR': 'Você mudou a forma como um país via o jogo.',
      'fr': 'Vous avez changé le regard d’un pays sur le jeu.',
    },
    LegacyTier.worldGreat: {
      'en': 'An era of football carries your signature.',
      'es': 'Una era del fútbol lleva tu firma.',
      'pt-BR': 'Uma era do futebol leva sua assinatura.',
      'fr': 'Une époque du football porte votre signature.',
    },
    LegacyTier.immortal: {
      'en': 'The game will keep telling your story.',
      'es': 'El fútbol seguirá contando tu historia.',
      'pt-BR': 'O futebol continuará contando sua história.',
      'fr': 'Le football continuera de raconter votre histoire.',
    },
  };
  return values[tier]?[locale] ?? values[tier]!['en']!;
}

String localizedLegacyTier(String locale, LegacyTier tier) {
  const values = <LegacyTier, Map<String, String>>{
    LegacyTier.localFavorite: {
      'en': 'Local favorite',
      'es': 'Favorito local',
      'pt-BR': 'Ídolo local',
      'fr': 'Favori local',
    },
    LegacyTier.clubIcon: {
      'en': 'Club icon',
      'es': 'Ídolo del club',
      'pt-BR': 'Ídolo do clube',
      'fr': 'Icône du club',
    },
    LegacyTier.nationalStar: {
      'en': 'National star',
      'es': 'Estrella nacional',
      'pt-BR': 'Estrela nacional',
      'fr': 'Star nationale',
    },
    LegacyTier.worldGreat: {
      'en': 'World great',
      'es': 'Leyenda mundial',
      'pt-BR': 'Craque mundial',
      'fr': 'Légende mondiale',
    },
    LegacyTier.immortal: {
      'en': 'Immortal',
      'es': 'Inmortal',
      'pt-BR': 'Imortal',
      'fr': 'Immortel',
    },
  };
  return values[tier]?[locale] ?? values[tier]!['en']!;
}

String localizedFactor(String locale, String value) {
  const keys = {
    'Manager trust': 'manager',
    'Manager relationship': 'managerRelationship',
    'Current form': 'form',
    'Match fitness': 'fitness',
    'Tactical fit': 'fit',
    'Player level': 'level',
    'Key attributes': 'attributes',
    'Opponent quality': 'opponent',
    'Chosen risk': 'risk',
    'Difficulty': 'difficulty',
    'Home support': 'homeSupport',
    'Away pressure': 'awayPressure',
    'Equipped lifestyle': 'equippedLifestyle',
    'Community support': 'communitySupport',
  };
  const translations = {
    'manager': {
      'en': 'Manager trust',
      'es': 'Confianza del entrenador',
      'pt-BR': 'Confiança do treinador',
      'fr': 'Confiance de l’entraîneur',
    },
    'managerRelationship': {
      'en': 'Manager relationship',
      'es': 'Relación con el entrenador',
      'pt-BR': 'Relação com o treinador',
      'fr': 'Relation avec l’entraîneur',
    },
    'form': {
      'en': 'Current form',
      'es': 'Forma actual',
      'pt-BR': 'Fase atual',
      'fr': 'Dynamique actuelle',
    },
    'fitness': {
      'en': 'Match fitness',
      'es': 'Estado físico',
      'pt-BR': 'Condição física',
      'fr': 'Condition physique',
    },
    'fit': {
      'en': 'Tactical fit',
      'es': 'Encaje táctico',
      'pt-BR': 'Encaixe tático',
      'fr': 'Compatibilité tactique',
    },
    'level': {
      'en': 'Player level',
      'es': 'Nivel del jugador',
      'pt-BR': 'Nível do jogador',
      'fr': 'Niveau du joueur',
    },
    'attributes': {
      'en': 'Key attributes',
      'es': 'Atributos clave',
      'pt-BR': 'Atributos principais',
      'fr': 'Attributs clés',
    },
    'opponent': {
      'en': 'Opponent quality',
      'es': 'Calidad del rival',
      'pt-BR': 'Qualidade do adversário',
      'fr': 'Qualité adverse',
    },
    'risk': {
      'en': 'Chosen risk',
      'es': 'Riesgo elegido',
      'pt-BR': 'Risco escolhido',
      'fr': 'Risque choisi',
    },
    'difficulty': {
      'en': 'Difficulty',
      'es': 'Dificultad',
      'pt-BR': 'Dificuldade',
      'fr': 'Difficulté',
    },
    'homeSupport': {
      'en': 'Home support',
      'es': 'Apoyo local',
      'pt-BR': 'Apoio da torcida',
      'fr': 'Soutien à domicile',
    },
    'awayPressure': {
      'en': 'Away pressure',
      'es': 'Presión visitante',
      'pt-BR': 'Pressão fora de casa',
      'fr': 'Pression à l’extérieur',
    },
    'equippedLifestyle': {
      'en': 'Equipped lifestyle',
      'es': 'Estilo de vida equipado',
      'pt-BR': 'Estilo de vida equipado',
      'fr': 'Mode de vie équipé',
    },
    'communitySupport': {
      'en': 'Community support',
      'es': 'Apoyo de la comunidad',
      'pt-BR': 'Apoio da comunidade',
      'fr': 'Soutien de la communauté',
    },
  };
  final key = keys[value];
  return key == null ? value : translations[key]?[locale] ?? value;
}

String localizedFootballNation(String locale, FootballNation nation) =>
    switch (nation) {
      FootballNation.england => 'England',
      FootballNation.spain =>
        locale == 'es'
            ? 'España'
            : locale == 'fr'
            ? 'Espagne'
            : 'Spain',
      FootballNation.france =>
        locale == 'es'
            ? 'Francia'
            : locale == 'pt-BR'
            ? 'França'
            : 'France',
      FootballNation.germany =>
        locale == 'es'
            ? 'Alemania'
            : locale == 'pt-BR'
            ? 'Alemanha'
            : locale == 'fr'
            ? 'Allemagne'
            : 'Germany',
      FootballNation.brazil => locale == 'fr' ? 'Brésil' : 'Brasil',
      FootballNation.unitedStates =>
        locale == 'fr'
            ? 'États-Unis'
            : locale == 'en'
            ? 'United States'
            : 'Estados Unidos',
    };
