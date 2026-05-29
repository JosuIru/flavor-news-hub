// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Galician (`gl`).
class AppLocalizationsGl extends AppLocalizations {
  AppLocalizationsGl([String locale = 'gl']) : super(locale);

  @override
  String get appName => 'Flavor News Hub';

  @override
  String get appTagline => 'Medios alternativos e colectivos que se organizan';

  @override
  String get tabFeed => 'Titulares';

  @override
  String get tabAudio => 'Audio';

  @override
  String get tabRadios => 'Radios';

  @override
  String get tabMusic => 'Música';

  @override
  String get tabDirectory => 'Colectivos';

  @override
  String get tabClientes => 'Clientes';

  @override
  String get tabSettings => 'Axustes';

  @override
  String get tabTv => 'TV';

  @override
  String get tvTabMedios => 'Medios';

  @override
  String get tvTabUltimas => 'Últimas emisións';

  @override
  String get tvEmptyMedios =>
      'Aínda non hai canles de TV. Engadiranse dende Admin ou ao importar o catálogo.';

  @override
  String get tvEmptyUltimas => 'Sen emisións recentes das canles de TV.';

  @override
  String get radiosTitle => 'Radios libres';

  @override
  String get radiosEmpty => 'Non hai radios nesta instancia.';

  @override
  String get radiosOnlyFavorites => 'Só as miñas radios';

  @override
  String get radiosOnlyFavoritesEmpty => 'Aínda non tes radios favoritas.';

  @override
  String get radiosOnlyFavoritesHint =>
      'Marca radios como favoritas para telos arriba.';

  @override
  String get radiosOnlyFavoritesActive =>
      'Amósanse só as túas radios favoritas.';

  @override
  String get radiosStreamError =>
      'Non se puido conectar co stream. Toca para reintentar.';

  @override
  String get videosTitle => 'Vídeos';

  @override
  String get videosEmpty =>
      'Agora mesmo non hai vídeos. Engade canles de YouTube dende Axustes → Os meus medios.';

  @override
  String get videosPlayNext => 'Seguinte vídeo';

  @override
  String get videosOnlyFavorites => 'Só as miñas canles';

  @override
  String get playerSpeed => 'Velocidade';

  @override
  String get playerSleepTimer => 'Apagar en…';

  @override
  String get itemCopyLink => 'Copiar ligazón';

  @override
  String get itemLinkCopied => 'Ligazón copiada.';

  @override
  String get savedSearchHint => 'Filtra gardados…';

  @override
  String get historyTitle => 'Historial de lectura';

  @override
  String get historyEmpty => 'Aínda non abriches ningún titular.';

  @override
  String get settingsHistory => 'Historial';

  @override
  String get settingsHistorySubtitle => 'Titulares que abriches.';

  @override
  String get opmlExport => 'Exportar os meus medios (OPML)';

  @override
  String get opmlImport => 'Importar OPML…';

  @override
  String get opmlExportCopied => 'OPML copiado ao portapapeis.';

  @override
  String get opmlImportHint => 'Pega aquí o contido OPML doutro agregador.';

  @override
  String opmlImportSuccess(int count) {
    return 'Importadas $count fontes.';
  }

  @override
  String get opmlImportEmpty => 'Non se atoparon fontes válidas no OPML.';

  @override
  String get privacyPolicyTitle => 'Política de privacidade';

  @override
  String get videoDescription => 'Descrición';

  @override
  String videoOpenExternal(String platform) {
    return 'Ver en $platform';
  }

  @override
  String get videoChannelWebsite => 'Web da canle';

  @override
  String get videoPlatformYoutube => 'YouTube';

  @override
  String get videoPlatformPeertube => 'PeerTube';

  @override
  String get videoPlatformExternal => 'o navegador';

  @override
  String get videoCommentsHint =>
      'Os comentarios vense na plataforma orixinal.';

  @override
  String get feedTitle => 'Titulares';

  @override
  String get feedEmpty => 'Aínda non hai novas cargadas.';

