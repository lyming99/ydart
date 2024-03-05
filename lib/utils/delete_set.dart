import 'package:ydart/lib0/update_encoder_v2.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/transaction.dart';

class DeleteItem {
  int clock;
  int length;

  DeleteItem({
    required this.clock,
    required this.length,
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

  void write(UpdateEncoderV2 encoder) {}
}
