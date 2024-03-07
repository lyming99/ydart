import 'package:ydart/utils/id.dart';

import 'package:ydart/utils/transaction.dart';

import '../structs/abstract_struct.dart';

class StructStore {
  late Map<int, List<AbstractStruct>> clients;

  void addStruct(AbstractStruct item) {}

  AbstractStruct? getItemCleanStart(Transaction transaction, ID id) {}

  int getState(int clientId) {
    return 0;
  }

  int findIndexSS(List<AbstractStruct>? structs, int index) {
    return -1;
  }

  void iterateStructs(Transaction transaction, List<AbstractStruct>? structs,
      int clock, int length, bool Function(AbstractStruct type) fun) {}
}
