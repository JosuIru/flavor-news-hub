#!/usr/bin/env python3
"""
Importa las fuentes del "Vol. 2" del documento de fuentes al seed del APK.

Toma tres bloques: Mastodon, Radios, YouTube. Resuelve handles YouTube
(@canal) a channel_id haciendo scraping del HTML del canal (sin API key).

Uso:
    python3 bin/importar-fuentes-doc.py

Sobreescribe `app/assets/seed/sources.json` y `app/assets/seed/radios.json`
añadiendo las nuevas entradas (no duplica por slug).
"""
from __future__ import annotations

import json
import re
import sys
import urllib.request
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[2]
DESTINO_SOURCES = RAIZ / "app" / "assets" / "seed" / "sources.json"
DESTINO_RADIOS = RAIZ / "app" / "assets" / "seed" / "radios.json"


def slugify(nombre: str) -> str:
    s = nombre.lower()
    s = re.sub(r"[áàä]", "a", s)
    s = re.sub(r"[éèë]", "e", s)
    s = re.sub(r"[íìï]", "i", s)
    s = re.sub(r"[óòö]", "o", s)
    s = re.sub(r"[úùü]", "u", s)
    s = re.sub(r"ñ", "n", s)
    s = re.sub(r"[^a-z0-9]+", "-", s).strip("-")
    return s


# --- 1) Cuentas Mastodon ---
# (nombre, instancia, usuario, territorio, idiomas)
MASTODON = [
    ("Framasoft", "framapiaf.org", "framasoft", "Internacional", ["fr", "en"]),
    ("FSFE", "mastodon.social", "fsfe", "Internacional", ["en"]),
    ("Software Freedom Conservancy", "mastodon.social", "conservancy", "Internacional", ["en"]),
    ("EFF", "mastodon.social", "eff", "Internacional", ["en"]),
    ("Tor Project", "mastodon.social", "torproject", "Internacional", ["en"]),
    ("Internet Archive", "mastodon.archive.org", "internetarchive", "Internacional", ["en"]),
    ("Wikimedia", "wikis.world", "wikimedia", "Internacional", ["en"]),
    ("Mozilla", "mozilla.social", "mozilla", "Internacional", ["en"]),
    ("GNOME", "floss.social", "gnome", "Internacional", ["en"]),
    ("KDE", "floss.social", "kde", "Internacional", ["en"]),
    ("F-Droid", "floss.social", "fdroidorg", "Internacional", ["en"]),
    ("Codeberg", "social.anoxinon.de", "Codeberg", "Internacional", ["en"]),
    ("Bellingcat", "mastodon.social", "bellingcat", "Internacional", ["en"]),
    ("ProPublica", "newsie.social", "propublica", "Internacional", ["en"]),
    ("The Markup", "mastodon.social", "themarkup", "Internacional", ["en"]),
    ("Mediapart", "piaille.fr", "Mediapart", "Internacional", ["fr"]),
    ("Reporterre", "kolektiva.media", "reporterre", "Internacional", ["fr"]),
    ("DDoSecrets", "mastodon.social", "ddosecrets", "Internacional", ["en"]),
    ("AlgorithmWatch", "social.algorithmwatch.org", "algorithmwatch", "Internacional", ["en", "de"]),
    ("La Quadrature du Net", "mamot.fr", "laquadrature", "Internacional", ["fr"]),
    ("Maldita.es", "mastodon.social", "maldita", "España", ["es"]),
    ("Civio", "mastodon.social", "civio", "España", ["es"]),
    ("Xnet", "mamot.fr", "xnet", "España", ["es", "ca"]),
    ("Sursiendo", "kolektiva.social", "sursiendo", "Internacional", ["es"]),
]


