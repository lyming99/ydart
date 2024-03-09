import 'dart:js_interop_unsafe';

import 'package:ydart/lib0/constans.dart';
import 'package:ydart/structs/abstract_struct.dart';
import 'package:ydart/structs/content_deleted.dart';
import 'package:ydart/structs/gc.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/encoding.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/struct_store.dart';
import 'package:ydart/utils/transaction.dart';

import '../utils/id.dart';
import '../utils/update_encoder.dart';
import 'base_content.dart';
import 'content_type.dart';

class InfoEnum {
  static int zero = 0;
  static int keep = 1;
  static int countable = (1 << 1);
  static int deleted = (1 << 2);
  static int marker = (1 << 3);
}

extension _InfoEnum on int {
  bool hasFlag(int other) {
    return (other & this) > 0;
  }
}

class Item extends AbstractStruct {
  AbstractStruct? left;
  AbstractStruct? right;
  ID? leftOrigin;
  ID? rightOrigin;

  // AbstractType or ID
  Object? parent;
  String? parentSub;
  IContentEx content;
  late int info;
  ID? redone;

  Item({
    required super.id,
    this.left,
    this.leftOrigin,
    this.right,
    this.rightOrigin,
    this.parent,
    this.parentSub,
    required this.content,
    super.length = 1,
  }) {
    length = content.length;
    info = content.isCountable ? InfoEnum.countable : InfoEnum.zero;
  }

  factory Item.create(
      ID id,
      AbstractStruct? left,
      ID? leftOrigin,
      AbstractStruct? right,
      ID? rightOrigin,
      Object? parent,
      String? parentSub,
      IContentEx content,
      [int length = 1]) {
    return Item(
      id: id,
      content: content,
      leftOrigin: leftOrigin,
      left: left,
      right: right,
      rightOrigin: rightOrigin,
      parentSub: parentSub,
      parent: parent,
      length: length,
    );
  }

  bool get marker {
    return info.hasFlag(InfoEnum.marker);
  }

  set marker(bool value) {
    if (value) {
      info |= InfoEnum.marker;
    } else {
      info &= ~InfoEnum.marker;
    }
  }

  bool get keep {
    return info.hasFlag(InfoEnum.keep);
  }

  set keep(bool value) {
    if (value) {
      info |= InfoEnum.keep;
    } else {
      info &= ~InfoEnum.keep;
    }
  }

  bool get countable {
    return info.hasFlag(InfoEnum.countable);
  }

  set countable(bool value) {
    if (value) {
      info |= InfoEnum.countable;
    } else {
      info &= ~InfoEnum.countable;
    }
  }

  @override
  bool get deleted => info.hasFlag(InfoEnum.deleted);

  ID get lastId =>
      length == 1 ? id : ID.create(id.client, id.clock + length - 1);

  AbstractStruct? get next {
    var n = right;
    while (n != null && n.deleted) {
      n = (n as Item).right;
    }
    return n;
  }

  AbstractStruct? get prev {
    var n = left;
    while (n != null && n.deleted) {
      n = (n as Item).left;
    }
    return n;
  }

  void markDeleted() {
    info |= InfoEnum.deleted;
  }

  @override
  bool mergeWith(AbstractStruct right) {
    var rightItem = right as Item?;

    if ((rightItem?.leftOrigin == lastId) &&
        this.right == right &&
        (rightItem?.rightOrigin == rightOrigin) &&
        id.client == right.id.client &&
        id.clock + length == right.id.clock &&
        deleted == right.deleted &&
        redone == null &&
        rightItem?.redone == null &&
        content.runtimeType == rightItem?.content.runtimeType &&
        content.mergeWith(rightItem!.content)) {
      if (rightItem.keep) {
        keep = true;
      }

      this.right = rightItem.right;
      if (this.right is Item) {
        (this.right as Item).left = this;
      }
      length += rightItem.length;
      return true;
    }

    return false;
  }

  @override
  void delete(Transaction transaction) {
    if (!deleted) {
      var parent = this.parent as AbstractType?;
      if (countable && parentSub == null) {
        parent!.length -= length;
      }
      markDeleted();
      transaction.deleteSet.add(id.client, id.clock, length);
      transaction.addChangedTypeToTransaction(parent, parentSub);
    }
  }

