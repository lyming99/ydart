/// 完成1次review
import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';
import '../utils/encoding.dart';
import '../utils/transaction.dart';
import '../utils/y_doc.dart';

const yArrayRefId = 0;
class YArrayEvent extends YEvent {
  YArrayEvent({
    required super.target,
    required super.transaction,
  });
}

class YArray extends YArrayBase {
  /// 记录没有整合的内容
  final List<Object> _prelimContent = [];

  @override
  int get length => _prelimContent.length;

  @override
  void integrate(YDoc? doc, Item item) {
    super.integrate(doc, item);
    insert(0, _prelimContent);
  }

  @override
  void write(AbstractEncoder encoder) {
    encoder.writeTypeRef(yArrayRefId);
  }

  static YArray read(AbstractDecoder decoder) {
    return YArray();
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    super.callObserver(transaction, parentSubs);
    callTypeObservers(
        transaction, YArrayEvent(target: this, transaction: transaction));
  }

  void insert(int index, List<Object> content) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        insertGenerics(tr, index, content);
      });
    } else {
      _prelimContent.insertAll(index, content);
    }
  }

  void add(List<Object> content) {
    insert(length, content);
  }

  void delete(int index, [int length = 1]) {
    var doc = this.doc;
    if (doc != null) {
      doc.transact((tr) {
        deleteImpl(tr, index, length);
      });
    } else {
      _prelimContent.removeRange(index, index + length);
    }
  }

  List<Object> slice([int start = 0, int end = 0]) {
    return internalSlice(start, end);
  }

  Object get(int index) {
    var mark = findMarker(index);
    var n = start;
    if (mark != null) {
      n = mark.p;
      index -= mark.index;
    }
    // 按照逻辑，right 只会是 item 或者 null，而不应该是 gc
    for (; n != null; n = n.right as Item?) {
      if (!n.deleted && n.countable) {
        if (index < n.length) {
          return n.content.getContent()[index];
        }
        index -= n.length;
      }
    }
    return -1;
  }
}
