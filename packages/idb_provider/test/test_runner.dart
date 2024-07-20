import 'dynamic_provider_test.dart' as dynamic_provider_test;
import 'provider_meta_test.dart' as provider_meta_test;
import 'provider_test.dart' as provider_test;
import 'provider_transaction_test.dart' as provider_transaction_test;
import 'record_provider_test.dart' as record_provider_test;
import 'synced_record_provider_test.dart' as synced_record_provider_test;
import 'test_common.dart';

void main() {
  testMain(idbMemoryContext);
}

void testMain(TestContext context) {
  provider_test.testMain(context);
  dynamic_provider_test.testMain(context);
  provider_meta_test.testMain(context);
  provider_transaction_test.testMain(context);
  record_provider_test.testMain(context);
  synced_record_provider_test.testMain(context);
}