  @override
  void integrate(Transaction transaction, int offset) {
    if (offset > 0) {
      id = ID(client: id.client, clock: id.clock + offset);
    }
    if (parent == null) {
      GC(id: id, length: length).integrate(transaction, 0);
      return;
    }
    if ((left == null && (right == null || (right as Item?)?.left != null)) ||
        (left != null && (left as Item?)?.right != right)) {
      var left = this.left;
      AbstractStruct? o;
      // Set 'o' to the first conflicting item.
      if (left != null) {
        o = (left as Item?)?.right;
      } else if (parentSub != null) {
        o = (parent as AbstractType?)?.map[parentSub!];
        while (o != null && (o as Item?)?.left != null) {
          o = (o as Item).left;
        }
      } else {
        o = (parent as AbstractType?)?.start;
      }

      var conflictingItems = <AbstractStruct>{};
      var itemsBeforeOrigin = <AbstractStruct>{};

      while (o != null && o != right) {
        itemsBeforeOrigin.add(o);
        conflictingItems.add(o);

        if ((leftOrigin == (o as Item?)?.leftOrigin)) {
          // Case 1
          if (o.id.client < id.client) {
            left = o;
            conflictingItems.clear();
          } else if ((rightOrigin == (o as Item?)?.rightOrigin)) {
            // This and 'o' are conflicting and point to the same integration points.
            // The id decides which item comes first.
            // Since this is to the left of 'o', we can break here.
            break;
          }
          // Else, 'o' might be integrated before an item that this conflicts with.
          // If so, we will find it in the next iterations.
        }
        // Use 'Find' instead of 'GetItemCleanEnd', because we don't want / need to split items.
        else if ((o as Item?)?.leftOrigin != null &&
            itemsBeforeOrigin.contains(
                transaction.doc.store.find((o as Item).leftOrigin!))) {
          // Case 2
          // TODO: Store.Find is called twice here, call once?
          if (!conflictingItems
              .contains(transaction.doc.store.find((o).leftOrigin!))) {
            left = o;
            conflictingItems.clear();
          }
        } else {
          break;
        }

        o = (o as Item?)?.right;
      }

      this.left = left;
    }

    // Reconnect left/right + update parent map/start if necessary.
    if (this.left != null) {
      if (this.left is Item) {
        var leftItem = this.left as Item;
        this.right = leftItem.right;
        leftItem.right = this;
      } else {
        this.right = null;
      }
    } else {
      AbstractStruct? r;

      if (parentSub != null) {
        var parentMap = (parent as AbstractType?)?.map;
        r = parentMap?[parentSub];
        while (r != null && (r as Item?)?.left != null) {
          r = (r as Item).left;
        }
      } else {
        var abstractTypeParent = parent;
        if (abstractTypeParent is AbstractType) {
          r = abstractTypeParent.start;
          abstractTypeParent.start = this;
        } else {
          r = null;
        }
      }

      right = r;
    }

    if (right != null) {
      var rightItem = right;
      if (rightItem is Item) {
        rightItem.left = this;
      }
    } else if (parentSub != null) {
      // Set as current parent value if right == null and this is parentSub.
      (parent as AbstractType).map[parentSub!] = this;
      // This is the current attribute value of parent. Delete right.
      left?.delete(transaction);
    }

    // Adjust length of parent.
    if (parentSub == null && countable && !deleted) {
      (parent as AbstractType).length += length;
    }

    transaction.doc.store.addStruct(this);
    content.integrate(transaction, this);

    // Add parent to transaction.changed.
    transaction.addChangedTypeToTransaction(parent as AbstractType?, parentSub);

    if (((parent as AbstractType?)?.item != null &&
            (parent as AbstractType).item!.deleted) ||
        (parentSub != null && right != null)) {
      // Delete if parent is deleted or if this is not the current attribute value of parent.
      delete(transaction);
    }
  }

