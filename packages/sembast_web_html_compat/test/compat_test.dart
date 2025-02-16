// ignore_for_file: deprecated_member_use

import 'package:idb_shim_html_compat/idb_client_native_html.dart';
import 'package:test/test.dart';

Future<void> main() async {
  test('compile on io', () {
    try {
      idbFactoryNativeHtml;
    } catch (e) {
      print(e);
    }
  });
}
