
import 'dart:collection';

enum OperationType{
  undo,redo
}
class StackEventArgs{

}

class StackItem {
  late Map<int, int> beforeState;
  late Map<int, int> afterState;
  late Map<String, Object> meta;
  late DeleteSet deleteSet;

  StackItem(this.deleteSet, this.beforeState, this.afterState) {
    meta = {};
  }
}

class UndoManager {
  late List<AbstractType> _scope;
  late bool Function(Item) _deleteFilter;
  late Set<Object> _trackedOrigins;
  late Stack<StackItem> _undoStack;
  late Stack<StackItem> _redoStack;
  late bool _undoing;
  late bool _redoing;
  late YDoc _doc;
  late DateTime _lastChange;
  late int _captureTimeout;

  UndoManager(AbstractType typeScope)
      : this([typeScope], 500, (Item it) => true, {null});

  UndoManager(List<AbstractType> typeScopes, int captureTimeout,
      bool Function(Item) deleteFilter, Set<Object> trackedOrigins) {
    _scope = typeScopes;
    _deleteFilter = deleteFilter ?? ((Item it) => true);
    _trackedOrigins = trackedOrigins..add(this);
    _undoStack = Stack<StackItem>();
    _redoStack = Stack<StackItem>();
    _undoing = false;
    _redoing = false;
    _doc = typeScopes[0].doc;
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
    _captureTimeout = captureTimeout;

    _doc.afterTransaction.listen((transaction) {
      if (!_scope.any((type) => transaction.changedParentTypes.containsKey(type)) ||
          (!_trackedOrigins.contains(transaction.origin) &&
              (transaction.origin == null ||
                  !_trackedOrigins.any((to) =>
                      (to as Type).isAssignableFrom(transaction.origin.runtimeType)))) {
      return;
      }

      var undoing = _undoing;
      var redoing = _redoing;
      var stack = undoing ? _redoStack : _undoStack;

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
        var lastOp = stack.top;
        lastOp.deleteSet = DeleteSet([lastOp.deleteSet, transaction.deleteSet]);
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

      stackItemAdded?.call(StackEventArgs(stack.top, undoing ? OperationType.redo : OperationType.undo,
          transaction.changedParentTypes, transaction.origin));
    });
  }

  void stopCapturing() {
    _lastChange = DateTime.fromMillisecondsSinceEpoch(0);
  }

  StackItem undo() {
    _undoing = true;
    StackItem res;

    try {
      res = popStackItem(_undoStack, OperationType.undo);
    } finally {
      _undoing = false;
    }

    return res;
  }

  StackItem redo() {
    _redoing = true;
    StackItem res;

    try {
      res = popStackItem(_redoStack, OperationType.redo);
    } finally {
      _redoing = false;
    }

    return res;
  }

  StackItem popStackItem(Stack<StackItem> stack, OperationType eventType) {
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
          var structs = _doc.store.clients[client];

          if (startClock != endClock) {
            _doc.store.getItemCleanStart(transaction, ID(client, startClock));

            if (endClock < _doc.store.getState(client)) {
              _doc.store.getItemCleanStart(transaction, ID(client, endClock));
            }

            _doc.store.iterateStructs(transaction, structs, startClock, len, (str) {
              if (str is Item) {
                if (str.redone != null) {
                  var redoneResult = _doc.store.followRedone(str.id);
                  var diff = redoneResult.diff;
                  var item = redoneResult.item;

                  if (diff > 0) {
                    item = _doc.store.getItemCleanStart(transaction, ID(item.id.client, item.id.clock + diff)) as Item;
                  }

                  if (item.length > len) {
                    _doc.store.getItemCleanStart(transaction, ID(item.id.client, endClock));
                  }

                  str = item;
                }

                if (!str.deleted && _scope.any((type) => isParentOf(type, str))) {
                  itemsToDelete.add(str);
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

        itemsToRedo.forEach((str) {
          performedChange |= transaction.redoItem(str, itemsToRedo) != null;
        });

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
      stackItemPopped?.call(StackEventArgs(result!, eventType, tr!.changedParentTypes, tr!.origin));
    }

    return result!;
  }

  bool isParentOf(AbstractType parent, Item child) {
    var currentChild = child;
    while (currentChild != null) {
      if (currentChild.parent == parent) {
        return true;
      }
      currentChild = (currentChild.parent as AbstractType)._item;
    }
    return false;
  }
}