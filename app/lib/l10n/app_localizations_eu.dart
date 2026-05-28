// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Basque (`eu`).
class AppLocalizationsEu extends AppLocalizations {
  AppLocalizationsEu([String locale = 'eu']) : super(locale);

  @override
  String get appName => 'Flavor News Hub';

  @override
  String get appTagline =>
      'Hedabide alternatiboak eta antolatzen diren kolektiboak';

  @override
  String get tabFeed => 'Titularrak';

  @override
  String get tabAudio => 'Audioa';

  @override
  String get tabRadios => 'Irratiak';

  @override
  String get tabMusic => 'Musika';

  @override
  String get tabDirectory => 'Kolektiboak';

  @override
  String get tabClientes => 'Bezeroak';

  @override
  String get tabSettings => 'Ezarpenak';

  @override
  String get tabTv => 'TB';

  @override
  String get tvTabMedios => 'Hedabideak';

  @override
  String get tvTabUltimas => 'Azken emisioak';

  @override
  String get tvEmptyMedios =>
      'Oraindik ez dago TB kanalik. Adminetik edo katalogoa inportatuz gehituko dira.';

  @override
  String get tvEmptyUltimas => 'TB kanaletatik ez dago azken emisiorik.';

  @override
  String get radiosTitle => 'Irrati libreak';

  @override
  String get radiosEmpty => 'Ez dago irratirik instantzia honetan.';

  @override
  String get radiosOnlyFavorites => 'Nire irratiak soilik';

  @override
  String get radiosOnlyFavoritesEmpty => 'Oraindik ez duzu irrati gogokorik.';

  @override
  String get radiosOnlyFavoritesHint =>
      'Markatu irratiak gogoko gisa goian edukitzeko.';

  @override
  String get radiosOnlyFavoritesActive =>
      'Zure irrati gogokoak bakarrik erakusten dira.';

  @override
  String get radiosStreamError =>
      'Ezin izan da jariora konektatu. Ukitu berriro saiatzeko.';

  @override
  String get videosTitle => 'Bideoak';

  @override
  String get videosEmpty =>
      'Orain ez dago bideorik. Gehitu YouTube kanalak Ezarpenak → Nire hedabideak atalean.';

  @override
  String get videosPlayNext => 'Hurrengo bideoa';

  @override
  String get videosOnlyFavorites => 'Nire kanalak soilik';

  @override
  String get playerSpeed => 'Abiadura';

  @override
  String get playerSleepTimer => 'Itzali gero…';

  @override
  String get itemCopyLink => 'Kopiatu esteka';

  @override
  String get itemLinkCopied => 'Esteka kopiatuta.';

  @override
  String get savedSearchHint => 'Iragazi gordetakoak…';

  @override
  String get historyTitle => 'Irakurketa-historia';

  @override
  String get historyEmpty => 'Ez duzu titularrik ireki oraindik.';

  @override
  String get settingsHistory => 'Historia';

  @override
  String get settingsHistorySubtitle => 'Ireki dituzun titularrak.';

  @override
  String get opmlExport => 'Esportatu nire hedabideak (OPML)';

  @override
  String get opmlImport => 'Inportatu OPML…';

  @override
  String get opmlExportCopied => 'OPML arbelera kopiatuta.';

  @override
  String get opmlImportHint =>
      'Itsatsi hemen beste agregatzaile baten OPML edukia.';

  @override
  String opmlImportSuccess(int count) {
    return '$count iturri inportatuta.';
  }

  @override
  String get opmlImportEmpty => 'Ez da OPML-n iturri baliodunik aurkitu.';

  @override
  String get privacyPolicyTitle => 'Pribatutasun-politika';

  @override
  String get videoDescription => 'Deskribapena';

  @override
  String videoOpenExternal(String platform) {
    return 'Ikusi $platform-en';
  }

  @override
  String get videoChannelWebsite => 'Kanalaren webgunea';

  @override
  String get videoPlatformYoutube => 'YouTube';

  @override
  String get videoPlatformPeertube => 'PeerTube';

