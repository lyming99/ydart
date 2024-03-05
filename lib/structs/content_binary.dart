import 'dart:typed_data';

import 'package:ydart/structs/base_content.dart';
import 'package:ydart/structs/item.dart';
import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

class ContentBinary extends IContentEx {
  Uint8List content;

  ContentBinary(this.content);

  @override
  int get ref => 3;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List<Object?> getContent() {
    return [content];
  }

  @override
  IContent copy() {
    return ContentBinary(content);
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
  void integrate(Transaction transaction, Item item) {}

  @override
  void delete(Transaction transaction) {}

  @override
  void gc(StructStore store) {}

  @override
  void write(AbstractEncoder encoder, int offset) {
    encoder.writeBuffer(content);
  }

  static ContentBinary read(AbstractDecoder decoder) {
    Uint8List content = decoder.readBuffer();
    return ContentBinary(content);
  }
}
