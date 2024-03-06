import 'dart:ffi';

import 'package:ydart/structs/content_embed.dart';
import 'package:ydart/structs/content_format.dart';
import 'package:ydart/structs/content_string.dart';
import 'package:ydart/types/abstract_type.dart';
import 'package:ydart/types/y_array_base.dart';
import 'package:ydart/utils/id.dart';
import 'package:ydart/utils/snapshot.dart';
import 'package:ydart/utils/transaction.dart';
import 'package:ydart/utils/y_doc.dart';
import 'package:ydart/utils/y_event.dart';

import '../structs/item.dart';

const yTextRefId = 2;
const changeKey = "ychange";

enum ChangeType { insert, delete, retain }

enum YTextChangeType { added, removed }

class YTextChangeAttributes {
  YTextChangeType? type;
  int? user;
  YTextChangeType? state;

  YTextChangeAttributes({
    this.type,
    this.user,
    this.state,
  });
}

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

class ItemTextListPosition {
  Item? left;
  Item? right;
  int index;
  Map<String, Object> currentAttributes;

  ItemTextListPosition({
    this.left,
    this.right,
    required this.index,
    required this.currentAttributes,
  });

  factory ItemTextListPosition.create(Item? left, Item? right, int index,
      Map<String, Object> currentAttributes) {
    return ItemTextListPosition(
      left: left,
      right: right,
      index: index,
      currentAttributes: currentAttributes,
    );
  }

  void forward() {
    var right = this.right;
    if (right == null) {
      throw Exception("unexpected");
    }
    var rightContent = right.content;
    if (rightContent is ContentEmbed || rightContent is ContentString) {
      if (!right.deleted) {
        index += right.length;
      }
    }
    if (rightContent is ContentFormat) {
      if (!right.deleted) {
        YText.updateCurrentAttributes(currentAttributes, rightContent);
      }
    }
    left = right;
    this.right = right.right as Item?;
  }

  void findNexPosition(Transaction transaction, int count) {
    var right = this.right;
    while (right != null && count > 0) {
      var rContent = right.content;
      if (rContent is ContentEmbed || rContent is ContentString) {
        if (!right.deleted) {
          if (count < right.length) {
            transaction.doc.store.getItemCleanStart(
              transaction,
              ID(
                client: right.id.client,
                clock: right.id.clock + count,
              ),
            );
          }
          index += right.length;
          count -= right.length;
        }
      } else if (rContent is ContentFormat) {
        if (!right.deleted) {
          YText.updateCurrentAttributes(currentAttributes, rContent);
        }
      }
      left = right;
      this.right = right = right.right as Item?;
    }
  }

  void insertNegatedAttributes(Transaction transaction, AbstractType parent,
      Map<String, Object> negatedAttributes) {
    bool loopCheck() {
      var right = this.right;
      if (right == null) {
        return false;
      }
      if (right.deleted) {
        return true;
      }
      var content = right.content;
      if (content is ContentFormat) {
        if (negatedAttributes.containsKey(content.key)) {
          if (YText.equalAttrs(negatedAttributes[content.key], content.value)) {
            return true;
          }
        }
      }
      return false;
    }

    while (loopCheck()) {
      if (!this.right!.deleted) {
        negatedAttributes.remove((this.right!.content as ContentFormat).key);
      }
      forward();
    }
    var doc = transaction.doc;
    var ownClientId = doc.clientId;
    var left = this.left;
    var right = this.right;
    for (var kvp in negatedAttributes.entries) {
      left = Item.create(
        ID.create(ownClientId, doc.store.getState(ownClientId)),
        left,
        left?.lastId,
        right,
        right?.id,
        parent,
        null,
        ContentFormat.create(kvp.key, kvp.value),
        1,
      );
      left.integrate(transaction, 0);

      currentAttributes[kvp.key] = kvp.value;
      YText.updateCurrentAttributes(
          currentAttributes, left.content as ContentFormat);
    }
  }

  void minimizeAttributeChanges(Map<String, Object> attributes) {
    bool checkForward() {
      if (right!.deleted) {
        return true;
      }
      var content = right!.content;
      if (content is! ContentFormat) {
        return false;
      }
      var val = attributes[content.key];
      if (YText.equalAttrs(val, content.value)) {
        return true;
      }
      return false;
    }

    while (right != null) {
      if (!checkForward()) {
        break;
      }
      forward();
    }
  }
}

class YText extends YArrayBase {
  final List<Function> _pending = [];

  YText(String text) {
    if (text.isNotEmpty) {
      _pending.add(() => insert(0, text));
    }
  }

