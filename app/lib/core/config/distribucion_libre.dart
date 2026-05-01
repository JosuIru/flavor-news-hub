/// URLs del canal libre (F-Droid / GitHub Releases / IzzyOnDroid /
/// Obtainium). Hoy todas se construyen sobre un único repositorio
/// público — esa URL es lo que cambia cuando alguien forkea y
/// distribuye su propio binario.
///
/// Filosofía: el manifiesto promete apropiabilidad — un colectivo que
/// monte su propio fork debería poder enviar el botón "Compartir app"
/// a su release, no al canónico. Con esta gate basta con compilar
/// pasando `--dart-define=FNH_REPO_DESCARGA=https://github.com/MiFork/...`
/// y el `shareAppMessage` ya enlaza al APK del fork.
const String urlRepoDescarga = String.fromEnvironment(
  'FNH_REPO_DESCARGA',
  defaultValue: 'https://github.com/JosuIru/flavor-news-hub',
);

/// URL estable al APK más reciente del flavor `libre`. El workflow
/// `release-apk.yml` sube en cada release un asset adicional con
/// nombre fijo `flavor-news-hub-app.apk` además del versionado, así
/// que esta URL siempre devuelve el último APK sin cambiar entre
/// releases — apta para enviar por chat, escribir en flyers, etc.
///
/// Forks que cambien `urlRepoDescarga` heredan esta URL apuntando a
/// su propio repo sin tocar nada más.
String get urlApkUltimoLibre =>
    '$urlRepoDescarga/releases/latest/download/flavor-news-hub-app.apk';