# --- 2) Radios libres adicionales ---
# (nombre, feed_url, website_url, territorio, idiomas)
RADIOS_EXTRA = [
    ("Hala Bedi Irratia", "https://halabedi.eus/feed/", "https://halabedi.eus", "Vitoria-Gasteiz", ["eu"]),
    ("97 Irratia", "https://97irratia.info/feed/", "https://97irratia.info", "Bortziri", ["eu"]),
    ("Eguzki Irratia", "https://eguzki.eus/feed/", "https://eguzki.eus", "Iruñea", ["eu"]),
    ("Tas Tas Irratia", "https://tastasirratia.org/feed/", "https://tastasirratia.org", "Bilbo", ["eu"]),
    ("Aiaraldea Komunikabidea", "https://aiaraldea.eus/feed", "https://aiaraldea.eus", "Aiara", ["eu"]),
    ("ContraBanda FM", "https://contrabanda.org/feed/", "https://contrabanda.org", "Barcelona", ["ca"]),
    ("Ràdio Bronka", "https://radiobronka.info/feed/", "https://radiobronka.info", "Barcelona", ["ca"]),
    ("La Tele", "https://latele.cat/feed/", "https://latele.cat", "Barcelona", ["ca"]),
    ("Ràdio Pica", "https://radiopica.cat/feed/", "https://radiopica.cat", "Barcelona", ["ca"]),
    ("Ràdio Klara", "https://radioklara.org/feed/", "https://radioklara.org", "València", ["ca", "es"]),
    ("Cuac FM", "https://cuacfm.org/feed/", "https://cuacfm.org", "A Coruña", ["gl"]),
    ("Radio Kras", "https://radiokras.org/feed/", "https://radiokras.org", "Asturies", ["es"]),
    ("Radio Topo", "https://radiotopo.org/feed/", "https://radiotopo.org", "Zaragoza", ["es"]),
    ("Radio Almenara", "https://radioalmenara.net/feed/", "https://radioalmenara.net", "Madrid", ["es"]),
    ("Radio Vallekas", "https://radiovallekas.org/feed/", "https://radiovallekas.org", "Madrid", ["es"]),
    ("Radio Enlace", "https://radioenlace.org/feed/", "https://radioenlace.org", "Madrid", ["es"]),
    ("Radio Carcoma", "https://radiocarcoma.com/feed/", "https://radiocarcoma.com", "Madrid", ["es"]),
    ("Onda Color", "https://ondacolor.org/feed", "https://ondacolor.org", "Málaga", ["es"]),
    ("Radio Pimienta", "https://radiopimienta.org/feed/", "https://radiopimienta.org", "Tenerife", ["es"]),
    ("Onda Polígono", "https://ondapoligono.org/feed/", "https://ondapoligono.org", "Toledo", ["es"]),
    ("Radio Onda Rossa", "https://www.ondarossa.info/rss/news.xml", "https://www.ondarossa.info", "Roma", ["it"]),
    ("Radio Blackout", "https://radioblackout.org/feed/", "https://radioblackout.org", "Torino", ["it"]),
    ("A-Radio Berlin", "https://aradio.blogsport.de/feed/", "https://aradio.blogsport.de", "Berlin", ["de"]),
    ("Radio Libertaire", "https://rl.federation-anarchiste.org/feed/", "https://rl.federation-anarchiste.org", "París", ["fr"]),
    ("Radio Canut", "https://radiocanut.org/feed/", "https://radiocanut.org", "Lyon", ["fr"]),
]


# --- 3) Canales YouTube por HANDLE (resolvemos channel_id) ---
YOUTUBE_HANDLES = [
    # (nombre, handle_sin_arroba, territorio, idiomas)
    ("QuantumFracture", "QuantumFracture", "Internacional", ["es"]),
    ("Date un Voltio", "DateunVoltio", "Internacional", ["es"]),
    ("Date un Vlog", "dateunvlog", "Internacional", ["es"]),
    ("La Gata de Schrödinger", "LaGatadeSchrodinger", "Internacional", ["es"]),
    ("La Hiperactina", "LaHiperactina", "Internacional", ["es"]),
    ("Antroporama", "Antroporama", "Internacional", ["es"]),
    ("Derivando", "Derivando", "Internacional", ["es"]),
    ("C de Ciencia", "CdeCiencia", "Internacional", ["es"]),
    ("DotCSV", "DotCSV", "Internacional", ["es"]),
    ("El Robot de Platón", "elrobotdeplaton", "Internacional", ["es"]),
    ("Pol Lluís", "PolLluis", "Internacional", ["es"]),
    ("Jaime Altozano", "JaimeAltozano", "Internacional", ["es"]),
    ("Veritasium", "veritasium", "Internacional", ["en"]),
    ("3Blue1Brown", "3blue1brown", "Internacional", ["en"]),
    ("Kurzgesagt", "kurzgesagt", "Internacional", ["en"]),
    ("Sabine Hossenfelder", "SabineHossenfelder", "Internacional", ["en"]),
    ("PBS Space Time", "pbsspacetime", "Internacional", ["en"]),
    ("Quanta Magazine", "QuantaScienceChannel", "Internacional", ["en"]),
    ("Andrewism", "Andrewism", "Internacional", ["en"]),
    ("Our Changing Climate", "OurChangingClimate", "Internacional", ["en"]),
    ("Folding Ideas", "FoldingIdeas", "Internacional", ["en"]),
    ("MIT OpenCourseWare", "mitocw", "Internacional", ["en"]),
    ("CCC (Chaos Computer Club)", "mediacccde", "Internacional", ["de", "en"]),
    ("TED-Ed", "TEDEd", "Internacional", ["en"]),
]


