import 'package:ydart/structs/base_content.dart';

import '../utils/encoding.dart';
import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

class ContentDeleted extends IContentEx {
  @override
  int length;

  ContentDeleted(this.length);

  @override
  int get ref => 1;

  @override
  bool get isCountable => false;

  @override
  List<Object?> getContent() {
    throw UnimplementedError();
  }

  @override
  IContent copy() {
    return ContentDeleted(length);
  }

  @override
  IContent splice(int offset) {
    var right = ContentDeleted(length - offset);
    length = offset;
    return right;
  }

  @override
  bool mergeWith(IContent right) {
    if (right is ContentDeleted) {
      length += right.length;
    }
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
    encoder.writeVarInt(length - offset);
  }

  static ContentDeleted read(AbstractDecoder decoder) {
    var len = decoder.readLength();
    return ContentDeleted(len);
  }
}
