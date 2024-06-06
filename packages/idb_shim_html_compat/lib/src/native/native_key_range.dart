// ignore_for_file: public_member_api_docs

import 'dart:indexed_db' as idb;

import 'package:idb_shim/idb.dart';

idb.KeyRange? toNativeKeyRange(KeyRange? common) {
  //print(common);
  if (common == null) {
    return null;
  }
  if (common.lower != null) {
    if (common.upper != null) {
      return idb.KeyRange.bound(common.lower, common.upper,
          common.lowerOpen == true, common.upperOpen == true);
    } else {
      return idb.KeyRange.lowerBound(common.lower, common.lowerOpen == true);
    }
  } else {
    // devPrint('upper ${common.upper} ${common.upperOpen}');
    return idb.KeyRange.upperBound(common.upper, common.upperOpen == true);
  }
}

/// Convert a query (key range or key to a native object)
dynamic toNativeQuery(dynamic query) {
  if (query is KeyRange) {
    return toNativeKeyRange(query);
  }
  return query;
}
