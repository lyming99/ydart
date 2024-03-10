import 'package:ydart/utils/queue_stack.dart';

import '../structs/item.dart';
import '../types/abstract_type.dart';
import '../types/y_array_base.dart';
import 'delete_set.dart';
import 'id.dart';
import 'transaction.dart';
import 'y_doc.dart';
import 'y_event.dart';

enum OperationType { undo, redo }

class StackEventArgs {
  final StackItem stackItem;
  final OperationType type;
  final Map<AbstractType, List<YEvent>> changedParentTypes;
  final Object? origin;

  StackEventArgs(
      this.stackItem, this.type, this.changedParentTypes, this.origin);
}

class StackItem {
  late Map<int, int> beforeState;
  late Map<int, int> afterState;
  late Map<String, Object> meta;
  late DeleteSet deleteSet;
  late DeleteSet deletions;

  StackItem(this.deleteSet, this.beforeState, this.afterState) {
    meta = {};
  }
}

class UndoManager {
  late List<AbstractType> _scope;
  late bool Function(Item) _deleteFilter;
  late Set<Object?> _trackedOrigins;
  late QueueStack<StackItem> _undoStack;
  late QueueStack<StackItem> _redoStack;
  late bool _undoing;
  late bool _redoing;
  late YDoc _doc;
  late DateTime _lastChange;
  late int _captureTimeout;
  var ignoreRemoteMapChanges = false;

  List<Function(StackEventArgs)> stackItemAdded = [];

  List<Function(StackEventArgs)> stackItemPopped = [];

  factory UndoManager.create(AbstractType typeScope) {
    return UndoManager([typeScope], 500, (Item it) => true, {null});
  }

  UndoManager(List<AbstractType> typeScopes, int captureTimeout,
      bool Function(Item)? deleteFilter,
      Set<Object?> trackedOrigins) {
    _scope = typeScopes;
    _deleteFilter = deleteFilter ?? ((Item it) => true);
    _trackedOrigins = trackedOrigins..add(this);
    _undoStack = QueueStack<StackItem>();
    _redoStack = QueueStack<StackItem>();
    _undoing = false;
    _redoing = false;
    _doc = typeScopes[0].doc!;
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
    _captureTimeout = captureTimeout;

    _doc.afterTransaction.add((transaction) {
      var isChangeParentType = _scope.any(
          (element) => transaction.changedParentTypes.containsKey(element));
      var isTrackOrigins = _trackedOrigins.contains(transaction.origin);
      var isOriginNull = transaction.origin == null;
      var hasType =
          _trackedOrigins.any((to) => transaction.origin.runtimeType == to);
      var flag1 = !isChangeParentType;
      var flag2 = !isTrackOrigins && (isOriginNull || !hasType);

      if (flag1 || flag2) {
        return;
      }

      var undoing = _undoing;
      var redoing = _redoing;
      QueueStack stack = undoing ? _redoStack : _undoStack;

      if (undoing) {
        stopCapturing();
      } else if (!redoing) {
        _redoStack.clear();
      }

      var beforeState = transaction.beforeState;
      var afterState = transaction.afterState;

      var now = DateTime.now();
      if (now.difference(_lastChange).inMilliseconds < _captureTimeout &&
          stack.isNotEmpty &&
          !undoing &&
          !redoing) {
        var lastOp = stack.peek();
        lastOp.deleteSet =
            DeleteSet.merge([lastOp.deleteSet, transaction.deleteSet]);
        lastOp.afterState = afterState;
      } else {
        var item = StackItem(transaction.deleteSet, beforeState, afterState);
        stack.push(item);
      }

      if (!undoing && !redoing) {
        _lastChange = now;
      }

      transaction.deleteSet.iterateDeletedStructs(transaction, (str) {
        if (str is Item && _scope.any((type) => isParentOf(type, str))) {
          str.keepItemAndParents(true);
        }
        return true;
      });
      stackItemAdded.forEach((element) {
        element.call(StackEventArgs(
            stack.peek(),
            undoing ? OperationType.redo : OperationType.undo,
            transaction.changedParentTypes,
            transaction.origin));
      });
    });
  }

  void stopCapturing() {
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
  }

  StackItem? undo() {
    _undoing = true;
    StackItem? res;
    try {
      res = popStackItem(_undoStack, OperationType.undo);
    } finally {
      _undoing = false;
    }
    return res;
  }

