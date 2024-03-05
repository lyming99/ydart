import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/transaction.dart';

class DeleteItem {
  int clock;
  int len;

  DeleteItem({
    required this.clock,
    required this.len,
  });
}

class DeleteSet {
  Map<int, List<DeleteItem>> clients;

  DeleteSet({
    required this.clients,
  });

  void iterateDeletedStructs(Transaction transaction,) {
    for(var entry in clients.entries){
      var client = entry.key;
      var deletes = entry.value;

    }
  }

  bool isDeleted(ID id) {
    throw UnimplementedError();
  }
}
