import 'package:flavor_news_hub/core/services/registro_errores.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tests de la red de seguridad de errores: persistir el último fallo y
/// poder reconstruir un informe compartible. Es la base de la captura
/// global instalada en `main` (FlutterError.onError / runZonedGuarded).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('RegistroErrores', () {
    test('sin errores registrados, leerUltimo devuelve null', () async {
      expect(await RegistroErrores.instancia.leerUltimo(), isNull);
    });

    test('registrar persiste tipo, mensaje y stack recuperables', () async {
      await RegistroErrores.instancia.registrar(
        StateError('algo explotó'),
        StackTrace.fromString('#0 foo\n#1 bar'),
        cuando: DateTime.utc(2026, 5, 29, 10, 30),
      );

      final informe = await RegistroErrores.instancia.leerUltimo();
      expect(informe, isNotNull);
      expect(informe!.tipo, 'StateError');
      expect(informe.mensaje, contains('algo explotó'));
      expect(informe.stack, contains('#0 foo'));
      expect(informe.fechaIso, '2026-05-29T10:30:00.000Z');
    });

    test('una traza enorme se trunca para no inflar el almacén', () async {
      final stackGigante = StackTrace.fromString('x' * 20000);

      await RegistroErrores.instancia.registrar(Exception('boom'), stackGigante);

      final informe = await RegistroErrores.instancia.leerUltimo();
      expect(informe!.stack.length, lessThan(20000));
      expect(informe.stack, contains('truncado'));
    });

    test('comoTextoCompartible incluye versión, plataforma y mensaje', () async {
      await RegistroErrores.instancia.registrar(
        Exception('fallo de red'),
        StackTrace.fromString('#0 cliente.http'),
      );
      final informe = await RegistroErrores.instancia.leerUltimo();

      final texto = informe!.comoTextoCompartible(version: '0.16.9', plataforma: 'android');

      expect(texto, contains('Flavor News Hub'));
      expect(texto, contains('0.16.9'));
      expect(texto, contains('android'));
      expect(texto, contains('fallo de red'));
      expect(texto, contains('#0 cliente.http'));
    });

    test('limpiar borra el informe guardado', () async {
      await RegistroErrores.instancia.registrar(Exception('x'), StackTrace.current);
      expect(await RegistroErrores.instancia.leerUltimo(), isNotNull);

      await RegistroErrores.instancia.limpiar();

      expect(await RegistroErrores.instancia.leerUltimo(), isNull);
    });

    test('el último registro pisa al anterior', () async {
      await RegistroErrores.instancia.registrar(Exception('primero'), null);
      await RegistroErrores.instancia.registrar(Exception('segundo'), null);

      final informe = await RegistroErrores.instancia.leerUltimo();
      expect(informe!.mensaje, contains('segundo'));
      expect(informe.mensaje, isNot(contains('primero')));
    });
  });
}