  @override
  int? getMissing(Transaction transaction, StructStore store) {
    if (leftOrigin != null &&
        leftOrigin!.client != id.client &&
        leftOrigin!.clock >= store.getState(leftOrigin!.client)) {
      return leftOrigin!.client;
    }

    if (rightOrigin != null &&
        rightOrigin!.client != id.client &&
        rightOrigin!.clock >= store.getState(rightOrigin!.client)) {
      return rightOrigin!.client;
    }
    var parentId = parent;
    if ((parentId is ID) &&
        id.client != parentId.client &&
        parentId.clock >= store.getState(parentId.client)) {
      return parentId.client;
    }

    // We have all missing ids, now find the items.

    if (leftOrigin != null) {
      left = store.getItemCleanEnd(transaction, leftOrigin!);
      leftOrigin = (left as Item?)?.lastId;
    }

    if (rightOrigin != null) {
      right = store.getItemCleanStart(transaction, rightOrigin!);
      rightOrigin = right!.id;
    }

    if (left is GC || right is GC) {
      parent = null;
    }
    var pid = parent;
    // Only set parent if this shouldn't be garbage collected.
    if (parent == null) {
      var rightItem = right;
      var leftItem = left;
      if (rightItem is Item) {
        parent = rightItem.parent;
        parentSub = rightItem.parentSub;
      } else if (leftItem is Item) {
        parent = leftItem.parent;
        parentSub = leftItem.parentSub;
      }
    } else if (pid is ID) {
      var parentItem = store.find(pid);
      if (parentItem is GC) {
        parent = null;
      } else {
        parent = ((parentItem as Item?)?.content as ContentType?)?.type;
      }
    }

    return null;
  }

  void gc(StructStore store, bool parentGCd) {
    if (!deleted) {
      throw Exception("invalid operation.");
    }
    content.gc(store);
    if (parentGCd) {
      store.replaceStruct(this, GC(id: id, length: length));
    } else {
      content = ContentDeleted(length);
    }
  }

  void keepItemAndParents(bool value) {
    Item? item = this;
    while (item != null && item.keep != value) {
      item.keep = value;
      item = (item.parent as AbstractType?)?.item;
    }
  }

  bool isVisible(Snapshot? snapshot) {
    if (snapshot == null) {
      return !deleted;
    }
    var state = snapshot.stateVector[id.client];
    if (state != null) {
      return state > id.clock && snapshot.deleteSet.isDeleted(id);
    }
    return false;
  }

  @override
  void write(IUpdateEncoder encoder, int offset) {
    var origin = offset > 0
        ? ID(client: id.client, clock: id.clock + offset - 1)
        : leftOrigin;
    var rightOrigin = this.rightOrigin;
    var parentSub = this.parentSub;
    var info = (content.ref & Bits.bits5) |
        (origin == null ? 0 : Bit.bit8) |
        (rightOrigin == null ? 0 : Bit.bit7) |
        (parentSub == null ? 0 : Bit.bit6);
    encoder.writeInfo(info);
    if (origin != null) {
      encoder.writeLeftId(origin);
    }
    if (rightOrigin != null) {
      encoder.writeRightId(rightOrigin);
    }
    if (origin == null && rightOrigin == null) {
      var parent = this.parent as AbstractType;
      var parentItem = parent.item;
      if (parentItem == null) {
        var yKey = parent.findRootTypeKey();
        encoder.writeParentInfo(true);
        encoder.writeString(yKey);
      } else {
        encoder.writeParentInfo(false);
        encoder.writeLeftId(parentItem.id);
      }
      if (parentSub != null) {
        encoder.writeString(parentSub);
      }
    }
    content.write(encoder, offset);
  }

  Item splitItem(Transaction transaction, int diff) {
    var client = id.client;
    var clock = id.clock;
    var rightItem = Item.create(
        ID.create(client, clock + diff),
        this,
        ID.create(client, clock + diff - 1),
        right,
        rightOrigin,
        parent,
        parentSub,
        content.splice(diff));
    if (deleted) {
      rightItem.markDeleted();
    }
    if (keep) {
      rightItem.keep = true;
    }
    if (redone != null) {
      rightItem.redone =
          ID(client: redone!.client, clock: redone!.clock + diff);
    }
    right = rightItem;
    var rightIt = rightItem.right;
    if (rightIt is Item) {
      rightIt.left = rightItem;
    }
    transaction.mergeStructs.add(rightItem);
    if (rightItem.parentSub != null && rightItem.right == null) {
      var rParent = rightItem.parent as AbstractType;
      rParent.map[rightItem.parentSub!] = rightItem;
    }
    length = diff;
    return rightItem;
  }
}
