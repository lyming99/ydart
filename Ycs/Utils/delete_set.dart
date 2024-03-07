import 'dart:collection';

class DeleteSet {
  late Map<int, List<DeleteItem>> clients;

  DeleteSet() {
    clients = HashMap<int, List<DeleteItem>>();
  }

  DeleteSet.fromList(List<DeleteSet> dss) : this() {
    mergeDeleteSets(dss);
  }

  DeleteSet.fromStructStore(StructStore ss) : this() {
    createDeleteSetFromStructStore(ss);
  }

  void add(int client, int clock, int length) {
    if (!clients.containsKey(client)) {
      clients[client] = [];
    }

    clients[client]!.add(DeleteItem(clock, length));
  }

  void iterateDeletedStructs(Transaction transaction, bool Function(AbstractStruct) fun) {
    clients.forEach((client, deletes) {
      var structs = transaction.doc.store.clients[client];
      deletes.forEach((del) {
        transaction.doc.store.iterateStructs(transaction, structs, del.clock, del.length, fun);
      });
    });
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
    return clients.containsKey(id.client) && findIndexSS(clients[id.client]!, id.clock) != null;
  }

  void sortAndMergeDeleteSet() {
    clients.forEach((client, dels) {
      dels.sort((a, b) => a.clock.compareTo(b.clock));

      int i, j;
      for (i = 1, j = 1; i < dels.length; i++) {
        var left = dels[j - 1];
        var right = dels[i];

        if (left.clock + left.length == right.clock) {
          left = dels[j - 1] = DeleteItem(left.clock, left.length + right.length);
        } else {
          if (j < i) {
            dels[j] = right;
          }

          j++;
        }
      }

      if (j < dels.length) {
        dels.removeRange(j, dels.length - j);
      }
    });
  }

  void tryGc(StructStore store, bool Function(Item) gcFilter) {
    tryGcDeleteSet(store, gcFilter);
    tryMergeDeleteSet(store);
  }

  void tryGcDeleteSet(StructStore store, bool Function(Item) gcFilter) {
    clients.forEach((client, deleteItems) {
      var structs = store.clients[client];
      for (int di = deleteItems.length - 1; di >= 0; di--) {
        var deleteItem = deleteItems[di];
        var endDeleteItemClock = deleteItem.clock + deleteItem.length;

        for (int si = StructStore.findIndexSS(structs, deleteItem.clock); si < structs.length; si++) {
          var str = structs[si];
          if (str.id.clock >= endDeleteItemClock) {
            break;
          }

          if (str is Item && str.deleted && !str.keep && gcFilter(str)) {
            str.gc(store, parentGCd: false);
          }
        }
      }
    });
  }

  void tryMergeDeleteSet(StructStore store) {
    clients.forEach((client, deleteItems) {
      var structs = store.clients[client];
      for (int di = deleteItems.length - 1; di >= 0; di--) {
        var deleteItem = deleteItems[di];
        var mostRightIndexToCheck = structs.length - 1;
        mostRightIndexToCheck = 1 + StructStore.findIndexSS(structs, deleteItem.clock + deleteItem.length - 1);
        for (int si = mostRightIndexToCheck; si > 0 && structs[si].id.clock >= deleteItem.clock; si--) {
          tryToMergeWithLeft(structs, si);
        }
      }
    });
  }

  static void tryToMergeWithLeft(List<AbstractStruct> structs, int pos) {
    var left = structs[pos - 1];
    var right = structs[pos];

    if (left.deleted == right.deleted && left.runtimeType == right.runtimeType) {
      if (left.mergeWith(right)) {
        structs.removeAt(pos);

        if (right is Item && right.parentSub != null) {
          if ((right.parent as AbstractType)._map[right.parentSub] == right) {
            (right.parent as AbstractType)._map[right.parentSub] = left as Item;
          }
        }
      }
    }
  }

