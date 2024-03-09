import 'dart:collection';

import 'package:ydart/utils/y_event.dart';

import '../structs/abstract_struct.dart';
import '../structs/content_type.dart';
import '../structs/item.dart';
import '../types/abstract_type.dart';
import 'delete_set.dart';
import 'encoding_utils.dart';
import 'id.dart';
import 'snapshot.dart';
import 'struct_store.dart';
import 'update_encoder.dart';
import 'y_doc.dart';

class Transaction {
  final List<AbstractStruct> mergeStructs;
  final YDoc doc;
  final Object? origin;
  final bool local;
  final DeleteSet deleteSet;
  final Map<int, int> beforeState;
  Map<int, int> afterState;
  final Map<AbstractType, Set<String>> changed;
  final Map<AbstractType, List<YEvent>> changedParentTypes;
  final Map<String, Object> meta;
  final Set<YDoc> subdocsAdded;
  final Set<YDoc> subdocsRemoved;
  final Set<YDoc> subdocsLoaded;

  Transaction(this.doc, this.origin, this.local)
      : mergeStructs = [],
        deleteSet = DeleteSet(clients: {}),
        beforeState = doc.store.getStateVector(),
        afterState = {},
        changed = {},
        changedParentTypes = {},
        meta = {},
        subdocsAdded = {},
        subdocsRemoved = {},
        subdocsLoaded = {};

  ID getNextId() {
    return ID.create(doc.clientId, doc.store.getState(doc.clientId));
  }

  void addChangedTypeToTransaction(AbstractType? type, String? parentSub) {
    var item = type?.item;
    if (item == null ||
        (beforeState.containsKey(item.id.client) &&
            item.id.clock < beforeState[item.id.client]! &&
            !item.deleted)) {
      if (!changed.containsKey(type)) {
        changed[type!] = {};
      }
      if (parentSub != null) {
        changed[type]!.add(parentSub);
      }
    }
  }

  static void cleanupTransactions(
      List<Transaction> transactionCleanups, int i) {
    if (i < transactionCleanups.length) {
      var transaction = transactionCleanups[i];
      var doc = transaction.doc;
      var store = doc.store;
      var ds = transaction.deleteSet;
      var mergeStructs = transaction.mergeStructs;
      var actions = <Function>[];

      try {
        ds.sortAndMergeDeleteSet();
        transaction.afterState = store.getStateVector();
        doc.transaction = null;

        actions.add(() {
          doc.invokeOnBeforeObserverCalls(transaction);
        });

        actions.add(() {
          transaction.changed.forEach((itemType, subs) {
            if (itemType.item == null || !itemType.item!.deleted) {
              itemType.callObserver(transaction, subs);
            }
          });
        });

        actions.add(() {
          transaction.changedParentTypes.forEach((type, events) {
            if (type.item == null || !type.item!.deleted) {
              for (var evt in events) {
                if (evt.target.item == null || !evt.target.item!.deleted) {
                  evt.currentTarget = type;
                }
              }

              List<YEvent> sortedEvents = List.from(events);
              sortedEvents.sort((a, b) => a.path.length - b.path.length);

              assert(sortedEvents.isNotEmpty);

              actions.add(() {
                type.callDeepEventHandlerListeners(sortedEvents, transaction);
              });
            }
          });
        });

        actions.add(() {
          doc.invokeOnAfterTransaction(transaction);
        });

        callAll(actions);
      } finally {
        if (doc.gc) {
          ds.tryGcDeleteSet(store, doc.gcFilter);
        }

        ds.tryMergeDeleteSet(store);

        transaction.afterState.forEach((client, clock) {
          var beforeClock = transaction.beforeState[client] ?? 0;

          if (beforeClock != clock) {
            var structs = store.clients[client]!;
            var firstChangePos = StructStore.findIndexSS(structs, beforeClock);
            if (firstChangePos < 1) {
              firstChangePos = 1;
            }
            for (var j = structs.length - 1; j >= firstChangePos; j--) {
              DeleteSet.tryToMergeWithLeft(structs, j);
            }
          }
        });

        for (var j = 0; j < mergeStructs.length; j++) {
          var client = mergeStructs[j].id.client;
          var clock = mergeStructs[j].id.clock;
          var structs = store.clients[client]!;
          var replacedStructPos = StructStore.findIndexSS(structs, clock);

          if (replacedStructPos + 1 < structs.length) {
            DeleteSet.tryToMergeWithLeft(structs, replacedStructPos + 1);
          }

          if (replacedStructPos > 0) {
            DeleteSet.tryToMergeWithLeft(structs, replacedStructPos);
          }
        }

        if (!transaction.local) {
          var afterClock = transaction.afterState[doc.clientId] ?? -1;
          var beforeClock = transaction.beforeState[doc.clientId] ?? -1;
          // todo 这里为啥要创建行的clientId？
          if (afterClock != beforeClock) {
            doc.clientId = YDoc.generateNewClientId();
          }
        }

        doc.invokeAfterAllTransactions(transactionCleanups);
        doc.invokeUpdateV2(transaction);
        if (transactionCleanups.length <= i + 1) {
          doc.transactionCleanups.clear();
        } else {
          cleanupTransactions(transactionCleanups, i + 1);
        }
      }
    }
  }