  @override
  String get videoPlatformExternal => 'nabigatzailea';

  @override
  String get videoCommentsHint =>
      'Iruzkinak jatorrizko plataforman ikus daitezke.';

  @override
  String get feedTitle => 'Titularrak';

  @override
  String get feedEmpty => 'Oraindik ez dago kargatutako albisterik.';

  @override
  String get feedEmptyWithFilters =>
      'Ez dago iragazki aktiboekin bat datorren titularrik. Garbitu denak ikusteko.';

  @override
  String get feedLoading => 'Titularrak kargatzen…';

  @override
  String get feedError => 'Ezin izan da jarioa kargatu.';

  @override
  String get filtersTitle => 'Iragazkiak';

  @override
  String get filterByTopic => 'Gaiaren arabera';

  @override
  String get filterTopicsOffline =>
      'Zerbitzariarekin konexiorik ez: gaiak ez daude eskuragarri. Saiatu berriro estaldura duzunean.';

  @override
  String get filterByTerritory => 'Lurraldearen arabera';

  @override
  String get filterByLanguage => 'Hizkuntzaren arabera';

  @override
  String get filtersClear => 'Garbitu iragazkiak';

  @override
  String get filtersApply => 'Aplikatu';

  @override
  String itemOpenInSource(String sourceName) {
    return 'Irakurri $sourceName-en';
  }

  @override
  String get itemShare => 'Partekatu';

  @override
  String get itemSave => 'Gorde';

  @override
  String get itemUnsave => 'Kendu gordeetatik';

  @override
  String get itemMarkUseful => 'Markatu baliagarri gisa';

  @override
  String get itemUnmarkUseful => 'Kendu baliagarrietatik';

  @override
  String get settingsTusIntereses => 'Zure interesak';

  @override
  String get settingsTusInteresesSubtitle =>
      'Zein gai eta hedabide ari zaizkizun interesatzen gehien';

  @override
  String get tusInteresesTitle => 'Zure interesak';

  @override
  String get tusInteresesEmpty =>
      'Oraindik ez duzu titularrik baliagarri gisa markatu.';

  @override
  String get tusInteresesEmptyHelp =>
      'Erabili bonbilla botoia (💡) albiste bakoitzean baliagarri gisa markatzeko. Hemen zure gai eta hedabide errekurrenteenen laburpena ikusiko duzu — ezer ez da zerbitzarira bidaltzen.';

