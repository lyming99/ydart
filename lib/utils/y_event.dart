import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/item.dart';

class ChangesCollection {
  Set<Item>? added;
  Set<Item>? deleted;
  List<Delta>? delta;

  ChangesCollection({
    this.added,
    this.deleted,
    this.delta,
  });
}

class Delta {
  Object? insert;
  int? delete;
  int? retain;
  Map<String, Object?>? attributes;

  Delta({
    this.insert,
    this.delete,
    this.retain,
    this.attributes,
  });
}

enum ChangeAction {
  Add,
  Update,
  Delete,
}

class ChengeKey {
  ChangeAction action;
  Object oldValue;

  ChengeKey({
    required this.action,
    required this.oldValue,
  });
}

class YEvent {
  ChangesCollection? _changes;
  AbstractType target;
  late AbstractType currentTarget;
  Transaction transaction;

  YEvent({
    required this.target,
    required this.transaction,
  }) {
    currentTarget = target;
  }

  List<Object> get path => getPathTo(currentTarget, target);

  ChangesCollection get changes => ChangesCollection();

  bool deletes(AbstractStruct str) {
    return transaction.deleteset.isDeleted(str.id);
  }

  bool adds(AbstractStruct str) {
    throw UnimplementedError();
  }

  List<Object> getPathTo(AbstractType currentTarget, AbstractType target) {
    throw UnimplementedError();
  }
}
