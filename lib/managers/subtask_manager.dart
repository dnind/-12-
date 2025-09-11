import '../models/todo_model.dart';
import '../utils/timezone_utils.dart';
import 'progress_manager.dart';

class SubtaskManager {
  static String createSubtask(String parentId, String title, String part, List<Todo> allTodos) {
    final subtaskId = TimeZoneUtils.kstNow.millisecondsSinceEpoch.toString();
    final subtask = Todo(
      id: subtaskId,
      title: title,
      part: part,
      parentId: parentId,
      priority: Priority.medium,
    );
    
    // 부모 태스크에 서브태스크 ID 추가
    final parent = allTodos.firstWhere((t) => t.id == parentId);
    parent.subtaskIds.add(subtaskId);
    
    allTodos.add(subtask);
    return subtaskId;
  }
  
  static void deleteSubtask(String subtaskId, List<Todo> allTodos) {
    final subtask = allTodos.firstWhere((t) => t.id == subtaskId);
    if (subtask.parentId != null) {
      // 부모 태스크에서 서브태스크 ID 제거
      final parent = allTodos.firstWhere((t) => t.id == subtask.parentId);
      parent.subtaskIds.remove(subtaskId);
      
      // 부모 진행률 업데이트
      ProgressManager.updateParentProgress(subtask.parentId!, allTodos);
    }
    
    allTodos.removeWhere((t) => t.id == subtaskId);
  }
  
  static List<Todo> getMainTasks(List<Todo> allTodos) {
    return allTodos.where((t) => !t.isSubtask).toList();
  }
  
  static List<Todo> getSubtasks(String parentId, List<Todo> allTodos) {
    return allTodos.where((t) => t.parentId == parentId).toList();
  }
  
  static List<Todo> getHierarchicalTodos(List<Todo> allTodos) {
    final result = <Todo>[];
    final mainTasks = getMainTasks(allTodos);
    
    for (final mainTask in mainTasks) {
      result.add(mainTask);
      final subtasks = getSubtasks(mainTask.id, allTodos);
      result.addAll(subtasks);
    }
    
    return result;
  }
}