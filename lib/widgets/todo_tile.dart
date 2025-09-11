import 'package:flutter/material.dart';
import '../models/todo_model.dart';
import '../managers/category_manager.dart';

class TodoTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const TodoTile({
    super.key,
    required this.todo,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 16,
      fontWeight: todo.priority == Priority.urgent ? FontWeight.bold : FontWeight.normal,
      decoration: todo.done ? TextDecoration.lineThrough : null,
      color: todo.done ? Colors.grey : (todo.isOverdue ? Colors.red : null),
    );

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: todo.isSubtask ? 24.0 : 8.0,
        vertical: 4.0,
      ),
      elevation: todo.isSubtask ? 1.0 : 2.0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // 우선순위 표시
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: todo.priority.color,
                    shape: BoxShape.circle,
                  ),
                ),
                
                // 카테고리 아이콘
                Icon(
                  CategoryManager.categoryIcons[todo.category] ?? Icons.help,
                  size: 16,
                  color: CategoryManager.categoryColors[todo.category] ?? Colors.grey,
                ),
                const SizedBox(width: 4),
                
                // 제목
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(todo.title, style: titleStyle),
                      if (todo.dueDateType != DueDateType.none)
                        Text(
                          todo.dueDateDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            color: todo.isOverdue 
                              ? Colors.red 
                              : todo.isDueSoon 
                                ? Colors.orange 
                                : Colors.grey,
                          ),
                        ),
                    ],
                  ),
                ),
                
                // 완료/미완료 버튼
                IconButton(
                  tooltip: todo.done ? '미완료로 표시' : '완료로 표시',
                  onPressed: onToggle,
                  icon: Icon(
                    todo.done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: todo.done ? Colors.green : Colors.grey,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                // 카테고리 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: (CategoryManager.categoryColors[todo.category] ?? Colors.grey).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    todo.displayCategory,
                    style: const TextStyle(fontSize: 10),
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // 우선순위 표시
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: todo.priority.color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    todo.priority.displayName,
                    style: TextStyle(
                      fontSize: 10,
                      color: todo.priority.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // 진행률 표시
                if (todo.hasSubtasks || todo.progressPercentage > 0)
                  SizedBox(
                    width: 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${todo.progressPercentage}%',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        LinearProgressIndicator(
                          value: todo.progressPercentage / 100,
                          backgroundColor: Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation(todo.priority.color),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(width: 8),
                
                // 알림 아이콘
                if (todo.notificationInterval != NotificationInterval.none)
                  Icon(
                    Icons.notifications,
                    size: 14,
                    color: Colors.blue.withValues(alpha: 0.7),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}