#!/usr/bin/env python3
"""Sincroniza los seeds del backend con el seed offline de la app.

El seed offline (`app/assets/seed/*.json`) debe ser espejo exacto del
seed bundleado del backend (`backend/seed/*.json`). Sin esta copia, la
app móvil queda desactualizada respecto al catálogo del plugin tras
cada release.

Uso:
  python3 scripts/sync-seeds.py            # copia backend → app
  python3 scripts/sync-seeds.py --check    # falla si no coinciden (CI)

El modo --check no toca archivos. Devuelve exit code 0 si están
alineados y 1 si no, listando los archivos divergentes.
"""
import json
import sys
from pathlib import Path

RAIZ = Path(__file__).resolve().parent.parent
BACKEND = RAIZ / "backend" / "seed"
APP = RAIZ / "app" / "assets" / "seed"
ARCHIVOS = ["sources.json", "collectives.json", "radios.json"]


def cargar(ruta: Path):
    with ruta.open(encoding="utf-8") as fh:
        return json.load(fh)


def serializar(datos) -> str:
    """Misma formato que usamos al editar a mano: indent=2 + newline final."""
    return json.dumps(datos, ensure_ascii=False, indent=2) + "\n"


def main(argv: list[str]) -> int:
    modo_check = "--check" in argv
    if not BACKEND.is_dir() or not APP.is_dir():
        print(f"ERROR: directorios no encontrados\n  backend: {BACKEND}\n  app:     {APP}",
              file=sys.stderr)
        return 2

    divergentes: list[str] = []
    for nombre in ARCHIVOS:
        ruta_backend = BACKEND / nombre
        ruta_app = APP / nombre
        if not ruta_backend.is_file():
            print(f"AVISO: {ruta_backend} no existe — salto.", file=sys.stderr)
            continue
        contenido_backend = serializar(cargar(ruta_backend))
        if not ruta_app.is_file():
            if modo_check:
                divergentes.append(nombre + " (no existe en app)")
            else:
                ruta_app.write_text(contenido_backend, encoding="utf-8")
                print(f"  CREADO  app/assets/seed/{nombre} ({len(cargar(ruta_backend))} entradas)")
            continue
        contenido_app = serializar(cargar(ruta_app))
        if contenido_backend == contenido_app:
            print(f"  OK      {nombre}")
            continue
        if modo_check:
            divergentes.append(nombre)
        else:
            ruta_app.write_text(contenido_backend, encoding="utf-8")
            print(f"  COPIADO {nombre} ({len(cargar(ruta_backend))} entradas)")

    if modo_check and divergentes:
        print(
            "\nERROR: los siguientes seeds del app divergen del backend:\n  "
            + "\n  ".join(divergentes)
            + "\n\nEjecuta `python3 scripts/sync-seeds.py` y commitea el resultado.",
            file=sys.stderr,
        )
        return 1
    if modo_check:
        print("\nTodos los seeds están sincronizados.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
