import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/item.dart';

typedef GcFilter = bool Function(Item item);

class YDocOptions {
  late String guid;

  void write(AbstractEncoder encoder, int offset) {}

  static YDocOptions read(AbstractDecoder decoder) {
    return YDocOptions();
  }
}

class YDoc {
  YDocOptions options;

  late StructStore store;

  YDoc({
    required this.options,
  });

  String get guid => options.guid;

  get clientId => null;

  bool get gc => false;

  String findRootTypeKey(AbstractType abstractType) {
    throw UnimplementedError();
  }

  void transact(Function(Transaction tr) fun,
      [Object? origin, bool local = true]) {

  }

  cloneOptionsWithNewGuid() {}

  void applyUpdateV2(array, {required String transactionOrigin}) {}
}
