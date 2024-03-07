import 'package:ydart/lib0/update_encoder_v2.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/abstract_struct.dart';

class DeleteItem {
  final int clock;
  final int length;

  DeleteItem(this.clock, this.length);
}

class DeleteSet {
  Map<int, List<DeleteItem>> clients;

  DeleteSet({
    required this.clients,
  });

  void add(int client, int clock, int length) {
    if (!clients.containsKey(client)) {
      clients[client] = [];
    }
    clients[client]!.add(DeleteItem(clock, length));
  }

  void iterateDeletedStructs(
      Transaction transaction, bool Function(AbstractStruct type) fun) {
    for (var kvp in clients.entries) {
      var structs = transaction.doc.store.clients[kvp.key];
      for (var del in kvp.value) {
        transaction.doc.store
            .iterateStructs(transaction, structs, del.clock, del.length, fun);
      }
    }
  }

  int? findIndexSS(List<DeleteItem> dis, int clock) {
    var left = 0;
    var right = dis.length - 1;
    while (left <= right) {
      var midIndex = (left + right) ~/ 2;
      var mid = dis[midIndex];
      var midClock = mid.clock;
      if (midClock <= clock) {
        if (clock < midClock + mid.length) {
          return midIndex;
        }
        left = midIndex + 1;
      } else {
        right = midIndex - 1;
      }
    }
    return null;
  }

  bool isDeleted(ID id) {
    var dis = clients[id.client];
    return dis != null && findIndexSS(dis, id.clock) != null;
  }

  void write(UpdateEncoderV2 encoder) {}
}
