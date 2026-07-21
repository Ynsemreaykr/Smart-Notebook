import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:home_widget/home_widget.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/plan.dart';

class PlanProvider extends ChangeNotifier {
  static const String _boxName = 'plans';

  List<Plan> _plans = [];
  bool _isLoading = false;
  final _uuid = const Uuid();
  final Set<String> _expandedIds = {};

  List<Plan> get plans => _plans;
  bool get isLoading => _isLoading;
  Set<String> get expandedIds => _expandedIds;

  bool isExpanded(String id) => _expandedIds.contains(id);

  Future<void> toggleExpanded(String id) async {
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
    } else {
      _expandedIds.add(id);
    }
    notifyListeners();
    await updateWidget();
  }

  // Load plans from Hive
  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Load expanded IDs from widget preferences
      final rawExpanded = await HomeWidget.getWidgetData<String>('expanded_ids');
      _expandedIds.clear();
      if (rawExpanded != null && rawExpanded.isNotEmpty) {
        _expandedIds.addAll(rawExpanded.split(','));
      }

      final box = Hive.box(_boxName);
      final List<Plan> loaded = [];
      for (final key in box.keys) {
        final data = box.get(key);
        if (data is Map) {
          loaded.add(Plan.fromJson(data));
        }
      }
      // Sort by creation date, newest first
      loaded.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _plans = loaded;
      await updateWidget();
    } catch (e) {
      debugPrint('Error loading plans: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Add new plan
  Future<void> addPlan(String title) async {
    if (title.trim().isEmpty) return;

    final plan = Plan(
      id: _uuid.v4(),
      title: title.trim(),
      items: [],
      createdAt: DateTime.now(),
    );

    try {
      final box = Hive.box(_boxName);
      await box.put(plan.id, plan.toJson());
      _plans.insert(0, plan);
      notifyListeners();
      await updateWidget();
    } catch (e) {
      debugPrint('Error adding plan: $e');
    }
  }

  // Delete plan
  Future<void> deletePlan(String planId) async {
    try {
      final box = Hive.box(_boxName);
      await box.delete(planId);
      _plans.removeWhere((p) => p.id == planId);
      notifyListeners();
      await updateWidget();
    } catch (e) {
      debugPrint('Error deleting plan: $e');
    }
  }

  // Reorder plans by shifting their createdAt times
  Future<void> reorderPlans(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _plans.removeAt(oldIndex);
    _plans.insert(newIndex, item);
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      final now = DateTime.now();
      for (int i = 0; i < _plans.length; i++) {
        _plans[i] = _plans[i].copyWith(createdAt: now.subtract(Duration(seconds: i)));
        await box.put(_plans[i].id, _plans[i].toJson());
      }
      await updateWidget();
    } catch (e) {
      debugPrint('Error reordering plans: $e');
    }
  }

  // Add item recursively
  Future<void> addItem(String planId, String text, {String? parentItemId}) async {
    if (text.trim().isEmpty) return;

    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx == -1) return;

    final newItem = PlanItem(
      id: _uuid.v4(),
      text: text.trim(),
      status: 'todo',
      subItems: [],
    );

    List<PlanItem> updatedItems;
    if (parentItemId == null) {
      updatedItems = List<PlanItem>.from(_plans[idx].items)..add(newItem);
    } else {
      updatedItems = _addSubItemRecursively(_plans[idx].items, parentItemId, newItem);
    }
    updatedItems = _syncParentStatuses(updatedItems);

    final updatedPlan = _syncPlanStatus(_plans[idx].copyWith(items: updatedItems));
    _plans[idx] = updatedPlan;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      await box.put(planId, updatedPlan.toJson());
      await updateWidget();
    } catch (e) {
      debugPrint('Error adding plan item: $e');
    }
  }

  List<PlanItem> _addSubItemRecursively(List<PlanItem> list, String parentId, PlanItem newItem) {
    return list.map((item) {
      if (item.id == parentId) {
        return item.copyWith(subItems: List<PlanItem>.from(item.subItems)..add(newItem));
      } else if (item.subItems.isNotEmpty) {
        return item.copyWith(subItems: _addSubItemRecursively(item.subItems, parentId, newItem));
      }
      return item;
    }).toList();
  }

  // Cycle item status recursively
  Future<void> cycleItemStatus(String planId, String itemId) async {
    final planIdx = _plans.indexWhere((p) => p.id == planId);
    if (planIdx == -1) return;

    var updatedItems = _cycleStatusRecursively(_plans[planIdx].items, itemId);
    updatedItems = _syncParentStatuses(updatedItems);
    final updatedPlan = _syncPlanStatus(_plans[planIdx].copyWith(items: updatedItems));
    _plans[planIdx] = updatedPlan;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      await box.put(planId, updatedPlan.toJson());
      await updateWidget();
    } catch (e) {
      debugPrint('Error updating plan item status: $e');
    }
  }

  // Cycle plan status
  Future<void> cyclePlanStatus(String planId) async {
    final planIdx = _plans.indexWhere((p) => p.id == planId);
    if (planIdx == -1) return;

    final current = _plans[planIdx].status;
    String next;
    switch (current) {
      case 'todo':
        next = 'doing';
        break;
      case 'doing':
        next = 'done';
        break;
      default:
        next = 'todo';
    }

    // Set all subitems recursively to match the new status
    final updatedItems = _setAllStatusRecursively(_plans[planIdx].items, next);
    final updatedPlan = _plans[planIdx].copyWith(status: next, items: updatedItems);
    
    _plans[planIdx] = updatedPlan;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      await box.put(planId, updatedPlan.toJson());
      await updateWidget();
    } catch (e) {
      debugPrint('Error cycling plan status: $e');
    }
  }

  List<PlanItem> _cycleStatusRecursively(List<PlanItem> list, String itemId) {
    return list.map((item) {
      if (item.id == itemId) {
        final currentStatus = item.status;
        String nextStatus;
        switch (currentStatus) {
          case 'todo':
            nextStatus = 'doing';
            break;
          case 'doing':
            nextStatus = 'done';
            break;
          case 'done':
          default:
            nextStatus = 'todo';
            break;
        }

        List<PlanItem> updatedSubs = item.subItems;
        if (nextStatus == 'done') {
          updatedSubs = _setAllStatusRecursively(item.subItems, 'done');
        }
        return item.copyWith(status: nextStatus, subItems: updatedSubs);
      } else if (item.subItems.isNotEmpty) {
        return item.copyWith(subItems: _cycleStatusRecursively(item.subItems, itemId));
      }
      return item;
    }).toList();
  }

  List<PlanItem> _setAllStatusRecursively(List<PlanItem> list, String status) {
    return list.map((item) {
      return item.copyWith(
        status: status,
        subItems: _setAllStatusRecursively(item.subItems, status),
      );
    }).toList();
  }

  // Delete item recursively
  Future<void> deleteItem(String planId, String itemId) async {
    final planIdx = _plans.indexWhere((p) => p.id == planId);
    if (planIdx == -1) return;

    var updatedItems = _deleteRecursively(_plans[planIdx].items, itemId);
    updatedItems = _syncParentStatuses(updatedItems);
    final updatedPlan = _syncPlanStatus(_plans[planIdx].copyWith(items: updatedItems));
    _plans[planIdx] = updatedPlan;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      await box.put(planId, updatedPlan.toJson());
      await updateWidget();
    } catch (e) {
      debugPrint('Error deleting plan item: $e');
    }
  }

  List<PlanItem> _deleteRecursively(List<PlanItem> list, String itemId) {
    final filtered = list.where((item) => item.id != itemId).toList();
    return filtered.map((item) {
      if (item.subItems.isNotEmpty) {
        return item.copyWith(subItems: _deleteRecursively(item.subItems, itemId));
      }
      return item;
    }).toList();
  }

  // Reorder plan items recursively
  Future<void> reorderItemsRecursively(String planId, String? parentItemId, int oldIndex, int newIndex) async {
    final idx = _plans.indexWhere((p) => p.id == planId);
    if (idx == -1) return;

    List<PlanItem> updatedItems;
    if (parentItemId == null) {
      final items = List<PlanItem>.from(_plans[idx].items);
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);
      updatedItems = items;
    } else {
      updatedItems = _reorderRecursively(_plans[idx].items, parentItemId, oldIndex, newIndex);
    }

    final updatedPlan = _plans[idx].copyWith(items: updatedItems);
    _plans[idx] = updatedPlan;
    notifyListeners();

    try {
      final box = Hive.box(_boxName);
      await box.put(planId, updatedPlan.toJson());
      await updateWidget();
    } catch (e) {
      debugPrint('Error reordering plan items: $e');
    }
  }

  List<PlanItem> _reorderRecursively(List<PlanItem> list, String parentId, int oldIndex, int newIndex) {
    return list.map((item) {
      if (item.id == parentId) {
        final items = List<PlanItem>.from(item.subItems);
        if (oldIndex < newIndex) {
          newIndex -= 1;
        }
        final removed = items.removeAt(oldIndex);
        items.insert(newIndex, removed);
        return item.copyWith(subItems: items);
      } else if (item.subItems.isNotEmpty) {
        return item.copyWith(subItems: _reorderRecursively(item.subItems, parentId, oldIndex, newIndex));
      }
      return item;
    }).toList();
  }

  List<PlanItem> _syncParentStatuses(List<PlanItem> list) {
    return list.map((item) {
      if (item.subItems.isEmpty) {
        return item;
      }
      final syncedSubItems = _syncParentStatuses(item.subItems);
      
      final allDone = syncedSubItems.every((child) => child.status == 'done');
      final allTodo = syncedSubItems.every((child) => child.status == 'todo');
      
      String nextStatus;
      if (allDone) {
        nextStatus = 'done';
      } else if (allTodo) {
        nextStatus = 'todo';
      } else {
        nextStatus = 'doing';
      }
      
      return item.copyWith(
        status: nextStatus,
        subItems: syncedSubItems,
      );
    }).toList();
  }

  Plan _syncPlanStatus(Plan plan) {
    if (plan.items.isEmpty) return plan;
    final pct = plan.completionPercent;
    String newStatus = 'todo';
    if (pct >= 100) {
      newStatus = 'done';
    } else if (pct > 0) {
      newStatus = 'doing';
    }
    return plan.copyWith(status: newStatus);
  }

  // Sync plans data to SharedPreferences and trigger Android HomeWidget update
  Future<void> updateWidget() async {
    try {
      String serialized = '';
      if (_plans.isNotEmpty) {
        // Format: PlanTitle1||%completion1::PlanTitle2||%completion2::...
        serialized = _plans.map((p) => '${p.title}||%${p.completionPercent}').join('::');
      }

      await HomeWidget.saveWidgetData<String>('plans_widget_data', serialized);

      // Serialize entire plans tree to plans_json
      final jsonStr = jsonEncode(_plans.map((p) => p.toJson()).toList());
      await HomeWidget.saveWidgetData<String>('plans_json', jsonStr);

      // Save expanded IDs to expanded_ids
      final expandedStr = _expandedIds.join(',');
      await HomeWidget.saveWidgetData<String>('expanded_ids', expandedStr);

      const channel = MethodChannel('com.example.smart_notebook/launch');
      await channel.invokeMethod('updatePlansWidget');
      debugPrint('[PlansWidget] Updated JSON & Expanded: $jsonStr, $expandedStr');
    } catch (e) {
      debugPrint('[PlansWidget] Error: $e');
    }
  }
}
