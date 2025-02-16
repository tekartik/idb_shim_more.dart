/// {@canonicalFor idb_shim.src.native.idb_native_web.idbFactoryFromIndexedDB}
/// Legacy version using dart:html not wasm compatible
@Deprecated('Use idb_shim_web instead')
library;

export 'src/native/idb_native.dart'
    show
        idbFactoryNative,
        idbFactoryNativeHtml,
        idbFactoryNativeSupported,
        idbFactoryFromIndexedDB;
