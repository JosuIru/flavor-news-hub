/// Modelos ligeros (sin freezed) para la API pública de Flavor Platform.
///
/// No usamos freezed aquí porque los campos vienen con tipos laxos (a veces
/// numéricos como strings, otras como ints) y preferimos tener una única
/// función `_asInt()` / `_asString()` conservadora en lugar de desplegar
/// toda la maquinaria de json_serializable. Son modelos de sólo lectura, no
/// los persistimos ni los mutamos.
library;

int _asInt(dynamic valor) {
  if (valor is int) return valor;
  if (valor is num) return valor.toInt();
  if (valor is String) return int.tryParse(valor) ?? 0;
  return 0;
}

String _asString(dynamic valor) {
  if (valor == null) return '';
  if (valor is String) return valor;
  return valor.toString();
}

/// Nodo público en el directorio. Corresponde a una entrada de
/// `/flavor-network/v1/directory`.
class FlavorNode {
  const FlavorNode({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.descripcionCorta,
    required this.siteUrl,
    required this.logoUrl,
    required this.tipoEntidad,
    required this.sector,
    required this.ciudad,
    required this.pais,
  });

  final int id;
  final String nombre;
  final String slug;
  final String descripcionCorta;
  final String siteUrl;
  final String logoUrl;
  final String tipoEntidad;
  final String sector;
  final String ciudad;
  final String pais;

  factory FlavorNode.fromJson(Map<String, dynamic> j) => FlavorNode(
        id: _asInt(j['id']),
        nombre: _asString(j['nombre']),
        slug: _asString(j['slug']),
        descripcionCorta: _asString(j['descripcion_corta']),
        siteUrl: _asString(j['site_url']),
        logoUrl: _asString(j['logo_url']),
        tipoEntidad: _asString(j['tipo_entidad']),
        sector: _asString(j['sector']),
        ciudad: _asString(j['ciudad']),
        pais: _asString(j['pais']),
      );
}

/// Entrada del catálogo público de un nodo: productos, espacios, servicios,
/// etc. Viene de `/flavor-network/v1/content` o del catálogo embebido.
class FlavorContenido {
  const FlavorContenido({
    required this.id,
    required this.nodoId,
    required this.tipoContenido,
    required this.titulo,
    required this.descripcion,
    required this.imagenUrl,
    required this.precio,
    required this.moneda,
    required this.ubicacion,
  });

  final int id;
  final int nodoId;
  final String tipoContenido;
  final String titulo;
  final String descripcion;
  final String imagenUrl;
  final String precio;
  final String moneda;
  final String ubicacion;

  factory FlavorContenido.fromJson(Map<String, dynamic> j) => FlavorContenido(
        id: _asInt(j['id']),
        nodoId: _asInt(j['nodo_id']),
        tipoContenido: _asString(j['tipo_contenido']),
        titulo: _asString(j['titulo']),
        descripcion: _asString(j['descripcion']),
        imagenUrl: _asString(j['imagen_url']),
        precio: _asString(j['precio']),
        moneda: _asString(j['moneda']),
        ubicacion: _asString(j['ubicacion']),
      );
}

/// Evento federado. Viene de `/flavor-network/v1/events`.
class FlavorEvento {
  const FlavorEvento({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.ubicacion,
    required this.imagenUrl,
    required this.esOnline,
    required this.urlOnline,
  });

  final int id;
  final String titulo;
  final String descripcion;
  final String fechaInicio;
  final String ubicacion;
  final String imagenUrl;
  final bool esOnline;
  final String urlOnline;

  factory FlavorEvento.fromJson(Map<String, dynamic> j) => FlavorEvento(
        id: _asInt(j['id']),
        titulo: _asString(j['titulo']),
        descripcion: _asString(j['descripcion']),
        fechaInicio: _asString(j['fecha_inicio']),
        ubicacion: _asString(j['ubicacion']),
        imagenUrl: _asString(j['imagen'] ?? j['imagen_url']),
        esOnline: _asInt(j['es_online']) == 1,
        urlOnline: _asString(j['url_online']),
      );
}

/// Publicación del tablón de la red. Viene de `/flavor-network/v1/board`.
class FlavorPublicacionTablon {
  const FlavorPublicacionTablon({
    required this.id,
    required this.titulo,
    required this.contenido,
    required this.fecha,
    required this.autor,
  });

  final int id;
  final String titulo;
  final String contenido;
  final String fecha;
  final String autor;

  factory FlavorPublicacionTablon.fromJson(Map<String, dynamic> j) =>
      FlavorPublicacionTablon(
        id: _asInt(j['id']),
        titulo: _asString(j['titulo']),
        contenido: _asString(j['contenido'] ?? j['descripcion']),
        fecha: _asString(j['fecha'] ?? j['created_at']),
        autor: _asString(j['autor'] ?? j['autor_nombre']),
      );
}

/// Paquete con todo lo público que un nodo expone. La UI lo renderiza como
/// pestañas o una lista mixta.
class ActividadNodoFlavor {
  const ActividadNodoFlavor({
    required this.eventos,
    required this.contenidos,
    required this.publicaciones,
  });

  final List<FlavorEvento> eventos;
  final List<FlavorContenido> contenidos;
  final List<FlavorPublicacionTablon> publicaciones;

  bool get estaVacio =>
      eventos.isEmpty && contenidos.isEmpty && publicaciones.isEmpty;

  static const ActividadNodoFlavor vacia = ActividadNodoFlavor(
    eventos: [],
    contenidos: [],
    publicaciones: [],
  );
}
