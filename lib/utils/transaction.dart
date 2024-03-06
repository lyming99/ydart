import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/delete_set.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

class Transaction {
  late YDoc doc;

  late DeleteSet deleteset;

  bool get local => false;
  late Map<AbstractType, List<YEvent>> changedParentTypes;

  static void splitSnapshotAffectedStructs(Transaction tr, Snapshot snapshot) {}
}