def resolver_channel_id(handle: str) -> str | None:
    """
    Descarga el HTML del canal YouTube y extrae el channel_id (UC...).
    Devuelve None si falla.
    """
    url = f"https://www.youtube.com/@{handle}"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64)"})
        html = urllib.request.urlopen(req, timeout=15).read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  ERROR {handle}: {e}", file=sys.stderr)
        return None
    m = re.search(r'"channelId":"(UC[A-Za-z0-9_-]{22})"', html)
    if m:
        return m.group(1)
    m = re.search(r'"externalId":"(UC[A-Za-z0-9_-]{22})"', html)
    return m.group(1) if m else None


def fusionar_sources() -> None:
    datos = json.loads(DESTINO_SOURCES.read_text())
    slugs = {s["slug"] for s in datos}
    id_siguiente = max(s["id"] for s in datos) + 1
    nuevos = 0

    # Mastodon
    for nombre, instancia, usuario, territorio, idiomas in MASTODON:
        slug = slugify(f"mastodon-{nombre}")
        if slug in slugs:
            continue
        feed_url = f"https://{instancia}/@{usuario}.rss"
        website_url = f"https://{instancia}/@{usuario}"
        datos.append({
            "id": id_siguiente,
            "name": f"{nombre} (Mastodon)",
            "slug": slug,
            "feed_url": feed_url,
            "feed_type": "rss",
            "website_url": website_url,
            "territory": territorio,
            "languages": idiomas,
        })
        slugs.add(slug)
        id_siguiente += 1
        nuevos += 1

    # YouTube (resolvemos handles)
    print(f"Resolviendo {len(YOUTUBE_HANDLES)} handles de YouTube...")
    for nombre, handle, territorio, idiomas in YOUTUBE_HANDLES:
        slug = slugify(f"yt-{nombre}")
        if slug in slugs:
            print(f"  SKIP {nombre} (ya existe)")
            continue
        channel_id = resolver_channel_id(handle)
        if not channel_id:
            print(f"  FALLO {nombre} ({handle}) — no resuelve channel_id")
            continue
        feed_url = f"https://www.youtube.com/feeds/videos.xml?channel_id={channel_id}"
        website_url = f"https://www.youtube.com/@{handle}"
        datos.append({
            "id": id_siguiente,
            "name": nombre,
            "slug": slug,
            "feed_url": feed_url,
            "feed_type": "youtube",
            "website_url": website_url,
            "territory": territorio,
            "languages": idiomas,
        })
        slugs.add(slug)
        id_siguiente += 1
        nuevos += 1
        print(f"  OK {nombre} -> {channel_id}")

    DESTINO_SOURCES.write_text(json.dumps(datos, ensure_ascii=False, indent=1))
    print(f"\nsources.json: +{nuevos} nuevas entradas (total {len(datos)})")


def fusionar_radios() -> None:
    datos = json.loads(DESTINO_RADIOS.read_text())
    slugs = {r["slug"] for r in datos}
    id_siguiente = max(r["id"] for r in datos) + 1
    nuevas = 0

    for nombre, feed_url, website_url, territorio, idiomas in RADIOS_EXTRA:
        slug = slugify(nombre)
        if slug in slugs:
            continue
        datos.append({
            "id": id_siguiente,
            "name": nombre,
            "slug": slug,
            # No tenemos stream_url desde el doc — sólo web/RSS. El app
            # filtra radios sin stream, pero las metemos como sources
            # textuales en `sources.json` vía este script también.
            "stream_url": "",
            "website_url": website_url,
            "rss_url": feed_url,
            "territory": territorio,
            "languages": idiomas,
        })
        slugs.add(slug)
        id_siguiente += 1
        nuevas += 1

    DESTINO_RADIOS.write_text(json.dumps(datos, ensure_ascii=False, indent=1))
    print(f"radios.json: +{nuevas} nuevas entradas (total {len(datos)})")


if __name__ == "__main__":
    fusionar_sources()
    fusionar_radios()
