import 'package:ydart/structs/base_content.dart';
import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/types/y_text.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';
import 'item.dart';

class ContentFormat extends IContentEx {
  String key;
  dynamic value;

  ContentFormat({
    required this.key,
    required this.value,
  });

  factory ContentFormat.create(String key, Object? value) {
    return ContentFormat(key: key, value: value);
  }

  @override
  int get ref => 6;

  @override
  bool get isCountable => false;

  @override
  int get length => 1;

  @override
  IContentEx copy() {
    return ContentFormat(key: key, value: value);
  }

  @override
  List<Object?> getContent() {
    throw UnimplementedError();
  }

  @override
  IContentEx splice(int offset) {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(IContent right) {
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {
    (item.parent as YArrayBase?)?.clearSearchMarkers();
  }

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeKey(key);
    encoder.writeJson(value?.toMap());
  }

  static ContentFormat read(IUpdateDecoder decoder) {
    var key = decoder.readKey();
    var value = decoder.readJson();
    if (key == "ychange") {
      value = YTextChangeAttributes.fromMap(value);
    }
    return ContentFormat(key: key, value: value);
  }
}