  @override
  String get feedEmptyWithFilters =>
      'Ningún titular coincide cos filtros activos. Límpaos para ver todo.';

  @override
  String get feedLoading => 'Cargando titulares…';

  @override
  String get feedError => 'Non se puido cargar a canle.';

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filterByTopic => 'Por temática';

  @override
  String get filterTopicsOffline =>
      'Sen conexión co servidor: as temáticas non están dispoñibles. Téntao de novo cando teñas cobertura.';

  @override
  String get filterByTerritory => 'Por territorio';

  @override
  String get filterByLanguage => 'Por idioma';

  @override
  String get filtersClear => 'Limpar filtros';

  @override
  String get filtersApply => 'Aplicar';

  @override
  String itemOpenInSource(String sourceName) {
    return 'Ler en $sourceName';
  }

  @override
  String get itemShare => 'Compartir';

  @override
  String get itemSave => 'Gardar';

  @override
  String get itemUnsave => 'Quitar de gardados';

  @override
  String get itemMarkUseful => 'Marcar como útil';

  @override
  String get itemUnmarkUseful => 'Quitar de útiles';

  @override
  String get settingsTusIntereses => 'Os teus intereses';

  @override
  String get settingsTusInteresesSubtitle =>
      'Que temáticas e medios che están a interesar máis';

  @override
  String get tusInteresesTitle => 'Os teus intereses';

  @override
  String get tusInteresesEmpty =>
      'Aínda non marcaches ningún titular como útil.';

  @override
  String get tusInteresesEmptyHelp =>
      'Usa o botón da lámpada (💡) en cada nova para marcala útil. Aquí verás un resumo coas túas temáticas e medios máis recorrentes — nada viaxa ao servidor.';

