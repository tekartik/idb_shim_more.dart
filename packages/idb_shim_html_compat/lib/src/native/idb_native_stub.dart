// ignore_for_file: public_member_api_docs

import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim/src/utils/unimplemented_stub.dart';

/// The native factory
@Deprecated('use idbFactoryNative fom idb_client_native_interop')
IdbFactory get idbFactoryNative => idbUnimplementedStub('idbFactoryNative');
bool get idbFactoryNativeSupported =>
    idbUnimplementedStub('idbFactoryNativeSupported');

IdbFactory idbFactoryFromIndexedDB(dynamic nativeIdbFactory) =>
    idbUnimplementedStub('idbFactoryFromIndexedDB');
