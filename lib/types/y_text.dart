import 'dart:ffi';

import 'package:ydart/structs/content_embed.dart';
import 'package:ydart/structs/content_format.dart';
import 'package:ydart/structs/content_string.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';

enum ChangeType { insert, delete, retain }

class YTextEvent extends YEvent {
  Set<String>? subs;
  List<Delta>? _delta;
  Set<String>? keysChanged;
  bool childListChanged = false;

  YTextEvent({
    required super.target,
    required super.transaction,
  });

  List<Delta> get delta {
    var delta = _delta;
    if (delta == null) {
      _delta = delta = <Delta>[];
      var doc = target.doc;
      if (doc != null) {
        doc.transact((tr) {
          _computeDelta(target, tr, delta!);
        });
      }
    }
    return delta;
  }

  void _computeDelta(AbstractType target, Transaction tr, List<Delta> delta) {
    var currentAttributes = <String, Object?>{};
    var oldAttributes = <String, Object?>{};
    var item = target.start;
    ChangeType? action;
    var attributes = <String, Object?>{};
    Object insert = "";
    int retain = 0;
    int deleteLen = 0;
    void addOp() {
      if (action == null) {
        return;
      }
      Delta op;
      if (action case ChangeType.delete) {
        op = Delta(delete: deleteLen);
        deleteLen = 0;
      } else if (action case ChangeType.insert) {
        op = Delta(insert: insert);
        if (currentAttributes.isNotEmpty) {
          var attr = op.attributes = <String, Object?>{};
          attr.addAll(currentAttributes);
        }
      } else if (action case ChangeType.retain) {
        op = Delta(retain: retain);
        if (attributes.isNotEmpty) {
          var attr = op.attributes = <String, Object?>{};
          attr.addAll(attributes);
        }
        retain = 0;
      } else {
        throw Exception("type error.");
      }
      delta.add(op);
      action = null;
    }
    while (item != null) {
      var content = item.content;
      if (content is ContentEmbed) {
        if (adds(item)) {
          if (!deletes(item)) {
            addOp();
            action = ChangeType.insert;
            insert = content.embed;
            addOp();
          }
        } else if (deletes(item)) {
          if (action != ChangeType.delete) {
            addOp();
            action = ChangeType.delete;
          }
          deleteLen++;
        } else if (!item.deleted) {
          if (action != ChangeType.retain) {
            addOp();
            action = ChangeType.retain;
          }
          retain++;
        }
      } else if (content is ContentString) {
        if (adds(item)) {
          if (!deletes(item)) {
            if (action != ChangeType.insert) {
              addOp();
              action = ChangeType.insert;
            }
            // 能否使用StringBuffer增加性能？
            insert = "$insert${content.content}";
          }
        } else if (deletes(item)) {
          if (action != ChangeType.delete) {
            addOp();
            action = ChangeType.delete;
          }
          deleteLen += item.length;
        } else if (!item.deleted) {
          if (action != ChangeType.retain) {
            addOp();
            action = ChangeType.retain;
          }
          retain += item.length;
        }
      } else if (content is ContentFormat) {
        if (adds(item)) {
          if (!deletes(item)) {
            var curVal = currentAttributes[content.key];
            if (!YText.equalAttrs(curVal, content.value)) {
              if (action == ChangeType.retain) {
                addOp();
              }
              var oldVal = oldAttributes[content.key];
              if (YText.equalAttrs(content.value, oldVal)) {
                attributes.remove(content.key);
              } else {
                attributes[content.key] = content.value;
              }
            } else {
              item.delete(tr);
            }
          }
        } else if (deletes(item)) {
          oldAttributes[content.key] = content.value;
          var curVal = currentAttributes[content.key];
          if (!YText.equalAttrs(curVal, content.value)) {
            if (action == ChangeType.retain) {
              addOp();
            }
            attributes[content.key] = curVal;
          }
        } else if (!item.deleted) {
          oldAttributes[content.key] = content.value;
          var attr = attributes[content.key];
          if (!YText.equalAttrs(attr, content.value)) {
            if (action == ChangeType.retain) {
              addOp();
            }
            if (content.value == null) {
              attributes[content.key] = null;
            } else {
              attributes.remove(content.key);
            }
          } else {
            item.delete(tr);
          }
        }
        if (!item.deleted) {
          if (action == ChangeType.insert) {
            addOp();
          }
          YText.updateCurrentAttributes(currentAttributes, content);
        }
      }
      item = item.right as Item?;
    }
    addOp();
    while (delta.isNotEmpty) {
      var lastOp = delta.last;
      if (lastOp.retain != null && lastOp.attributes != null) {
        delta.removeLast();
      } else {
        break;
      }
    }
  }
}

class YText extends YArrayBase {
  static void updateCurrentAttributes(
      Map<String, Object?> currentAttributes, ContentFormat content) {}

  static bool equalAttrs(Object? curVal, Object? value) {
    return false;
  }
}