  @override
  String tusInteresesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titulares marcados útiles',
      one: '$count titular marcado útil',
    );
    return '$_temp0';
  }

  @override
  String get tusInteresesTopTopics => 'Temáticas que máis che interesan';

  @override
  String get tusInteresesTopSources => 'Medios que máis che interesan';

  @override
  String get tusInteresesFormats => 'Formato preferido';

  @override
  String get tusInteresesApplyFilter => 'Aplicar estas temáticas ao feed';

  @override
  String get feedOfflineBanner =>
      'Modo autónomo. Titulares descargados directos dos medios.';

  @override
  String get savedTitle => 'Gardados';

  @override
  String get savedSubtitle => 'Titulares que marcaches para ler despois.';

  @override
  String get savedEmpty =>
      'Aínda non gardaches ningún titular. Dende o feed ou dende o detalle, usa a icona do marcador.';

  @override
  String get savedTabNews => 'Titulares';

  @override
  String get savedTabAudio => 'O meu audio';

  @override
  String get savedAudioEmpty =>
      'Aínda non marcaches como favorito ningún podcast nin canción. No reprodutor preme o corazón.';

  @override
  String get itemOrganizingTitle => 'Quen se organiza sobre isto?';

  @override
  String get itemOrganizingEmpty =>
      'Aínda non hai colectivos verificados neste directorio sobre estas temáticas. Se o teu colectivo encaixa, podes dalo de alta.';

  @override
  String get itemOrganizingSeeAll => 'Ver todos';

  @override
  String get sourceTitle => 'Medio';

  @override
  String get sourceListNews => 'Ver novas deste medio';

  @override
  String get sourceListVideos => 'Ver vídeos desta canle';

  @override
  String get sourceListAudio => 'Ver episodios deste podcast';

  @override
  String get tabPodcasts => 'Podcasts';

  @override
  String get podcastsEmpty =>
      'Aínda non hai episodios. Os medios do directorio con feed_type=podcast aparecerán aquí cando publiquen.';

  @override
  String get sourceEditorialHeader => 'Ficha editorial';

  @override
  String get sourceOwnership => 'Propiedade e financiamento';

  @override
  String get sourceEditorialNote => 'Liña editorial declarada';

  @override
  String get sourceLegalNote => 'Contexto legal';

  @override
  String get sourceTerritory => 'Territorio';

  @override
  String get sourceLanguages => 'Idiomas';

  @override
  String get sourceWebsite => 'Web';

  @override
  String get directoryTitle => 'Colectivos';

  @override
  String get colectivosTabNoticias => 'Movementos';

  @override
  String get colectivosTabDirectorio => 'Directorio';

  @override
  String get directoryEmpty =>
      'Aínda non hai colectivos verificados nesta instancia.';

  @override
  String get directoryAddCta => 'O teu colectivo non está aquí? Engádeo';

  @override
  String get collectiveVisitWebsite => 'Visitar web';

  @override
  String get collectiveFlavorCommunity => 'Comunidade en Flavor';

  @override
  String get collectiveShare => 'Compartir';

  @override
  String get collectiveMediaTitle => 'Medios que edita';

  @override
  String get collectiveMediaEmpty =>
      'Este colectivo non ten medios vinculados.';

  @override
  String get submitTitle => 'Dar de alta un colectivo';

  @override
  String get submitName => 'Nome do colectivo';

  @override
  String get submitDescription => 'Descrición';

  @override
  String get submitWebsite => 'Web (opcional)';

  @override
  String get submitContactEmail => 'Email de contacto';

  @override
  String get submitTerritory => 'Territorio (opcional)';

  @override
  String get submitFlavorUrl => 'URL da súa instancia Flavor (opcional)';

  @override
  String get submitTopics => 'Temáticas nas que traballa';

  @override
  String get submitSend => 'Enviar';

  @override
  String get submitSuccess =>
      'Grazas. Revisaremos a túa alta e aparecerá no directorio cando estea verificada.';

  @override
  String get submitErrorGeneric =>
      'Non puidemos enviar a alta. Inténtao máis tarde.';

  @override
  String get submitErrorRateLimited =>
      'Demasiadas peticións desde esta conexión. Proba nun anaco.';

  @override
  String get submitRequiredName => 'O nome é obrigatorio.';

  @override
  String get submitRequiredDescription => 'A descrición é obrigatoria.';

  @override
  String get submitRequiredEmail => 'Fai falta un email de contacto válido.';

  @override
  String get settingsTitle => 'Axustes';

  @override
  String get settingsInterfaceLanguage => 'Idioma da interface';

  @override
  String get settingsInterfaceLanguageSystem => 'Seguir sistema';

  @override
  String get settingsMyTerritory => 'O meu territorio';

  @override
  String get settingsMyTerritorySubtitle =>
      'Desde aquí, os contidos próximos aparecen primeiro. Os globais seguen visibles debaixo.';

  @override
  String get settingsMyTerritoryNone => 'Sen territorio (amosar todo igual)';

  @override
  String get settingsMyTerritoryChoose => 'Escolle o teu territorio base';

  @override
  String get settingsContentLanguage => 'Idioma do contido';

  @override
  String get settingsContentLanguageSubtitle =>
      'Decide que idiomas queres ver en titulares, vídeos, radios e podcasts.';

  @override
  String get settingsContentLanguageFollowUi => 'Seguir o idioma da interface';

  @override
  String get settingsContentLanguageManual => 'Escoller varios manualmente';

  @override
  String get settingsContentLanguageOff => 'Amosar todos os idiomas';

  @override
  String get settingsContentLanguageManualHint =>
      'Marca os idiomas que queres. Baleiro = sen filtro.';

  @override
  String get supportEntity => 'Apoiar';

  @override
  String get movimientosTitle => 'Voces de movementos';

  @override
  String get movimientosSubtitle =>
      'Medios pequenos e colectivos cuxas publicacións quedan tapadas no feed xeral polos agregadores prolíficos.';

  @override
  String get movimientosEmpty =>
      'Aínda non hai publicacións de movementos. Volverán cando os medios marcados publiquen.';

  @override
  String get movimientosEmptyHint =>
      'Se esta lista nunca se enche, pode que a túa instancia aínda non teña medios marcados como voz de movemento. O admin pode activalos desde o panel.';

  @override
  String get settingsMovimientos => 'Voces de movementos';

  @override
  String get settingsMovimientosSubtitle =>
      'Sección dedicada a medios e colectivos pequenos ou militantes.';

  @override
  String get shareAppMessage =>
      'Flavor News Hub — Unha app, todos os medios alternativos\n\nQue atoparás:\n• Titulares de medios alternativos (es/eu/ca/gl), ordenados por data. Sen algoritmo.\n• Vídeos e canles de TV libres.\n• Radios en directo e podcasts.\n• Música libre (Funkwhale, Audius, Jamendo, Archive.org).\n• Directorio de colectivos e mapa para atopalos.\n• Sen publicidade, sen seguimento, sen conta.\n\nInstalación en Android:\n1. Toca a ligazón para descargar o APK:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. O navegador avisarate de que o ficheiro \"podería danar o teu dispositivo\". Preme \"Conservar\" (ou \"Descargar igualmente\").\n3. Abre o APK descargado. A primeira vez Android pedirache permiso para que o teu navegador instale apps desde fontes descoñecidas — concédeo.\n4. É posible que apareza outro aviso de Google Play Protect do tipo \"esta app non se verificou\" ou \"pode ser perigosa\". Preme \"Instalar igualmente\" (ou \"Máis detalles\" → \"Instalar igualmente\").\n5. Listo. Abre a app.\n\nPor que aparecen eses avisos: Android marca como \"non verificada\" calquera app que non veña de Google Play, aínda que sexa código aberto e auditable. Flavor News Hub é libre (AGPL-3.0), todo o código está en GitHub e non envía telemetría — os avisos son a política predeterminada de Android, non un problema real da app.\n\nCódigo aberto · AGPL-3.0';

  @override
  String get onboardingTerritoryTitle => 'Do local ao global';

  @override
  String get onboardingTerritoryBody =>
      'Escolle o teu territorio para que o próximo apareza primeiro. O resto segue visible debaixo — non se agocha nada. Podes cambialo sempre en Axustes.';

  @override
  String get onboardingTerritorySkip => 'Saltar';

  @override
  String get onboardingTerritoryConfirm => 'Usar este territorio';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Seguir sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsTextScale => 'Tamaño do texto';

  @override
  String get settingsBackendUrl => 'URL da instancia';

  @override
  String get settingsBackendUrlDescription =>
      'Se o cambias, a app consumirá os datos doutra instancia de Flavor News Hub.';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsCheckUpdate => 'Comprobar actualizacións';

  @override
  String get settingsCheckUpdateSubtitle =>
      'Forzar comprobación agora saltando a caché.';

  @override
  String get settingsCheckUpdateChecking => 'Comprobando…';

  @override
  String get settingsCheckUpdateUpToDate => 'Xa tes a última versión.';

  @override
  String settingsCheckUpdateAvailable(String version) {
    return 'Hai unha nova versión dispoñible ($version).';
  }

  @override
  String get settingsCheckUpdateError =>
      'Non se puido comprobar agora. Téntao de novo máis tarde.';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get settingsProposeSource => 'Propor un medio';

  @override
  String get settingsProposeSourceSubtitle =>
      'Bótase de menos un medio alternativo? Propóno para revisión.';

  @override
  String get settingsMyMedia => 'Os meus medios';

  @override
  String get settingsMyMediaSubtitle =>
      'As túas propias fontes RSS, pódcast ou canles de vídeo. Só no teu teléfono.';

  @override
  String get settingsShareApp => 'Compartir a app';

  @override
  String get settingsShareAppSubtitle => 'Pásaa a quen poida serlle útil.';

  @override
  String get settingsNotifications => 'Notificacións';

  @override
  String get settingsNotificationsSubtitle =>
      'Aviso cando haxa novos titulares, vídeos ou podcasts.';

  @override
  String get notifTitle => 'Notificacións de contido novo';

  @override
  String get notifHelp =>
      'A app verifica en segundo plano se hai novos titulares, vídeos ou podcasts e avísate. Sen servidores push nin seguimento — todo no dispositivo.';

  @override
  String get notifFreqNever => 'Desactivadas';

  @override
  String get notifFreqHour => 'Cada hora';

  @override
  String get notifFreq3h => 'Cada 3 horas';

  @override
  String get notifFreq6h => 'Cada 6 horas';

  @override
  String get notifFreq12h => 'Cada 12 horas';

  @override
  String get notifFreq24h => 'Unha vez ao día';

  @override
  String get notifPermissionDenied =>
      'Denegaches o permiso de notificacións. A app seguirá comprobando en background pero non poderá avisarte até que o concedas nos Axustes do sistema.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapSubtitle => 'Radios e colectivos por territorio.';

  @override
  String get settingsSourcesPrefs => 'Os meus medios do directorio';

  @override
  String get settingsSourcesPrefsSubtitle =>
      'Silencia fontes que non queiras ver no feed.';

  @override
  String get sourcesPrefsTitle => 'Os meus medios do directorio';

  @override
  String get sourcesPrefsHelp =>
      'Desactiva as fontes que non queiras ver. Os titulares deixan de aparecer no teu feed; outros usuarios seguirán recibíndoos.';

  @override
  String get sourcesPrefsEmpty => 'Aínda non hai fontes curadas.';

  @override
  String get sourcesPrefsResetAll => 'Reactivar todas';

  @override
  String get sourcesCategoryAll => 'Todas';

  @override
  String get sourcesCategoryPress => 'Prensa';

  @override
  String get sourcesCategoryAudio => 'Audio';

  @override
  String get sourcesCategoryVideo => 'Vídeo';

  @override
  String get sourcesCategoryFediverse => 'Fediverso';

  @override
  String get donationsTitle => 'Apoia o proxecto';

  @override
  String get donationsIntro =>
      'Flavor News Hub é libre e sen publicidade. Se che é útil, estas son as formas de sostelo.';

  @override
  String get donationsKofi => 'Convida a un café puntual';

  @override
  String get donationsPaypal => 'Doazón directa';

  @override
  String get donationsBitcoinSegwit => 'Bitcoin (Native SegWit)';

  @override
  String get donationsBitcoinTaproot => 'Bitcoin (Taproot)';

  @override
  String get donationsCopyAddress => 'Copiar enderezo';

  @override
  String get donationsAddressCopied => 'Enderezo copiado ao portapapeis';

  @override
  String get donationsShare => 'Comparte o proxecto';

  @override
  String get donationsShareHelp =>
      'Recomendar a alguén tamén é axudar — crece por humanos, non por algoritmo.';

  @override
  String get donationsShareAction => 'Compartir';

  @override
  String get donationsShareMessage =>
      'Flavor News Hub: app de novas federada, sen algoritmo nin publicidade.';

  @override
  String get donationsOtherWays => 'Outras formas de axudar';

  @override
  String get donationsHelpStar => 'Dálle unha estrela en GitHub';

  @override
  String get donationsHelpBug => 'Reporta bugs ou suxire melloras';

  @override
  String get donationsHelpTranslate => 'Axuda coas traducións';

  @override
  String get donationsHelpContribute => 'Contribúe con código ou documentación';

  @override
  String get ecosistemaTitle => 'Parte do ecosistema Colección del Nuevo Ser';

  @override
  String get ecosistemaSubtitle => 'Visita coleccion-nuevo-ser.gailu.net';

  @override
  String updateTitle(String version) {
    return 'Nova versión $version dispoñible';
  }

  @override
  String get updateBodyGeneric =>
      'Hai unha actualización dispoñible. Descárgaa para ter as últimas novidades.';

  @override
  String get updateDownload => 'Descargar';

  @override
  String get updateDismiss => 'Agora non';

  @override
  String get updateDownloadingTitle => 'Descargando actualización';

  @override
  String get updateDownloadingIndeterminate => 'Preparando…';

  @override
  String get updateDownloadFallback =>
      'Non se puido descargar dentro da app. Abríndoo no navegador.';

  @override
  String get updateInstallFallback =>
      'Non se puido abrir o instalador. Abríndoo no navegador.';

  @override
  String get settingsMusic => 'Música libre';

  @override
  String get settingsMusicSubtitle =>
      'Busca e escoita música federada dende Funkwhale.';

  @override
  String get musicInstanceLabel => 'Instancia Funkwhale';

  @override
  String get musicInstanceHelp =>
      'Pega a URL dunha instancia pública (p. ex. https://open.audio/).';

  @override
  String get musicInstancePrompt =>
      'Para escoitar, engade polo menos unha instancia Funkwhale.';

  @override
  String get musicInstanceCurrent => 'Instancia';

  @override
  String get musicInstancesLabel => 'Instancias Funkwhale';

  @override
  String get musicInstancesHelp =>
      'Podes engadir varias. A busca consulta todas en paralelo.';

  @override
  String get jamendoLabel => 'Jamendo';

  @override
  String get jamendoHelp =>
      'Catálogo Creative Commons. Consegue un client_id gratuíto e pégao aquí.';

  @override
  String get jamendoGetKey => 'Conseguir client_id';

  @override
  String get musicSearchHint => 'Buscar canción, artista ou álbum…';

  @override
  String get musicSearchPrompt => 'Escribe para buscar música federada.';

  @override
  String get musicGenresHeader => 'Xéneros';

  @override
  String get musicNewHeader => 'Novidades';

  @override
  String get musicNewEmpty => 'Non hai novidades agora mesmo.';

  @override
  String get personalSourcesTitle => 'Os meus medios';

  @override
  String get personalSourcesEmpty =>
      'Aínda non engadiches ningún medio propio.';

  @override
  String get personalSourcesEmptyHelp =>
      'Os medios que engadas aquí quedan no teu teléfono e os seus titulares mestúranse co feed principal.';

  @override
  String get personalSourcesAdd => 'Engadir';

  @override
  String get personalSourcesAddAction => 'Engadir';

  @override
  String get personalSourcesRemove => 'Eliminar';

  @override
  String get personalSourcesRemoveTitle => 'Eliminar este medio?';

  @override
  String get personalSourcesFieldName => 'Nome';

  @override
  String get personalSourcesFieldUrl => 'URL da canle';

  @override
  String get personalSourcesFieldUrlHelp =>
      'RSS/Atom do medio. YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. Pódcast: a URL da canle do programa.';

  @override
  String get personalSourcesFieldType => 'Tipo';

  @override
  String get personalSourcesRequiredUrl => 'Fai falta a URL da canle.';

  @override
  String get personalSourcesInvalidUrl =>
      'Debe comezar por http:// ou https:// e ter dominio.';

  @override
  String get personalSourcesAddedSnackbar =>
      'Medio engadido. Refresca o feed para ver os titulares.';

  @override
  String get personalSourcesAlreadyExists => 'Esa canle xa está na túa lista.';

  @override
  String get personalSourcesExport => 'Copiar lista ao portapapeis';

  @override
  String get personalSourcesImport => 'Pegar lista dende o portapapeis';

  @override
  String get personalSourcesExportedSnackbar => 'Lista copiada ao portapapeis.';

  @override
  String get personalSourcesImportEmpty => 'O portapapeis está baleiro.';

  @override
  String get personalSourcesImportInvalid =>
      'O contido do portapapeis non é unha lista válida.';

  @override
  String personalSourcesImportedSnackbar(int count) {
    return 'Importáronse $count fontes.';
  }

  @override
  String get personalSourcesNote =>
      'Os titulares destes medios descárganse directamente dende o teu teléfono en cada refresco. Non se comparte nada co servidor.';

  @override
  String get personalSourcesCategoryReading => 'Lectura';

  @override
  String get personalSourcesCategoryAudio => 'Audio';

  @override
  String get personalSourcesCategoryVideo => 'Vídeo';

  @override
  String get personalSourcesDiscoverFeed => 'Buscar canle automaticamente';

  @override
  String get personalSourcesDiscoverNothing =>
      'Non atopamos ningunha canle nesa URL. Pégaa directamente se a coñeces.';

  @override
  String get personalSourcesDiscoverPickerTitle => 'Atopamos varias canles';

  @override
  String get sourceSubmitTitle => 'Propor un medio';

  @override
  String get sourceSubmitIntro =>
      'Propón un medio (web, podcast, canle de vídeo, conta de Mastodon…). O equipo editorial revisarao antes de activalo.';

  @override
  String get sourceSubmitName => 'Nome do medio';

  @override
  String get sourceSubmitFeedUrl => 'URL da canle';

  @override
  String get sourceSubmitFeedUrlHelp =>
      'RSS/Atom: pega a URL do feed. YouTube: pega a URL da canle, resolvémola ao verificar.';

  @override
  String get sourceSubmitFeedType => 'Tipo de canle';

  @override
  String get sourceSubmitDescription => 'Descrición (opcional)';

  @override
  String get sourceSubmitWebsiteUrl => 'Web do medio (opcional)';

  @override
  String get sourceSubmitTerritory => 'Territorio (opcional)';

  @override
  String get sourceSubmitLanguages => 'Idiomas do contido';

  @override
  String get sourceSubmitEmailHelp =>
      'Non se publica; só se usa se o equipo necesita contactar contigo.';

  @override
  String get sourceSubmitSuccess =>
      'Grazas. Revisaremos a proposta e o medio aparecerá unha vez verificado.';

  @override
  String get sourceSubmitRequiredFeedUrl => 'Fai falta a URL do feed.';

  @override
  String get sourceSubmitInvalidFeedUrl =>
      'A URL do feed debe comezar por http:// ou https://';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutManifestoHeader => 'Que é isto';

  @override
  String get aboutManifestoBody =>
      'Unha ferramenta sinxela para romper o circuíto entre informarse e actuar. Sen algoritmo de engagement, sen tracking, sen publicidade. AGPL-3.0.';

  @override
  String get aboutRepository => 'Repositorio';

  @override
  String get aboutLicense => 'Licenza';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Pechar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get searchTooltip => 'Buscar';

  @override
  String get searchHint => 'Buscar en novas, medios, radios…';

  @override
  String get searchPromptHint => 'Escribe para buscar en toda a app.';

  @override
  String get searchNoResults => 'Sen resultados.';

  @override
  String get searchSectionItems => 'Novas';

  @override
  String get searchSectionSources => 'Medios';

  @override
  String get searchSectionRadios => 'Radios';

  @override
  String get searchSectionCollectives => 'Colectivos';

  @override
  String get radioWebsite => 'Web';

  @override
  String get radioPrograms => 'Programas';

  @override
  String get radioProgramsEmpty => 'Non hai programas no feed.';

  @override
  String get radioProgramsFetchError =>
      'Non se puido cargar o feed de programas.';

  @override
  String get flavorActivityHeader => 'Actividade en Flavor';

  @override
  String get flavorActivityEvents => 'Eventos';

  @override
  String get flavorActivityContent => 'Catálogo';

  @override
  String get flavorActivityBoard => 'Taboleiro';

  @override
  String get flavorActivityEmpty =>
      'Este nodo non publica actividade pública agora mesmo.';

  @override
  String get settingsErrorReport => 'Compartir informe de erro';

  @override
  String get settingsErrorReportSubtitle =>
      'Rexistrouse un fallo recente. Compárteo para axudar a arranxalo; non se envía nada só.';

  @override
  String get settingsErrorReportDismiss => 'Descartar informe';

  @override
  String feedOrganizingCardTitle(String tema) {
    return 'Quen se organiza sobre $tema?';
  }

  @override
  String get feedOrganizingCardCta => 'Ver colectivos';

  @override
  String get commonUndo => 'Desfacer';

  @override
  String get feedItemSaved => 'Gardado';

  @override
  String get feedItemMarkedUseful => 'Marcado como útil';

  @override
  String get sourceMuted => 'Fonte silenciada';
}
