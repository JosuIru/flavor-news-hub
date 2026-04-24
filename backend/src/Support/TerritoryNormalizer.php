<?php
declare(strict_types=1);

namespace FlavorNewsHub\Support;

/**
 * Convierte el `territory` libre del catálogo en una ubicación
 * normalizada y legible por máquina.
 *
 * El campo `territory` sigue siendo la referencia humana y compatible
 * con datos antiguos. Los campos derivados (`country`, `region`, `city`,
 * `network`) sirven para filtros, mapa y ordenación editorial.
 */
final class TerritoryNormalizer
{
    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    public static function desglosar(string $territorio): array
    {
        $clave = self::normalizarCadena($territorio);
        if ($clave === '') {
            return self::vacio();
        }

        $mapa = self::mapa();
        if (isset($mapa[$clave])) {
            return $mapa[$clave];
        }

        if (str_contains($clave, ',')) {
            $segmentos = array_values(array_filter(array_map('trim', explode(',', $clave))));
            if (count($segmentos) >= 2) {
                $primero = self::desglosar($segmentos[0]);
                if ($primero['country'] !== '' || $primero['region'] !== '' || $primero['city'] !== '' || $primero['network'] !== '') {
                    return $primero;
                }
                $segundo = self::desglosar($segmentos[1]);
                if ($segundo['country'] !== '' || $segundo['region'] !== '' || $segundo['city'] !== '' || $segundo['network'] !== '') {
                    return $segundo;
                }
            }
        }

        return self::vacio();
    }

