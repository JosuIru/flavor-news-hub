// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Catalan Valencian (`ca`).
class AppLocalizationsCa extends AppLocalizations {
  AppLocalizationsCa([String locale = 'ca']) : super(locale);

  @override
  String get appName => 'Flavor News Hub';

  @override
  String get appTagline =>
      'Mitjans alternatius i col·lectius que s\'organitzen';

  @override
  String get tabFeed => 'Titulars';

  @override
  String get tabAudio => 'Àudio';

  @override
  String get tabRadios => 'Ràdios';

  @override
  String get tabMusic => 'Música';

  @override
  String get tabDirectory => 'Col·lectius';

  @override
  String get tabClientes => 'Clients';

  @override
  String get tabSettings => 'Ajustaments';

  @override
  String get tabTv => 'TV';

  @override
  String get tvTabMedios => 'Mitjans';

  @override
  String get tvTabUltimas => 'Últimes emissions';

  @override
  String get tvEmptyMedios =>
      'Encara no hi ha canals de TV. S\'afegiran des d\'Admin o en importar el catàleg.';

  @override
  String get tvEmptyUltimas => 'Sense emissions recents dels canals de TV.';

  @override
  String get radiosTitle => 'Ràdios lliures';

  @override
  String get radiosEmpty => 'No hi ha ràdios en aquesta instància.';

  @override
  String get radiosOnlyFavorites => 'Només les meves ràdios';

  @override
  String get radiosOnlyFavoritesEmpty => 'Encara no tens ràdios favorites.';

  @override
  String get radiosOnlyFavoritesHint =>
      'Marca les ràdios com a favorites per tenir-les a dalt.';

  @override
  String get radiosOnlyFavoritesActive =>
      'Es mostren només les teves ràdios favorites.';

  @override
  String get radiosStreamError =>
      'No s\'ha pogut connectar amb el canal. Toca per tornar-ho a provar.';

  @override
  String get videosTitle => 'Vídeos';

  @override
  String get videosEmpty =>
      'Ara mateix no hi ha vídeos. Afegeix canals de YouTube a Ajustaments → Els meus mitjans.';

  @override
  String get videosPlayNext => 'Següent vídeo';

  @override
  String get videosOnlyFavorites => 'Només els meus canals';

  @override
  String get playerSpeed => 'Velocitat';

  @override
  String get playerSleepTimer => 'Apagar en…';

  @override
  String get itemCopyLink => 'Copiar enllaç';

  @override
  String get itemLinkCopied => 'Enllaç copiat.';

  @override
  String get savedSearchHint => 'Filtra desats…';

  @override
  String get historyTitle => 'Historial de lectura';

  @override
  String get historyEmpty =>
      'Encara no has llegit cap titular. Els que obris apareixeran aquí.';

  @override
  String get settingsHistory => 'Historial';

  @override
  String get settingsHistorySubtitle => 'Titulars que has obert.';

  @override
  String get opmlExport => 'Exporta els meus mitjans (OPML)';

  @override
  String get opmlImport => 'Importa OPML…';

  @override
  String get opmlExportCopied => 'OPML copiat al porta-retalls.';

  @override
  String get opmlImportHint =>
      'Enganxa aquí el contingut OPML d\'un altre agregador.';

  @override
  String opmlImportSuccess(int count) {
    return 'Importades $count fonts.';
  }

  @override
  String get opmlImportEmpty => 'No s\'han trobat fonts vàlides a l\'OPML.';

  @override
  String get privacyPolicyTitle => 'Política de privacitat';

  @override
  String get videoDescription => 'Descripció';

  @override
  String videoOpenExternal(String platform) {
    return 'Veure a $platform';
  }

  @override
  String get videoChannelWebsite => 'Web del canal';

  @override
  String get videoPlatformYoutube => 'YouTube';

  @override
  String get videoPlatformPeertube => 'PeerTube';

  @override
  String get videoPlatformExternal => 'el navegador';

  @override
  String get videoCommentsHint =>
      'Els comentaris es veuen a la plataforma original.';

  @override
  String get feedTitle => 'Titulars';

  @override
  String get feedEmpty => 'Encara no hi ha notícies carregades.';

  @override
  String get feedEmptyWithFilters =>
      'Cap titular no coincideix amb els filtres actius. Neteja\'ls per veure-ho tot.';

