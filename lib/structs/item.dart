import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/id.dart';
import 'base_content.dart';

enum InfoEnum {
  zero(0),
  keep(1),
  countable(1 << 1),
  deleted(1 << 2),
  marker(1 << 3);

  final int value;

  const InfoEnum(this.value);
}

class Item extends AbstractStruct {
  AbstractStruct? left;
  AbstractStruct? right;
  ID? leftOrigin;
  ID? rightOrigin;

  // AbstractType or ID
  Object? parent;
  String? parentSub;
  IContentEx content;
  late InfoEnum info;
  ID? redone;

  Item({
    required super.id,
    this.left,
    this.leftOrigin,
    this.right,
    this.rightOrigin,
    this.parent,
    this.parentSub,
    required this.content,
    super.length = 1,
  }) {
    length = content.length;
    info = content.isCountable ? InfoEnum.countable : InfoEnum.zero;
  }

  factory Item.create(
      ID id,
      AbstractStruct? left,
      ID? leftOrigin,
      AbstractStruct? right,
      ID? rightOrigin,
      Object? parent,
      String? parentSub,
      IContentEx content,
      int length) {
    return Item(
      id: id,
      content: content,
      leftOrigin: leftOrigin,
      left: left,
      right: right,
      rightOrigin: rightOrigin,
      parentSub: parentSub,
      parent: parent,
      length: length,
    );
  }

  bool get marker {
    return false;
  }

  set marker(bool value) {}

  bool get keep {
    return false;
  }

  set keep(bool value) {}

  bool get countable {
    return false;
  }

  set countable(bool value) {}

  @override
  // TODO: implement deleted
  bool get deleted => throw UnimplementedError();

  // TODO: implement deleted
  ID get lastId => throw UnimplementedError();

  AbstractStruct? get next {
    throw UnimplementedError();
  }

  AbstractStruct? get prev {
    throw UnimplementedError();
  }

  void markDeleted() {
    throw UnimplementedError();
  }

  @override
  bool mergeWith(AbstractStruct right) {
    // TODO: implement mergeWith
    throw UnimplementedError();
  }

  @override
  void delete(Transaction transaction) {
    // TODO: implement delete
  }

  @override
  void integrate(Transaction transaction, int offset) {
    // TODO: implement integrate
  }

  @override
  int? getMissing(Transaction transaction, StructStore store) {
    // TODO: implement getMissing
    throw UnimplementedError();
  }

  void gc(StructStore store, bool parentGCd) {}

  void keepItemAndParents(bool value) {}

  bool isVisible(Snapshot snapshot) {
    return false;
  }

  @override
  void write(AbstractEncoder encoder, int offset) {
    // TODO: implement write
  }

  Item splitItem(Transaction transaction, int diff) {
    throw UnimplementedError();
  }
}
