import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/item.dart';

class ChangesCollection {
  Set<Item>? added;
  Set<Item>? deleted;
  List<Delta>? delta;

  ChangesCollection({
    this.added,
    this.deleted,
    this.delta,
  });
}

class Delta {
  Object? insert;
  int? delete;
  int? retain;
  Map<String, Object?>? attributes;

  Delta({
    this.insert,
    this.delete,
    this.retain,
    this.attributes,
  });
}

class YEvent {
  ChangesCollection? _changes;

  YEvent(AbstractType target, Transaction transaction) {
    Target = target;
    CurrentTarget = target;
    Transaction = transaction;
  }

  AbstractType Target;
  AbstractType CurrentTarget;
  Transaction Transaction;

  List<Object> get Path => GetPathTo(CurrentTarget, Target);
  ChangesCollection get Changes => CollectChanges();

  bool Deletes(AbstractStruct str) {
    return Transaction.DeleteSet.IsDeleted(str.Id);
  }

  bool Adds(AbstractStruct str) {
    return !Transaction.BeforeState.containsKey(str.Id.Client) || str.Id.Clock >= Transaction.BeforeState[str.Id.Client];
  }

  ChangesCollection CollectChanges() {
    if (_changes == null) {
      var target = Target;
      var added = Set<Item>();
      var deleted = Set<Item>();
      var delta = List<Delta>();
      var keys = Map<String, ChangeKey>();

      _changes = ChangesCollection()
        ..Added = added
        ..Deleted = deleted
        ..Delta = delta
        ..Keys = keys;

      var changed = Transaction.Changed[Target];
      if (changed == null) {
        changed = HashSet<String>();
        Transaction.Changed[Target] = changed;
      }

      if (changed.contains(null)) {
        Delta? lastOp;

        void packOp() {
          if (lastOp != null) {
            delta.add(lastOp!);
          }
        }

        for (var item = Target._start; item != null; item = item.Right as Item) {
          if (item.Deleted) {
            if (Deletes(item) && !Adds(item)) {
              if (lastOp == null || lastOp!.Delete == null) {
                packOp();
                lastOp = Delta()..Delete = 0;
              }

              lastOp!.Delete! += item.Length;
              deleted.add(item);
            }
          } else {
            if (Adds(item)) {
              if (lastOp == null || lastOp!.Insert == null) {
                packOp();
                lastOp = Delta()..Insert = <Object>[];
              }

              (lastOp!.Insert as List<Object>).addAll(item.Content.GetContent());
              added.add(item);
            } else {
              if (lastOp == null || lastOp!.Retain == null) {
                packOp();
                lastOp = Delta()..Retain = 0;
              }

              lastOp!.Retain! += item.Length;
            }
          }
        }

        if (lastOp != null && lastOp!.Retain == null) {
          packOp();
        }
      }

      for (var key in changed) {
        if (key != null) {
          ChangeAction action;
          dynamic oldValue;
          var item = target._map[key];

          if (Adds(item)) {
            var prev = item.Left;
            while (prev != null && Adds(prev)) {
              prev = prev!.Left;
            }

            if (Deletes(item)) {
              if (prev != null && Deletes(prev)) {
                action = ChangeAction.Delete;
                oldValue = (prev as Item).Content.GetContent().last;
              } else {
                break;
              }
            } else {
              if (prev != null && Deletes(prev)) {
                action = ChangeAction.Update;
                oldValue = (prev as Item).Content.GetContent().last;
              } else {
                action = ChangeAction.Add;
                oldValue = null;
              }
            }
          } else {
            if (Deletes(item)) {
              action = ChangeAction.Delete;
              oldValue = item.Content.GetContent().last;
            } else {
              break;
            }
          }

          keys[key] = ChangeKey()..Action = action..OldValue = oldValue;
        }
      }
    }

    return _changes!;
  }

  List<Object> GetPathTo(AbstractType parent, AbstractType child) {
    var path = List<Object>();

    while (child._item != null && child != parent) {
      if (child._item.ParentSub != null && child._item.ParentSub!.isNotEmpty) {
        path.add(child._item.ParentSub);
      } else {
        int i = 0;
        AbstractStruct? c = child._item.Parent as AbstractType?._start;
        while (c != child._item && c != null) {
          if (!c.Deleted) {
            i++;
          }

          c = (c as Item?)?.Right;
        }

        path.add(i);
      }

      child = child._item.Parent as AbstractType;
    }

    return path.reversed.toList();
  }
}