  StackItem? redo() {
    _redoing = true;
    StackItem? res;
    try {
      res = popStackItem(_redoStack, OperationType.redo);
    } finally {
      _redoing = false;
    }
    return res;
  }
  StackItem? popStackItem1(
      QueueStack<StackItem> stack, OperationType eventType) {
    StackItem? result;
    Transaction? tr;
    _doc.transact((transaction) {
      while (stack.isNotEmpty && result == null) {
         var store = _doc.store;
         var stackItem = stack.pop();
         var itemsToRedo = {};
         var itemsToDelete = [];
         stackItem.beforeState;
         stackItem.deleteSet.iterateDeletedStructs(transaction, (type) => false)
      }

      transaction.changed.forEach((type, subProps) {
        if (subProps.contains(null) && type is YArrayBase) {
          type.clearSearchMarkers();
        }
      });
    }, origin: this);

    if (result != null) {
      for (var element in stackItemPopped) {
        element.call(StackEventArgs(
            result!, eventType, tr!.changedParentTypes, tr!.origin));
      }
    }
    return result;
  }
  StackItem? popStackItem(
      QueueStack<StackItem> stack, OperationType eventType) {
    StackItem? result;

    Transaction? tr;

    _doc.transact((transaction) {
      tr = transaction;

      while (stack.isNotEmpty && result == null) {
        var stackItem = stack.pop();
        var itemsToRedo = <Item>{};
        var itemsToDelete = <Item>[];
        var performedChange = false;

        stackItem.afterState.forEach((client, endClock) {
          var startClock = stackItem.beforeState[client] ?? 0;
          var len = endClock - startClock;
          var structs = _doc.store.clients[client]!;

          if (startClock != endClock) {
            _doc.store
                .getItemCleanStart(transaction, ID.create(client, startClock));

            if (endClock < _doc.store.getState(client)) {
              _doc.store
                  .getItemCleanStart(transaction, ID.create(client, endClock));
            }

            _doc.store.iterateStructs(transaction, structs, startClock, len,
                (it) {
              if (it is Item) {
                if (it.redone != null) {
                  var redoneResult = _doc.store.followRedone(it.id);
                  var diff = redoneResult.diff;
                  var item = redoneResult.item;

                  if (diff > 0) {
                    item = _doc.store.getItemCleanStart(transaction,
                            ID.create(item!.id.client, item.id.clock + diff))
                        as Item;
                  }

                  if (item!.length > len) {
                    _doc.store.getItemCleanStart(
                        transaction, ID.create(item.id.client, endClock));
                  }

                  it = item;
                }

                if (!it.deleted &&
                    _scope.any((type) => isParentOf(type, it as Item))) {
                  itemsToDelete.add(it as Item);
                }
              }

              return true;
            });
          }
        });

        stackItem.deleteSet.iterateDeletedStructs(transaction, (str) {
          var id = str.id;
          var clock = id.clock;
          var client = id.client;
          var startClock = stackItem.beforeState[client] ?? 0;
          var endClock = stackItem.afterState[client] ?? 0;

          if (str is Item &&
              _scope.any((type) => isParentOf(type, str)) &&
              !(clock >= startClock && clock < endClock)) {
            itemsToRedo.add(str);
          }

          return true;
        });

        for (var str in itemsToRedo) {
          performedChange |= transaction.redoItem(str, itemsToRedo) != null;
        }

        for (var i = itemsToDelete.length - 1; i >= 0; i--) {
          var item = itemsToDelete[i];
          if (_deleteFilter(item)) {
            item.delete(transaction);
            performedChange = true;
          }
        }

        result = stackItem;
      }

      transaction.changed.forEach((type, subProps) {
        if (subProps.contains(null) && type is YArrayBase) {
          type.clearSearchMarkers();
        }
      });
    }, origin: this);

    if (result != null) {
      for (var element in stackItemPopped) {
        element.call(StackEventArgs(
            result!, eventType, tr!.changedParentTypes, tr!.origin));
      }
    }
    return result;
  }

  bool isParentOf(AbstractType parent, Item child) {
    Item? currentChild = child;
    while (currentChild != null) {
      if (currentChild.parent == parent) {
        return true;
      }
      currentChild = (currentChild.parent as AbstractType).item;
    }
    return false;
  }
}
