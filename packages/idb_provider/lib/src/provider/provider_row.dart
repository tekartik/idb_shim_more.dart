import 'package:collection/collection.dart';
import 'package:idb_shim/idb.dart';
import 'package:tekartik_common_utils/hash_code_utils.dart';

abstract class _BaseRow<K, V> {
  K? key;
  V? value;

  _BaseRow();
  _BaseRow.from(this.key, this.value);

  @override
  int get hashCode => safeHashCode(key);

  @override
  String toString() => '$key: $value';

  @override
  bool operator ==(Object other) {
    if (other is _BaseRow && other.runtimeType == runtimeType) {
      return (key == other.key) && (value == other.value);
    }
    return false;
  }
}

abstract class _BaseMapRow<K> extends _BaseRow<K, Map> {
  _BaseMapRow.from(K super.key, Map super.map) : super.from();

  @override
  int get hashCode => value?.hashCode ?? 0;
  @override
  bool operator ==(other) {
    if (other is _BaseMapRow) {
      return const MapEquality<Object?, Object?>().equals(value, other.value);
    }
    return false;
  }

  dynamic operator [](String key) => value![key];
}

class StringMapRow extends _BaseMapRow<String> {
  StringMapRow.from(super.key, super.value) : super.from();
}

class IntMapRow extends _BaseMapRow<int> {
  IntMapRow.from(super.key, super.value) : super.from();
}

// ignore: library_private_types_in_public_api
abstract class ProviderRowFactory<T extends _BaseRow<K, V>, K, V> {
  T newRow(K key, V value);

  T cursorWithValueRow(CursorWithValue cwv) =>
      newRow(cwv.primaryKey as K, cwv.value as V);
}

class IntMapProviderRowFactory extends ProviderRowFactory<IntMapRow, int, Map> {
  @override
  IntMapRow newRow(int key, Map value) {
    return IntMapRow.from(key, value);
  }
}

final IntMapProviderRowFactory intMapProviderRawFactory =
    IntMapProviderRowFactory();

class StringMapProviderRowFactory
    extends ProviderRowFactory<StringMapRow, String, Map> {
  @override
  StringMapRow newRow(String key, Map value) {
    return StringMapRow.from(key, value);
  }
}