  void applyDelta(List<Delta> delta, [bool sanitize = true]) {
    var doc = this.doc;
    if (doc == null) {
      _pending.add(() => applyDelta(delta, sanitize));
      return;
    }
    doc.transact((tr) {
      var curPos = ItemTextListPosition.create(null, start, 0, {});
      for (int i = 0; i < delta.length; i++) {
        var op = delta[i];
        if (op.insert != null) {
          var insertStr = op.insert as String;
          var ins = (!sanitize &&
                  i == delta.length - 1 &&
                  curPos.right == null &&
                  insertStr.endsWith("\n"))
              ? insertStr.substring(0, insertStr.length - 1)
              : op.insert;
          if (ins is! String || ins.isNotEmpty) {
            insertText(tr, curPos, ins, op.attributes ?? {});
          }
        } else if (op.retain != null) {
          formatText(tr, curPos, op.retain, op.attributes ?? {});
        } else if (op.delete != null) {
          deleteText(tr, curPos, op.delete);
        }
      }
    });
  }

  List<Delta> toDelta({
    Snapshot? snapshot,
    Snapshot? prevSnapshot,
    YTextChangeAttributes Function(YTextChangeType type, ID id)? computeYChange,
  }) {
    var ops = <Delta>[];
    var currentAttributes = <String, Object>{};
    var doc = this.doc;
    var str = "";

    void packStr() {
      if (str.isNotEmpty) {
        // Pack str with attributes to ops.
        var attributes = <String, Object>{};
        var addAttributes = false;

        for (var kvp in currentAttributes.entries) {
          addAttributes = true;
          attributes[kvp.key] = kvp.value;
        }

        var op = Delta(insert: str);
        if (addAttributes) {
          op.attributes = attributes;
        }
        ops.add(op);
        str = "";
      }
    }

    doc?.transact((tr) {
      if (snapshot != null) {
        Transaction.splitSnapshotAffectedStructs(tr, snapshot);
      }

      if (prevSnapshot != null) {
        Transaction.splitSnapshotAffectedStructs(tr, prevSnapshot);
      }
      var n = start;
      while (n != null) {
        bool isSnapshotVisible = snapshot != null && n.isVisible(snapshot);
        bool isPrevSnapshotVisible =
            prevSnapshot != null && n.isVisible(prevSnapshot);
        if (isSnapshotVisible || isPrevSnapshotVisible) {
          var content = n.content;
          if (content is ContentString) {
            var cur = currentAttributes[changeKey] as YTextChangeAttributes?;
            if (isSnapshotVisible) {
              if (cur == null ||
                  cur.user != n.id.client ||
                  cur.state != YTextChangeType.removed) {
                packStr();
                currentAttributes[changeKey] = computeYChange != null
                    ? computeYChange(YTextChangeType.removed, n.id)
                    : YTextChangeAttributes(
                        type: YTextChangeType.removed,
                      );
              }
            } else if (isPrevSnapshotVisible) {
              if (cur == null ||
                  cur.user != n.id.client ||
                  cur.state != YTextChangeType.added) {
                packStr();
                currentAttributes[changeKey] = computeYChange != null
                    ? computeYChange(YTextChangeType.added, n.id)
                    : YTextChangeAttributes(type: YTextChangeType.added);
              }
            } else if (cur != null) {
              packStr();
              currentAttributes.remove(changeKey);
            }
            str += content.content;
          }
          if (content is ContentEmbed) {
            packStr();
            var op = Delta(insert: content.embed);
            if (currentAttributes.isNotEmpty) {
              op.attributes = Map.from(currentAttributes);
            }
            ops.add(op);
          }
          if (content is ContentFormat) {
            if (isSnapshotVisible) {
              packStr();
              updateCurrentAttributes(currentAttributes, content);
            }
          }
        }

        n = n.right as Item?;
      }
      packStr();
    }, "splitSnapshotAffectedStructs");

    return ops;
  }

  void insert(int index, String text, [Map<String, Object>? attributes]) {}

  void insertEmbed(int index, Object embed,
      [Map<String, Object>? attributes]) {}

  void delete(int index, int length) {}

  void format(int index, int length, Map<String, Object> attributes) {}

  void removeAttribute(String name) {}

  void setAttribute(String name, Object value) {}

  Object? getAttribute(String name) {
    return tryTypeMapGet(name);
  }

  Map<String, Object>? getAttributes() {
    return null;
  }

  @override
  void integrate(YDoc? doc, Item item) {
    super.integrate(doc, item);
  }

  @override
  void callObserver(Transaction transaction, Set<String> parentSubs) {
    super.callObserver(transaction, parentSubs);
  }

  @override
  String toString() {
    return super.toString();
  }

  static void updateCurrentAttributes(
      Map<String, Object?> currentAttributes, ContentFormat content) {}

  static bool equalAttrs(Object? curVal, Object? value) {
    return false;
  }
}
