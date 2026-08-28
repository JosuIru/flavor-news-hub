#!/usr/bin/env python3
"""Revisa el estado real de las fuentes en producción y diagnostica fallos.

Combina dos señales que, por separado, no dicen toda la verdad:

  1. El endpoint público `/diagnostics` del backend, que sabe qué
     fuentes acumulan errores, latencia alta o nunca devuelven 304
     desde la IP del servidor.

     Si el backend está actualizado, el endpoint trae además, por
     fuente, el `http_status` y el `mensaje` REALES del último error
     del servidor — no sólo el conteo. Eso es lo que el script cruza
     abajo; si no están (backend viejo), cae al sondeo local.

  2. Un sondeo HTTP local, hecho desde ESTA máquina (IP residencial,
     análoga a la de un móvil), con EXACTAMENTE las mismas cabeceras y
     User-Agent que usa el ingester del servidor.

El cruce de ambas es lo que permite responder la pregunta clave:
"¿por qué una fuente carga desde el móvil pero no desde el servidor?".
Si el servidor reporta un error de TRANSPORTE (status HTTP != 200) pero
el sondeo local da 200, el veredicto es inequívoco: bloqueo por IP/WAF
del datacenter. Ojo: si el servidor obtuvo 200 y aun así registró error,
NO es bloqueo de IP (un WAF rechaza con status de error, no con 200);
es un fallo de contenido del feed, reproducible desde cualquier IP.

  - 200 aquí pero con errores en el server  -> bloqueo por IP/WAF del
    datacenter (Cloudflare/Sucuri marcan la IP de salida del hosting),
    SÓLO si el servidor tuvo status de error. Si el servidor también dio
    200, es contenido inválido en origen (XML mal formado), no bloqueo.
    Es la causa #1 del fenómeno "móvil sí, servidor no".
  - 429 aquí y allá                         -> rate-limit del origen;
    bajar la frecuencia o subir el throttle por host lo arregla.
  - 404 con cuerpo HTML                      -> la URL del feed cambió o
    murió; hay que corregir `feed_url` en el seed.
  - SSL_verify != 0                          -> cadena de certificado
    incompleta; candidata a `DOMINIOS_SSL_BYPASS`.
  - 000 / timeout                            -> DNS muerto o servidor que
    no responde a tiempo.

Uso:
  python3 scripts/revisar-fuentes.py              # top errores 7d + sondeo
  python3 scripts/revisar-fuentes.py --todas      # sondea TODAS las fuentes del seed
  python3 scripts/revisar-fuentes.py --instancia https://otra.instancia

No modifica nada. Sólo lee producción y los feeds de origen.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.parse
import urllib.request
from pathlib import Path

INSTANCIA_DEFAULT = "https://flavor.gailu.it/wp-json/flavor-news/v1"

# Mismo User-Agent y cabeceras que envía FeedIngester::fetchFeedHttp() en
# el backend. Replicarlos es esencial: un sondeo con el UA por defecto de
# curl puede pasar donde el del server falla (o al revés), y eso
# invalidaría la comparación.
USER_AGENT_INGESTER = (
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)
CABECERAS_INGESTER = [
    "From: flavor.gailu.it (Flavor News Hub agregator)",
    "Accept: application/rss+xml,application/atom+xml,application/xml;q=0.9,text/xml;q=0.8,*/*;q=0.5",
    "Accept-Language: es,en;q=0.8",
]

RAIZ_REPO = Path(__file__).resolve().parent.parent
SEED_FUENTES = RAIZ_REPO / "backend" / "seed" / "sources.json"


def obtener_diagnostico(instancia: str) -> dict:
    """Descarga el endpoint público /diagnostics del backend."""
    url = f"{instancia.rstrip('/')}/diagnostics"
    peticion = urllib.request.Request(url, headers={"Accept": "application/json"})
    with urllib.request.urlopen(peticion, timeout=30) as respuesta:
        return json.load(respuesta)


def cargar_mapa_feed_urls() -> dict[str, dict]:
    """Mapa nombre_normalizado -> {feed_url, feed_type} desde el seed."""
    datos = json.loads(SEED_FUENTES.read_text(encoding="utf-8"))
    fuentes = datos if isinstance(datos, list) else datos.get("sources", datos)
    mapa: dict[str, dict] = {}
    for fuente in fuentes:
        nombre = str(fuente.get("name", "")).strip().lower()
        if nombre:
            mapa[nombre] = {
                "feed_url": fuente.get("feed_url", ""),
                "feed_type": fuente.get("feed_type", "?"),
            }
    return mapa


def resolver_feed_url(nombre_fuente: str, mapa: dict[str, dict]) -> dict:
    """Empareja un nombre de /diagnostics con su entrada del seed.

    Los nombres de /diagnostics pueden traer entidades HTML (L&#8217;…),
    así que probamos coincidencia exacta y luego por inclusión.
    """
    clave = nombre_fuente.strip().lower()
    if clave in mapa:
        return mapa[clave]
    for nombre_seed, datos in mapa.items():
        if clave in nombre_seed or nombre_seed in clave:
            return datos
    return {"feed_url": "", "feed_type": "?"}


def detectar_waf(cabeceras_crudas: str) -> str:
    """Identifica el WAF/CDN delante del origen por sus cabeceras.

    Saber esto es lo que distingue un bloqueo por reputación de IP
    (Cloudflare/Sucuri rechazan rangos de datacenter) de un rate-limit
    del propio origen (LiteSpeed/Apache mod_security), que afecta a
    cualquier IP por igual.
    """
    texto = cabeceras_crudas.lower()
    if "cf-ray:" in texto or "server: cloudflare" in texto:
        return "Cloudflare"
    if "x-sucuri" in texto:
        return "Sucuri"
    if "server: litespeed" in texto:
        return "LiteSpeed"
    if "youtube" in texto:
        return "YouTube"
    for linea in cabeceras_crudas.splitlines():
        if linea.lower().startswith("server:"):
            return linea.split(":", 1)[1].strip() or "?"
    return ""


def sondear_feed(feed_url: str) -> dict:
    """Hace un GET local con las cabeceras del ingester y clasifica.

    Devuelve código HTTP, tiempo, bytes, verificación SSL, el WAF/CDN
    detectado y una etiqueta de diagnóstico legible.
    """
    if not feed_url:
        return {"http": "?", "tiempo": "", "bytes": "", "nota": "sin feed_url en seed",
                "ssl_roto": False, "waf": "", "host": ""}

    host = urllib.parse.urlparse(feed_url).hostname or ""
    formato_salida = "%{http_code}|%{time_total}|%{size_download}|%{ssl_verify_result}"
    # `-D /dev/stderr` vuelca las cabeceras de respuesta a stderr, así
    # quedan separadas de las métricas de `-w` (stdout) y del cuerpo
    # (`-o /dev/null`). Sin esto no hay forma limpia de leer `Server:`.
    comando = [
        "curl", "-s", "-o", "/dev/null", "-D", "/dev/stderr",
        "-w", formato_salida, "--max-time", "15", "-L", "-A", USER_AGENT_INGESTER,
    ]
    for cabecera in CABECERAS_INGESTER:
        comando += ["-H", cabecera]
    comando.append(feed_url)

    resultado = subprocess.run(comando, capture_output=True, text=True)
    if "|" not in resultado.stdout:
        return {"http": "000", "tiempo": "", "bytes": "", "nota": "curl falló",
                "ssl_roto": False, "waf": "", "host": host}

    codigo, tiempo, tam, ssl = resultado.stdout.split("|")
    waf = detectar_waf(resultado.stderr)
    nota = clasificar(codigo, ssl)
    return {"http": codigo, "tiempo": tiempo, "bytes": tam, "nota": nota,
            "ssl_roto": ssl not in ("0", ""), "waf": waf, "host": host}


def diagnosticar_contenido(mensaje_servidor: str) -> str:
    """Clasifica un error de CONTENIDO a partir del mensaje del servidor.

    Cuando el servidor recibió 200 pero registró un error, la petición
    llegó al origen y respondió bien: lo que falla es el cuerpo. Distingue
    el XML mal formado (caracteres/markup inválidos) del cuerpo que ni
    siquiera es un feed (HTML de error servido con 200, feed vacío…).
    """
    mensaje = (mensaje_servidor or "").lower()
    if "invalid xml" in mensaje or "invalid characters" in mensaje or "xml error" in mensaje:
        return "XML mal formado en origen → el feed emite caracteres/markup inválidos"
    if "could not be found" in mensaje or "valid rss" in mensaje or "valid atom" in mensaje:
        return "respuesta sin feed (200 pero el cuerpo no es RSS/Atom) → revisar feed_url"
    return "contenido inválido en origen (200 pero no parsea como feed)"


def clasificar_error_servidor(srv_http, srv_msg: str) -> str:
    """Causa probable usando SÓLO la señal del servidor (status + mensaje).

    Se aplica cuando no hay sondeo local con el que cruzar: la fuente no
    está en el seed (típicamente porque se añadió desde el admin de
    producción). El endpoint ya trae status y mensaje, que bastan para
    clasificar sin descargar el feed desde esta máquina.
    """
    mensaje = (srv_msg or "").lower()
    http = str(srv_http)
    if "no tiene feed_url" in mensaje:
        return "sin feed_url en producción → la fuente se creó sin URL en el admin"
    if "could not resolve host" in mensaje or "couldn't resolve" in mensaje:
        return "DNS muerto → el dominio del feed ya no resuelve (origen desaparecido)"
    if http == "200":
        return diagnosticar_contenido(srv_msg)
    if http == "404":
        return "feed_url muerto/cambiado en origen (404)"
    if http in ("403", "486"):
        return "anti-bot del origen (403)"
    if http == "429":
        return "rate-limit del origen (429)"
    if http == "0":
        return "origen inalcanzable (timeout / DNS / SSL)"
    return f"error de servidor HTTP {http}"


def veredicto_cruzado(srv_http, srv_msg: str, sondeo: dict) -> str:
    """Cruza el error real del servidor con el sondeo local.

    Es el diagnóstico que ninguna de las dos señales da por separado:

      - server con 200 pero error -> el origen respondió bien a la IP del
        datacenter; el fallo es de CONTENIDO (feed mal formado), no de
        transporte. Nunca es bloqueo de IP: un WAF rechaza con un status
        de error, no con 200.
      - server con error + local 200 -> "móvil sí, servidor no": la IP del
        datacenter está bloqueada (WAF/anti-bot). Causa #1.
      - server y local coinciden   -> el fallo es del origen, no de la
        IP: feed muerto, rate-limit global, TLS roto…
      - server no reporta error    -> caemos al diagnóstico del sondeo.
    """
    local_http = sondeo["http"]
    ssl_roto = sondeo.get("ssl_roto", False)
    host = sondeo.get("host", "")
    waf = sondeo.get("waf", "")
    detalle = f" [srv: {srv_msg}]" if srv_msg else ""

    # Sin dato de servidor (modo --todas): sólo el sondeo local.
    if srv_http is None:
        return sondeo["nota"]

    # No se pudo sondear localmente (la fuente no está en el seed, p.ej.
    # añadida desde el admin). En vez de quedarnos en "intermitente — sin
    # feed_url en seed", clasificamos con la señal del servidor, que el
    # endpoint ya trae: status + mensaje real del último error.
    if local_http == "?":
        return f"sólo-servidor: {clasificar_error_servidor(srv_http, srv_msg)}{detalle}"

    # El servidor obtuvo 200: la petición llegó y el origen respondió. No
    # hubo bloqueo de transporte, así que el error es del CONTENIDO del
    # feed (XML mal formado, cuerpo vacío o que no es RSS/Atom),
    # reproducible desde cualquier IP. Etiquetarlo como "bloqueo de IP"
    # era el falso veredicto: el datacenter no estaba bloqueado.
    if str(srv_http) == "200":
        return f"origen: {diagnosticar_contenido(srv_msg)}{detalle}"

    # A partir de aquí el servidor SÍ tuvo un error de transporte (status
    # != 200). Si localmente carga -> "móvil sí, servidor no".
    if local_http == "200" and not ssl_roto:
        # YouTube no es un WAF que bloquee por reputación: limita las
        # RÁFAGAS de peticiones por IP. El servidor, con 280 fuentes en
        # cola, las dispara seguidas; el sondeo local (una sola) pasa.
        # El arreglo es subir el intervalo del host, no "desbloquear IP".
        if host.endswith("youtube.com"):
            return f"YouTube anti-ráfaga por IP → subir intervalo del host{detalle}"
        # WAF/CDN que rechaza la IP del datacenter pero responde 200 a
        # una IP residencial: el caso clásico de bloqueo por reputación.
        etiqueta_waf = f" tras {waf}" if waf else ""
        return f"⚠ MÓVIL SÍ / SERVIDOR NO → bloqueo de IP del datacenter{etiqueta_waf}{detalle}"

    # Coinciden ambos -> el problema es del origen, reproducible en
    # cualquier IP. El sondeo local ya lo clasificó (404, 429, TLS…).
    if str(srv_http) == str(local_http):
        return f"origen: {sondeo['nota']} (confirmado server+local)"

    # Difieren sin que local sea 200: intermitencia o respuestas
    # distintas. Mostramos ambos para inspección manual.
    return f"server {srv_http} vs local {local_http}: intermitente — {sondeo['nota']}"


def clasificar(codigo_http: str, ssl_verify: str) -> str:
    """Traduce el resultado del sondeo a una causa probable."""
    if ssl_verify not in ("0", ""):
        return f"cadena TLS incompleta (ssl_verify={ssl_verify}) → candidata a SSL bypass"
    if codigo_http == "200":
        return "OK aquí: si el server da error → bloqueo por IP/WAF del datacenter"
    if codigo_http == "429":
        return "rate-limit del origen (también aquí) → bajar frecuencia/throttle"
    if codigo_http in ("403", "486"):
        return "anti-bot del origen → ajustar cabeceras o aceptar bloqueo"
    if codigo_http == "404":
        return "feed_url muerto/cambiado → corregir en el seed"
    if codigo_http == "000":
        return "DNS muerto o timeout → origen caído"
    return f"HTTP {codigo_http}"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--instancia", default=INSTANCIA_DEFAULT)
    parser.add_argument("--todas", action="store_true",
                        help="sondea todas las fuentes del seed, no sólo el top de errores")
    parser.add_argument("--cuarentena", action="store_true",
                        help="sondea las fuentes EN CUARENTENA en vez del top de "
                             "errores. Son las que el circuit breaker salta sin "
                             "dejar log: no aparecen en el top porque sólo se "
                             "reintentan una vez al día, así que llevan meses "
                             "cayendo en silencio. Requiere backend >= 0.16.19")
    args = parser.parse_args()

    mapa_feeds = cargar_mapa_feed_urls()

    if args.todas:
        # Sin diagnóstico de servidor: sólo sondeo local de todo el seed.
        fuentes_a_revisar = [
            {"nombre": nombre, "errores": 0, "srv_http": None, "srv_msg": ""}
            for nombre in mapa_feeds
        ]
    else:
        diagnostico = obtener_diagnostico(args.instancia)
        print(f"Plugin: {diagnostico.get('plugin_version')}  ·  "
              f"fuentes activas: {diagnostico.get('sources_activas')}  ·  "
              f"items 24h: {diagnostico.get('items_nuevos_ultimas_24h')}  ·  "
              f"última ingesta: {diagnostico.get('ultima_ejecucion_utc')}\n")
        # Fuentes en cuarentena: el circuit breaker las salta ANTES de
        # crear el log, así que no aparecen en `ultimos_logs` y, al
        # reintentarse sólo una vez al día, tampoco acumulan errores
        # para entrar en el top-40. Sin listarlas aquí son invisibles:
        # dejan de publicar y no dan ninguna señal de por qué (así se
        # nos escapó Radio Sudaca). Los backends viejos no traen la
        # clave y simplemente no se imprime nada.
        en_cuarentena = diagnostico.get("fuentes_en_cuarentena") or []
        if en_cuarentena:
            print(f"EN CUARENTENA ({len(en_cuarentena)}) — saltadas sin dejar log:")
            for entrada in en_cuarentena:
                print(f"  {entrada.get('source_name','?')[:34]:36} "
                      f"{entrada.get('errores_consecutivos',0):3} errores seguidos"
                      f"  · reintento {entrada.get('reintento_utc','?')}")
            print()
        # El endpoint ahora trae el error REAL del servidor por fuente
        # (`mensaje` + `http_status`). Lo cruzamos con el sondeo local.
        if args.cuarentena:
            # En cuarentena el servidor no ha llegado a registrar un
            # error nuevo (sale antes de crear el log), así que no hay
            # `http_status` ni `mensaje` que cruzar: el veredicto sale
            # del sondeo local. Lo que aporta el diagnóstico aquí es
            # QUÉ fuentes mirar y cuántos errores llevan acumulados.
            fuentes_a_revisar = [
                {
                    "nombre":   entrada.get("source_name", ""),
                    "errores":  entrada.get("errores_consecutivos", 0),
                    "srv_http": None,
                    "srv_msg":  "",
                }
                for entrada in (diagnostico.get("fuentes_en_cuarentena") or [])
            ]
            if not fuentes_a_revisar:
                print("No hay fuentes en cuarentena (o el backend es anterior "
                      "a 0.16.19 y no expone la clave).")
                return 0
        else:
            fuentes_a_revisar = [
                {
                    "nombre":   entrada["nombre"],
                    "errores":  entrada.get("errores", 0),
                    "srv_http": entrada.get("http_status"),
                    "srv_msg":  entrada.get("mensaje", ""),
                }
                for entrada in diagnostico.get("top_errores_7d", [])
            ]

    encabezado = (f"{'FUENTE':<28} {'ERR':>4} {'SRV':>4} {'LOCAL':>5} {'WAF/CDN':<11} VEREDICTO")
    print(encabezado)
    print("-" * max(len(encabezado), 96))
    for fuente in fuentes_a_revisar:
        datos_feed = resolver_feed_url(fuente["nombre"], mapa_feeds)
        sondeo = sondear_feed(datos_feed["feed_url"])
        veredicto = veredicto_cruzado(fuente["srv_http"], fuente["srv_msg"], sondeo)
        nombre_corto = fuente["nombre"] if len(fuente["nombre"]) <= 28 else fuente["nombre"][:25] + "…"
        srv_http = "—" if fuente["srv_http"] is None else str(fuente["srv_http"])
        celda_waf = (sondeo.get("waf") or "—")[:11]
        print(f"{nombre_corto:<28} {fuente['errores']:>4} {srv_http:>4} {sondeo['http']:>5} "
              f"{celda_waf:<11} {veredicto}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
