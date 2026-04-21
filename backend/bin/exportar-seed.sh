#!/usr/bin/env bash
# Exporta el catálogo vivo del backend (sources + radios) a los assets
# embebidos del APK (`app/assets/seed/`). Sirve para regenerar el modo
# autónomo cuando se añaden o se quitan medios/radios en WordPress.
#
# Uso: ./bin/exportar-seed.sh [URL_BASE]
#   - Sin argumentos: usa http://sitio-prueba.local (entorno dev local).
#   - Con argumento: cualquier URL del namespace, p. ej.
#     https://flavornews.xyz.
set -euo pipefail

BASE="${1:-http://sitio-prueba.local}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
DESTINO="$RAIZ/app/assets/seed"

if [ ! -d "$DESTINO" ]; then
    echo "ERROR: no existe $DESTINO. ¿Estás en el monorepo correcto?" >&2
    exit 1
fi

PY="$(cat <<'EOF'
import json, sys, urllib.request

BASE = sys.argv[1]
DEST = sys.argv[2]

def fetch(path):
    req = urllib.request.Request(BASE + path, headers={'Accept': 'application/json'})
    return json.load(urllib.request.urlopen(req, timeout=20))

# Sources: sólo los que tengan feed_url.
sources = fetch('/wp-json/flavor-news/v1/sources?per_page=100')
out_s = []
for s in sources:
    if not s.get('feed_url'):
        continue
    out_s.append({
        'id': s.get('id'),
        'name': s.get('name', ''),
        'slug': s.get('slug', ''),
        'feed_url': s.get('feed_url', ''),
        'feed_type': s.get('feed_type', 'rss'),
        'website_url': s.get('website_url', ''),
        'territory': s.get('territory', ''),
        'languages': s.get('languages', []),
    })
with open(DEST + '/sources.json', 'w') as f:
    json.dump(out_s, f, ensure_ascii=False, indent=1)
print('sources:', len(out_s))

# Radios: sólo las que tengan stream.
radios = fetch('/wp-json/flavor-news/v1/radios?per_page=100')
out_r = []
for r in radios:
    if not r.get('stream_url'):
        continue
    out_r.append({
        'id': r.get('id'),
        'name': r.get('name', ''),
        'slug': r.get('slug', ''),
        'stream_url': r.get('stream_url', ''),
        'website_url': r.get('website_url', ''),
        'rss_url': r.get('rss_url', ''),
        'territory': r.get('territory', ''),
        'languages': r.get('languages', []),
    })
with open(DEST + '/radios.json', 'w') as f:
    json.dump(out_r, f, ensure_ascii=False, indent=1)
print('radios:', len(out_r))

# Colectivos: el directorio completo. Son datos curados, no cambian mucho.
colectivos = fetch('/wp-json/flavor-news/v1/collectives?per_page=50')
out_c = []
for c in colectivos:
    out_c.append({
        'id': c.get('id'),
        'name': c.get('name', ''),
        'slug': c.get('slug', ''),
        'description': c.get('description', ''),
        'url': c.get('url', ''),
        'website_url': c.get('website_url', ''),
        'flavor_url': c.get('flavor_url', ''),
        'territory': c.get('territory', ''),
        'has_contact': c.get('has_contact', False),
        'verified': c.get('verified', True),
        'topics': c.get('topics', []),
    })
with open(DEST + '/collectives.json', 'w') as f:
    json.dump(out_c, f, ensure_ascii=False, indent=1)
print('colectivos:', len(out_c))

# Items: últimos 80 titulares. A diferencia de sources/radios/colectivos,
# los items caducan con el tiempo, pero tener un puñado empaquetado permite
# que la app muestre algo "out of the box" en el primer arranque sin red.
items = fetch('/wp-json/flavor-news/v1/items?per_page=80')
out_i = []
for it in items:
    out_i.append({
        'id': it.get('id'),
        'slug': it.get('slug', ''),
        'title': it.get('title', ''),
        'excerpt': it.get('excerpt', ''),
        'url': it.get('url', ''),
        'original_url': it.get('original_url', ''),
        'published_at': it.get('published_at', ''),
        'media_url': it.get('media_url', ''),
        'audio_url': it.get('audio_url', ''),
        'duration_seconds': it.get('duration_seconds', 0),
        'source': it.get('source'),
        'topics': it.get('topics', []),
    })
with open(DEST + '/items.json', 'w') as f:
    json.dump(out_i, f, ensure_ascii=False, indent=1)
print('items:', len(out_i))
EOF
)"

python3 -c "$PY" "$BASE" "$DESTINO"
echo
echo "Seed regenerado en $DESTINO"
echo "Recompila el APK para que el cambio entre: (cd app && flutter build apk)"