  @override
  String get feedLoading => 'S\'estan carregant els titulars…';

  @override
  String get feedError => 'No s\'ha pogut carregar el canal.';

  @override
  String get filtersTitle => 'Filtres';

  @override
  String get filterByTopic => 'Per temàtica';

  @override
  String get filterTopicsOffline =>
      'Sense connexió amb el servidor: les temàtiques no estan disponibles. Torna-ho a provar quan tinguis cobertura.';

  @override
  String get filterByTerritory => 'Per territori';

  @override
  String get filterByLanguage => 'Per idioma';

  @override
  String get filtersClear => 'Buida els filtres';

  @override
  String get filtersApply => 'Aplica';

  @override
  String itemOpenInSource(String sourceName) {
    return 'Llegeix a $sourceName';
  }

  @override
  String get itemShare => 'Comparteix';

  @override
  String get itemSave => 'Desa';

  @override
  String get itemUnsave => 'Treu dels desats';

  @override
  String get itemMarkUseful => 'Marca com a útil';

  @override
  String get itemUnmarkUseful => 'Treu d\'útils';

  @override
  String get settingsTusIntereses => 'Els teus interessos';

  @override
  String get settingsTusInteresesSubtitle =>
      'Quines temàtiques i mitjans t\'estan interessant més';

  @override
  String get tusInteresesTitle => 'Els teus interessos';

  @override
  String get tusInteresesEmpty =>
      'Encara no has marcat cap titular com a útil.';

  @override
  String get tusInteresesEmptyHelp =>
      'Fes servir el botó de la bombeta (💡) a cada notícia per marcar-la útil. Aquí veuràs un resum amb les teves temàtiques i mitjans més recurrents — res no surt del dispositiu.';

