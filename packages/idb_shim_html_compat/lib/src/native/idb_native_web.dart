library idb_shim.src.native.idb_native_web;

import 'dart:indexed_db' as native;
import 'package:idb_shim/idb_client.dart';
import 'package:idb_shim_html_compat/src/native/native_factory.dart';

/// True if native factory is supported
///
/// To use instead of html.window.indexedDB but provides the same API.
///
/// Is false if IndexedDB is not supported
bool get idbFactoryNativeSupported =>
    IdbFactoryNativeBrowserWrapperImpl.supported;

/// The native factory
///
/// To use instead of html.window.indexedDB but provides the same API.
///
/// throw if IndexedDB is not supported
IdbFactory get idbFactoryNative => idbFactoryNativeBrowserImpl;

/// Wrap the window/service worker implementation
///
/// [nativeIdbFactory] can be html.window.indexedDB for browser app, for
/// service worker you can use self.indexedDB
IdbFactory idbFactoryFromIndexedDB(native.IdbFactory nativeIdbFactory) =>
    IdbFactoryNativeWrapperImpl(nativeIdbFactory);
