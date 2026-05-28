// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appName => 'Flavor News Hub';

  @override
  String get appTagline => 'Medios alternativos y colectivos que se organizan';

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
  String get tabSettings => 'Ajustes';

  @override
  String get tabTv => 'TV';

  @override
  String get tvTabMedios => 'Medios';

  @override
  String get tvTabUltimas => 'Últimas emisiones';

  @override
  String get tvEmptyMedios =>
      'No hay canales de TV todavía. Se añadirán desde Admin o al importar el catálogo.';

  @override
  String get tvEmptyUltimas => 'Sin emisiones recientes de los canales de TV.';

  @override
  String get radiosTitle => 'Radios libres';

  @override
  String get radiosEmpty => 'No hay radios en esta instancia.';

  @override
  String get radiosOnlyFavorites => 'Sólo mis radios';

  @override
  String get radiosOnlyFavoritesEmpty => 'Aún no tienes radios favoritas.';

  @override
  String get radiosOnlyFavoritesHint =>
      'Marca radios como favoritas para tenerlas arriba.';

  @override
  String get radiosOnlyFavoritesActive =>
      'Mostrando sólo tus radios favoritas.';

  @override
  String get radiosStreamError =>
      'No se pudo conectar con el stream. Toca para reintentar.';

  @override
  String get videosTitle => 'Vídeos';

  @override
  String get videosEmpty =>
      'No hay vídeos ahora mismo. Añade canales de YouTube desde Ajustes → Mis medios para que aparezcan aquí.';

  @override
  String get videosPlayNext => 'Siguiente vídeo';

  @override
  String get videosOnlyFavorites => 'Sólo mis canales';

  @override
  String get playerSpeed => 'Velocidad';

  @override
  String get playerSleepTimer => 'Apagar en…';

  @override
  String get itemCopyLink => 'Copiar enlace';

  @override
  String get itemLinkCopied => 'Enlace copiado.';

  @override
  String get savedSearchHint => 'Filtrar guardados…';

  @override
  String get historyTitle => 'Historial de lectura';

  @override
  String get historyEmpty =>
      'Aún no has leído ningún titular. Los que abras aparecerán aquí.';

  @override
  String get settingsHistory => 'Historial';

  @override
  String get settingsHistorySubtitle => 'Titulares que has abierto.';

  @override
  String get opmlExport => 'Exportar mis medios (OPML)';

  @override
  String get opmlImport => 'Importar OPML…';

  @override
  String get opmlExportCopied => 'OPML copiado al portapapeles.';

  @override
  String get opmlImportHint => 'Pega aquí el contenido OPML de otro agregador.';

  @override
  String opmlImportSuccess(int count) {
    return 'Importadas $count fuentes.';
  }

  @override
  String get opmlImportEmpty => 'No se encontraron fuentes válidas en el OPML.';

  @override
  String get privacyPolicyTitle => 'Política de privacidad';

  @override
  String get videoDescription => 'Descripción';

  @override
  String videoOpenExternal(String platform) {
    return 'Ver en $platform';
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
      'Los comentarios se ven en la plataforma original.';

  @override
  String get feedTitle => 'Titulares';

  @override
  String get feedEmpty => 'Todavía no hay noticias cargadas.';

  @override
  String get feedEmptyWithFilters =>
      'Ningún titular coincide con los filtros activos. Límpialos para ver todo.';

  @override
  String get feedLoading => 'Cargando titulares…';

  @override
  String get feedError => 'No se pudo cargar el feed.';

  @override
  String get filtersTitle => 'Filtros';

  @override
  String get filterByTopic => 'Por temática';

  @override
  String get filterTopicsOffline =>
      'Sin conexión con el servidor: las temáticas no están disponibles. Vuelve a intentarlo cuando haya señal.';

  @override
  String get filterByTerritory => 'Por territorio';

  @override
  String get filterByLanguage => 'Por idioma';

  @override
  String get filtersClear => 'Limpiar filtros';

  @override
  String get filtersApply => 'Aplicar';

  @override
  String itemOpenInSource(String sourceName) {
    return 'Leer en $sourceName';
  }

  @override
  String get itemShare => 'Compartir';

  @override
  String get itemSave => 'Guardar';

  @override
  String get itemUnsave => 'Quitar de guardados';

  @override
  String get itemMarkUseful => 'Marcar como útil';

  @override
  String get itemUnmarkUseful => 'Quitar de útiles';

  @override
  String get settingsTusIntereses => 'Tus intereses';

  @override
  String get settingsTusInteresesSubtitle =>
      'Qué temáticas y medios te están interesando más';

  @override
  String get tusInteresesTitle => 'Tus intereses';

  @override
  String get tusInteresesEmpty =>
      'Aún no has marcado ningún titular como útil.';

  @override
  String get tusInteresesEmptyHelp =>
      'Usa el botón de la bombilla (💡) en cada noticia para marcarla útil. Aquí verás un resumen con tus temáticas y medios más recurrentes — nada viaja al servidor.';

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
  String get tusInteresesTopTopics => 'Temáticas que más te interesan';

  @override
  String get tusInteresesTopSources => 'Medios que más te interesan';

  @override
  String get tusInteresesFormats => 'Formato preferido';

  @override
  String get tusInteresesApplyFilter => 'Aplicar estas temáticas al feed';

  @override
  String get feedOfflineBanner =>
      'Modo autónomo. Titulares descargados directos desde los medios.';

  @override
  String get savedTitle => 'Guardados';

  @override
  String get savedSubtitle => 'Titulares que has marcado para leer después.';

  @override
  String get savedEmpty =>
      'Aún no has guardado ningún titular. Desde el feed o desde el detalle, usa el icono del marcador.';

  @override
  String get savedTabNews => 'Titulares';

  @override
  String get savedTabAudio => 'Mi audio';

  @override
  String get savedAudioEmpty =>
      'Todavía no has marcado como favorito ningún pódcast ni canción. En el reproductor pulsa el corazón.';

  @override
  String get itemOrganizingTitle => '¿Quién se organiza sobre esto?';

  @override
  String get itemOrganizingEmpty =>
      'Aún no hay colectivos verificados en este directorio sobre estas temáticas. Si tu colectivo encaja, puedes darlo de alta.';

  @override
  String get itemOrganizingSeeAll => 'Ver todos';

  @override
  String get sourceTitle => 'Medio';

  @override
  String get sourceListNews => 'Ver noticias de este medio';

  @override
  String get sourceListVideos => 'Ver vídeos de este canal';

  @override
  String get sourceListAudio => 'Ver episodios de este podcast';

  @override
  String get tabPodcasts => 'Podcast';

  @override
  String get podcastsEmpty =>
      'Aún no hay episodios de podcast. Los medios del directorio con feed_type=podcast aparecen aquí cuando publican.';

  @override
  String get sourceEditorialHeader => 'Ficha editorial';

  @override
  String get sourceOwnership => 'Propiedad y financiación';

  @override
  String get sourceEditorialNote => 'Línea editorial declarada';

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
  String get colectivosTabNoticias => 'Movimientos';

  @override
  String get colectivosTabDirectorio => 'Directorio';

  @override
  String get directoryEmpty =>
      'Aún no hay colectivos verificados en esta instancia.';

  @override
  String get directoryAddCta => '¿Tu colectivo no está aquí? Añádelo';

  @override
  String get collectiveVisitWebsite => 'Visitar web';

  @override
  String get collectiveFlavorCommunity => 'Comunidad en Flavor';

  @override
  String get collectiveShare => 'Compartir';

  @override
  String get collectiveMediaTitle => 'Medios que edita';

  @override
  String get collectiveMediaEmpty =>
      'Este colectivo no tiene medios vinculados.';

  @override
  String get submitTitle => 'Dar de alta un colectivo';

  @override
  String get submitName => 'Nombre del colectivo';

  @override
  String get submitDescription => 'Descripción';

  @override
  String get submitWebsite => 'Web (opcional)';

  @override
  String get submitContactEmail => 'Email de contacto';

  @override
  String get submitTerritory => 'Territorio (opcional)';

  @override
  String get submitFlavorUrl => 'URL de su instancia Flavor (opcional)';

  @override
  String get submitTopics => 'Temáticas en las que trabaja';

  @override
  String get submitSend => 'Enviar';

  @override
  String get submitSuccess =>
      'Gracias. Revisaremos tu alta y aparecerá en el directorio cuando esté verificada.';

  @override
  String get submitErrorGeneric =>
      'No hemos podido enviar el alta. Inténtalo de nuevo más tarde.';

  @override
  String get submitErrorRateLimited =>
      'Demasiadas peticiones desde esta conexión. Prueba en un rato.';

  @override
  String get submitRequiredName => 'El nombre es obligatorio.';

  @override
  String get submitRequiredDescription => 'La descripción es obligatoria.';

  @override
  String get submitRequiredEmail => 'Hace falta un email de contacto válido.';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsInterfaceLanguage => 'Idioma de la interfaz';

  @override
  String get settingsInterfaceLanguageSystem => 'Seguir sistema';

  @override
  String get settingsMyTerritory => 'Mi territorio';

  @override
  String get settingsMyTerritorySubtitle =>
      'Desde aquí, los contenidos cercanos aparecen primero. Los globales siguen visibles debajo.';

  @override
  String get settingsMyTerritoryNone =>
      'Sin territorio (mostrar todo por igual)';

  @override
  String get settingsMyTerritoryChoose => 'Elige tu territorio base';

  @override
  String get settingsContentLanguage => 'Idioma del contenido';

  @override
  String get settingsContentLanguageSubtitle =>
      'Decide qué idiomas quieres ver en titulares, vídeos, radios y podcasts.';

  @override
  String get settingsContentLanguageFollowUi =>
      'Seguir el idioma de la interfaz';

  @override
  String get settingsContentLanguageManual => 'Elegir varios manualmente';

  @override
  String get settingsContentLanguageOff => 'Mostrar todos los idiomas';

  @override
  String get settingsContentLanguageManualHint =>
      'Marca los idiomas que quieres ver. Vacío = sin filtro.';

  @override
  String get supportEntity => 'Apoyar';

  @override
  String get movimientosTitle => 'Voces de movimientos';

  @override
  String get movimientosSubtitle =>
      'Medios pequeños y colectivos cuyas publicaciones quedan tapadas en el feed general por agregadores prolíficos.';

  @override
  String get movimientosEmpty =>
      'Aún no hay publicaciones de movimientos. Volverán cuando los medios marcados publiquen.';

  @override
  String get movimientosEmptyHint =>
      'Si esta lista no se llena nunca, puede que tu instancia aún no tenga medios marcados como voz de movimiento. El admin puede activarlos desde el panel.';

  @override
  String get settingsMovimientos => 'Voces de movimientos';

  @override
  String get settingsMovimientosSubtitle =>
      'Sección dedicada a medios y colectivos pequeños o militantes.';

  @override
  String get shareAppMessage =>
      'Flavor News Hub — Una app, todos los medios alternativos\n\nQué encontrarás:\n• Titulares de medios alternativos (es/eu/ca/gl), ordenados por fecha. Sin algoritmo.\n• Vídeos y canales de TV libres.\n• Radios en directo y podcasts.\n• Música libre (Funkwhale, Audius, Jamendo, Archive.org).\n• Directorio de colectivos y mapa para encontrarlos.\n• Sin publicidad, sin tracking, sin cuenta.\n\nInstalación en Android:\n1. Toca el enlace para descargar el APK:\n   https://github.com/JosuIru/flavor-news-hub/releases/latest/download/flavor-news-hub-app.apk\n2. El navegador te avisará de que el archivo \"podría dañar tu dispositivo\". Pulsa \"Conservar\" (o \"Descargar igualmente\").\n3. Abre el APK descargado. La primera vez Android te pedirá permiso para que tu navegador instale apps desde fuentes desconocidas — concédelo.\n4. Es posible que aparezca otro aviso de Google Play Protect tipo \"esta app no se ha verificado\" o \"puede ser peligrosa\". Pulsa \"Instalar de todos modos\" (o \"Más detalles\" → \"Instalar de todos modos\").\n5. Listo. Abre la app.\n\nPor qué salen esos avisos: Android marca como \"no verificada\" cualquier app que no venga de Google Play, aunque sea código abierto y auditable. Flavor News Hub es libre (AGPL-3.0), todo el código está en GitHub y no envía telemetría — los avisos son la política por defecto de Android, no un problema real de la app.\n\nCódigo abierto · AGPL-3.0';

  @override
  String get onboardingTerritoryTitle => 'De lo local a lo global';

  @override
  String get onboardingTerritoryBody =>
      'Elige tu territorio para que lo cercano aparezca primero. Todo lo demás sigue visible detrás — no se oculta nada. Siempre puedes cambiarlo en Ajustes.';

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
  String get settingsThemeDark => 'Oscuro';

  @override
  String get settingsTextScale => 'Tamaño del texto';

  @override
  String get settingsBackendUrl => 'URL de la instancia';

  @override
  String get settingsBackendUrlDescription =>
      'Si cambias esto, la app consumirá los datos de otra instancia de Flavor News Hub.';

  @override
  String get settingsAbout => 'Acerca de';

  @override
  String get settingsCheckUpdate => 'Comprobar actualizaciones';

  @override
  String get settingsCheckUpdateSubtitle =>
      'Forzar comprobación ahora saltando la caché.';

  @override
  String get settingsCheckUpdateChecking => 'Comprobando…';

  @override
  String get settingsCheckUpdateUpToDate => 'Ya tienes la última versión.';

  @override
  String settingsCheckUpdateAvailable(String version) {
    return 'Hay una nueva versión disponible ($version).';
  }

  @override
  String get settingsCheckUpdateError =>
      'No se pudo comprobar ahora. Inténtalo en un rato.';

  @override
  String get settingsAdvanced => 'Avanzado';

  @override
  String get settingsVersion => 'Versión';

  @override
  String get settingsProposeSource => 'Proponer un medio';

  @override
  String get settingsProposeSourceSubtitle =>
      '¿Echas en falta un medio alternativo? Sugiérenoslo para revisión.';

  @override
  String get settingsMyMedia => 'Mis medios';

  @override
  String get settingsMyMediaSubtitle =>
      'Tus propias fuentes RSS, pódcast o canales de vídeo. Sólo en tu teléfono.';

  @override
  String get settingsShareApp => 'Compartir la app';

  @override
  String get settingsShareAppSubtitle =>
      'Pasa la app a quien crea que le puede servir.';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsNotificationsSubtitle =>
      'Aviso cuando haya titulares, vídeos o podcasts nuevos.';

  @override
  String get notifTitle => 'Notificaciones de contenido nuevo';

  @override
  String get notifHelp =>
      'La app comprueba en background si hay titulares, vídeos o podcasts nuevos y te avisa. Sin servidores push ni tracking — todo se hace en el dispositivo.';

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
  String get notifFreq24h => 'Una vez al día';

  @override
  String get notifPermissionDenied =>
      'Has denegado el permiso de notificaciones. La app comprobará en background pero no podrá avisarte hasta que lo concedas en Ajustes del sistema.';

  @override
  String get settingsMap => 'Mapa';

  @override
  String get settingsMapSubtitle => 'Radios y colectivos por territorio.';

  @override
  String get settingsSourcesPrefs => 'Mis medios del directorio';

  @override
  String get settingsSourcesPrefsSubtitle =>
      'Silencia fuentes que no quieras ver en el feed.';

  @override
  String get sourcesPrefsTitle => 'Mis medios del directorio';

  @override
  String get sourcesPrefsHelp =>
      'Desactiva las fuentes que no quieras ver. Los titulares dejan de aparecer en el feed, pero seguirán publicándose para el resto de la instancia.';

  @override
  String get sourcesPrefsEmpty => 'No hay fuentes curadas todavía.';

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
  String get donationsTitle => 'Apoya el proyecto';

  @override
  String get donationsIntro =>
      'Flavor News Hub es libre y sin publicidad. Si te es útil, estas son las formas de sostenerlo.';

  @override
  String get donationsKofi => 'Invita a un café puntual';

  @override
  String get donationsPaypal => 'Donación directa';

  @override
  String get donationsBitcoinSegwit => 'Bitcoin (Native SegWit)';

  @override
  String get donationsBitcoinTaproot => 'Bitcoin (Taproot)';

  @override
  String get donationsCopyAddress => 'Copiar dirección';

  @override
  String get donationsAddressCopied => 'Dirección copiada al portapapeles';

  @override
  String get donationsShare => 'Comparte el proyecto';

  @override
  String get donationsShareHelp =>
      'Recomendar a alguien es otra forma de apoyar — crece por humanos, no por algoritmo.';

  @override
  String get donationsShareAction => 'Compartir';

  @override
  String get donationsShareMessage =>
      'Flavor News Hub: app de noticias federada, sin algoritmo ni publicidad.';

  @override
  String get donationsOtherWays => 'Otras formas de ayudar';

  @override
  String get donationsHelpStar => 'Dale una estrella en GitHub';

  @override
  String get donationsHelpBug => 'Reporta bugs o sugiere mejoras';

  @override
  String get donationsHelpTranslate => 'Ayuda con traducciones';

  @override
  String get donationsHelpContribute => 'Contribuye con código o documentación';

  @override
  String get ecosistemaTitle => 'Parte del ecosistema Colección del Nuevo Ser';

  @override
  String get ecosistemaSubtitle => 'Visita coleccion-nuevo-ser.gailu.net';

  @override
  String updateTitle(String version) {
    return 'Nueva versión $version disponible';
  }

  @override
  String get updateBodyGeneric =>
      'Hay una actualización disponible. Descárgala para tener las últimas novedades y correcciones.';

  @override
  String get updateDownload => 'Descargar';

  @override
  String get updateDismiss => 'Ahora no';

  @override
  String get updateDownloadingTitle => 'Descargando actualización';

  @override
  String get updateDownloadingIndeterminate => 'Preparando…';

  @override
  String get updateDownloadFallback =>
      'No se pudo descargar dentro de la app. Abriendo en el navegador.';

  @override
  String get updateInstallFallback =>
      'No se pudo abrir el instalador. Abriendo en el navegador.';

  @override
  String get settingsMusic => 'Música libre';

  @override
  String get settingsMusicSubtitle =>
      'Buscar y escuchar música federada desde Funkwhale.';

  @override
  String get musicInstanceLabel => 'Instancia Funkwhale';

  @override
  String get musicInstanceHelp =>
      'Pega la URL de una instancia pública (p. ej. https://open.audio/).';

  @override
  String get musicInstancePrompt =>
      'Para escuchar música, añade al menos una instancia Funkwhale.';

  @override
  String get musicInstanceCurrent => 'Instancia';

  @override
  String get musicInstancesLabel => 'Instancias Funkwhale';

  @override
  String get musicInstancesHelp =>
      'Puedes añadir varias. La búsqueda consulta todas en paralelo.';

  @override
  String get jamendoLabel => 'Jamendo';

  @override
  String get jamendoHelp =>
      'Catálogo Creative Commons con licencias libres. Pide un client_id gratis y pégalo aquí.';

  @override
  String get jamendoGetKey => 'Conseguir client_id';

  @override
  String get musicSearchHint => 'Buscar canción, artista o álbum…';

  @override
  String get musicSearchPrompt => 'Escribe para buscar música federada.';

  @override
  String get musicGenresHeader => 'Géneros';

  @override
  String get musicNewHeader => 'Novedades';

  @override
  String get musicNewEmpty => 'No hay novedades ahora mismo.';

  @override
  String get personalSourcesTitle => 'Mis medios';

  @override
  String get personalSourcesEmpty => 'Aún no has añadido ningún medio propio.';

  @override
  String get personalSourcesEmptyHelp =>
      'Los medios que añadas aquí se quedan en tu teléfono y sus titulares se mezclan con el feed principal.';

  @override
  String get personalSourcesAdd => 'Añadir';

  @override
  String get personalSourcesAddAction => 'Añadir';

  @override
  String get personalSourcesRemove => 'Eliminar';

  @override
  String get personalSourcesRemoveTitle => '¿Eliminar este medio?';

  @override
  String get personalSourcesFieldName => 'Nombre';

  @override
  String get personalSourcesFieldUrl => 'URL del feed';

  @override
  String get personalSourcesFieldUrlHelp =>
      'RSS/Atom del medio. Para YouTube: https://www.youtube.com/feeds/videos.xml?channel_id=UCxxx. Para pódcast iVoox: la URL del feed del programa.';

  @override
  String get personalSourcesFieldType => 'Tipo';

  @override
  String get personalSourcesRequiredUrl => 'Hace falta la URL del feed.';

  @override
  String get personalSourcesInvalidUrl =>
      'Debe empezar por http:// o https:// y tener dominio.';

  @override
  String get personalSourcesAddedSnackbar =>
      'Medio añadido. Refresca el feed para ver sus titulares.';

  @override
  String get personalSourcesAlreadyExists => 'Ese feed ya está en tu lista.';

  @override
  String get personalSourcesExport => 'Copiar lista al portapapeles';

  @override
  String get personalSourcesImport => 'Pegar lista desde portapapeles';

  @override
  String get personalSourcesExportedSnackbar =>
      'Lista copiada al portapapeles.';

  @override
  String get personalSourcesImportEmpty => 'El portapapeles está vacío.';

  @override
  String get personalSourcesImportInvalid =>
      'El contenido del portapapeles no es una lista válida.';

  @override
  String personalSourcesImportedSnackbar(int count) {
    return 'Importadas $count fuentes.';
  }

  @override
  String get personalSourcesNote =>
      'Los titulares de estos medios se descargan desde tu teléfono cada vez que refrescas el feed. Nada se comparte con el servidor.';

  @override
  String get personalSourcesCategoryReading => 'Lectura';

  @override
  String get personalSourcesCategoryAudio => 'Audio';

  @override
  String get personalSourcesCategoryVideo => 'Vídeo';

  @override
  String get personalSourcesDiscoverFeed => 'Buscar feed automáticamente';

  @override
  String get personalSourcesDiscoverNothing =>
      'No hemos encontrado ningún feed en esa URL. Pégala directamente si la conoces.';

  @override
  String get personalSourcesDiscoverPickerTitle =>
      'Hemos encontrado varios feeds';

  @override
  String get sourceSubmitTitle => 'Proponer un medio';

  @override
  String get sourceSubmitIntro =>
      'Propón un medio (web, podcast, canal de vídeo, cuenta de Mastodon…). El equipo editorial lo revisará antes de activarlo.';

  @override
  String get sourceSubmitName => 'Nombre del medio';

  @override
  String get sourceSubmitFeedUrl => 'URL del feed';

  @override
  String get sourceSubmitFeedUrlHelp =>
      'RSS/Atom: pega la URL del feed. YouTube: pega la URL del canal, ya la resolvemos al verificar.';

  @override
  String get sourceSubmitFeedType => 'Tipo de feed';

  @override
  String get sourceSubmitDescription => 'Descripción (opcional)';

  @override
  String get sourceSubmitWebsiteUrl => 'Web del medio (opcional)';

  @override
  String get sourceSubmitTerritory => 'Territorio (opcional)';

  @override
  String get sourceSubmitLanguages => 'Idiomas del contenido';

  @override
  String get sourceSubmitEmailHelp =>
      'No se publica; sólo se usa si el equipo necesita escribirte.';

  @override
  String get sourceSubmitSuccess =>
      'Gracias. Revisaremos la propuesta y el medio aparecerá cuando esté verificado.';

  @override
  String get sourceSubmitRequiredFeedUrl => 'Hace falta la URL del feed.';

  @override
  String get sourceSubmitInvalidFeedUrl =>
      'La URL del feed debe empezar por http:// o https://';

  @override
  String get aboutTitle => 'Acerca de';

  @override
  String get aboutManifestoHeader => 'Qué es esto';

  @override
  String get aboutManifestoBody =>
      'Una herramienta sencilla para romper el circuito entre informarse y actuar. Sin algoritmo de engagement, sin tracking, sin publicidad. AGPL-3.0.';

  @override
  String get aboutRepository => 'Repositorio';

  @override
  String get aboutLicense => 'Licencia';

  @override
  String get commonBack => 'Volver';

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonClose => 'Cerrar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonOk => 'Aceptar';

  @override
  String get searchTooltip => 'Buscar';

  @override
  String get searchHint => 'Buscar en noticias, medios, radios…';

  @override
  String get searchPromptHint => 'Escribe para buscar en toda la app.';

  @override
  String get searchNoResults => 'Ningún resultado.';

  @override
  String get searchSectionItems => 'Noticias';

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
  String get radioProgramsEmpty => 'No hay programas publicados en el feed.';

  @override
  String get radioProgramsFetchError =>
      'No se pudo cargar el feed de programas.';

  @override
  String get flavorActivityHeader => 'Actividad en Flavor';

  @override
  String get flavorActivityEvents => 'Eventos';

  @override
  String get flavorActivityContent => 'Catálogo';

  @override
  String get flavorActivityBoard => 'Tablón';

  @override
  String get flavorActivityEmpty =>
      'Este nodo no publica actividad pública ahora mismo.';

  @override
  String get settingsErrorReport => 'Compartir informe de error';

  @override
  String get settingsErrorReportSubtitle =>
      'Se registró un fallo reciente. Compártelo para ayudar a arreglarlo; no se envía nada solo.';

  @override
  String get settingsErrorReportDismiss => 'Descartar informe';
}