  void mergeDeleteSets(List<DeleteSet> dss) {
    for (int dssI = 0; dssI < dss.length; dssI++) {
      dss[dssI].clients.forEach((client, delsLeft) {
        if (!clients.containsKey(client)) {
          var dels = List<DeleteItem>.from(delsLeft);

          for (int i = dssI + 1; i < dss.length; i++) {
            if (dss[i].clients.containsKey(client)) {
              dels.addAll(dss[i].clients[client]!);
            }
          }

          clients[client] = dels;
        }
      });
    }

    sortAndMergeDeleteSet();
  }

  void createDeleteSetFromStructStore(StructStore ss) {
    ss.clients.forEach((client, structs) {
      var dsItems = <DeleteItem>[];

      for (int i = 0; i < structs.length; i++) {
        var str = structs[i];
        if (str.deleted) {
          var clock = str.id.clock;
          var len = str.length;

          while (i + 1 < structs.length) {
            var next = structs[i + 1];
            if (next.id.clock == clock + len && next.deleted) {
              len += next.length;
              i++;
            } else {
              break;
            }
          }

          dsItems.add(DeleteItem(clock, len));
        }
      }

      if (dsItems.isNotEmpty) {
        clients[client] = dsItems;
      }
    });
  }

  void write(IDSEncoder encoder) {
    encoder.restWriter.writeVarUint(clients.length);

    clients.forEach((client, dsItems) {
      encoder.resetDsCurVal();
      encoder.restWriter.writeVarUint(client);
      encoder.restWriter.writeVarUint(dsItems.length);

      dsItems.forEach((item) {
        encoder.writeDsClock(item.clock);
        encoder.writeDsLength(item.length);
      });
    });
  }

  static DeleteSet read(IDSDecoder decoder) {
    var ds = DeleteSet();

    var numClients = decoder.reader.readVarUint();
    assert(numClients >= 0);

    for (var i = 0; i < numClients; i++) {
      decoder.resetDsCurVal();

      var client = decoder.reader.readVarUint();
      var numberOfDeletes = decoder.reader.readVarUint();

      if (numberOfDeletes > 0) {
        if (!ds.clients.containsKey(client)) {
          ds.clients[client] = [];
        }

        for (var j = 0; j < numberOfDeletes; j++) {
          var deleteItem = DeleteItem(decoder.readDsClock(), decoder.readDsLength());
          ds.clients[client]!.add(deleteItem);
        }
      }
    }

    return ds;
  }
}

class DeleteItem {
  final int clock;
  final int length;

  DeleteItem(this.clock, this.length);
}

class Transaction {
  late Doc doc;

  Transaction(this.doc);
}

class AbstractStruct {
  late ID id;
  late int length;
  late bool deleted;

  bool mergeWith(AbstractStruct other) {
    return false;
  }
}

class Item extends AbstractStruct {
  late bool keep;
  late bool parentGCd;
  late AbstractType parent;
  late dynamic parentSub;

  void gc(StructStore store, {required bool parentGCd}) {}
}

class StructStore {
  late Map<int, List<AbstractStruct>> clients;

  static int findIndexSS(List<AbstractStruct> structs, int clock) {
    return 0;
  }
}

class ID {
  late int client;
  late int clock;

  ID(this.client, this.clock);
}

class Doc {
  late StructStore store;

  Doc(this.store);
}

class AbstractType {
  late Map<dynamic, Item> _map;
}

class IDSEncoder {
  late RestWriter restWriter;

  void resetDsCurVal() {}

  void writeDsClock(int clock) {}

  void writeDsLength(int length) {}
}

class IDSDecoder {
  late RestReader reader;

  void resetDsCurVal() {}

  int readDsClock() {
    return 0;
  }

  int readDsLength() {
    return 0;
  }
}

class RestWriter {
  void writeVarUint(int value) {}
}

class RestReader {
  int readVarUint() {
    return 0;
  }
}