import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ca.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_eu.dart';
import 'app_localizations_gl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ca'),
    Locale('en'),
    Locale('es'),
    Locale('eu'),
    Locale('gl')
  ];

  /// Nombre visible de la aplicación.
  ///
  /// In es, this message translates to:
  /// **'Flavor News Hub'**
  String get appName;

  /// Lema mostrado en Acerca de.
  ///
  /// In es, this message translates to:
  /// **'Medios alternativos y colectivos que se organizan'**
  String get appTagline;

  /// No description provided for @tabFeed.
  ///
  /// In es, this message translates to:
  /// **'Titulares'**
  String get tabFeed;

  /// No description provided for @tabAudio.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get tabAudio;

  /// No description provided for @tabRadios.
  ///
  /// In es, this message translates to:
  /// **'Radios'**
  String get tabRadios;

  /// No description provided for @tabMusic.
  ///
  /// In es, this message translates to:
  /// **'Música'**
  String get tabMusic;

  /// No description provided for @tabDirectory.
  ///
  /// In es, this message translates to:
  /// **'Colectivos'**
  String get tabDirectory;

  /// No description provided for @tabClientes.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get tabClientes;

  /// No description provided for @tabSettings.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get tabSettings;

  /// No description provided for @tabTv.
  ///
  /// In es, this message translates to:
  /// **'TV'**
  String get tabTv;

  /// No description provided for @tvTabMedios.
  ///
  /// In es, this message translates to:
  /// **'Medios'**
  String get tvTabMedios;

  /// No description provided for @tvTabUltimas.
  ///
  /// In es, this message translates to:
  /// **'Últimas emisiones'**
  String get tvTabUltimas;

  /// No description provided for @tvEmptyMedios.
  ///
  /// In es, this message translates to:
  /// **'No hay canales de TV todavía. Se añadirán desde Admin o al importar el catálogo.'**
  String get tvEmptyMedios;

  /// No description provided for @tvEmptyUltimas.
  ///
  /// In es, this message translates to:
  /// **'Sin emisiones recientes de los canales de TV.'**
  String get tvEmptyUltimas;

  /// No description provided for @radiosTitle.
  ///
  /// In es, this message translates to:
  /// **'Radios libres'**
  String get radiosTitle;

  /// No description provided for @radiosEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay radios en esta instancia.'**
  String get radiosEmpty;

  /// No description provided for @radiosOnlyFavorites.
  ///
  /// In es, this message translates to:
  /// **'Sólo mis radios'**
  String get radiosOnlyFavorites;

  /// No description provided for @radiosOnlyFavoritesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no tienes radios favoritas.'**
  String get radiosOnlyFavoritesEmpty;

  /// No description provided for @radiosOnlyFavoritesHint.
  ///
  /// In es, this message translates to:
  /// **'Marca radios como favoritas para tenerlas arriba.'**
  String get radiosOnlyFavoritesHint;

  /// No description provided for @radiosOnlyFavoritesActive.
  ///
  /// In es, this message translates to:
  /// **'Mostrando sólo tus radios favoritas.'**
  String get radiosOnlyFavoritesActive;

  /// No description provided for @radiosStreamError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo conectar con el stream. Toca para reintentar.'**
  String get radiosStreamError;

  /// No description provided for @videosTitle.
  ///
  /// In es, this message translates to:
  /// **'Vídeos'**
  String get videosTitle;

  /// No description provided for @videosEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay vídeos ahora mismo. Añade canales de YouTube desde Ajustes → Mis medios para que aparezcan aquí.'**
  String get videosEmpty;

  /// No description provided for @videosPlayNext.
  ///
  /// In es, this message translates to:
  /// **'Siguiente vídeo'**
  String get videosPlayNext;

  /// No description provided for @videosOnlyFavorites.
  ///
  /// In es, this message translates to:
  /// **'Sólo mis canales'**
  String get videosOnlyFavorites;

  /// No description provided for @playerSpeed.
  ///
  /// In es, this message translates to:
  /// **'Velocidad'**
  String get playerSpeed;

  /// No description provided for @playerSleepTimer.
  ///
  /// In es, this message translates to:
  /// **'Apagar en…'**
  String get playerSleepTimer;

  /// No description provided for @itemCopyLink.
  ///
  /// In es, this message translates to:
  /// **'Copiar enlace'**
  String get itemCopyLink;

  /// No description provided for @itemLinkCopied.
  ///
  /// In es, this message translates to:
  /// **'Enlace copiado.'**
  String get itemLinkCopied;

  /// No description provided for @savedSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Filtrar guardados…'**
  String get savedSearchHint;

  /// No description provided for @historyTitle.
  ///
  /// In es, this message translates to:
  /// **'Historial de lectura'**
  String get historyTitle;

  /// No description provided for @historyEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has leído ningún titular. Los que abras aparecerán aquí.'**
  String get historyEmpty;

  /// No description provided for @settingsHistory.
  ///
  /// In es, this message translates to:
  /// **'Historial'**
  String get settingsHistory;

  /// No description provided for @settingsHistorySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Titulares que has abierto.'**
  String get settingsHistorySubtitle;

  /// No description provided for @opmlExport.
  ///
  /// In es, this message translates to:
  /// **'Exportar mis medios (OPML)'**
  String get opmlExport;

  /// No description provided for @opmlImport.
  ///
  /// In es, this message translates to:
  /// **'Importar OPML…'**
  String get opmlImport;

  /// No description provided for @opmlExportCopied.
  ///
  /// In es, this message translates to:
  /// **'OPML copiado al portapapeles.'**
  String get opmlExportCopied;

  /// No description provided for @opmlImportHint.
  ///
  /// In es, this message translates to:
  /// **'Pega aquí el contenido OPML de otro agregador.'**
  String get opmlImportHint;

  /// No description provided for @opmlImportSuccess.
  ///
  /// In es, this message translates to:
  /// **'Importadas {count} fuentes.'**
  String opmlImportSuccess(int count);

  /// No description provided for @opmlImportEmpty.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron fuentes válidas en el OPML.'**
  String get opmlImportEmpty;

  /// No description provided for @privacyPolicyTitle.
  ///
  /// In es, this message translates to:
  /// **'Política de privacidad'**
  String get privacyPolicyTitle;

  /// No description provided for @videoDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get videoDescription;

  /// No description provided for @videoOpenExternal.
  ///
  /// In es, this message translates to:
  /// **'Ver en {platform}'**
  String videoOpenExternal(String platform);

  /// No description provided for @videoChannelWebsite.
  ///
  /// In es, this message translates to:
  /// **'Web del canal'**
  String get videoChannelWebsite;

  /// No description provided for @videoPlatformYoutube.
  ///
  /// In es, this message translates to:
  /// **'YouTube'**
  String get videoPlatformYoutube;

  /// No description provided for @videoPlatformPeertube.
  ///
  /// In es, this message translates to:
  /// **'PeerTube'**
  String get videoPlatformPeertube;

  /// No description provided for @videoPlatformExternal.
  ///
  /// In es, this message translates to:
  /// **'el navegador'**
  String get videoPlatformExternal;

  /// No description provided for @videoCommentsHint.
  ///
  /// In es, this message translates to:
  /// **'Los comentarios se ven en la plataforma original.'**
  String get videoCommentsHint;

  /// No description provided for @feedTitle.
  ///
  /// In es, this message translates to:
  /// **'Titulares'**
  String get feedTitle;

  /// No description provided for @feedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no hay noticias cargadas.'**
  String get feedEmpty;

  /// No description provided for @feedEmptyWithFilters.
  ///
  /// In es, this message translates to:
  /// **'Ningún titular coincide con los filtros activos. Límpialos para ver todo.'**
  String get feedEmptyWithFilters;

  /// No description provided for @feedLoading.
  ///
  /// In es, this message translates to:
  /// **'Cargando titulares…'**
  String get feedLoading;

  /// No description provided for @feedError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el feed.'**
  String get feedError;

  /// No description provided for @filtersTitle.
  ///
  /// In es, this message translates to:
  /// **'Filtros'**
  String get filtersTitle;

  /// No description provided for @filterByTopic.
  ///
  /// In es, this message translates to:
  /// **'Por temática'**
  String get filterByTopic;

  /// No description provided for @filterTopicsOffline.
  ///
  /// In es, this message translates to:
  /// **'Sin conexión con el servidor: las temáticas no están disponibles. Vuelve a intentarlo cuando haya señal.'**
  String get filterTopicsOffline;

  /// No description provided for @filterByTerritory.
  ///
  /// In es, this message translates to:
  /// **'Por territorio'**
  String get filterByTerritory;

  /// No description provided for @filterByLanguage.
  ///
  /// In es, this message translates to:
  /// **'Por idioma'**
  String get filterByLanguage;

  /// No description provided for @filtersClear.
  ///
  /// In es, this message translates to:
  /// **'Limpiar filtros'**
  String get filtersClear;

  /// No description provided for @filtersApply.
  ///
  /// In es, this message translates to:
  /// **'Aplicar'**
  String get filtersApply;

  /// No description provided for @itemOpenInSource.
  ///
  /// In es, this message translates to:
  /// **'Leer en {sourceName}'**
  String itemOpenInSource(String sourceName);

  /// No description provided for @itemShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get itemShare;

  /// No description provided for @itemSave.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get itemSave;

  /// No description provided for @itemUnsave.
  ///
  /// In es, this message translates to:
  /// **'Quitar de guardados'**
  String get itemUnsave;

  /// No description provided for @itemMarkUseful.
  ///
  /// In es, this message translates to:
  /// **'Marcar como útil'**
  String get itemMarkUseful;

  /// No description provided for @itemUnmarkUseful.
  ///
  /// In es, this message translates to:
  /// **'Quitar de útiles'**
  String get itemUnmarkUseful;

  /// No description provided for @settingsTusIntereses.
  ///
  /// In es, this message translates to:
  /// **'Tus intereses'**
  String get settingsTusIntereses;

  /// No description provided for @settingsTusInteresesSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Qué temáticas y medios te están interesando más'**
  String get settingsTusInteresesSubtitle;

  /// No description provided for @tusInteresesTitle.
  ///
  /// In es, this message translates to:
  /// **'Tus intereses'**
  String get tusInteresesTitle;

  /// No description provided for @tusInteresesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has marcado ningún titular como útil.'**
  String get tusInteresesEmpty;

  /// No description provided for @tusInteresesEmptyHelp.
  ///
  /// In es, this message translates to:
  /// **'Usa el botón de la bombilla (💡) en cada noticia para marcarla útil. Aquí verás un resumen con tus temáticas y medios más recurrentes — nada viaja al servidor.'**
  String get tusInteresesEmptyHelp;

  /// No description provided for @tusInteresesCount.
  ///
  /// In es, this message translates to:
  /// **'{count, plural, one{{count} titular marcado útil} other{{count} titulares marcados útiles}}'**
  String tusInteresesCount(int count);

  /// No description provided for @tusInteresesTopTopics.
  ///
  /// In es, this message translates to:
  /// **'Temáticas que más te interesan'**
  String get tusInteresesTopTopics;

  /// No description provided for @tusInteresesTopSources.
  ///
  /// In es, this message translates to:
  /// **'Medios que más te interesan'**
  String get tusInteresesTopSources;

  /// No description provided for @tusInteresesFormats.
  ///
  /// In es, this message translates to:
  /// **'Formato preferido'**
  String get tusInteresesFormats;

  /// No description provided for @tusInteresesApplyFilter.
  ///
  /// In es, this message translates to:
  /// **'Aplicar estas temáticas al feed'**
  String get tusInteresesApplyFilter;

  /// No description provided for @feedOfflineBanner.
  ///
  /// In es, this message translates to:
  /// **'Modo autónomo. Titulares descargados directos desde los medios.'**
  String get feedOfflineBanner;

  /// No description provided for @savedTitle.
  ///
  /// In es, this message translates to:
  /// **'Guardados'**
  String get savedTitle;

  /// No description provided for @savedSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Titulares que has marcado para leer después.'**
  String get savedSubtitle;

  /// No description provided for @savedEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has guardado ningún titular. Desde el feed o desde el detalle, usa el icono del marcador.'**
  String get savedEmpty;

  /// No description provided for @savedTabNews.
  ///
  /// In es, this message translates to:
  /// **'Titulares'**
  String get savedTabNews;

  /// No description provided for @savedTabAudio.
  ///
  /// In es, this message translates to:
  /// **'Mi audio'**
  String get savedTabAudio;

  /// No description provided for @savedAudioEmpty.
  ///
  /// In es, this message translates to:
  /// **'Todavía no has marcado como favorito ningún pódcast ni canción. En el reproductor pulsa el corazón.'**
  String get savedAudioEmpty;

  /// No description provided for @itemOrganizingTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Quién se organiza sobre esto?'**
  String get itemOrganizingTitle;

  /// No description provided for @itemOrganizingEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay colectivos verificados en este directorio sobre estas temáticas. Si tu colectivo encaja, puedes darlo de alta.'**
  String get itemOrganizingEmpty;

  /// No description provided for @itemOrganizingSeeAll.
  ///
  /// In es, this message translates to:
  /// **'Ver todos'**
  String get itemOrganizingSeeAll;

  /// No description provided for @sourceTitle.
  ///
  /// In es, this message translates to:
  /// **'Medio'**
  String get sourceTitle;

  /// No description provided for @sourceListNews.
  ///
  /// In es, this message translates to:
  /// **'Ver noticias de este medio'**
  String get sourceListNews;

  /// No description provided for @sourceListVideos.
  ///
  /// In es, this message translates to:
  /// **'Ver vídeos de este canal'**
  String get sourceListVideos;

  /// No description provided for @sourceListAudio.
  ///
  /// In es, this message translates to:
  /// **'Ver episodios de este podcast'**
  String get sourceListAudio;

  /// No description provided for @tabPodcasts.
  ///
  /// In es, this message translates to:
  /// **'Podcast'**
  String get tabPodcasts;

  /// No description provided for @podcastsEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay episodios de podcast. Los medios del directorio con feed_type=podcast aparecen aquí cuando publican.'**
  String get podcastsEmpty;

  /// No description provided for @sourceEditorialHeader.
  ///
  /// In es, this message translates to:
  /// **'Ficha editorial'**
  String get sourceEditorialHeader;

  /// No description provided for @sourceOwnership.
  ///
  /// In es, this message translates to:
  /// **'Propiedad y financiación'**
  String get sourceOwnership;

  /// No description provided for @sourceEditorialNote.
  ///
  /// In es, this message translates to:
  /// **'Línea editorial declarada'**
  String get sourceEditorialNote;

  /// No description provided for @sourceLegalNote.
  ///
  /// In es, this message translates to:
  /// **'Contexto legal'**
  String get sourceLegalNote;

  /// No description provided for @sourceTerritory.
  ///
  /// In es, this message translates to:
  /// **'Territorio'**
  String get sourceTerritory;

  /// No description provided for @sourceLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas'**
  String get sourceLanguages;

  /// No description provided for @sourceWebsite.
  ///
  /// In es, this message translates to:
  /// **'Web'**
  String get sourceWebsite;

  /// No description provided for @directoryTitle.
  ///
  /// In es, this message translates to:
  /// **'Colectivos'**
  String get directoryTitle;

  /// No description provided for @colectivosTabNoticias.
  ///
  /// In es, this message translates to:
  /// **'Movimientos'**
  String get colectivosTabNoticias;

  /// No description provided for @colectivosTabDirectorio.
  ///
  /// In es, this message translates to:
  /// **'Directorio'**
  String get colectivosTabDirectorio;

  /// No description provided for @directoryEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay colectivos verificados en esta instancia.'**
  String get directoryEmpty;

  /// No description provided for @directoryAddCta.
  ///
  /// In es, this message translates to:
  /// **'¿Tu colectivo no está aquí? Añádelo'**
  String get directoryAddCta;

  /// No description provided for @collectiveVisitWebsite.
  ///
  /// In es, this message translates to:
  /// **'Visitar web'**
  String get collectiveVisitWebsite;

  /// No description provided for @collectiveFlavorCommunity.
  ///
  /// In es, this message translates to:
  /// **'Comunidad en Flavor'**
  String get collectiveFlavorCommunity;

  /// No description provided for @collectiveShare.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get collectiveShare;

  /// No description provided for @collectiveMediaTitle.
  ///
  /// In es, this message translates to:
  /// **'Medios que edita'**
  String get collectiveMediaTitle;

  /// No description provided for @collectiveMediaEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este colectivo no tiene medios vinculados.'**
  String get collectiveMediaEmpty;

  /// No description provided for @submitTitle.
  ///
  /// In es, this message translates to:
  /// **'Dar de alta un colectivo'**
  String get submitTitle;

  /// No description provided for @submitName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del colectivo'**
  String get submitName;

  /// No description provided for @submitDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get submitDescription;

  /// No description provided for @submitWebsite.
  ///
  /// In es, this message translates to:
  /// **'Web (opcional)'**
  String get submitWebsite;

  /// No description provided for @submitContactEmail.
  ///
  /// In es, this message translates to:
  /// **'Email de contacto'**
  String get submitContactEmail;

  /// No description provided for @submitTerritory.
  ///
  /// In es, this message translates to:
  /// **'Territorio (opcional)'**
  String get submitTerritory;

  /// No description provided for @submitFlavorUrl.
  ///
  /// In es, this message translates to:
  /// **'URL de su instancia Flavor (opcional)'**
  String get submitFlavorUrl;

  /// No description provided for @submitTopics.
  ///
  /// In es, this message translates to:
  /// **'Temáticas en las que trabaja'**
  String get submitTopics;

  /// No description provided for @submitSend.
  ///
  /// In es, this message translates to:
  /// **'Enviar'**
  String get submitSend;

  /// No description provided for @submitSuccess.
  ///
  /// In es, this message translates to:
  /// **'Gracias. Revisaremos tu alta y aparecerá en el directorio cuando esté verificada.'**
  String get submitSuccess;

  /// No description provided for @submitErrorGeneric.
  ///
  /// In es, this message translates to:
  /// **'No hemos podido enviar el alta. Inténtalo de nuevo más tarde.'**
  String get submitErrorGeneric;

  /// No description provided for @submitErrorRateLimited.
  ///
  /// In es, this message translates to:
  /// **'Demasiadas peticiones desde esta conexión. Prueba en un rato.'**
  String get submitErrorRateLimited;

  /// No description provided for @submitRequiredName.
  ///
  /// In es, this message translates to:
  /// **'El nombre es obligatorio.'**
  String get submitRequiredName;

  /// No description provided for @submitRequiredDescription.
  ///
  /// In es, this message translates to:
  /// **'La descripción es obligatoria.'**
  String get submitRequiredDescription;

  /// No description provided for @submitRequiredEmail.
  ///
  /// In es, this message translates to:
  /// **'Hace falta un email de contacto válido.'**
  String get submitRequiredEmail;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Ajustes'**
  String get settingsTitle;

  /// No description provided for @settingsInterfaceLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma de la interfaz'**
  String get settingsInterfaceLanguage;

  /// No description provided for @settingsInterfaceLanguageSystem.
  ///
  /// In es, this message translates to:
  /// **'Seguir sistema'**
  String get settingsInterfaceLanguageSystem;

  /// No description provided for @settingsMyTerritory.
  ///
  /// In es, this message translates to:
  /// **'Mi territorio'**
  String get settingsMyTerritory;

  /// No description provided for @settingsMyTerritorySubtitle.
  ///
  /// In es, this message translates to:
  /// **'Desde aquí, los contenidos cercanos aparecen primero. Los globales siguen visibles debajo.'**
  String get settingsMyTerritorySubtitle;

  /// No description provided for @settingsMyTerritoryNone.
  ///
  /// In es, this message translates to:
  /// **'Sin territorio (mostrar todo por igual)'**
  String get settingsMyTerritoryNone;

  /// No description provided for @settingsMyTerritoryChoose.
  ///
  /// In es, this message translates to:
  /// **'Elige tu territorio base'**
  String get settingsMyTerritoryChoose;

  /// No description provided for @settingsContentLanguage.
  ///
  /// In es, this message translates to:
  /// **'Idioma del contenido'**
  String get settingsContentLanguage;

  /// No description provided for @settingsContentLanguageSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Decide qué idiomas quieres ver en titulares, vídeos, radios y podcasts.'**
  String get settingsContentLanguageSubtitle;

  /// No description provided for @settingsContentLanguageFollowUi.
  ///
  /// In es, this message translates to:
  /// **'Seguir el idioma de la interfaz'**
  String get settingsContentLanguageFollowUi;

  /// No description provided for @settingsContentLanguageManual.
  ///
  /// In es, this message translates to:
  /// **'Elegir varios manualmente'**
  String get settingsContentLanguageManual;

  /// No description provided for @settingsContentLanguageOff.
  ///
  /// In es, this message translates to:
  /// **'Mostrar todos los idiomas'**
  String get settingsContentLanguageOff;

  /// No description provided for @settingsContentLanguageManualHint.
  ///
  /// In es, this message translates to:
  /// **'Marca los idiomas que quieres ver. Vacío = sin filtro.'**
  String get settingsContentLanguageManualHint;

  /// No description provided for @supportEntity.
  ///
  /// In es, this message translates to:
  /// **'Apoyar'**
  String get supportEntity;

  /// No description provided for @movimientosTitle.
  ///
  /// In es, this message translates to:
  /// **'Voces de movimientos'**
  String get movimientosTitle;

  /// No description provided for @movimientosSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Medios pequeños y colectivos cuyas publicaciones quedan tapadas en el feed general por agregadores prolíficos.'**
  String get movimientosSubtitle;

  /// No description provided for @movimientosEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no hay publicaciones de movimientos. Volverán cuando los medios marcados publiquen.'**
  String get movimientosEmpty;

  /// No description provided for @movimientosEmptyHint.
  ///
  /// In es, this message translates to:
  /// **'Si esta lista no se llena nunca, puede que tu instancia aún no tenga medios marcados como voz de movimiento. El admin puede activarlos desde el panel.'**
  String get movimientosEmptyHint;

  /// No description provided for @settingsMovimientos.
  ///
  /// In es, this message translates to:
  /// **'Voces de movimientos'**
  String get settingsMovimientos;

  /// No description provided for @settingsMovimientosSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Sección dedicada a medios y colectivos pequeños o militantes.'**
  String get settingsMovimientosSubtitle;

  /// No description provided for @shareAppMessage.
  ///
  /// In es, this message translates to:
  /// **'Flavor News Hub — Una app, todos los medios alternativos\n\nQué encontrarás:\n• Titulares de medios alternativos (es/eu/ca/gl), ordenados por fecha. Sin algoritmo.\n• Vídeos y canales de TV libres.\n• Radios en directo y podcasts.\n• Música libre (Funkwhale, Audius, Jamendo, Archive.org).\n• Directorio de colectivos y mapa para encontrarlos.\n• Sin publicidad, sin tracking, sin cuenta.\n\nInstalación en Android:\n1. Toca el enlace para descargar el APK:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. El navegador te avisará de que el archivo \"podría dañar tu dispositivo\". Pulsa \"Conservar\" (o \"Descargar igualmente\").\n3. Abre el APK descargado. La primera vez Android te pedirá permiso para que tu navegador instale apps desde fuentes desconocidas — concédelo.\n4. Es posible que aparezca otro aviso de Google Play Protect tipo \"esta app no se ha verificado\" o \"puede ser peligrosa\". Pulsa \"Instalar de todos modos\" (o \"Más detalles\" → \"Instalar de todos modos\").\n5. Listo. Abre la app.\n\nPor qué salen esos avisos: Android marca como \"no verificada\" cualquier app que no venga de Google Play, aunque sea código abierto y auditable. Flavor News Hub es libre (AGPL-3.0), todo el código está en GitHub y no envía telemetría — los avisos son la política por defecto de Android, no un problema real de la app.\n\nCódigo abierto · AGPL-3.0'**
  String get shareAppMessage;

  /// No description provided for @onboardingTerritoryTitle.
  ///
  /// In es, this message translates to:
  /// **'De lo local a lo global'**
  String get onboardingTerritoryTitle;

  /// No description provided for @onboardingTerritoryBody.
  ///
  /// In es, this message translates to:
  /// **'Elige tu territorio para que lo cercano aparezca primero. Todo lo demás sigue visible detrás — no se oculta nada. Siempre puedes cambiarlo en Ajustes.'**
  String get onboardingTerritoryBody;

  /// No description provided for @onboardingTerritorySkip.
  ///
  /// In es, this message translates to:
  /// **'Saltar'**
  String get onboardingTerritorySkip;

  /// No description provided for @onboardingTerritoryConfirm.
  ///
  /// In es, this message translates to:
  /// **'Usar este territorio'**
  String get onboardingTerritoryConfirm;

  /// No description provided for @settingsTheme.
  ///
  /// In es, this message translates to:
  /// **'Tema'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSystem.
  ///
  /// In es, this message translates to:
  /// **'Seguir sistema'**
  String get settingsThemeSystem;

  /// No description provided for @settingsThemeLight.
  ///
  /// In es, this message translates to:
  /// **'Claro'**
  String get settingsThemeLight;

  /// No description provided for @settingsThemeDark.
  ///
  /// In es, this message translates to:
  /// **'Oscuro'**
  String get settingsThemeDark;

  /// No description provided for @settingsTextScale.
  ///
  /// In es, this message translates to:
  /// **'Tamaño del texto'**
  String get settingsTextScale;

  /// No description provided for @settingsRadioBluetooth.
  ///
  /// In es, this message translates to:
  /// **'Radio al conectar el coche (Bluetooth)'**
  String get settingsRadioBluetooth;

  /// No description provided for @settingsRadioBluetoothSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Al conectar el audio Bluetooth del coche, la última emisora arranca sola si no suena nada. Desactivado no cambia nada.'**
  String get settingsRadioBluetoothSubtitle;

  /// No description provided for @settingsBackendUrl.
  ///
  /// In es, this message translates to:
  /// **'URL de la instancia'**
  String get settingsBackendUrl;

  /// No description provided for @settingsBackendUrlDescription.
  ///
  /// In es, this message translates to:
  /// **'Si cambias esto, la app consumirá los datos de otra instancia de Flavor News Hub.'**
  String get settingsBackendUrlDescription;

  /// No description provided for @settingsAbout.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get settingsAbout;

  /// No description provided for @settingsCheckUpdate.
  ///
  /// In es, this message translates to:
  /// **'Comprobar actualizaciones'**
  String get settingsCheckUpdate;

  /// No description provided for @settingsCheckUpdateSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Forzar comprobación ahora saltando la caché.'**
  String get settingsCheckUpdateSubtitle;

  /// No description provided for @settingsCheckUpdateChecking.
  ///
  /// In es, this message translates to:
  /// **'Comprobando…'**
  String get settingsCheckUpdateChecking;

  /// No description provided for @settingsCheckUpdateUpToDate.
  ///
  /// In es, this message translates to:
  /// **'Ya tienes la última versión.'**
  String get settingsCheckUpdateUpToDate;

  /// No description provided for @settingsCheckUpdateAvailable.
  ///
  /// In es, this message translates to:
  /// **'Hay una nueva versión disponible ({version}).'**
  String settingsCheckUpdateAvailable(String version);

  /// No description provided for @settingsCheckUpdateError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo comprobar ahora. Inténtalo en un rato.'**
  String get settingsCheckUpdateError;

  /// No description provided for @settingsAdvanced.
  ///
  /// In es, this message translates to:
  /// **'Avanzado'**
  String get settingsAdvanced;

  /// No description provided for @settingsVersion.
  ///
  /// In es, this message translates to:
  /// **'Versión'**
  String get settingsVersion;

  /// No description provided for @settingsProposeSource.
  ///
  /// In es, this message translates to:
  /// **'Proponer un medio'**
  String get settingsProposeSource;

  /// No description provided for @settingsProposeSourceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'¿Echas en falta un medio alternativo? Sugiérenoslo para revisión.'**
  String get settingsProposeSourceSubtitle;

  /// No description provided for @settingsMyMedia.
  ///
  /// In es, this message translates to:
  /// **'Mis medios'**
  String get settingsMyMedia;

  /// No description provided for @settingsMyMediaSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Tus propias fuentes RSS, pódcast o canales de vídeo. Sólo en tu teléfono.'**
  String get settingsMyMediaSubtitle;

  /// No description provided for @settingsShareApp.
  ///
  /// In es, this message translates to:
  /// **'Compartir la app'**
  String get settingsShareApp;

  /// No description provided for @settingsShareAppSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Pasa la app a quien crea que le puede servir.'**
  String get settingsShareAppSubtitle;

  /// No description provided for @settingsNotifications.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones'**
  String get settingsNotifications;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aviso cuando haya titulares, vídeos o podcasts nuevos.'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @notifTitle.
  ///
  /// In es, this message translates to:
  /// **'Notificaciones de contenido nuevo'**
  String get notifTitle;

  /// No description provided for @notifHelp.
  ///
  /// In es, this message translates to:
  /// **'La app comprueba en background si hay titulares, vídeos o podcasts nuevos y te avisa. Sin servidores push ni tracking — todo se hace en el dispositivo.'**
  String get notifHelp;

  /// No description provided for @notifFreqNever.
  ///
  /// In es, this message translates to:
  /// **'Desactivadas'**
  String get notifFreqNever;

  /// No description provided for @notifFreqHour.
  ///
  /// In es, this message translates to:
  /// **'Cada hora'**
  String get notifFreqHour;

  /// No description provided for @notifFreq3h.
  ///
  /// In es, this message translates to:
  /// **'Cada 3 horas'**
  String get notifFreq3h;

  /// No description provided for @notifFreq6h.
  ///
  /// In es, this message translates to:
  /// **'Cada 6 horas'**
  String get notifFreq6h;

  /// No description provided for @notifFreq12h.
  ///
  /// In es, this message translates to:
  /// **'Cada 12 horas'**
  String get notifFreq12h;

  /// No description provided for @notifFreq24h.
  ///
  /// In es, this message translates to:
  /// **'Una vez al día'**
  String get notifFreq24h;

  /// No description provided for @notifPermissionDenied.
  ///
  /// In es, this message translates to:
  /// **'Has denegado el permiso de notificaciones. La app comprobará en background pero no podrá avisarte hasta que lo concedas en Ajustes del sistema.'**
  String get notifPermissionDenied;

  /// No description provided for @settingsMap.
  ///
  /// In es, this message translates to:
  /// **'Mapa'**
  String get settingsMap;

  /// No description provided for @settingsMapSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Radios y colectivos por territorio.'**
  String get settingsMapSubtitle;

  /// No description provided for @settingsSourcesPrefs.
  ///
  /// In es, this message translates to:
  /// **'Mis medios del directorio'**
  String get settingsSourcesPrefs;

  /// No description provided for @settingsSourcesPrefsSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Silencia fuentes que no quieras ver en el feed.'**
  String get settingsSourcesPrefsSubtitle;

  /// No description provided for @sourcesPrefsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis medios del directorio'**
  String get sourcesPrefsTitle;

  /// No description provided for @sourcesPrefsHelp.
  ///
  /// In es, this message translates to:
  /// **'Desactiva las fuentes que no quieras ver. Los titulares dejan de aparecer en el feed, pero seguirán publicándose para el resto de la instancia.'**
  String get sourcesPrefsHelp;

  /// No description provided for @sourcesPrefsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay fuentes curadas todavía.'**
  String get sourcesPrefsEmpty;

  /// No description provided for @sourcesPrefsResetAll.
  ///
  /// In es, this message translates to:
  /// **'Reactivar todas'**
  String get sourcesPrefsResetAll;

  /// No description provided for @sourcesCategoryAll.
  ///
  /// In es, this message translates to:
  /// **'Todas'**
  String get sourcesCategoryAll;

  /// No description provided for @sourcesCategoryPress.
  ///
  /// In es, this message translates to:
  /// **'Prensa'**
  String get sourcesCategoryPress;

  /// No description provided for @sourcesCategoryAudio.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get sourcesCategoryAudio;

  /// No description provided for @sourcesCategoryVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo'**
  String get sourcesCategoryVideo;

  /// No description provided for @sourcesCategoryFediverse.
  ///
  /// In es, this message translates to:
  /// **'Fediverso'**
  String get sourcesCategoryFediverse;

  /// No description provided for @donationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Apoya el proyecto'**
  String get donationsTitle;

  /// No description provided for @donationsIntro.
  ///
  /// In es, this message translates to:
  /// **'Flavor News Hub es libre y sin publicidad. Si te es útil, estas son las formas de sostenerlo.'**
  String get donationsIntro;

  /// No description provided for @donationsKofi.
  ///
  /// In es, this message translates to:
  /// **'Invita a un café puntual'**
  String get donationsKofi;

  /// No description provided for @donationsPaypal.
  ///
  /// In es, this message translates to:
  /// **'Donación directa'**
  String get donationsPaypal;

  /// No description provided for @donationsBitcoinSegwit.
  ///
  /// In es, this message translates to:
  /// **'Bitcoin (Native SegWit)'**
  String get donationsBitcoinSegwit;

  /// No description provided for @donationsBitcoinTaproot.
  ///
  /// In es, this message translates to:
  /// **'Bitcoin (Taproot)'**
  String get donationsBitcoinTaproot;

  /// No description provided for @donationsCopyAddress.
  ///
  /// In es, this message translates to:
  /// **'Copiar dirección'**
  String get donationsCopyAddress;

  /// No description provided for @donationsAddressCopied.
  ///
  /// In es, this message translates to:
  /// **'Dirección copiada al portapapeles'**
  String get donationsAddressCopied;

  /// No description provided for @donationsShare.
  ///
  /// In es, this message translates to:
  /// **'Comparte el proyecto'**
  String get donationsShare;

  /// No description provided for @donationsShareHelp.
  ///
  /// In es, this message translates to:
  /// **'Recomendar a alguien es otra forma de apoyar — crece por humanos, no por algoritmo.'**
  String get donationsShareHelp;

  /// No description provided for @donationsShareAction.
  ///
  /// In es, this message translates to:
  /// **'Compartir'**
  String get donationsShareAction;

  /// No description provided for @donationsShareMessage.
  ///
  /// In es, this message translates to:
  /// **'Flavor News Hub: app de noticias federada, sin algoritmo ni publicidad.'**
  String get donationsShareMessage;

  /// No description provided for @donationsOtherWays.
  ///
  /// In es, this message translates to:
  /// **'Otras formas de ayudar'**
  String get donationsOtherWays;

  /// No description provided for @donationsHelpStar.
  ///
  /// In es, this message translates to:
  /// **'Dale una estrella en GitHub'**
  String get donationsHelpStar;

  /// No description provided for @donationsHelpBug.
  ///
  /// In es, this message translates to:
  /// **'Reporta bugs o sugiere mejoras'**
  String get donationsHelpBug;

  /// No description provided for @donationsHelpTranslate.
  ///
  /// In es, this message translates to:
  /// **'Ayuda con traducciones'**
  String get donationsHelpTranslate;

  /// No description provided for @donationsHelpContribute.
  ///
  /// In es, this message translates to:
  /// **'Contribuye con código o documentación'**
  String get donationsHelpContribute;

  /// No description provided for @ecosistemaTitle.
  ///
  /// In es, this message translates to:
  /// **'Parte del ecosistema Colección del Nuevo Ser'**
  String get ecosistemaTitle;

  /// No description provided for @ecosistemaSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Visita coleccion-nuevo-ser.gailu.net'**
  String get ecosistemaSubtitle;

  /// No description provided for @updateTitle.
  ///
  /// In es, this message translates to:
  /// **'Nueva versión {version} disponible'**
  String updateTitle(String version);

  /// No description provided for @updateBodyGeneric.
  ///
  /// In es, this message translates to:
  /// **'Hay una actualización disponible. Descárgala para tener las últimas novedades y correcciones.'**
  String get updateBodyGeneric;

  /// No description provided for @updateDownload.
  ///
  /// In es, this message translates to:
  /// **'Descargar'**
  String get updateDownload;

  /// No description provided for @updateDismiss.
  ///
  /// In es, this message translates to:
  /// **'Ahora no'**
  String get updateDismiss;

  /// No description provided for @updateDownloadingTitle.
  ///
  /// In es, this message translates to:
  /// **'Descargando actualización'**
  String get updateDownloadingTitle;

  /// No description provided for @updateDownloadingIndeterminate.
  ///
  /// In es, this message translates to:
  /// **'Preparando…'**
  String get updateDownloadingIndeterminate;

  /// No description provided for @updateDownloadFallback.
  ///
  /// In es, this message translates to:
  /// **'No se pudo descargar dentro de la app. Abriendo en el navegador.'**
  String get updateDownloadFallback;

  /// No description provided for @updateInstallFallback.
  ///
  /// In es, this message translates to:
  /// **'No se pudo abrir el instalador. Abriendo en el navegador.'**
  String get updateInstallFallback;

  /// No description provided for @settingsMusic.
  ///
  /// In es, this message translates to:
  /// **'Música libre'**
  String get settingsMusic;

  /// No description provided for @settingsMusicSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Buscar y escuchar música federada desde Funkwhale.'**
  String get settingsMusicSubtitle;

  /// No description provided for @musicInstanceLabel.
  ///
  /// In es, this message translates to:
  /// **'Instancia Funkwhale'**
  String get musicInstanceLabel;

  /// No description provided for @musicInstanceHelp.
  ///
  /// In es, this message translates to:
  /// **'Pega la URL de una instancia pública (p. ej. https://open.audio/).'**
  String get musicInstanceHelp;

  /// No description provided for @musicInstancePrompt.
  ///
  /// In es, this message translates to:
  /// **'Para escuchar música, añade al menos una instancia Funkwhale.'**
  String get musicInstancePrompt;

  /// No description provided for @musicInstanceCurrent.
  ///
  /// In es, this message translates to:
  /// **'Instancia'**
  String get musicInstanceCurrent;

  /// No description provided for @musicInstancesLabel.
  ///
  /// In es, this message translates to:
  /// **'Instancias Funkwhale'**
  String get musicInstancesLabel;

  /// No description provided for @musicInstancesHelp.
  ///
  /// In es, this message translates to:
  /// **'Puedes añadir varias. La búsqueda consulta todas en paralelo.'**
  String get musicInstancesHelp;

  /// No description provided for @jamendoLabel.
  ///
  /// In es, this message translates to:
  /// **'Jamendo'**
  String get jamendoLabel;

  /// No description provided for @jamendoHelp.
  ///
  /// In es, this message translates to:
  /// **'Catálogo Creative Commons con licencias libres. Pide un client_id gratis y pégalo aquí.'**
  String get jamendoHelp;

  /// No description provided for @jamendoGetKey.
  ///
  /// In es, this message translates to:
  /// **'Conseguir client_id'**
  String get jamendoGetKey;

  /// No description provided for @musicSearchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar canción, artista o álbum…'**
  String get musicSearchHint;

  /// No description provided for @musicSearchPrompt.
  ///
  /// In es, this message translates to:
  /// **'Escribe para buscar música federada.'**
  String get musicSearchPrompt;

  /// No description provided for @musicGenresHeader.
  ///
  /// In es, this message translates to:
  /// **'Géneros'**
  String get musicGenresHeader;

  /// No description provided for @musicNewHeader.
  ///
  /// In es, this message translates to:
  /// **'Novedades'**
  String get musicNewHeader;

  /// No description provided for @musicNewEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay novedades ahora mismo.'**
  String get musicNewEmpty;

  /// No description provided for @personalSourcesTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis medios'**
  String get personalSourcesTitle;

  /// No description provided for @personalSourcesEmpty.
  ///
  /// In es, this message translates to:
  /// **'Aún no has añadido ningún medio propio.'**
  String get personalSourcesEmpty;

  /// No description provided for @personalSourcesEmptyHelp.
  ///
  /// In es, this message translates to:
  /// **'Los medios que añadas aquí se quedan en tu teléfono y sus titulares se mezclan con el feed principal.'**
  String get personalSourcesEmptyHelp;

  /// No description provided for @personalSourcesAdd.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get personalSourcesAdd;

  /// No description provided for @personalSourcesAddAction.
  ///
  /// In es, this message translates to:
  /// **'Añadir'**
  String get personalSourcesAddAction;

  /// No description provided for @personalSourcesRemove.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get personalSourcesRemove;

  /// No description provided for @personalSourcesRemoveTitle.
  ///
  /// In es, this message translates to:
  /// **'¿Eliminar este medio?'**
  String get personalSourcesRemoveTitle;

  /// No description provided for @personalSourcesFieldName.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get personalSourcesFieldName;

  /// No description provided for @personalSourcesFieldUrl.
  ///
  /// In es, this message translates to:
  /// **'URL del feed'**
  String get personalSourcesFieldUrl;

  /// No description provided for @personalSourcesFieldUrlHelp.
  ///
  /// In es, this message translates to:
  /// **'RSS/Atom del medio. Para YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. Para pódcast iVoox: la URL del feed del programa.'**
  String get personalSourcesFieldUrlHelp;

  /// No description provided for @personalSourcesFieldType.
  ///
  /// In es, this message translates to:
  /// **'Tipo'**
  String get personalSourcesFieldType;

  /// No description provided for @personalSourcesRequiredUrl.
  ///
  /// In es, this message translates to:
  /// **'Hace falta la URL del feed.'**
  String get personalSourcesRequiredUrl;

  /// No description provided for @personalSourcesInvalidUrl.
  ///
  /// In es, this message translates to:
  /// **'Debe empezar por http:// o https:// y tener dominio.'**
  String get personalSourcesInvalidUrl;

  /// No description provided for @personalSourcesAddedSnackbar.
  ///
  /// In es, this message translates to:
  /// **'Medio añadido. Refresca el feed para ver sus titulares.'**
  String get personalSourcesAddedSnackbar;

  /// No description provided for @personalSourcesAlreadyExists.
  ///
  /// In es, this message translates to:
  /// **'Ese feed ya está en tu lista.'**
  String get personalSourcesAlreadyExists;

  /// No description provided for @personalSourcesExport.
  ///
  /// In es, this message translates to:
  /// **'Copiar lista al portapapeles'**
  String get personalSourcesExport;

  /// No description provided for @personalSourcesImport.
  ///
  /// In es, this message translates to:
  /// **'Pegar lista desde portapapeles'**
  String get personalSourcesImport;

  /// No description provided for @personalSourcesExportedSnackbar.
  ///
  /// In es, this message translates to:
  /// **'Lista copiada al portapapeles.'**
  String get personalSourcesExportedSnackbar;

  /// No description provided for @personalSourcesImportEmpty.
  ///
  /// In es, this message translates to:
  /// **'El portapapeles está vacío.'**
  String get personalSourcesImportEmpty;

  /// No description provided for @personalSourcesImportInvalid.
  ///
  /// In es, this message translates to:
  /// **'El contenido del portapapeles no es una lista válida.'**
  String get personalSourcesImportInvalid;

  /// No description provided for @personalSourcesImportedSnackbar.
  ///
  /// In es, this message translates to:
  /// **'Importadas {count} fuentes.'**
  String personalSourcesImportedSnackbar(int count);

  /// No description provided for @personalSourcesNote.
  ///
  /// In es, this message translates to:
  /// **'Los titulares de estos medios se descargan desde tu teléfono cada vez que refrescas el feed. Nada se comparte con el servidor.'**
  String get personalSourcesNote;

  /// No description provided for @personalSourcesCategoryReading.
  ///
  /// In es, this message translates to:
  /// **'Lectura'**
  String get personalSourcesCategoryReading;

  /// No description provided for @personalSourcesCategoryAudio.
  ///
  /// In es, this message translates to:
  /// **'Audio'**
  String get personalSourcesCategoryAudio;

  /// No description provided for @personalSourcesCategoryVideo.
  ///
  /// In es, this message translates to:
  /// **'Vídeo'**
  String get personalSourcesCategoryVideo;

  /// No description provided for @personalSourcesDiscoverFeed.
  ///
  /// In es, this message translates to:
  /// **'Buscar feed automáticamente'**
  String get personalSourcesDiscoverFeed;

  /// No description provided for @personalSourcesDiscoverNothing.
  ///
  /// In es, this message translates to:
  /// **'No hemos encontrado ningún feed en esa URL. Pégala directamente si la conoces.'**
  String get personalSourcesDiscoverNothing;

  /// No description provided for @personalSourcesDiscoverPickerTitle.
  ///
  /// In es, this message translates to:
  /// **'Hemos encontrado varios feeds'**
  String get personalSourcesDiscoverPickerTitle;

  /// No description provided for @sourceSubmitTitle.
  ///
  /// In es, this message translates to:
  /// **'Proponer un medio'**
  String get sourceSubmitTitle;

  /// No description provided for @sourceSubmitIntro.
  ///
  /// In es, this message translates to:
  /// **'Propón un medio (web, podcast, canal de vídeo, cuenta de Mastodon…). El equipo editorial lo revisará antes de activarlo.'**
  String get sourceSubmitIntro;

  /// No description provided for @sourceSubmitName.
  ///
  /// In es, this message translates to:
  /// **'Nombre del medio'**
  String get sourceSubmitName;

  /// No description provided for @sourceSubmitFeedUrl.
  ///
  /// In es, this message translates to:
  /// **'URL del feed'**
  String get sourceSubmitFeedUrl;

  /// No description provided for @sourceSubmitFeedUrlHelp.
  ///
  /// In es, this message translates to:
  /// **'RSS/Atom: pega la URL del feed. YouTube: pega la URL del canal, ya la resolvemos al verificar.'**
  String get sourceSubmitFeedUrlHelp;

  /// No description provided for @sourceSubmitFeedType.
  ///
  /// In es, this message translates to:
  /// **'Tipo de feed'**
  String get sourceSubmitFeedType;

  /// No description provided for @sourceSubmitDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción (opcional)'**
  String get sourceSubmitDescription;

  /// No description provided for @sourceSubmitWebsiteUrl.
  ///
  /// In es, this message translates to:
  /// **'Web del medio (opcional)'**
  String get sourceSubmitWebsiteUrl;

  /// No description provided for @sourceSubmitTerritory.
  ///
  /// In es, this message translates to:
  /// **'Territorio (opcional)'**
  String get sourceSubmitTerritory;

  /// No description provided for @sourceSubmitLanguages.
  ///
  /// In es, this message translates to:
  /// **'Idiomas del contenido'**
  String get sourceSubmitLanguages;

  /// No description provided for @sourceSubmitEmailHelp.
  ///
  /// In es, this message translates to:
  /// **'No se publica; sólo se usa si el equipo necesita escribirte.'**
  String get sourceSubmitEmailHelp;

  /// No description provided for @sourceSubmitSuccess.
  ///
  /// In es, this message translates to:
  /// **'Gracias. Revisaremos la propuesta y el medio aparecerá cuando esté verificado.'**
  String get sourceSubmitSuccess;

  /// No description provided for @sourceSubmitRequiredFeedUrl.
  ///
  /// In es, this message translates to:
  /// **'Hace falta la URL del feed.'**
  String get sourceSubmitRequiredFeedUrl;

  /// No description provided for @sourceSubmitInvalidFeedUrl.
  ///
  /// In es, this message translates to:
  /// **'La URL del feed debe empezar por http:// o https://'**
  String get sourceSubmitInvalidFeedUrl;

  /// No description provided for @aboutTitle.
  ///
  /// In es, this message translates to:
  /// **'Acerca de'**
  String get aboutTitle;

  /// No description provided for @aboutManifestoHeader.
  ///
  /// In es, this message translates to:
  /// **'Qué es esto'**
  String get aboutManifestoHeader;

  /// No description provided for @aboutManifestoBody.
  ///
  /// In es, this message translates to:
  /// **'Una herramienta sencilla para romper el circuito entre informarse y actuar. Sin algoritmo de engagement, sin tracking, sin publicidad. AGPL-3.0.'**
  String get aboutManifestoBody;

  /// No description provided for @aboutRepository.
  ///
  /// In es, this message translates to:
  /// **'Repositorio'**
  String get aboutRepository;

  /// No description provided for @aboutLicense.
  ///
  /// In es, this message translates to:
  /// **'Licencia'**
  String get aboutLicense;

  /// No description provided for @commonBack.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get commonBack;

  /// No description provided for @commonRetry.
  ///
  /// In es, this message translates to:
  /// **'Reintentar'**
  String get commonRetry;

  /// No description provided for @commonClose.
  ///
  /// In es, this message translates to:
  /// **'Cerrar'**
  String get commonClose;

  /// No description provided for @commonCancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get commonCancel;

  /// No description provided for @commonOk.
  ///
  /// In es, this message translates to:
  /// **'Aceptar'**
  String get commonOk;

  /// No description provided for @searchTooltip.
  ///
  /// In es, this message translates to:
  /// **'Buscar'**
  String get searchTooltip;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar en noticias, medios, radios…'**
  String get searchHint;

  /// No description provided for @searchPromptHint.
  ///
  /// In es, this message translates to:
  /// **'Escribe para buscar en toda la app.'**
  String get searchPromptHint;

  /// No description provided for @searchNoResults.
  ///
  /// In es, this message translates to:
  /// **'Ningún resultado.'**
  String get searchNoResults;

  /// No description provided for @searchSectionItems.
  ///
  /// In es, this message translates to:
  /// **'Noticias'**
  String get searchSectionItems;

  /// No description provided for @searchSectionSources.
  ///
  /// In es, this message translates to:
  /// **'Medios'**
  String get searchSectionSources;

  /// No description provided for @searchSectionRadios.
  ///
  /// In es, this message translates to:
  /// **'Radios'**
  String get searchSectionRadios;

  /// No description provided for @searchSectionCollectives.
  ///
  /// In es, this message translates to:
  /// **'Colectivos'**
  String get searchSectionCollectives;

  /// No description provided for @radioWebsite.
  ///
  /// In es, this message translates to:
  /// **'Web'**
  String get radioWebsite;

  /// No description provided for @radioPrograms.
  ///
  /// In es, this message translates to:
  /// **'Programas'**
  String get radioPrograms;

  /// No description provided for @radioProgramsEmpty.
  ///
  /// In es, this message translates to:
  /// **'No hay programas publicados en el feed.'**
  String get radioProgramsEmpty;

  /// No description provided for @radioProgramsFetchError.
  ///
  /// In es, this message translates to:
  /// **'No se pudo cargar el feed de programas.'**
  String get radioProgramsFetchError;

  /// No description provided for @flavorActivityHeader.
  ///
  /// In es, this message translates to:
  /// **'Actividad en Flavor'**
  String get flavorActivityHeader;

  /// No description provided for @flavorActivityEvents.
  ///
  /// In es, this message translates to:
  /// **'Eventos'**
  String get flavorActivityEvents;

  /// No description provided for @flavorActivityContent.
  ///
  /// In es, this message translates to:
  /// **'Catálogo'**
  String get flavorActivityContent;

  /// No description provided for @flavorActivityBoard.
  ///
  /// In es, this message translates to:
  /// **'Tablón'**
  String get flavorActivityBoard;

  /// No description provided for @flavorActivityEmpty.
  ///
  /// In es, this message translates to:
  /// **'Este nodo no publica actividad pública ahora mismo.'**
  String get flavorActivityEmpty;

  /// Entrada de Ajustes para compartir la traza del último fallo registrado.
  ///
  /// In es, this message translates to:
  /// **'Compartir informe de error'**
  String get settingsErrorReport;

  /// Subtítulo de la entrada de Ajustes para compartir el informe de error.
  ///
  /// In es, this message translates to:
  /// **'Se registró un fallo reciente. Compártelo para ayudar a arreglarlo; no se envía nada solo.'**
  String get settingsErrorReportSubtitle;

  /// Acción para borrar el informe de error guardado.
  ///
  /// In es, this message translates to:
  /// **'Descartar informe'**
  String get settingsErrorReportDismiss;

  /// Acción para revertir la última acción, en el SnackBar de confirmación.
  ///
  /// In es, this message translates to:
  /// **'Deshacer'**
  String get commonUndo;

  /// Confirmación al guardar un titular.
  ///
  /// In es, this message translates to:
  /// **'Guardado'**
  String get feedItemSaved;

  /// Confirmación al marcar un titular como útil.
  ///
  /// In es, this message translates to:
  /// **'Marcado como útil'**
  String get feedItemMarkedUseful;

  /// Confirmación al silenciar una fuente.
  ///
  /// In es, this message translates to:
  /// **'Fuente silenciada'**
  String get sourceMuted;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ca', 'en', 'es', 'eu', 'gl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ca':
      return AppLocalizationsCa();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'eu':
      return AppLocalizationsEu();
    case 'gl':
      return AppLocalizationsGl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
