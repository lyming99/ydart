import 'dart:core';

import '../types/abstract_type.dart';

class AbsolutePosition {
  final AbstractType type;
  final int index;
  final int assoc;

  AbsolutePosition(this.type, this.index, {this.assoc = 0});

  static AbsolutePosition? tryCreateFromRelativePosition(RelativePosition rpos, YDoc doc) {
    var store = doc.store;
    var rightId = rpos.item;
    var typeId = rpos.typeId;
    var tName = rpos.tName;
    var assoc = rpos.assoc;
    int index = 0;
    AbstractType? type;

    if (rightId != null) {
      if (store.getState(rightId.value.client) <= rightId.value.clock) {
        return null;
      }

      var res = store.followRedone(rightId.value);
      var right = res.item as Item?;
      if (right == null) {
        return null;
      }

      type = right.parent as AbstractType?;
      assert(type != null);

      if (type!._item == null || !type!._item.deleted) {
        index = (right.deleted || !right.countable) ? 0 : (res.diff + (assoc >= 0 ? 0 : 1));
        var n = right.left as Item?;
        while (n != null) {
          if (!n.deleted && n.countable) {
            index += n.length;
          }

          n = n.left as Item?;
        }
      }
    } else {
      if (tName != null) {
        type = doc.get<AbstractType>(tName);
      } else if (typeId != null) {
        if (store.getState(typeId.value.client) <= typeId.value.clock) {
          return null;
        }

        var item = store.followRedone(typeId.value).item as Item?;
        if (item != null && item.content is ContentType) {
          type = (item.content as ContentType).type;
        } else {
          return null;
        }
      } else {
        throw Exception();
      }

      index = assoc >= 0 ? type.length : 0;
    }

    return AbsolutePosition(type!, index, assoc: assoc);
  }
}