import 'package:ydart/utils/id.dart';

import 'package:ydart/utils/transaction.dart';

import '../structs/abstract_struct.dart';

class StructStore {
  void addStruct(AbstractStruct item) {}

  AbstractStruct? getItemCleanStart(Transaction transaction, ID id) {}

  int getState(int clientId) {
    return 0;
  }
}
