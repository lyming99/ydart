import 'dart:convert';

import 'package:ydart/structs/base_content.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

class ContentJson extends IContentEx {
  List<Object?> content;

  ContentJson({
    required this.content,
  });

  @override
  int get ref => 2;

  @override
  bool get isCountable => true;

  @override
  int get length => content.length;

  @override
  List<Object?> getContent() {
    return content;
  }

  @override
  IContent copy() {
    return ContentJson(content: content);
  }

  @override
  IContent splice(int offset) {
    var right = ContentJson(content: content.sublist(offset));
    content.removeRange(offset, content.length - offset);
    return right;
  }

  @override
  bool mergeWith(IContent right) {
    if (right is ContentJson) {
      content.addAll(right.content);
    }
    return false;
  }

  @override
  void integrate(Transaction transaction, Item item) {}

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(AbstractEncoder encoder, int offset) {
    var len = content.length;
    encoder.writeLength(len);
    for (int i = offset; i < len; i++) {
      var c = content[i];
      var jsonStr = (c == null) ? "undefined" : jsonEncode(c);
      encoder.writeString(jsonStr);
    }
  }

  static ContentJson read(AbstractDecoder decoder) {
    var len = decoder.readLength();
    var content = [];
    for (var i = 0; i < len; i++) {
      var jsonStr = decoder.readString();
      var object = (jsonStr == "undefined") ? null : jsonDecode(jsonStr);
      content.add(object);
    }
    return ContentJson(content: content);
  }
}
