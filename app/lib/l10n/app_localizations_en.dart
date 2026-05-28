// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Flavor News Hub';

  @override
  String get appTagline => 'Alternative media and collectives organising';

  @override
  String get tabFeed => 'Headlines';

  @override
  String get tabAudio => 'Audio';

  @override
  String get tabRadios => 'Radios';

  @override
  String get tabMusic => 'Music';

  @override
  String get tabDirectory => 'Collectives';

  @override
  String get tabClientes => 'Clients';

  @override
  String get tabSettings => 'Settings';

  @override
  String get tabTv => 'TV';

  @override
  String get tvTabMedios => 'Channels';

  @override
  String get tvTabUltimas => 'Latest broadcasts';

  @override
  String get tvEmptyMedios =>
      'No TV channels yet. They\'ll be added from Admin or by importing the catalog.';

  @override
  String get tvEmptyUltimas => 'No recent broadcasts from TV channels.';

  @override
  String get radiosTitle => 'Free radios';

  @override
  String get radiosEmpty => 'No radios in this instance.';

  @override
  String get radiosOnlyFavorites => 'Only my radios';

  @override
  String get radiosOnlyFavoritesEmpty => 'You have no favorite radios yet.';

  @override
  String get radiosOnlyFavoritesHint =>
      'Mark radios as favorites to keep them at the top.';

  @override
  String get radiosOnlyFavoritesActive => 'Showing only your favorite radios.';

  @override
  String get radiosStreamError =>
      'Couldn\'t connect to the stream. Tap to retry.';

  @override
  String get videosTitle => 'Videos';

  @override
  String get videosEmpty =>
      'No videos right now. Add YouTube channels from Settings → My sources.';

  @override
  String get videosPlayNext => 'Next video';

  @override
  String get videosOnlyFavorites => 'Only my channels';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerSleepTimer => 'Sleep timer';

  @override
  String get itemCopyLink => 'Copy link';

  @override
  String get itemLinkCopied => 'Link copied.';

  @override
  String get savedSearchHint => 'Filter saved…';

  @override
  String get historyTitle => 'Reading history';

  @override
  String get historyEmpty =>
      'You haven\'t opened any headline yet. They will show up here.';

  @override
  String get settingsHistory => 'History';

  @override
  String get settingsHistorySubtitle => 'Headlines you\'ve opened.';

  @override
  String get opmlExport => 'Export my sources (OPML)';

  @override
  String get opmlImport => 'Import OPML…';

  @override
  String get opmlExportCopied => 'OPML copied to clipboard.';

  @override
  String get opmlImportHint =>
      'Paste here the OPML content from another aggregator.';

  @override
  String opmlImportSuccess(int count) {
    return 'Imported $count sources.';
  }

  @override
  String get opmlImportEmpty => 'No valid sources found in the OPML.';

  @override
  String get privacyPolicyTitle => 'Privacy policy';

  @override
  String get videoDescription => 'Description';

  @override
  String videoOpenExternal(String platform) {
    return 'Open on $platform';
  }

  @override
  String get videoChannelWebsite => 'Channel website';

  @override
  String get videoPlatformYoutube => 'YouTube';

  @override
  String get videoPlatformPeertube => 'PeerTube';

  @override
  String get videoPlatformExternal => 'browser';

  @override
  String get videoCommentsHint =>
      'Comments are available on the original platform.';

  @override
  String get feedTitle => 'Headlines';

  @override
  String get feedEmpty => 'No news yet.';

  @override
  String get feedEmptyWithFilters =>
      'No headline matches the active filters. Clear them to see everything.';

  @override
  String get feedLoading => 'Loading headlines…';

  @override
  String get feedError => 'Could not load the feed.';

  @override
  String get filtersTitle => 'Filters';

  @override
  String get filterByTopic => 'By topic';

  @override
  String get filterTopicsOffline =>
      'Offline: topics not available. Try again when you have signal.';

  @override
  String get filterByTerritory => 'By territory';

  @override
  String get filterByLanguage => 'By language';

  @override
  String get filtersClear => 'Clear filters';

  @override
  String get filtersApply => 'Apply';

  @override
  String itemOpenInSource(String sourceName) {
    return 'Read on $sourceName';
  }

  @override
  String get itemShare => 'Share';

  @override
  String get itemSave => 'Save';

  @override
  String get itemUnsave => 'Remove from saved';

  @override
  String get itemMarkUseful => 'Mark as useful';

  @override
  String get itemUnmarkUseful => 'Remove from useful';

  @override
  String get settingsTusIntereses => 'Your interests';

  @override
  String get settingsTusInteresesSubtitle =>
      'Which topics and outlets you\'re finding most useful';

  @override
  String get tusInteresesTitle => 'Your interests';

  @override
  String get tusInteresesEmpty =>
      'You haven\'t marked any headline as useful yet.';

  @override
  String get tusInteresesEmptyHelp =>
      'Use the lightbulb button (💡) on each item to mark it useful. Here you\'ll see a summary of your most recurrent topics and outlets — nothing leaves your device.';

  @override
  String tusInteresesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count headlines marked useful',
      one: '$count headline marked useful',
    );
    return '$_temp0';
  }

  @override
  String get tusInteresesTopTopics => 'Topics you mark most';

  @override
  String get tusInteresesTopSources => 'Outlets you mark most';

  @override
  String get tusInteresesFormats => 'Preferred format';

  @override
  String get tusInteresesApplyFilter => 'Apply these topics to the feed';

  @override
  String get feedOfflineBanner =>
      'Standalone mode. Headlines fetched directly from the sources.';

  @override
  String get savedTitle => 'Saved';

  @override
  String get savedSubtitle => 'Headlines you bookmarked for later.';

  @override
  String get savedEmpty =>
      'You haven\'t saved any headlines yet. Use the bookmark icon from the feed or the detail view.';

  @override
  String get savedTabNews => 'Headlines';

  @override
  String get savedTabAudio => 'My audio';

  @override
  String get savedAudioEmpty =>
      'You haven\'t favourited any podcast or song yet. Tap the heart in the player.';

  @override
  String get itemOrganizingTitle => 'Who\'s organising around this?';

  @override
  String get itemOrganizingEmpty =>
      'No verified collectives yet in this directory for these topics. If your collective fits, you can submit it.';

  @override
  String get itemOrganizingSeeAll => 'See all';

  @override
  String get sourceTitle => 'Source';

  @override
  String get sourceListNews => 'See this medium\'s news';

  @override
  String get sourceListVideos => 'See videos from this channel';

  @override
  String get sourceListAudio => 'See episodes of this podcast';

  @override
  String get tabPodcasts => 'Podcasts';

  @override
  String get podcastsEmpty =>
      'No podcast episodes yet. Directory sources with feed_type=podcast will appear here when they publish.';

  @override
  String get sourceEditorialHeader => 'Editorial info';

  @override
  String get sourceOwnership => 'Ownership and funding';

  @override
  String get sourceEditorialNote => 'Declared editorial stance';

  @override
  String get sourceLegalNote => 'Legal context';

  @override
  String get sourceTerritory => 'Territory';

  @override
  String get sourceLanguages => 'Languages';

  @override
  String get sourceWebsite => 'Website';

  @override
  String get directoryTitle => 'Collectives';

  @override
  String get colectivosTabNoticias => 'Movements';

  @override
  String get colectivosTabDirectorio => 'Directory';

  @override
  String get directoryEmpty => 'No verified collectives yet in this instance.';

  @override
  String get directoryAddCta => 'Is your collective missing? Add it';

  @override
  String get collectiveVisitWebsite => 'Visit website';

  @override
  String get collectiveFlavorCommunity => 'Community on Flavor';

  @override
  String get collectiveShare => 'Share';

  @override
  String get collectiveMediaTitle => 'Media edited by this collective';

  @override
  String get collectiveMediaEmpty => 'No linked media for this collective.';

  @override
  String get submitTitle => 'Submit a collective';

  @override
  String get submitName => 'Collective name';

  @override
  String get submitDescription => 'Description';

  @override
  String get submitWebsite => 'Website (optional)';

  @override
  String get submitContactEmail => 'Contact email';

  @override
  String get submitTerritory => 'Territory (optional)';

  @override
  String get submitFlavorUrl => 'Their Flavor instance URL (optional)';

  @override
  String get submitTopics => 'Topics they work on';

  @override
  String get submitSend => 'Send';

  @override
  String get submitSuccess =>
      'Thanks. We\'ll review your submission and it will appear once verified.';

  @override
  String get submitErrorGeneric => 'Couldn\'t submit. Try again later.';

  @override
  String get submitErrorRateLimited =>
      'Too many requests from this connection. Try again later.';

  @override
  String get submitRequiredName => 'Name is required.';

  @override
  String get submitRequiredDescription => 'Description is required.';

  @override
  String get submitRequiredEmail => 'A valid contact email is required.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsInterfaceLanguage => 'Interface language';

  @override
  String get settingsInterfaceLanguageSystem => 'Follow system';

  @override
  String get settingsMyTerritory => 'My territory';

  @override
  String get settingsMyTerritorySubtitle =>
      'Content from here appears first. Global items stay visible below.';

  @override
  String get settingsMyTerritoryNone =>
      'No territory (show everything equally)';

  @override
  String get settingsMyTerritoryChoose => 'Pick your base territory';

  @override
  String get settingsContentLanguage => 'Content language';

  @override
  String get settingsContentLanguageSubtitle =>
      'Decide which languages to show in headlines, videos, radios and podcasts.';

  @override
  String get settingsContentLanguageFollowUi => 'Follow interface language';

  @override
  String get settingsContentLanguageManual => 'Pick multiple manually';

  @override
  String get settingsContentLanguageOff => 'Show all languages';

  @override
  String get settingsContentLanguageManualHint =>
      'Tick the languages you want. Empty = no filter.';

  @override
  String get supportEntity => 'Support';

  @override
  String get movimientosTitle => 'Voices of movements';

  @override
  String get movimientosSubtitle =>
      'Small media and collectives whose posts get buried in the main feed by high-volume aggregators.';

  @override
  String get movimientosEmpty =>
      'No movement posts yet. They will appear when marked media publish.';

  @override
  String get movimientosEmptyHint =>
      'If this list never fills up, your instance may not have any media marked as movement voices yet. The admin can enable them from the panel.';

  @override
  String get settingsMovimientos => 'Voices of movements';

  @override
  String get settingsMovimientosSubtitle =>
      'Dedicated section for small or grassroots media and collectives.';

  @override
  String get shareAppMessage =>
      'Flavor News Hub — One app, all the alternative media\n\nWhat you\\\'ll find:\n• Headlines from alternative media (es/eu/ca/gl), sorted by date. No algorithm.\n• Videos and free TV channels.\n• Live radios and podcasts.\n• Free music (Funkwhale, Audius, Jamendo, Archive.org).\n• Directory of organized collectives and a map to find them.\n• No ads, no tracking, no account.\n\nHow to install on Android:\n1. Tap the link to download the APK:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. Your browser will warn that the file \"may harm your device\". Tap \"Keep\" (or \"Download anyway\").\n3. Open the downloaded APK. The first time, Android will ask you to allow your browser to install apps from unknown sources — grant it.\n4. Google Play Protect may show another warning like \"this app hasn\\\'t been verified\" or \"may be dangerous\". Tap \"Install anyway\" (or \"More details\" → \"Install anyway\").\n5. Done. Open the app.\n\nWhy these warnings appear: Android marks as \"unverified\" any app that doesn\\\'t come from Google Play, even when it\\\'s open source and auditable. Flavor News Hub is free software (AGPL-3.0), all the code is on GitHub and it sends no telemetry — these warnings are Android\\\'s default policy, not a real issue with the app.\n\nOpen source · AGPL-3.0';

  @override
  String get onboardingTerritoryTitle => 'From local to global';

  @override
  String get onboardingTerritoryBody =>
      'Pick your territory so nearby content appears first. Everything else stays visible below — nothing is hidden. You can change it anytime in Settings.';

  @override
  String get onboardingTerritorySkip => 'Skip';

  @override
  String get onboardingTerritoryConfirm => 'Use this territory';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSystem => 'Follow system';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsTextScale => 'Text size';

  @override
  String get settingsBackendUrl => 'Instance URL';

  @override
  String get settingsBackendUrlDescription =>
      'Change this to consume a different Flavor News Hub instance.';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsCheckUpdate => 'Check for updates';

  @override
  String get settingsCheckUpdateSubtitle =>
      'Force a fresh check, ignoring cache.';

  @override
  String get settingsCheckUpdateChecking => 'Checking…';

  @override
  String get settingsCheckUpdateUpToDate =>
      'You already have the latest version.';

  @override
  String settingsCheckUpdateAvailable(String version) {
    return 'A new version is available ($version).';
  }

  @override
  String get settingsCheckUpdateError =>
      'Couldn\'t check right now. Try again later.';

  @override
  String get settingsAdvanced => 'Advanced';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsProposeSource => 'Propose a source';

  @override
  String get settingsProposeSourceSubtitle =>
      'Missing an alternative medium? Suggest it for review.';

  @override
  String get settingsMyMedia => 'My sources';

  @override
  String get settingsMyMediaSubtitle =>
      'Your own RSS, podcast or video feeds. Stored only on this device.';

  @override
  String get settingsShareApp => 'Share the app';

  @override
  String get settingsShareAppSubtitle =>
      'Pass it on to anyone who might find it useful.';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNotificationsSubtitle =>
      'Get notified when there are new headlines, videos or podcasts.';

  @override
  String get notifTitle => 'New content notifications';

  @override
  String get notifHelp =>
      'The app checks for new headlines, videos or podcasts in background and pings you. No push servers, no tracking — all on-device.';

  @override
  String get notifFreqNever => 'Off';

  @override
  String get notifFreqHour => 'Every hour';

  @override
  String get notifFreq3h => 'Every 3 hours';

  @override
  String get notifFreq6h => 'Every 6 hours';

  @override
  String get notifFreq12h => 'Every 12 hours';

  @override
  String get notifFreq24h => 'Once a day';

  @override
  String get notifPermissionDenied =>
      'You denied the notifications permission. The app will keep checking in background but can\'t notify until you grant it in system Settings.';

  @override
  String get settingsMap => 'Map';

  @override
  String get settingsMapSubtitle => 'Radios and collectives by territory.';

  @override
  String get settingsSourcesPrefs => 'Curated sources';

  @override
  String get settingsSourcesPrefsSubtitle =>
      'Mute sources you don\'t want in the feed.';

  @override
  String get sourcesPrefsTitle => 'Curated sources';

  @override
  String get sourcesPrefsHelp =>
      'Turn off the sources you don\'t want. Their headlines stop showing up in your feed, but keep being served to other users.';

  @override
  String get sourcesPrefsEmpty => 'No curated sources yet.';

  @override
  String get sourcesPrefsResetAll => 'Re-enable all';

  @override
  String get sourcesCategoryAll => 'All';

  @override
  String get sourcesCategoryPress => 'Press';

  @override
  String get sourcesCategoryAudio => 'Audio';

  @override
  String get sourcesCategoryVideo => 'Video';

  @override
  String get sourcesCategoryFediverse => 'Fediverse';

  @override
  String get donationsTitle => 'Support the project';

  @override
  String get donationsIntro =>
      'Flavor News Hub is free and ad-free. If you find it useful, here are ways to keep it alive.';

  @override
  String get donationsKofi => 'Buy a one-off coffee';

  @override
  String get donationsPaypal => 'Direct donation';

  @override
  String get donationsBitcoinSegwit => 'Bitcoin (Native SegWit)';

  @override
  String get donationsBitcoinTaproot => 'Bitcoin (Taproot)';

  @override
  String get donationsCopyAddress => 'Copy address';

  @override
  String get donationsAddressCopied => 'Address copied to clipboard';

  @override
  String get donationsShare => 'Share the project';

  @override
  String get donationsShareHelp =>
      'Recommending it to someone is another way to help — it grows by humans, not by algorithm.';

  @override
  String get donationsShareAction => 'Share';

  @override
  String get donationsShareMessage =>
      'Flavor News Hub: federated news app, no algorithm, no ads.';

  @override
  String get donationsOtherWays => 'Other ways to help';

  @override
  String get donationsHelpStar => 'Star it on GitHub';

  @override
  String get donationsHelpBug => 'Report bugs or suggest improvements';

  @override
  String get donationsHelpTranslate => 'Help with translations';

  @override
  String get donationsHelpContribute => 'Contribute code or documentation';

  @override
  String get ecosistemaTitle => 'Part of the Colección del Nuevo Ser ecosystem';

  @override
  String get ecosistemaSubtitle => 'Visit coleccion-nuevo-ser.gailu.net';

  @override
  String updateTitle(String version) {
    return 'New version $version available';
  }

  @override
  String get updateBodyGeneric =>
      'An update is available. Download it for the latest fixes and features.';

  @override
  String get updateDownload => 'Download';

  @override
  String get updateDismiss => 'Not now';

  @override
  String get updateDownloadingTitle => 'Downloading update';

  @override
  String get updateDownloadingIndeterminate => 'Preparing…';

  @override
  String get updateDownloadFallback =>
      'Couldn\'t download inside the app. Opening in the browser.';

  @override
  String get updateInstallFallback =>
      'Couldn\'t open the installer. Opening in the browser.';

  @override
  String get settingsMusic => 'Free music';

  @override
  String get settingsMusicSubtitle =>
      'Search and listen to federated music from Funkwhale.';

  @override
  String get musicInstanceLabel => 'Funkwhale instance';

  @override
  String get musicInstanceHelp =>
      'Paste the URL of a public Funkwhale instance (e.g. https://open.audio/).';

  @override
  String get musicInstancePrompt =>
      'To listen, add at least one Funkwhale instance.';

  @override
  String get musicInstanceCurrent => 'Instance';

  @override
  String get musicInstancesLabel => 'Funkwhale instances';

  @override
  String get musicInstancesHelp =>
      'You can add several. Search queries all in parallel.';

  @override
  String get jamendoLabel => 'Jamendo';

  @override
  String get jamendoHelp =>
      'Creative Commons catalogue. Grab a free client_id and paste it here.';

  @override
  String get jamendoGetKey => 'Get client_id';

  @override
  String get musicSearchHint => 'Search song, artist or album…';

  @override
  String get musicSearchPrompt => 'Type to search federated music.';

  @override
  String get musicGenresHeader => 'Genres';

  @override
  String get musicNewHeader => 'Latest uploads';

  @override
  String get musicNewEmpty => 'Nothing new right now.';

  @override
  String get personalSourcesTitle => 'My sources';

  @override
  String get personalSourcesEmpty =>
      'You haven\'t added any personal source yet.';

  @override
  String get personalSourcesEmptyHelp =>
      'Sources you add here stay on your phone and their headlines are mixed into the main feed.';

  @override
  String get personalSourcesAdd => 'Add';

  @override
  String get personalSourcesAddAction => 'Add';

  @override
  String get personalSourcesRemove => 'Remove';

  @override
  String get personalSourcesRemoveTitle => 'Remove this source?';

  @override
  String get personalSourcesFieldName => 'Name';

  @override
  String get personalSourcesFieldUrl => 'Feed URL';

  @override
  String get personalSourcesFieldUrlHelp =>
      'RSS/Atom of the source. For YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. For podcasts: the show\'s feed URL.';

  @override
  String get personalSourcesFieldType => 'Type';

  @override
  String get personalSourcesRequiredUrl => 'Feed URL is required.';

  @override
  String get personalSourcesInvalidUrl =>
      'Must start with http:// or https:// and include a host.';

  @override
  String get personalSourcesAddedSnackbar =>
      'Source added. Pull to refresh the feed.';

  @override
  String get personalSourcesAlreadyExists =>
      'That feed is already in your list.';

  @override
  String get personalSourcesExport => 'Copy list to clipboard';

  @override
  String get personalSourcesImport => 'Paste list from clipboard';

  @override
  String get personalSourcesExportedSnackbar => 'List copied to clipboard.';

  @override
  String get personalSourcesImportEmpty => 'Clipboard is empty.';

  @override
  String get personalSourcesImportInvalid =>
      'Clipboard content is not a valid list.';

  @override
  String personalSourcesImportedSnackbar(int count) {
    return 'Imported $count sources.';
  }

  @override
  String get personalSourcesNote =>
      'Headlines for these sources are fetched directly from your phone on every refresh. Nothing is shared with the server.';

  @override
  String get personalSourcesCategoryReading => 'Reading';

  @override
  String get personalSourcesCategoryAudio => 'Audio';

  @override
  String get personalSourcesCategoryVideo => 'Video';

  @override
  String get personalSourcesDiscoverFeed => 'Auto-discover feed';

  @override
  String get personalSourcesDiscoverNothing =>
      'Couldn\'t find a feed at that URL. Paste it directly if you know it.';

  @override
  String get personalSourcesDiscoverPickerTitle => 'Multiple feeds found';

  @override
  String get sourceSubmitTitle => 'Propose a source';

  @override
  String get sourceSubmitIntro =>
      'Suggest a source (website, podcast, video channel, Mastodon account…). The editorial team will review it before activating.';

  @override
  String get sourceSubmitName => 'Source name';

  @override
  String get sourceSubmitFeedUrl => 'Feed URL';

  @override
  String get sourceSubmitFeedUrlHelp =>
      'RSS/Atom: paste the feed URL. YouTube: paste the channel URL; we resolve it on review.';

  @override
  String get sourceSubmitFeedType => 'Feed type';

  @override
  String get sourceSubmitDescription => 'Description (optional)';

  @override
  String get sourceSubmitWebsiteUrl => 'Source website (optional)';

  @override
  String get sourceSubmitTerritory => 'Territory (optional)';

  @override
  String get sourceSubmitLanguages => 'Content languages';

  @override
  String get sourceSubmitEmailHelp =>
      'Not published; only used if the team needs to reach you.';

  @override
  String get sourceSubmitSuccess =>
      'Thanks. We\'ll review the submission; it\'ll appear once verified.';

  @override
  String get sourceSubmitRequiredFeedUrl => 'Feed URL is required.';

  @override
  String get sourceSubmitInvalidFeedUrl =>
      'Feed URL must start with http:// or https://';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutManifestoHeader => 'What this is';

  @override
  String get aboutManifestoBody =>
      'A small tool to break the loop between learning about something and being able to do something about it. No engagement algorithm, no tracking, no ads. AGPL-3.0.';

  @override
  String get aboutRepository => 'Repository';

  @override
  String get aboutLicense => 'License';

  @override
  String get commonBack => 'Back';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonOk => 'OK';

  @override
  String get searchTooltip => 'Search';

  @override
  String get searchHint => 'Search news, sources, radios…';

  @override
  String get searchPromptHint => 'Type to search across the app.';

  @override
  String get searchNoResults => 'No results.';

  @override
  String get searchSectionItems => 'News';

  @override
  String get searchSectionSources => 'Sources';

  @override
  String get searchSectionRadios => 'Radios';

  @override
  String get searchSectionCollectives => 'Collectives';

  @override
  String get radioWebsite => 'Website';

  @override
  String get radioPrograms => 'Programmes';

  @override
  String get radioProgramsEmpty => 'No programmes in the feed.';

  @override
  String get radioProgramsFetchError => 'Couldn\'t load the programmes feed.';

  @override
  String get flavorActivityHeader => 'Activity on Flavor';

  @override
  String get flavorActivityEvents => 'Events';

  @override
  String get flavorActivityContent => 'Catalogue';

  @override
  String get flavorActivityBoard => 'Board';

  @override
  String get flavorActivityEmpty =>
      'This node hasn\'t published any public activity yet.';

  @override
  String get settingsErrorReport => 'Share error report';

  @override
  String get settingsErrorReportSubtitle =>
      'A recent crash was recorded. Share it to help fix it; nothing is sent on its own.';

  @override
  String get settingsErrorReportDismiss => 'Discard report';
}
