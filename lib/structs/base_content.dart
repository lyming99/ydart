import 'package:ydart/utils/encoding.dart';

import '../utils/struct_store.dart';
import '../utils/transaction.dart';
import 'item.dart';

abstract class IContent {
  bool get isCountable;

  int get length;

  List<dynamic> getContent();

  IContent copy();

  IContent splice(int offset);

  bool mergeWith(IContent right);
}

abstract class IContentEx extends IContent {
  int get ref;

  void integrate(Transaction transaction, Item item);

  void delete(Transaction transaction);

  void gc(StructStore store);

  void write(AbstractEncoder encoder, int offset);
}
