import 'package:ydart/structs/base_content.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

class ContentFormat extends IContentEx {
  String key;
  Object? value;

  ContentFormat({
    required this.key,
    required this.value,
  });

  @override
  int get ref => 6;

  @override
  bool get isCountable => false;

  @override
  int get length => 1;

  @override
  IContent copy() {
    return ContentFormat(key: key, value: value);
  }

  @override
  List<Object?> getContent() {
    throw UnimplementedError();
  }

  @override
  IContent splice(int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(IContent right) {
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {
    // TODO: implement integrate
  }

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(AbstractEncoder encoder, int offset) {
    encoder.writeKey(key);
    encoder.writeJson(value);
  }

  static ContentFormat read(AbstractDecoder decoder) {
    var key = decoder.readKey();
    var value = decoder.readJson();
    return ContentFormat(key: key, value: value);
  }
}
