<?php
declare(strict_types=1);

namespace FlavorNewsHub\Tests;

use FlavorNewsHub\Activation\Activator;
use WP_UnitTestCase;

/**
 * Verifica el lock atómico que evita doble ejecución concurrente de
 * `migrarTimestampsPublicacion`. Antes del fix, dos requests en el
 * mismo init pasaban el chequeo `if (get_option(...) === 'done')` a
 * la vez y ejecutaban el trabajo duplicado. El lock con `add_option`
 * (que falla si la option ya existe) garantiza exclusividad.
 *
 * Cubre el patrón pero no la migración misma — el caso "primera
 * ejecución exitosa" ya está implícito en el `set_up` del activador
 * para los demás tests.
 */
final class ActivatorMigrationLockTest extends WP_UnitTestCase
{
    private const FLAG = 'fnh_mig_published_at_ts_v1';
    private const LOCK = 'fnh_mig_published_at_ts_v1_lock';

    public function set_up(): void
    {
        parent::set_up();
        delete_option(self::FLAG);
        delete_option(self::LOCK);
    }

    public function tear_down(): void
    {
        delete_option(self::FLAG);
        delete_option(self::LOCK);
        parent::tear_down();
    }

    public function test_segunda_ejecucion_sale_temprano_si_flag_done(): void
    {
        update_option(self::FLAG, 'done', false);

        Activator::ejecutarMigracionesPendientes();

        // Si la migración hubiera corrido, habría intentado coger el
        // lock; al estar el flag a 'done' debe salir antes.
        $this->assertFalse(get_option(self::LOCK), 'No debería haber lock activo si la migración ya estaba marcada done.');
        $this->assertSame('done', get_option(self::FLAG));
    }

    public function test_lock_existente_bloquea_segunda_ejecucion(): void
    {
        // Simulamos que otro proceso está ejecutando la migración: tiene
        // el lock cogido pero aún no ha marcado 'done' el flag.
        add_option(self::LOCK, (string) time(), '', 'no');

        Activator::ejecutarMigracionesPendientes();

        // Como el lock estaba cogido, esta ejecución sale sin hacer nada
        // — el lock NO se libera (lo libera el proceso que lo cogió) y
        // el flag NO pasa a 'done'.
        $this->assertNotFalse(get_option(self::LOCK), 'El lock no debería haberse tocado.');
        $this->assertFalse(get_option(self::FLAG), 'El flag no debería haberse marcado done por esta ejecución.');
    }

    public function test_primera_ejecucion_cogue_lock_termina_y_lo_libera(): void
    {
        $this->assertFalse(get_option(self::FLAG));
        $this->assertFalse(get_option(self::LOCK));

        Activator::ejecutarMigracionesPendientes();

        // Tras una ejecución exitosa: flag a 'done' y lock liberado.
        $this->assertSame('done', get_option(self::FLAG));
        $this->assertFalse(get_option(self::LOCK), 'El lock debe liberarse al terminar (`finally`).');
    }
}
