// ignore_for_file: avoid_print

import 'package:process_run/shell.dart';
import 'package:tekartik_app_web_build/dhttpd.dart';
Future<void> main(List<String> args) async {

  if (true) {
    await run('''
      dart pub get
      webdev build -o example:build
  ''');
  }
  await dhttpdReady();
  print('http://localhost:8080');
  await Shell(workingDirectory: 'build').run('dhttpd');
}
