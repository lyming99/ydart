import 'dart:typed_data';

import 'package:ydart/structs/content_any.dart';
import 'package:ydart/structs/content_type.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/utils/transaction.dart';

import '../structs/content_binary.dart';
import '../structs/content_doc.dart';
import '../structs/item.dart';
import '../utils/id.dart';
import '../utils/y_doc.dart';

class YArrayBase extends AbstractType {
  final ArraySearchMarkerCollection _searchMarkers =
      ArraySearchMarkerCollection();

  /// 通用的 insert
  void insertGenerics(
      Transaction transaction, int index, List<Object> content) {
    if (index == 0) {
      if (_searchMarkers.length > 0) {
        _searchMarkers.updateMarkerChanges(index, content.length);
      }
      insertGenericsAfter(transaction, null, content);
      return;
    }
    int startIndex = index;
    ArraySearchMarker? marker = findMarker(index);
    var n = start;

    if (marker != null) {
      n = marker.p;
      index -= marker.index;

      // We need to iterate one to the left so that the algorithm works.
      if (index == 0) {
        n = n.prev as Item?;
        index += n != null && n.countable && !n.deleted ? n.length : 0;
      }
    }

    for (; n != null; n = n.right as Item?) {
      if (!n.deleted && n.countable) {
        if (index <= n.length) {
          if (index < n.length) {
            // insert in-between
            transaction.doc.store.getItemCleanStart(transaction,
                ID(client: n.id.client, clock: n.id.clock + index));
          }
          break;
        }
        index -= n.length;
      }
    }

    if (_searchMarkers.length > 0) {
      _searchMarkers.updateMarkerChanges(startIndex, content.length);
    }

    insertGenericsAfter(transaction, n, content);
  }

  /// 通用的 insert after
  /// 即字面意思，在 reference item 后面创建一个新的 item,新的 item 的内容为 content
  void insertGenericsAfter(
      Transaction transaction, Item? referenceItem, List<Object> content) {
    var left = referenceItem;
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    var store = doc.store;
    var right = referenceItem == null ? start : referenceItem.right as Item?;

    var jsonContent = <Object>[];

    void packJsonContent() {
      if (jsonContent.isNotEmpty) {
        left = Item(
            id: ID(client: ownClientId, clock: store.getState(ownClientId)),
            left: left,
            leftOrigin: left?.lastId,
            right: right,
            rightOrigin: right?.id,
            parent: this,
            parentSub: null,
            content: ContentAny(content: jsonContent));
        left!.integrate(transaction, 0);
        jsonContent.clear();
      }
    }

    for (var c in content) {
      switch (c) {
        case Uint8List arr:
          packJsonContent();
          left = Item(
            id: ID(
              client: ownClientId,
              clock: store.getState(ownClientId),
            ),
            left: left,
            leftOrigin: left?.lastId,
            right: right,
            rightOrigin: right?.id,
            parent: this,
            content: ContentBinary(content: arr),
          );
          left!.integrate(transaction, 0);
          break;
        case YDoc d:
          packJsonContent();
          left = Item(
              id: ID(client: ownClientId, clock: store.getState(ownClientId)),
              left: left,
              leftOrigin: left?.lastId,
              right: right,
              rightOrigin: right?.id,
              parent: this,
              content: ContentDoc(doc: d));
          left!.integrate(transaction, 0);
          break;
        case AbstractType at:
          packJsonContent();
          left = Item(
              id: ID(client: ownClientId, clock: store.getState(ownClientId)),
              left: left,
              leftOrigin: left?.lastId,
              right: right,
              rightOrigin: right?.id,
              parent: this,
              content: ContentType(at));
          left!.integrate(transaction, 0);
          break;
        default:
          jsonContent.add(c);
          break;
      }
    }
    packJsonContent();
  }

  List<Object> internalSlice(int start, int end) {
    if (start < 0) {
      start += length;
    }
    if (end < 0) {
      end += length;
    }
    if (start < 0 || end < 0 || start < end) {
      throw RangeError("$start,$end");
    }
    int len = end - start;
    var cs = <Object>[];
    var n = this.start;
    while (n != null && len > 0) {
      if (n.countable && !n.deleted) {
        var c = n.content.getContent();
        if (c.length <= start) {
          start -= c.length;
        } else {
          for (int i = start; i < c.length && len > 0; i++) {
            cs.add(c[i]);
            len--;
          }
          start = 0;
        }
      }
      n = n.right as Item?;
    }
    return cs;
  }

  ArraySearchMarker? findMarker(int index) {
    var p = start;
    if (p == null || index == 0 || _searchMarkers.length == 0) {
      return null;
    }
    var marker = _searchMarkers.length == 0
        ? null
        : _searchMarkers._searchMarkers.reduce((a, b) =>
            ((index - a.index).abs() < (index - b.index).abs()) ? a : b);

    int pIndex = 0;
    if (marker != null) {
      p = marker.p;
      pIndex = marker.index;
      marker.refreshTimestamp();
    }
    while (p != null && p.right != null && pIndex < index) {
      if (!p.deleted && p.countable) {
        if (index < pIndex + p.length) {
          break;
        }
        pIndex += p.length;
      }
      p = p.right as Item;
    }
    while (p != null && p.left != null && pIndex > index) {
      p = p.left as Item;
      if (!p.deleted && p.countable) {
        pIndex -= p.length;
      }
    }
    while (p != null &&
        p.left != null &&
        p.left!.id.client == p.id.client &&
        p.left!.id.clock + p.left!.length == p.id.clock) {
      p = p.left as Item?;
      if (p == null) {
        break;
      }
      if (!p.deleted && p.countable) {
        pIndex -= p.length;
      }
    }
    if (p != null &&
        marker != null &&
        (marker.index - pIndex).abs() <
            ((p.parent as AbstractType).length / maxSearchMarkers)) {
      marker.update(p, pIndex);
      return marker;
    }
    return _searchMarkers.markPosition(p!, pIndex);
  }
}

const maxSearchMarkers = 80;

class ArraySearchMarkerCollection {
  final List<ArraySearchMarker> _searchMarkers = [];

  int get length => _searchMarkers.length;

  void clear() {
    _searchMarkers.clear();
  }

  ArraySearchMarker markPosition(Item p, int index) {
    if (length >= maxSearchMarkers) {
      var marker =
          _searchMarkers.reduce((a, b) => a.timestamp < b.timestamp ? a : b);
      marker.update(p, index);
      return marker;
    } else {
      var pm = ArraySearchMarker(p: p, index: index);
      _searchMarkers.add(pm);
      return pm;
    }
  }

  void updateMarkerChanges(int index, int length) {}
}

class ArraySearchMarker {
  static int _timeTick = -1;
  int timestamp = 0;
  Item p;
  int index;

  ArraySearchMarker({
    required this.p,
    required this.index,
  }) {
    timestamp = ++_timeTick;
  }

  void update(Item item, int index) {
    p.marker = false;
    p = item;
    p.marker = true;
    this.index = index;
    timestamp = ++_timeTick;
  }

  void refreshTimestamp() {
    timestamp = ++_timeTick;
  }
}
