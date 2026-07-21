class PlanItem {
  final String id;
  final String text;
  final String status; // 'todo', 'doing', 'done'
  final List<PlanItem> subItems;

  PlanItem({
    required this.id,
    required this.text,
    this.status = 'todo',
    this.subItems = const [],
  });

  bool get isDone => status == 'done';
  bool get isDoing => status == 'doing';

  /// Completion percentage based recursively on all leaf items under this item
  int get completionPercent {
    final allLeafs = _getLeafItems(subItems);
    if (allLeafs.isEmpty) {
      return isDone ? 100 : 0;
    }
    final done = allLeafs.where((i) => i.status == 'done').length;
    return ((done / allLeafs.length) * 100).round();
  }

  List<PlanItem> _getLeafItems(List<PlanItem> list) {
    final List<PlanItem> leafs = [];
    for (final item in list) {
      if (item.subItems.isEmpty) {
        leafs.add(item);
      } else {
        leafs.addAll(_getLeafItems(item.subItems));
      }
    }
    return leafs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'status': status,
        'subItems': subItems.map((i) => i.toJson()).toList(),
        'completionPercent': completionPercent,
      };

  factory PlanItem.fromJson(Map<dynamic, dynamic> json) {
    final rawSub = json['subItems'] as List<dynamic>? ?? [];
    final subItems = rawSub
        .whereType<Map>()
        .map((e) => PlanItem.fromJson(e))
        .toList();
    return PlanItem(
      id: json['id'] as String,
      text: json['text'] as String,
      status: json['status'] as String? ?? 'todo',
      subItems: subItems,
    );
  }

  PlanItem copyWith({
    String? id,
    String? text,
    String? status,
    List<PlanItem>? subItems,
  }) =>
      PlanItem(
        id: id ?? this.id,
        text: text ?? this.text,
        status: status ?? this.status,
        subItems: subItems ?? this.subItems,
      );
}

class Plan {
  final String id;
  final String title;
  final List<PlanItem> items;
  final DateTime createdAt;
  final String status; // 'todo', 'doing', 'done'

  Plan({
    required this.id,
    required this.title,
    required this.items,
    required this.createdAt,
    this.status = 'todo',
  });

  /// Completion percentage based recursively on all leaf items
  int get completionPercent {
    final allLeafs = _getLeafItems(items);
    if (allLeafs.isEmpty) {
      return status == 'done' ? 100 : (status == 'doing' ? 50 : 0);
    }
    final done = allLeafs.where((i) => i.status == 'done').length;
    return ((done / allLeafs.length) * 100).round();
  }

  List<PlanItem> _getLeafItems(List<PlanItem> list) {
    final List<PlanItem> leafs = [];
    for (final item in list) {
      if (item.subItems.isEmpty) {
        leafs.add(item);
      } else {
        leafs.addAll(_getLeafItems(item.subItems));
      }
    }
    return leafs;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'completionPercent': completionPercent,
        'status': status,
      };

  factory Plan.fromJson(Map<dynamic, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .whereType<Map>()
        .map((e) => PlanItem.fromJson(e))
        .toList();
    return Plan(
      id: json['id'] as String,
      title: json['title'] as String,
      items: items,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'todo',
    );
  }

  Plan copyWith({
    String? id,
    String? title,
    List<PlanItem>? items,
    DateTime? createdAt,
    String? status,
  }) =>
      Plan(
        id: id ?? this.id,
        title: title ?? this.title,
        items: items ?? this.items,
        createdAt: createdAt ?? this.createdAt,
        status: status ?? this.status,
      );
}