    /**
     * @return array<string,array{country:string,region:string,city:string,network:string}>
     */
    private static function mapa(): array
    {
        return [
            // Marcos transnacionales / redes.
            'internacional' => self::fila(network: 'Internacional'),
            'latinoamerica' => self::fila(network: 'Latinoamérica'),
            'latinoamérica' => self::fila(network: 'Latinoamérica'),
            'mesoamerica' => self::fila(network: 'Mesoamérica'),
            'mesoamérica' => self::fila(network: 'Mesoamérica'),
            'wallmapu' => self::fila(network: 'Wallmapu'),
            'euskal herria' => self::fila(network: 'Euskal Herria'),

            // Estado español y naciones/territorios internos.
            'estado espanol' => self::fila(country: 'España'),
            'estado español' => self::fila(country: 'España'),
            'españa' => self::fila(country: 'España'),
            'spain' => self::fila(country: 'España'),
            'catalunya' => self::fila(country: 'España', region: 'Catalunya'),
            'cataluña' => self::fila(country: 'España', region: 'Cataluña'),
            'catalonia' => self::fila(country: 'España', region: 'Catalunya'),
            'euskadi' => self::fila(country: 'España', region: 'Euskadi'),
            'pais vasco' => self::fila(country: 'España', region: 'País Vasco'),
            'país vasco' => self::fila(country: 'España', region: 'País Vasco'),
            'bizkaia' => self::fila(country: 'España', region: 'Bizkaia'),
            'vizcaya' => self::fila(country: 'España', region: 'Bizkaia'),
            'gipuzkoa' => self::fila(country: 'España', region: 'Gipuzkoa'),
            'guipuzcoa' => self::fila(country: 'España', region: 'Gipuzkoa'),
            'guipúzcoa' => self::fila(country: 'España', region: 'Gipuzkoa'),
            'araba' => self::fila(country: 'España', region: 'Araba'),
            'alava' => self::fila(country: 'España', region: 'Araba'),
            'álava' => self::fila(country: 'España', region: 'Araba'),
            'nafarroa' => self::fila(country: 'España', region: 'Nafarroa'),
            'navarra' => self::fila(country: 'España', region: 'Navarra'),
            'ipar euskal herria' => self::fila(country: 'Francia', region: 'Ipar Euskal Herria'),
            'iparralde' => self::fila(country: 'Francia', region: 'Ipar Euskal Herria'),
            'madrid' => self::fila(country: 'España', region: 'Madrid'),
            'comunidad de madrid' => self::fila(country: 'España', region: 'Comunidad de Madrid'),
            'andalucia' => self::fila(country: 'España', region: 'Andalucía'),
            'andalucía' => self::fila(country: 'España', region: 'Andalucía'),
            'galicia' => self::fila(country: 'España', region: 'Galicia'),
            'galiza' => self::fila(country: 'España', region: 'Galicia'),
            'país valencià' => self::fila(country: 'España', region: 'País Valencià'),
            'pais valencià' => self::fila(country: 'España', region: 'País Valencià'),
            'país valencia' => self::fila(country: 'España', region: 'País Valencià'),
            'país valenciá' => self::fila(country: 'España', region: 'País Valencià'),
            'valencia' => self::fila(country: 'España', region: 'Valencia'),
            'valència' => self::fila(country: 'España', region: 'València'),
            'murcia' => self::fila(country: 'España', region: 'Murcia'),
            'cantabria' => self::fila(country: 'España', region: 'Cantabria'),
            'asturias' => self::fila(country: 'España', region: 'Asturias'),
            'asturies' => self::fila(country: 'España', region: 'Asturies'),
            'aragon' => self::fila(country: 'España', region: 'Aragón'),
            'aragón' => self::fila(country: 'España', region: 'Aragón'),
            'castilla y leon' => self::fila(country: 'España', region: 'Castilla y León'),
            'castilla y león' => self::fila(country: 'España', region: 'Castilla y León'),
            'castilla-la mancha' => self::fila(country: 'España', region: 'Castilla-La Mancha'),
            'castilla la mancha' => self::fila(country: 'España', region: 'Castilla-La Mancha'),
            'la rioja' => self::fila(country: 'España', region: 'La Rioja'),
            'rioja' => self::fila(country: 'España', region: 'La Rioja'),
            'canarias' => self::fila(country: 'España', region: 'Canarias'),
            'balears' => self::fila(country: 'España', region: 'Illes Balears'),
            'baleares' => self::fila(country: 'España', region: 'Islas Baleares'),
            'portugal' => self::fila(country: 'Portugal'),
            'lisboa' => self::fila(country: 'Portugal', region: 'Lisboa'),

            // Países y ciudades de América.
            'argentina' => self::fila(country: 'Argentina'),
            'buenos aires' => self::fila(country: 'Argentina', city: 'Buenos Aires'),
            'mendoza' => self::fila(country: 'Argentina', city: 'Mendoza'),
            'santa fe' => self::fila(country: 'Argentina', city: 'Santa Fe'),
            'trelew' => self::fila(country: 'Argentina', city: 'Trelew'),
            'bolivia' => self::fila(country: 'Bolivia'),
            'la paz' => self::fila(country: 'Bolivia', city: 'La Paz'),
            'brasil' => self::fila(country: 'Brasil'),
            'colombia' => self::fila(country: 'Colombia'),
            'suba' => self::fila(country: 'Colombia', city: 'Suba'),
            'costa rica' => self::fila(country: 'Costa Rica'),
            'chile' => self::fila(country: 'Chile'),
            'san felipe' => self::fila(country: 'Chile', city: 'San Felipe'),
            'ecuador' => self::fila(country: 'Ecuador'),
            'saraguro' => self::fila(country: 'Ecuador', city: 'Saraguro'),
            'guatemala' => self::fila(country: 'Guatemala'),
            'honduras' => self::fila(country: 'Honduras'),
            'nicaragua' => self::fila(country: 'Nicaragua'),
            'matagalpa' => self::fila(country: 'Nicaragua', city: 'Matagalpa'),
            'el salvador' => self::fila(country: 'El Salvador'),
            'méxico' => self::fila(country: 'México'),
            'mexico' => self::fila(country: 'México'),
            'oaxaca' => self::fila(country: 'México', city: 'Oaxaca'),
            'guerrero' => self::fila(country: 'México', region: 'Guerrero'),
            'xochimilco' => self::fila(country: 'México', city: 'Xochimilco'),
            'panamá' => self::fila(country: 'Panamá'),
            'panama' => self::fila(country: 'Panamá'),
            'uruguay' => self::fila(country: 'Uruguay'),
            'paraguay' => self::fila(country: 'Paraguay'),
            'perú' => self::fila(country: 'Perú'),
            'peru' => self::fila(country: 'Perú'),
            'piura' => self::fila(country: 'Perú', city: 'Piura'),
            'venezuela' => self::fila(country: 'Venezuela'),
            'caracas' => self::fila(country: 'Venezuela', city: 'Caracas'),
            'república dominicana' => self::fila(country: 'República Dominicana'),
            'republica dominicana' => self::fila(country: 'República Dominicana'),
            'estados unidos' => self::fila(country: 'Estados Unidos'),
            'united states' => self::fila(country: 'Estados Unidos'),
            'oxnard' => self::fila(country: 'Estados Unidos', city: 'Oxnard'),
            'india' => self::fila(country: 'India'),
        ];
    }

    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    private static function vacio(): array
    {
        return self::fila();
    }

    /**
     * @return array{country:string,region:string,city:string,network:string}
     */
    private static function fila(
        string $country = '',
        string $region = '',
        string $city = '',
        string $network = ''
    ): array {
        return [
            'country' => $country,
            'region'  => $region,
            'city'    => $city,
            'network' => $network,
        ];
    }

    private static function normalizarCadena(string $valor): string
    {
        $valor = remove_accents(trim($valor));
        $valor = strtolower($valor);
        $valor = str_replace(['-', '_'], ' ', $valor);
        $valor = preg_replace('/\s+/', ' ', $valor);
        return is_string($valor) ? trim($valor) : '';
    }
}