  AbstractStruct? redoItem(Item item, Set<Item> redoItems) {
    var doc = this.doc;
    var store = doc.store;
    var ownClientId = doc.clientId;
    var redone = item.redone;

    if (redone != null) {
      return store.getItemCleanStart(this, redone);
    }

    var parentItem = (item.parent as AbstractType?)?.item;
    AbstractStruct? left;
    AbstractStruct? right;

    if (item.parentSub == null) {
      left = item.left;
      right = item;
    } else {
      left = item;
      while ((left as Item?)?.right != null) {
        left = left!.right;
        if (left?.id.client != ownClientId) {
          return null;
        }
      }
      if (left?.right != null) {
        left = (item.parent as AbstractType?)?.map[item.parentSub];
      }
      right = null;
    }

    if (parentItem != null && parentItem.deleted && parentItem.redone == null) {
      if (!redoItems.contains(parentItem) ||
          redoItem(parentItem, redoItems) == null) {
        return null;
      }
    }

    if (parentItem != null && parentItem.redone != null) {
      while (parentItem?.redone != null) {
        parentItem = store.getItemCleanStart(this, parentItem!.redone!) as Item;
      }

      while (left != null) {
        AbstractStruct? leftTrace = left;
        while (leftTrace != null &&
            ((leftTrace as Item).parent as AbstractType?)?.item != parentItem) {
          leftTrace = leftTrace.redone == null
              ? null
              : store.getItemCleanStart(this, leftTrace.redone!);
        }

        if (leftTrace != null &&
            ((leftTrace as Item).parent as AbstractType?)?.item == parentItem) {
          left = leftTrace;
          break;
        }

        left = (left as Item?)?.left;
      }

      while (right != null) {
        AbstractStruct? rightTrace = right;
        while (rightTrace != null &&
            ((rightTrace as Item).parent as AbstractType?)?.item !=
                parentItem) {
          rightTrace = rightTrace.redone == null
              ? null
              : store.getItemCleanStart(this, rightTrace.redone!);
        }

        if (rightTrace != null &&
            ((rightTrace as Item).parent as AbstractType?)?.item ==
                parentItem) {
          right = rightTrace;
          break;
        }

        right = (right as Item).right;
      }
    }

    var nextClock = store.getState(ownClientId);
    var nextId = ID.create(ownClientId, nextClock);

    var redoneItem = Item.create(
      nextId,
      left,
      (left as Item?)?.lastId,
      right,
      right?.id,
      parentItem == null
          ? item.parent
          : (parentItem.content as ContentType?)?.type,
      item.parentSub,
      item.content.copy(),
    );

    item.redone = nextId;

    redoneItem.keepItemAndParents(true);
    redoneItem.integrate(this, 0);

    return redoneItem;
  }

  static void splitSnapshotAffectedStructs(
      Transaction transaction, Snapshot snapshot) {
    if (!transaction.meta.containsKey('splitSnapshotAffectedStructs')) {
      transaction.meta['splitSnapshotAffectedStructs'] = HashSet<Snapshot>();
    }

    var meta =
        transaction.meta['splitSnapshotAffectedStructs'] as HashSet<Snapshot>;
    var store = transaction.doc.store;

    if (!meta.contains(snapshot)) {
      snapshot.stateVector.forEach((client, clock) {
        if (clock < store.getState(client)) {
          store.getItemCleanStart(transaction, ID.create(client, clock));
        }
      });

      snapshot.deleteSet.iterateDeletedStructs(transaction, (item) => true);
      meta.add(snapshot);
    }
  }

  bool writeUpdateMessageFromTransaction(IUpdateEncoder encoder) {
    if (deleteSet.clients.isEmpty &&
        !afterState.keys.any((client) =>
            !beforeState.containsKey(client) ||
            afterState[client] != beforeState[client])) {
      return false;
    }

    deleteSet.sortAndMergeDeleteSet();
    EncodingUtils.writeClientsStructs(encoder, doc.store, beforeState);
    deleteSet.write(encoder);

    return true;
  }

  static void callAll(List<Function> funcs, [int index = 0]) {
    for (; index < funcs.length; index++) {
      funcs[index]();
    }
  }
}
