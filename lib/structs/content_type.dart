import 'package:ydart/structs/base_content.dart';
import 'package:ydart/types/abstract_type.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

class ContentType extends IContentEx {
  AbstractType type;

  ContentType(this.type);

  @override
  int get ref => 7;

  @override
  bool get isCountable => true;

  @override
  int get length => 1;

  @override
  List getContent() {
    return [type];
  }

  @override
  IContent copy() {
    return ContentType(type.internalCopy());
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
    type.integrate(transaction.doc, item);
  }

  @override
  void delete(Transaction transaction) {
    // TODO: implement delete
  }

  @override
  void gc(StructStore store) {
    // TODO: implement gc
  }

  @override
  void write(AbstractEncoder encoder, int offset) {
    type.write(encoder);
  }

  static ContentType read(AbstractDecoder decoder) {
    // TODO: implement read
    throw UnimplementedError();
  }
}
