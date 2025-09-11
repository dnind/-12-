import '../models/todo_model.dart';

class ProgressManager {
  static int calculateProgressPercentage(Todo todo, List<Todo> allTodos) {
    if (todo.done) return 100;
    
    if (!todo.hasSubtasks) {
      // 서브태스크가 없는 경우 수동으로 설정된 진행률 반환
      return todo.progressPercentage;
    }
    
    // 서브태스크가 있는 경우 서브태스크들의 평균 진행률 계산
    final subtasks = allTodos.where((t) => todo.subtaskIds.contains(t.id)).toList();
    if (subtasks.isEmpty) return todo.progressPercentage;
    
    int totalProgress = 0;
    for (final subtask in subtasks) {
      totalProgress += calculateProgressPercentage(subtask, allTodos);
    }
    
    return (totalProgress / subtasks.length).round();
  }
  
  static void updateParentProgress(String parentId, List<Todo> allTodos) {
    final parent = allTodos.firstWhere((t) => t.id == parentId);
    final calculatedProgress = calculateProgressPercentage(parent, allTodos);
    parent.progressPercentage = calculatedProgress;
    
    // 진행률이 100%이면 자동으로 완료 처리
    if (calculatedProgress == 100 && !parent.done) {
      parent.done = true;
    } else if (calculatedProgress < 100 && parent.done) {
      parent.done = false;
    }
    
    // 부모의 부모도 업데이트 (재귀적)
    if (parent.parentId != null) {
      updateParentProgress(parent.parentId!, allTodos);
    }
  }
  
  static List<Todo> sortByPriority(List<Todo> todos) {
    final sorted = List<Todo>.from(todos);
    sorted.sort((a, b) {
      // 우선순위로 먼저 정렬
      final priorityCompare = b.priority.sortOrder.compareTo(a.priority.sortOrder);
      if (priorityCompare != 0) return priorityCompare;
      
      // 우선순위가 같으면 마감일로 정렬
      if (a.dueDate != null && b.dueDate != null) {
        return a.dueDate!.compareTo(b.dueDate!);
      } else if (a.dueDate != null) {
        return -1;
      } else if (b.dueDate != null) {
        return 1;
      }
      
      return 0;
    });
    return sorted;
  }
}