  @override
  String tusInteresesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count titular baliagarri gisa markatuta',
      one: '$count titular baliagarri gisa markatuta',
    );
    return '$_temp0';
  }

  @override
  String get tusInteresesTopTopics => 'Gehien interesatzen zaizkizun gaiak';

  @override
  String get tusInteresesTopSources =>
      'Gehien interesatzen zaizkizun hedabideak';

  @override
  String get tusInteresesFormats => 'Formatu gogokoena';

  @override
  String get tusInteresesApplyFilter => 'Aplikatu gai hauek jariora';

  @override
  String get feedOfflineBanner =>
      'Modu autonomoa. Titularrak hedabideengandik zuzenean deskargatuta.';

  @override
  String get savedTitle => 'Gordeak';

  @override
  String get savedSubtitle => 'Gero irakurtzeko markatu dituzun titularrak.';

  @override
  String get savedEmpty =>
      'Oraindik ez duzu titularrik gorde. Jariotik edo xehetasunetik markatzailearen ikonoa erabili.';

  @override
  String get savedTabNews => 'Titularrak';

  @override
  String get savedTabAudio => 'Nire audioa';

  @override
  String get savedAudioEmpty =>
      'Oraindik ez duzu podcast edo abestirik gogokoetan gorde. Erreproduzitzailean bihotza sakatu.';

  @override
  String get itemOrganizingTitle => 'Nor ari da horren inguruan antolatzen?';

  @override
  String get itemOrganizingEmpty =>
      'Oraindik ez dago kolektibo egiaztaturik gai hauentzako. Zure kolektiboa sartzen bada, alta eman dezakezu.';

  @override
  String get itemOrganizingSeeAll => 'Ikusi guztiak';

  @override
  String get sourceTitle => 'Hedabidea';

  @override
  String get sourceListNews => 'Ikusi hedabide honen albisteak';

  @override
  String get sourceListVideos => 'Ikusi kanal honen bideoak';

  @override
  String get sourceListAudio => 'Ikusi podcast honen atalak';

  @override
  String get tabPodcasts => 'Podcastak';

  @override
  String get podcastsEmpty =>
      'Oraindik ez dago atalik. Direktorioko hedabideek feed_type=podcast bezala argitaratzen dutenean agertuko dira hemen.';

  @override
  String get sourceEditorialHeader => 'Fitxa editoriala';

  @override
  String get sourceOwnership => 'Jabetza eta finantzaketa';

  @override
  String get sourceEditorialNote => 'Adierazitako lerro editoriala';

  @override
  String get sourceLegalNote => 'Testuinguru legala';

  @override
  String get sourceTerritory => 'Lurraldea';

  @override
  String get sourceLanguages => 'Hizkuntzak';

  @override
  String get sourceWebsite => 'Webgunea';

  @override
  String get directoryTitle => 'Kolektiboak';

  @override
  String get colectivosTabNoticias => 'Mugimenduak';

  @override
  String get colectivosTabDirectorio => 'Direktorioa';

  @override
  String get directoryEmpty =>
      'Oraindik ez dago egiaztatutako kolektiborik instantzia honetan.';

  @override
  String get directoryAddCta => 'Zure kolektiboa ez dago? Gehitu';

  @override
  String get collectiveVisitWebsite => 'Bisitatu webgunea';

  @override
  String get collectiveFlavorCommunity => 'Komunitatea Flavor-en';

  @override
  String get collectiveShare => 'Partekatu';

  @override
  String get collectiveMediaTitle => 'Editatzen duen hedabideak';

  @override
  String get collectiveMediaEmpty =>
      'Kolektibo honek ez du hedabide loturarik.';

  @override
  String get submitTitle => 'Kolektibo bat eman alta';

  @override
  String get submitName => 'Kolektiboaren izena';

  @override
  String get submitDescription => 'Deskribapena';

  @override
  String get submitWebsite => 'Webgunea (aukerakoa)';

  @override
  String get submitContactEmail => 'Harremanetarako e-posta';

  @override
  String get submitTerritory => 'Lurraldea (aukerakoa)';

  @override
  String get submitFlavorUrl => 'Haien Flavor instantziaren URLa (aukerakoa)';

  @override
  String get submitTopics => 'Zein gaietan lan egiten duten';

  @override
  String get submitSend => 'Bidali';

  @override
  String get submitSuccess =>
      'Eskerrik asko. Alta berrikusiko dugu eta egiaztatutakoan direktorioan agertuko da.';

  @override
  String get submitErrorGeneric =>
      'Ezin izan da alta bidali. Saiatu berriro geroago.';

  @override
  String get submitErrorRateLimited =>
      'Konexio honetatik eskaera gehiegi. Saiatu berriro beranduago.';

  @override
  String get submitRequiredName => 'Izena derrigorrezkoa da.';

  @override
  String get submitRequiredDescription => 'Deskribapena derrigorrezkoa da.';

  @override
  String get submitRequiredEmail =>
      'Harremanetarako e-posta baliagarria behar da.';

  @override
  String get settingsTitle => 'Ezarpenak';

  @override
  String get settingsInterfaceLanguage => 'Interfazearen hizkuntza';

  @override
  String get settingsInterfaceLanguageSystem => 'Sistemari jarraitu';

  @override
  String get settingsMyTerritory => 'Nire lurraldea';

  @override
  String get settingsMyTerritorySubtitle =>
      'Hemendik gertu dagoena lehenengo agertzen da. Mundu mailakoa behean ikusgai segitzen du.';

  @override
  String get settingsMyTerritoryNone =>
      'Lurralderik gabe (dena berdin erakutsi)';

  @override
  String get settingsMyTerritoryChoose => 'Aukeratu zure oinarrizko lurraldea';

  @override
  String get settingsContentLanguage => 'Edukiaren hizkuntza';

  @override
  String get settingsContentLanguageSubtitle =>
      'Erabaki zer hizkuntzatan ikusi nahi dituzun titularrak, bideoak, irratiak eta podcastak.';

  @override
  String get settingsContentLanguageFollowUi =>
      'Interfazearen hizkuntzari jarraitu';

  @override
  String get settingsContentLanguageManual => 'Hainbat eskuz aukeratu';

  @override
  String get settingsContentLanguageOff => 'Hizkuntza guztiak erakutsi';

  @override
  String get settingsContentLanguageManualHint =>
      'Markatu nahi dituzun hizkuntzak. Hutsik = iragazkirik gabe.';

  @override
  String get supportEntity => 'Babestu';

  @override
  String get movimientosTitle => 'Mugimenduen ahotsak';

  @override
  String get movimientosSubtitle =>
      'Hedabide txikiak eta kolektiboak, beren argitalpenak feed orokorrean sortzaile prolifikoek estaltzen dituztenak.';

  @override
  String get movimientosEmpty =>
      'Oraindik ez dago mugimenduen argitalpenik. Markatutako hedabideek argitaratzean agertuko dira.';

  @override
  String get movimientosEmptyHint =>
      'Zerrenda hau inoiz betetzen ez bada, agian zure instantziak ez du oraindik mugimenduen ahots gisa markatutako hedabiderik. Administratzaileak panelean aktiba ditzake.';

  @override
  String get settingsMovimientos => 'Mugimenduen ahotsak';

  @override
  String get settingsMovimientosSubtitle =>
      'Hedabide eta kolektibo txiki edo militanteentzako atal berezia.';

  @override
  String get shareAppMessage =>
      'Flavor News Hub — Aplikazio bakarra, hedabide alternatibo guztiak\n\nZer aurkituko duzu:\n• Hedabide alternatiboen titularrak (es/eu/ca/gl), datatik ordenatuak. Algoritmorik gabe.\n• Bideoak eta telebista kate libreak.\n• Irrati zuzena eta podcastak.\n• Musika librea (Funkwhale, Audius, Jamendo, Archive.org).\n• Antolatutako kolektiboen direktorioa eta mapa.\n• Iragarkirik gabe, jarraipenik gabe, konturik gabe.\n\nAndroid-en instalatzea:\n1. Sakatu esteka APK-a deskargatzeko:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. Nabigatzaileak abisatuko dizu fitxategiak \"zure gailua kalte dezakeela\". Sakatu \"Gorde\" (edo \"Deskargatu hala ere\").\n3. Ireki deskargatutako APK-a. Lehen aldiz, Androidek baimena eskatuko dizu zure nabigatzaileari iturri ezezagunetatik aplikazioak instalatzeko — eman baimena.\n4. Baliteke Google Play Protect-en beste abisu bat agertzea \"aplikazio hau ez da egiaztatu\" edo \"arriskutsua izan daiteke\" motakoa. Sakatu \"Instalatu hala ere\" (edo \"Xehetasun gehiago\" → \"Instalatu hala ere\").\n5. Listo. Ireki aplikazioa.\n\nZergatik agertzen dira abisu horiek: Androidek \"egiaztatu gabea\" gisa markatzen du Google Playtik datorrena ez den edozein aplikazio, kode irekikoa eta auditagarria izan arren. Flavor News Hub librea da (AGPL-3.0), kode guztia GitHub-en dago eta ez du telemetriarik bidaltzen — abisuak Androiden lehenetsitako politika dira, ez aplikazioaren benetako arazoa.\n\nKode irekia · AGPL-3.0';

  @override
  String get onboardingTerritoryTitle => 'Lokaletik globalera';

  @override
  String get onboardingTerritoryBody =>
      'Aukeratu zure lurraldea, gertukoa lehenengo ager dadin. Gainerakoa azpian ikusgai segitzen du — ez da ezer ezkutatzen. Ezarpenetatik alda dezakezu edonoiz.';

  @override
  String get onboardingTerritorySkip => 'Saltatu';

  @override
  String get onboardingTerritoryConfirm => 'Lurralde hau erabili';

  @override
  String get settingsTheme => 'Itxura';

  @override
  String get settingsThemeSystem => 'Sistemari jarraitu';

  @override
  String get settingsThemeLight => 'Argia';

  @override
  String get settingsThemeDark => 'Iluna';

  @override
  String get settingsTextScale => 'Testu-tamaina';

  @override
  String get settingsBackendUrl => 'Instantziaren URLa';

  @override
  String get settingsBackendUrlDescription =>
      'Hau aldatuz gero, aplikazioak beste Flavor News Hub instantzia batetik jasoko ditu datuak.';

  @override
  String get settingsAbout => 'Honi buruz';

  @override
  String get settingsCheckUpdate => 'Eguneratzeak begiratu';

  @override
  String get settingsCheckUpdateSubtitle =>
      'Behartu orain egiaztatzea, cachea alde batera utzita.';

  @override
  String get settingsCheckUpdateChecking => 'Begiratzen…';

  @override
  String get settingsCheckUpdateUpToDate => 'Azken bertsioa duzu jada.';

  @override
  String settingsCheckUpdateAvailable(String version) {
    return 'Bertsio berri bat dago eskuragarri ($version).';
  }

  @override
  String get settingsCheckUpdateError =>
      'Ezin izan da orain egiaztatu. Saiatu geroago.';

  @override
  String get settingsAdvanced => 'Aurreratua';

  @override
  String get settingsVersion => 'Bertsioa';

  @override
  String get settingsProposeSource => 'Hedabide bat proposatu';

  @override
  String get settingsProposeSourceSubtitle =>
      'Hedabide alternatiboren bat falta zaizu? Proposa ezazu berrikusteko.';

  @override
  String get settingsMyMedia => 'Nire hedabideak';

  @override
  String get settingsMyMediaSubtitle =>
      'Zure RSS, podcast edo bideo-kanalak. Telefonoan bakarrik.';

  @override
  String get settingsShareApp => 'Partekatu aplikazioa';

  @override
  String get settingsShareAppSubtitle =>
      'Pasa erabilgarri egin dakiokeen jendeari.';

  @override
  String get settingsNotifications => 'Jakinarazpenak';

  @override
  String get settingsNotificationsSubtitle =>
      'Abisua titular, bideo edo podcast berriak daudenean.';

  @override
  String get notifTitle => 'Eduki berrien jakinarazpenak';

  @override
  String get notifHelp =>
      'App-ak bigarren planoan begiratzen du titular, bideo edo podcast berriak daude eta jakinarazten dizu. Push zerbitzaririk gabe, jarraipenik gabe — dena gailuan.';

  @override
  String get notifFreqNever => 'Desaktibatuta';

  @override
  String get notifFreqHour => 'Orduro';

  @override
  String get notifFreq3h => '3 orduz behin';

  @override
  String get notifFreq6h => '6 orduz behin';

  @override
  String get notifFreq12h => '12 orduz behin';

  @override
  String get notifFreq24h => 'Egunean behin';

  @override
  String get notifPermissionDenied =>
      'Jakinarazpenen baimena ukatu duzu. Aplikazioak bigarren mailan egiaztatzen jarraituko du, baina ezin izango zaitu jakinarazi sistemaren Ezarpenetan baimena ematen ez duzun arte.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapSubtitle => 'Irratiak eta kolektiboak lurraldeka.';

  @override
  String get settingsSourcesPrefs => 'Direktorioko nire hedabideak';

  @override
  String get settingsSourcesPrefsSubtitle =>
      'Isildu jarioan ikusi nahi ez dituzun iturriak.';

  @override
  String get sourcesPrefsTitle => 'Direktorioko nire hedabideak';

  @override
  String get sourcesPrefsHelp =>
      'Desaktibatu ikusi nahi ez dituzun iturriak. Titularrak ez dira zure jarioan agertuko, baina beste erabiltzaileek jaso egingo dituzte.';

  @override
  String get sourcesPrefsEmpty => 'Oraindik ez dago iturri komisariaturik.';

  @override
  String get sourcesPrefsResetAll => 'Denak berriz gaitu';

  @override
  String get sourcesCategoryAll => 'Denak';

  @override
  String get sourcesCategoryPress => 'Prentsa';

  @override
  String get sourcesCategoryAudio => 'Audioa';

  @override
  String get sourcesCategoryVideo => 'Bideoa';

  @override
  String get sourcesCategoryFediverse => 'Fedibertsoa';

  @override
  String get donationsTitle => 'Lagundu proiektuari';

  @override
  String get donationsIntro =>
      'Flavor News Hub librea eta publizitaterik gabea da. Baliagarria bazaizu, horra hor bizirik eusteko moduak.';

  @override
  String get donationsKofi => 'Gonbidatu kafe bat';

  @override
  String get donationsPaypal => 'Dohaintza zuzena';

  @override
  String get donationsBitcoinSegwit => 'Bitcoin (Native SegWit)';

  @override
  String get donationsBitcoinTaproot => 'Bitcoin (Taproot)';

  @override
  String get donationsCopyAddress => 'Kopiatu helbidea';

  @override
  String get donationsAddressCopied => 'Helbidea arbelera kopiatu da';

  @override
  String get donationsShare => 'Partekatu proiektua';

  @override
  String get donationsShareHelp =>
      'Norbaiti gomendatzea ere laguntzeko modu bat da — gizakiez hazten da, ez algoritmoz.';

  @override
  String get donationsShareAction => 'Partekatu';

  @override
  String get donationsShareMessage =>
      'Flavor News Hub: albiste-app federatua, algoritmorik gabe, publizitaterik gabe.';

  @override
  String get donationsOtherWays => 'Laguntzeko beste era batzuk';

  @override
  String get donationsHelpStar => 'Eman izar bat GitHub-en';

  @override
  String get donationsHelpBug => 'Jakinarazi akatsak edo iradoki hobekuntzak';

  @override
  String get donationsHelpTranslate => 'Lagundu itzulpenekin';

  @override
  String get donationsHelpContribute =>
      'Lagundu kodearekin edo dokumentazioarekin';

  @override
  String get ecosistemaTitle => 'Colección del Nuevo Ser ekosistemaren parte';

  @override
  String get ecosistemaSubtitle => 'Bisitatu coleccion-nuevo-ser.gailu.net';

  @override
  String updateTitle(String version) {
    return '$version bertsio berria eskuragarri';
  }

  @override
  String get updateBodyGeneric =>
      'Eguneratzea eskuragarri dago. Deskargatu azken hobekuntzak izateko.';

  @override
  String get updateDownload => 'Deskargatu';

  @override
  String get updateDismiss => 'Orain ez';

  @override
  String get updateDownloadingTitle => 'Eguneratzea deskargatzen';

  @override
  String get updateDownloadingIndeterminate => 'Prestatzen…';

  @override
  String get updateDownloadFallback =>
      'Ezin izan da aplikazioan deskargatu. Nabigatzailean irekitzen.';

  @override
  String get updateInstallFallback =>
      'Ezin izan da instalatzailea ireki. Nabigatzailean irekitzen.';

  @override
  String get settingsMusic => 'Musika librea';

  @override
  String get settingsMusicSubtitle =>
      'Bilatu eta entzun Funkwhale-tik etorritako musika federatua.';

  @override
  String get musicInstanceLabel => 'Funkwhale instantzia';

  @override
  String get musicInstanceHelp =>
      'Itsatsi instantzia publiko baten URLa (adib. https://open.audio/).';

  @override
  String get musicInstancePrompt =>
      'Entzuteko, gehitu behintzat Funkwhale instantzia bat.';

  @override
  String get musicInstanceCurrent => 'Instantzia';

  @override
  String get musicInstancesLabel => 'Funkwhale instantziak';

  @override
  String get musicInstancesHelp =>
      'Hainbat gehi ditzakezu. Bilaketak denak aldi berean kontsultatzen ditu.';

  @override
  String get jamendoLabel => 'Jamendo';

  @override
  String get jamendoHelp =>
      'Creative Commons katalogoa. Lortu doako client_id bat eta itsatsi hemen.';

  @override
  String get jamendoGetKey => 'Lortu client_id';

  @override
  String get musicSearchHint => 'Bilatu kantua, artista edo albuma…';

  @override
  String get musicSearchPrompt => 'Idatzi musika federatua bilatzeko.';

  @override
  String get musicGenresHeader => 'Generoak';

  @override
  String get musicNewHeader => 'Azken igoerak';

  @override
  String get musicNewEmpty => 'Ez dago berritasunik oraintxe.';

  @override
  String get personalSourcesTitle => 'Nire hedabideak';

  @override
  String get personalSourcesEmpty => 'Oraindik ez duzu hedabiderik erantsi.';

  @override
  String get personalSourcesEmptyHelp =>
      'Hemen erantsitako hedabideak zure telefonoan gordetzen dira eta euren titularrak jario nagusiarekin nahasten dira.';

  @override
  String get personalSourcesAdd => 'Gehitu';

  @override
  String get personalSourcesAddAction => 'Gehitu';

  @override
  String get personalSourcesRemove => 'Kendu';

  @override
  String get personalSourcesRemoveTitle => 'Hedabide hau kendu?';

  @override
  String get personalSourcesFieldName => 'Izena';

  @override
  String get personalSourcesFieldUrl => 'Jarioaren URLa';

  @override
  String get personalSourcesFieldUrlHelp =>
      'Hedabidearen RSS/Atom. YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. Podcast-ak: saioaren jarioaren URLa.';

  @override
  String get personalSourcesFieldType => 'Mota';

  @override
  String get personalSourcesRequiredUrl => 'Jarioaren URLa behar da.';

  @override
  String get personalSourcesInvalidUrl =>
      'http:// edo https:// hasierakoa izan behar du eta domeinua izan.';

  @override
  String get personalSourcesAddedSnackbar =>
      'Hedabidea gehitu da. Freskatu jarioa titularrak ikusteko.';

  @override
  String get personalSourcesAlreadyExists =>
      'Jario hori dagoeneko zure zerrendan dago.';

  @override
  String get personalSourcesExport => 'Zerrenda arbelean kopiatu';

  @override
  String get personalSourcesImport => 'Zerrenda arbeletik itsatsi';

  @override
  String get personalSourcesExportedSnackbar => 'Zerrenda arbelean kopiatu da.';

  @override
  String get personalSourcesImportEmpty => 'Arbela hutsik dago.';

  @override
  String get personalSourcesImportInvalid =>
      'Arbeleko edukia ez da zerrenda baliagarria.';

  @override
  String personalSourcesImportedSnackbar(int count) {
    return '$count iturri inportatu dira.';
  }

  @override
  String get personalSourcesNote =>
      'Hedabide hauen titularrak zure telefonotik zuzenean deskargatzen dira freskatze bakoitzean. Ezer ez da zerbitzariarekin partekatzen.';

  @override
  String get personalSourcesCategoryReading => 'Irakurketa';

  @override
  String get personalSourcesCategoryAudio => 'Audioa';

  @override
  String get personalSourcesCategoryVideo => 'Bideoa';

  @override
  String get personalSourcesDiscoverFeed => 'Bilatu jarioa automatikoki';

  @override
  String get personalSourcesDiscoverNothing =>
      'Ez dugu jariorik aurkitu URL horretan. Itsatsi zuzenean ezagutzen baduzu.';

  @override
  String get personalSourcesDiscoverPickerTitle =>
      'Hainbat jario aurkitu ditugu';

  @override
  String get sourceSubmitTitle => 'Hedabide bat proposatu';

  @override
  String get sourceSubmitIntro =>
      'Hedabide bat proposatu (webgunea, podcast-a, bideo-kanala, Mastodon kontua…). Talde editorialak berrikusiko du aktibatu aurretik.';

  @override
  String get sourceSubmitName => 'Hedabidearen izena';

  @override
  String get sourceSubmitFeedUrl => 'Jarioaren URLa';

  @override
  String get sourceSubmitFeedUrlHelp =>
      'RSS/Atom: itsatsi jarioaren URLa. YouTube: itsatsi kanalaren URLa; egiaztatzean ebatziko dugu.';

  @override
  String get sourceSubmitFeedType => 'Jario mota';

  @override
  String get sourceSubmitDescription => 'Deskribapena (aukerakoa)';

  @override
  String get sourceSubmitWebsiteUrl => 'Hedabidearen webgunea (aukerakoa)';

  @override
  String get sourceSubmitTerritory => 'Lurraldea (aukerakoa)';

  @override
  String get sourceSubmitLanguages => 'Edukiaren hizkuntzak';

  @override
  String get sourceSubmitEmailHelp =>
      'Ez da argitaratzen; taldeak kontaktua behar izanez gero bakarrik erabiltzen da.';

  @override
  String get sourceSubmitSuccess =>
      'Eskerrik asko. Proposamena berrikusiko dugu eta hedabidea egiaztatutakoan agertuko da.';

  @override
  String get sourceSubmitRequiredFeedUrl => 'Jarioaren URLa beharrezkoa da.';

  @override
  String get sourceSubmitInvalidFeedUrl =>
      'Jarioaren URLak http:// edo https:// izan behar du hasieran';

  @override
  String get aboutTitle => 'Honi buruz';

  @override
  String get aboutManifestoHeader => 'Zer da hau';

  @override
  String get aboutManifestoBody =>
      'Informatzea eta ekitea arteko zirkuitua haustera bideratutako tresna sinple bat. Engagement algoritmorik gabe, tracking gabe, publizitaterik gabe. AGPL-3.0.';

  @override
  String get aboutRepository => 'Biltegia';

  @override
  String get aboutLicense => 'Lizentzia';

  @override
  String get commonBack => 'Itzuli';

  @override
  String get commonRetry => 'Saiatu berriro';

  @override
  String get commonClose => 'Itxi';

  @override
  String get commonCancel => 'Utzi';

  @override
  String get commonOk => 'Ados';

  @override
  String get searchTooltip => 'Bilatu';

  @override
  String get searchHint => 'Bilatu albisteetan, hedabideetan, irratietan…';

  @override
  String get searchPromptHint => 'Idatzi app osoan bilatzeko.';

  @override
  String get searchNoResults => 'Emaitzarik ez.';

  @override
  String get searchSectionItems => 'Albisteak';

  @override
  String get searchSectionSources => 'Hedabideak';

  @override
  String get searchSectionRadios => 'Irratiak';

  @override
  String get searchSectionCollectives => 'Kolektiboak';

  @override
  String get radioWebsite => 'Webgunea';

  @override
  String get radioPrograms => 'Programak';

  @override
  String get radioProgramsEmpty => 'Jarioan ez dago programarik.';

  @override
  String get radioProgramsFetchError =>
      'Ezin izan da programen jarioa kargatu.';

  @override
  String get flavorActivityHeader => 'Jarduera Flavor-en';

  @override
  String get flavorActivityEvents => 'Ekitaldiak';

  @override
  String get flavorActivityContent => 'Katalogoa';

  @override
  String get flavorActivityBoard => 'Iragarki-taula';

  @override
  String get flavorActivityEmpty =>
      'Nodo honek ez du jarduera publikorik orain.';

  @override
  String get settingsErrorReport => 'Partekatu errore-txostena';

  @override
  String get settingsErrorReportSubtitle =>
      'Azkenaldian huts bat erregistratu da. Partekatu konpontzen laguntzeko; ez da ezer bakarrik bidaltzen.';

  @override
  String get settingsErrorReportDismiss => 'Baztertu txostena';

  @override
  String feedOrganizingCardTitle(String tema) {
    return 'Nor ari da antolatzen $tema gaiaren inguruan?';
  }

  @override
  String get feedOrganizingCardCta => 'Ikusi kolektiboak';
}
