import 'package:angel_route/angel_route.dart';
import 'package:test/test.dart';

main() {
  final router = new Router();

  router.get('/', 'GET').as('root');
  router.get('/user/:id', 'GET');
  router.get('/first/:first/last/:last', 'GET').as('full_name');

  navigate(params) {
    final uri = router.navigate(params);
    print('Uri: $uri');
    return uri;
  }

  router.dumpTree(showMatchers: true);

  group('top-level', () {
    test('named', () {
      expect(navigate(['root']), equals('/'));
    });

    test('params', () {
      expect(
          navigate([
            'user/:id',
            {'id': 1337}
          ]),
          equals('/user/1337'));

      expect(
          navigate([
            'full_name',
            {'first': 'John', 'last': 'Smith'}
          ]),
          equals('/first/John/last/Smith'));
    });

    test('root', () {
      expect(navigate(['/']), equals('/'));
    });
  });
}