  @override
  String tusInteresesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titulars marcats útils',
      one: '$count titular marcat útil',
    );
    return '$_temp0';
  }

  @override
  String get tusInteresesTopTopics => 'Temàtiques que més t\'interessen';

  @override
  String get tusInteresesTopSources => 'Mitjans que més t\'interessen';

  @override
  String get tusInteresesFormats => 'Format preferit';

  @override
  String get tusInteresesApplyFilter => 'Aplica aquestes temàtiques al feed';

  @override
  String get feedOfflineBanner =>
      'Mode autònom. Titulars descarregats directament dels mitjans.';

  @override
  String get savedTitle => 'Desats';

  @override
  String get savedSubtitle => 'Titulars que has marcat per llegir després.';

  @override
  String get savedEmpty =>
      'Encara no has desat cap titular. Des del canal o el detall, fes servir la icona del marcador.';

  @override
  String get savedTabNews => 'Titulars';

  @override
  String get savedTabAudio => 'El meu àudio';

  @override
  String get savedAudioEmpty =>
      'Encara no has marcat com a preferit cap pòdcast ni cançó. Al reproductor prem el cor.';

  @override
  String get itemOrganizingTitle => 'Qui s\'organitza al voltant d\'això?';

  @override
  String get itemOrganizingEmpty =>
      'Encara no hi ha col·lectius verificats en aquest directori per a aquestes temàtiques. Si el teu col·lectiu hi encaixa, pots donar-lo d\'alta.';

  @override
  String get itemOrganizingSeeAll => 'Vés-hi tots';

  @override
  String get sourceTitle => 'Mitjà';

  @override
  String get sourceListNews => 'Veure les notícies d\'aquest mitjà';

  @override
  String get sourceListVideos => 'Veure vídeos d\'aquest canal';

  @override
  String get sourceListAudio => 'Veure episodis d\'aquest podcast';

  @override
  String get tabPodcasts => 'Podcasts';

  @override
  String get podcastsEmpty =>
      'Encara no hi ha episodis. Els mitjans del directori amb feed_type=podcast apareixen aquí quan publiquen.';

  @override
  String get sourceEditorialHeader => 'Fitxa editorial';

  @override
  String get sourceOwnership => 'Propietat i finançament';

  @override
  String get sourceEditorialNote => 'Línia editorial declarada';

  @override
  String get sourceLegalNote => 'Context legal';

  @override
  String get sourceTerritory => 'Territori';

  @override
  String get sourceLanguages => 'Idiomes';

  @override
  String get sourceWebsite => 'Web';

  @override
  String get directoryTitle => 'Col·lectius';

  @override
  String get colectivosTabNoticias => 'Moviments';

  @override
  String get colectivosTabDirectorio => 'Directori';

  @override
  String get directoryEmpty =>
      'Encara no hi ha col·lectius verificats en aquesta instància.';

  @override
  String get directoryAddCta => 'El teu col·lectiu no hi és? Afegeix-lo';

  @override
  String get collectiveVisitWebsite => 'Visita la web';

  @override
  String get collectiveFlavorCommunity => 'Comunitat a Flavor';

  @override
  String get collectiveShare => 'Comparteix';

  @override
  String get collectiveMediaTitle => 'Mitjans que edita';

  @override
  String get collectiveMediaEmpty =>
      'Aquest col·lectiu no té mitjans vinculats.';

  @override
  String get submitTitle => 'Dóna d\'alta un col·lectiu';

  @override
  String get submitName => 'Nom del col·lectiu';

  @override
  String get submitDescription => 'Descripció';

  @override
  String get submitWebsite => 'Web (opcional)';

  @override
  String get submitContactEmail => 'Correu de contacte';

  @override
  String get submitTerritory => 'Territori (opcional)';

  @override
  String get submitFlavorUrl => 'URL de la seva instància Flavor (opcional)';

  @override
  String get submitTopics => 'Temàtiques en què treballa';

  @override
  String get submitSend => 'Envia';

  @override
  String get submitSuccess =>
      'Gràcies. Revisarem l\'alta i apareixerà al directori un cop verificada.';

  @override
  String get submitErrorGeneric =>
      'No s\'ha pogut enviar l\'alta. Torna-ho a provar més tard.';

  @override
  String get submitErrorRateLimited =>
      'Massa peticions des d\'aquesta connexió. Prova-ho d\'aquí una estona.';

  @override
  String get submitRequiredName => 'El nom és obligatori.';

  @override
  String get submitRequiredDescription => 'La descripció és obligatòria.';

  @override
  String get submitRequiredEmail => 'Cal un correu de contacte vàlid.';

  @override
  String get settingsTitle => 'Ajustaments';

  @override
  String get settingsInterfaceLanguage => 'Idioma de la interfície';

  @override
  String get settingsInterfaceLanguageSystem => 'Segueix el sistema';

  @override
  String get settingsMyTerritory => 'El meu territori';

  @override
  String get settingsMyTerritorySubtitle =>
      'Des d\'aquí, els continguts propers apareixen primer. Els globals continuen visibles sota.';

  @override
  String get settingsMyTerritoryNone =>
      'Sense territori (mostrar-ho tot igual)';

  @override
  String get settingsMyTerritoryChoose => 'Tria el teu territori base';

  @override
  String get settingsContentLanguage => 'Idioma del contingut';

  @override
  String get settingsContentLanguageSubtitle =>
      'Decideix quins idiomes vols veure en titulars, vídeos, ràdios i podcasts.';

  @override
  String get settingsContentLanguageFollowUi =>
      'Seguir l\'idioma de la interfície';

  @override
  String get settingsContentLanguageManual => 'Triar-ne diversos manualment';

  @override
  String get settingsContentLanguageOff => 'Mostrar tots els idiomes';

  @override
  String get settingsContentLanguageManualHint =>
      'Marca els idiomes que vols. Buit = sense filtre.';

  @override
  String get supportEntity => 'Donar';

  @override
  String get movimientosTitle => 'Veus de moviments';

  @override
  String get movimientosSubtitle =>
      'Mitjans petits i col·lectius les publicacions dels quals queden tapades al feed general pels agregadors prolífics.';

  @override
  String get movimientosEmpty =>
      'Encara no hi ha publicacions de moviments. Tornaran quan els mitjans marcats publiquin.';

  @override
  String get movimientosEmptyHint =>
      'Si aquesta llista no s\'omple mai, pot ser que la teva instància encara no tingui mitjans marcats com a veu de moviment. L\'admin pot activar-los des del panell.';

  @override
  String get settingsMovimientos => 'Veus de moviments';

  @override
  String get settingsMovimientosSubtitle =>
      'Secció dedicada a mitjans i col·lectius petits o militants.';

  @override
  String get shareAppMessage =>
      'Flavor News Hub — Una app, tots els mitjans alternatius\n\nQuè hi trobaràs:\n• Titulars de mitjans alternatius (es/eu/ca/gl), ordenats per data. Sense algorisme.\n• Vídeos i canals de TV lliures.\n• Ràdios en directe i podcasts.\n• Música lliure (Funkwhale, Audius, Jamendo, Archive.org).\n• Directori de col·lectius i mapa per trobar-los.\n• Sense publicitat, sense rastreig, sense compte.\n\nInstal·lació a Android:\n1. Toca l\\\'enllaç per baixar l\\\'APK:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. El navegador t\\\'avisarà que el fitxer \"pot danyar el teu dispositiu\". Pulsa \"Conserva\" (o \"Baixa igualment\").\n3. Obre l\\\'APK baixat. La primera vegada Android et demanarà permís perquè el teu navegador instal·li apps des de fonts desconegudes — concedeix-lo.\n4. És possible que aparegui un altre avís de Google Play Protect del tipus \"aquesta app no s\\\'ha verificat\" o \"pot ser perillosa\". Pulsa \"Instal·la igualment\" (o \"Més detalls\" → \"Instal·la igualment\").\n5. Llest. Obre l\\\'app.\n\nPer què surten aquests avisos: Android marca com a \"no verificada\" qualsevol app que no vingui de Google Play, encara que sigui codi obert i auditable. Flavor News Hub és lliure (AGPL-3.0), tot el codi és a GitHub i no envia telemetria — els avisos són la política per defecte d\\\'Android, no un problema real de l\\\'app.\n\nCodi obert · AGPL-3.0';

  @override
  String get onboardingTerritoryTitle => 'Del local al global';

  @override
  String get onboardingTerritoryBody =>
      'Tria el teu territori perquè allò proper aparegui primer. La resta continua visible sota — no s\'amaga res. Ho pots canviar sempre a Ajustaments.';

  @override
  String get onboardingTerritorySkip => 'Saltar';

  @override
  String get onboardingTerritoryConfirm => 'Usar aquest territori';

  @override
  String get settingsTheme => 'Tema';

  @override
  String get settingsThemeSystem => 'Segueix el sistema';

  @override
  String get settingsThemeLight => 'Clar';

  @override
  String get settingsThemeDark => 'Fosc';

  @override
  String get settingsTextScale => 'Mida del text';

  @override
  String get settingsBackendUrl => 'URL de la instància';

  @override
  String get settingsBackendUrlDescription =>
      'Si ho canvies, l\'app consumirà dades d\'una altra instància de Flavor News Hub.';

  @override
  String get settingsAbout => 'Quant a';

  @override
  String get settingsCheckUpdate => 'Comprovar actualitzacions';

  @override
  String get settingsCheckUpdateSubtitle =>
      'Força la comprovació ara, saltant la memòria cau.';

  @override
  String get settingsCheckUpdateChecking => 'Comprovant…';

  @override
  String get settingsCheckUpdateUpToDate => 'Ja tens la darrera versió.';

  @override
  String settingsCheckUpdateAvailable(String version) {
    return 'Hi ha una nova versió disponible ($version).';
  }

  @override
  String get settingsCheckUpdateError =>
      'No s\'ha pogut comprovar ara. Prova-ho d\'aquí una estona.';

  @override
  String get settingsAdvanced => 'Avançat';

  @override
  String get settingsVersion => 'Versió';

  @override
  String get settingsProposeSource => 'Proposa un mitjà';

  @override
  String get settingsProposeSourceSubtitle =>
      'Trobes a faltar un mitjà alternatiu? Suggereix-lo per a revisió.';

  @override
  String get settingsMyMedia => 'Els meus mitjans';

  @override
  String get settingsMyMediaSubtitle =>
      'Els teus propis canals RSS, pòdcast o vídeo. Només al teu telèfon.';

  @override
  String get settingsShareApp => 'Comparteix l\'app';

  @override
  String get settingsShareAppSubtitle =>
      'Passa-la a qui creguis que li pot servir.';

  @override
  String get settingsNotifications => 'Notificacions';

  @override
  String get settingsNotificationsSubtitle =>
      'Avís quan hi hagi titulars, vídeos o podcasts nous.';

  @override
  String get notifTitle => 'Notificacions de contingut nou';

  @override
  String get notifHelp =>
      'L\'app comprova en segon pla si hi ha titulars, vídeos o podcasts nous i t\'avisa. Sense servidors push ni seguiment — tot al dispositiu.';

  @override
  String get notifFreqNever => 'Desactivades';

  @override
  String get notifFreqHour => 'Cada hora';

  @override
  String get notifFreq3h => 'Cada 3 hores';

  @override
  String get notifFreq6h => 'Cada 6 hores';

  @override
  String get notifFreq12h => 'Cada 12 hores';

  @override
  String get notifFreq24h => 'Un cop al dia';

  @override
  String get notifPermissionDenied =>
      'Has denegat el permís de notificacions. L\'app continuarà comprovant en background però no podrà avisar-te fins que el concedeixis a Ajustes del sistema.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapSubtitle => 'Ràdios i col·lectius per territori.';

  @override
  String get settingsSourcesPrefs => 'Els meus mitjans del directori';

  @override
  String get settingsSourcesPrefsSubtitle =>
      'Silencia fonts que no vols veure al canal.';

  @override
  String get sourcesPrefsTitle => 'Els meus mitjans del directori';

  @override
  String get sourcesPrefsHelp =>
      'Desactiva les fonts que no vulguis veure. Els titulars deixen d\'aparèixer al canal; altres usuaris els seguiran rebent.';

  @override
  String get sourcesPrefsEmpty => 'Encara no hi ha fonts curades.';

  @override
  String get sourcesPrefsResetAll => 'Reactivar-les totes';

  @override
  String get sourcesCategoryAll => 'Totes';

  @override
  String get sourcesCategoryPress => 'Premsa';

  @override
  String get sourcesCategoryAudio => 'Àudio';

  @override
  String get sourcesCategoryVideo => 'Vídeo';

  @override
  String get sourcesCategoryFediverse => 'Fedivers';

  @override
  String get donationsTitle => 'Dona un cop de mà al projecte';

  @override
  String get donationsIntro =>
      'Flavor News Hub és lliure i sense publicitat. Si et resulta útil, així és com el pots sostenir.';

  @override
  String get donationsKofi => 'Convida\'ns a un cafè puntual';

  @override
  String get donationsPaypal => 'Donació directa';

  @override
  String get donationsBitcoinSegwit => 'Bitcoin (Native SegWit)';

  @override
  String get donationsBitcoinTaproot => 'Bitcoin (Taproot)';

  @override
  String get donationsCopyAddress => 'Copia l\'adreça';

  @override
  String get donationsAddressCopied => 'Adreça copiada al porta-retalls';

  @override
  String get donationsShare => 'Comparteix el projecte';

  @override
  String get donationsShareHelp =>
      'Recomanar-lo a algú també és una forma d\'ajudar — creix per humans, no per algoritme.';

  @override
  String get donationsShareAction => 'Compartir';

  @override
  String get donationsShareMessage =>
      'Flavor News Hub: app de notícies federada, sense algoritme ni publicitat.';

  @override
  String get donationsOtherWays => 'Altres formes d\'ajudar';

  @override
  String get donationsHelpStar => 'Dóna-li un estel a GitHub';

  @override
  String get donationsHelpBug => 'Informa d\'errors o suggereix millores';

  @override
  String get donationsHelpTranslate => 'Ajuda amb les traduccions';

  @override
  String get donationsHelpContribute => 'Contribueix amb codi o documentació';

  @override
  String get ecosistemaTitle => 'Part de l\'ecosistema Col·lecció del Nou Ser';

  @override
  String get ecosistemaSubtitle => 'Visita coleccion-nuevo-ser.gailu.net';

  @override
  String updateTitle(String version) {
    return 'Nova versió $version disponible';
  }

  @override
  String get updateBodyGeneric =>
      'Hi ha una actualització disponible. Descarrega-la per tenir les darreres novetats.';

  @override
  String get updateDownload => 'Descarrega';

  @override
  String get updateDismiss => 'Ara no';

  @override
  String get updateDownloadingTitle => 'Descarregant actualització';

  @override
  String get updateDownloadingIndeterminate => 'Preparant…';

  @override
  String get updateDownloadFallback =>
      'No s\'ha pogut descarregar des de l\'app. S\'obre al navegador.';

  @override
  String get updateInstallFallback =>
      'No s\'ha pogut obrir l\'instal·lador. S\'obre al navegador.';

  @override
  String get settingsMusic => 'Música lliure';

  @override
  String get settingsMusicSubtitle =>
      'Cerca i escolta música federada des de Funkwhale.';

  @override
  String get musicInstanceLabel => 'Instància Funkwhale';

  @override
  String get musicInstanceHelp =>
      'Enganxa l\'URL d\'una instància pública (p. ex. https://open.audio/).';

  @override
  String get musicInstancePrompt =>
      'Per escoltar, afegeix almenys una instància Funkwhale.';

  @override
  String get musicInstanceCurrent => 'Instància';

  @override
  String get musicInstancesLabel => 'Instàncies Funkwhale';

  @override
  String get musicInstancesHelp =>
      'Pots afegir-ne diverses. La cerca consulta totes en paral·lel.';

  @override
  String get jamendoLabel => 'Jamendo';

  @override
  String get jamendoHelp =>
      'Catàleg Creative Commons. Aconsegueix un client_id gratuït i enganxa\'l aquí.';

  @override
  String get jamendoGetKey => 'Aconseguir client_id';

  @override
  String get musicSearchHint => 'Cerca cançó, artista o àlbum…';

  @override
  String get musicSearchPrompt => 'Escriu per cercar música federada.';

  @override
  String get musicGenresHeader => 'Gèneres';

  @override
  String get musicNewHeader => 'Novetats';

  @override
  String get musicNewEmpty => 'No hi ha novetats ara mateix.';

  @override
  String get personalSourcesTitle => 'Els meus mitjans';

  @override
  String get personalSourcesEmpty => 'Encara no has afegit cap mitjà propi.';

  @override
  String get personalSourcesEmptyHelp =>
      'Els mitjans que afegeixis aquí es queden al teu telèfon i els seus titulars es barregen al canal principal.';

  @override
  String get personalSourcesAdd => 'Afegeix';

  @override
  String get personalSourcesAddAction => 'Afegeix';

  @override
  String get personalSourcesRemove => 'Elimina';

  @override
  String get personalSourcesRemoveTitle => 'Eliminar aquest mitjà?';

  @override
  String get personalSourcesFieldName => 'Nom';

  @override
  String get personalSourcesFieldUrl => 'URL del canal';

  @override
  String get personalSourcesFieldUrlHelp =>
      'RSS/Atom del mitjà. YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. Pòdcast: l\'URL del canal del programa.';

  @override
  String get personalSourcesFieldType => 'Tipus';

  @override
  String get personalSourcesRequiredUrl => 'Cal l\'URL del canal.';

  @override
  String get personalSourcesInvalidUrl =>
      'Ha de començar per http:// o https:// i incloure un domini.';

  @override
  String get personalSourcesAddedSnackbar =>
      'Mitjà afegit. Refresca el canal per veure\'n els titulars.';

  @override
  String get personalSourcesAlreadyExists =>
      'Aquest canal ja és a la teva llista.';

  @override
  String get personalSourcesExport => 'Copia la llista al porta-retalls';

  @override
  String get personalSourcesImport => 'Enganxa la llista des del porta-retalls';

  @override
  String get personalSourcesExportedSnackbar =>
      'Llista copiada al porta-retalls.';

  @override
  String get personalSourcesImportEmpty => 'El porta-retalls és buit.';

  @override
  String get personalSourcesImportInvalid =>
      'El contingut del porta-retalls no és una llista vàlida.';

  @override
  String personalSourcesImportedSnackbar(int count) {
    return 'Importades $count fonts.';
  }

  @override
  String get personalSourcesNote =>
      'Els titulars d\'aquests mitjans es descarreguen directament des del teu telèfon a cada refresc. Res es comparteix amb el servidor.';

  @override
  String get personalSourcesCategoryReading => 'Lectura';

  @override
  String get personalSourcesCategoryAudio => 'Àudio';

  @override
  String get personalSourcesCategoryVideo => 'Vídeo';

  @override
  String get personalSourcesDiscoverFeed => 'Cerca el canal automàticament';

  @override
  String get personalSourcesDiscoverNothing =>
      'No hem trobat cap canal en aquesta URL. Enganxa-la directament si la coneixes.';

  @override
  String get personalSourcesDiscoverPickerTitle => 'Hem trobat diversos canals';

  @override
  String get sourceSubmitTitle => 'Proposa un mitjà';

  @override
  String get sourceSubmitIntro =>
      'Suggereix un mitjà (web, podcast, canal de vídeo, compte de Mastodon…). L\'equip editorial el revisarà abans d\'activar-lo.';

  @override
  String get sourceSubmitName => 'Nom del mitjà';

  @override
  String get sourceSubmitFeedUrl => 'URL del canal';

  @override
  String get sourceSubmitFeedUrlHelp =>
      'RSS/Atom: enganxa l\'URL del feed. YouTube: enganxa l\'URL del canal, el resolem en verificar.';

  @override
  String get sourceSubmitFeedType => 'Tipus de canal';

  @override
  String get sourceSubmitDescription => 'Descripció (opcional)';

  @override
  String get sourceSubmitWebsiteUrl => 'Web del mitjà (opcional)';

  @override
  String get sourceSubmitTerritory => 'Territori (opcional)';

  @override
  String get sourceSubmitLanguages => 'Idiomes del contingut';

  @override
  String get sourceSubmitEmailHelp =>
      'No es publica; només es fa servir si l\'equip ha de contactar.';

  @override
  String get sourceSubmitSuccess =>
      'Gràcies. Revisarem la proposta i el mitjà apareixerà un cop verificat.';

  @override
  String get sourceSubmitRequiredFeedUrl => 'Cal l\'URL del feed.';

  @override
  String get sourceSubmitInvalidFeedUrl =>
      'L\'URL del feed ha de començar per http:// o https://';

  @override
  String get aboutTitle => 'Quant a';

  @override
  String get aboutManifestoHeader => 'Què és això';

  @override
  String get aboutManifestoBody =>
      'Una eina senzilla per trencar el cicle entre informar-se i actuar. Sense algorisme d\'engagement, sense tracking, sense publicitat. AGPL-3.0.';

  @override
  String get aboutRepository => 'Repositori';

  @override
  String get aboutLicense => 'Llicència';

  @override
  String get commonBack => 'Torna';

  @override
  String get commonRetry => 'Reintenta';

  @override
  String get commonClose => 'Tanca';

  @override
  String get commonCancel => 'Cancel·la';

  @override
  String get commonOk => 'D\'acord';

  @override
  String get searchTooltip => 'Cerca';

  @override
  String get searchHint => 'Cerca a notícies, mitjans, ràdios…';

  @override
  String get searchPromptHint => 'Escriu per cercar a tota l\'app.';

  @override
  String get searchNoResults => 'Cap resultat.';

  @override
  String get searchSectionItems => 'Notícies';

  @override
  String get searchSectionSources => 'Mitjans';

  @override
  String get searchSectionRadios => 'Ràdios';

  @override
  String get searchSectionCollectives => 'Col·lectius';

  @override
  String get radioWebsite => 'Web';

  @override
  String get radioPrograms => 'Programes';

  @override
  String get radioProgramsEmpty => 'No hi ha programes al feed.';

  @override
  String get radioProgramsFetchError =>
      'No s\'ha pogut carregar el feed de programes.';

  @override
  String get flavorActivityHeader => 'Activitat a Flavor';

  @override
  String get flavorActivityEvents => 'Esdeveniments';

  @override
  String get flavorActivityContent => 'Catàleg';

  @override
  String get flavorActivityBoard => 'Tauler';

  @override
  String get flavorActivityEmpty =>
      'Aquest node no publica activitat pública ara mateix.';

  @override
  String get settingsErrorReport => 'Comparteix l\'informe d\'error';

  @override
  String get settingsErrorReportSubtitle =>
      'S\'ha registrat una fallada recent. Comparteix-la per ajudar a arreglar-la; no s\'envia res sol.';

  @override
  String get settingsErrorReportDismiss => 'Descarta l\'informe';

  @override
  String get commonUndo => 'Desfés';

  @override
  String get feedItemSaved => 'Desat';

  @override
  String get feedItemMarkedUseful => 'Marcat com a útil';

  @override
  String get sourceMuted => 'Font silenciada';
}
