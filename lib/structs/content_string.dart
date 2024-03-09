import 'package:ydart/structs/base_content.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import '../utils/update_decoder.dart';
import '../utils/update_encoder.dart';
import 'item.dart';

class ContentString extends IContentEx {
  String content;

  ContentString(this.content);

  @override
  int get ref => 4;

  @override
  bool get isCountable => true;

  @override
  int get length => content.length;

  @override
  List getContent() {
    return [content];
  }

  @override
  IContentEx copy() {
    return ContentString(content);
  }

  @override
  IContentEx splice(int offset) {
    return ContentString(content.substring(offset));
  }

  @override
  bool mergeWith(IContent right) {
    if (right is ContentString) {
      content += right.content;
      return true;
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
  void write(IUpdateEncoder encoder, int offset) {
    encoder.writeString(content.substring(offset));
  }

  static ContentString read(IUpdateDecoder decoder) {
    return ContentString(decoder.readString());
  }
}
