import 'package:flutter/material.dart';
import '../models/todo_model.dart';
import '../managers/category_manager.dart';
import '../utils/timezone_utils.dart';

class AddTodoDialog extends StatefulWidget {
  final Future<void> Function(String title, String category, String? customCategory, DateTime? dueDate, TimeOfDay? dueTime, DueDateType dueDateType, Priority priority, NotificationInterval notificationInterval)
  onSubmit;

  const AddTodoDialog({super.key, required this.onSubmit});

  @override
  State<AddTodoDialog> createState() => _AddTodoDialogState();
}

class _AddTodoDialogState extends State<AddTodoDialog> {
  final _controller = TextEditingController();
  final _customCategoryController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedCategory = '개인';
  Priority _selectedPriority = Priority.medium;
  DueDateType _dueDateType = DueDateType.none;
  NotificationInterval _notificationInterval = NotificationInterval.none;
  DateTime? _dueDate;
  TimeOfDay? _dueTime;

  @override
  void dispose() {
    _controller.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = TimeZoneUtils.kstNow;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        if (_dueDateType == DueDateType.none) {
          _dueDateType = DueDateType.date;
        }
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _dueTime = picked;
        if (_dueDate != null) {
          _dueDateType = DueDateType.dateTime;
        }
      });
    }
  }

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      String? customCategory;
      if (_selectedCategory == '기타' && _customCategoryController.text.isNotEmpty) {
        customCategory = _customCategoryController.text;
      }
      
      await widget.onSubmit(
        _controller.text, 
        _selectedCategory, 
        customCategory, 
        _dueDate, 
        _dueTime,
        _dueDateType,
        _selectedPriority,
        _notificationInterval
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.pets, size: 48, color: Colors.pinkAccent),
              const SizedBox(height: 20),
              const Text('할 일 추가', style: TextStyle(fontSize: 22)),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _controller,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '예) 프레젠테이션 자료 만들기',
                        border: OutlineInputBorder(),
                        labelText: '제목',
                      ),
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return '내용을 입력해주세요';
                        if (v.trim().length > 100) return '100자 이내로 입력해주세요';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    
                    // 카테고리 선택
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '카테고리',
                      ),
                      items: CategoryManager.predefinedCategories
                          .map((category) => DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(
                                  CategoryManager.categoryIcons[category],
                                  size: 16,
                                  color: CategoryManager.categoryColors[category],
                                ),
                                const SizedBox(width: 8),
                                Text(category),
                              ],
                            ),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                    ),
                    
                    // 사용자 정의 카테고리 입력 (기타 선택 시)
                    if (_selectedCategory == '기타') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customCategoryController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: '사용자 정의 카테고리',
                          hintText: '예) 프로젝트명, 특별한 작업 등',
                        ),
                        validator: (v) {
                          if (_selectedCategory == '기타' && (v == null || v.trim().isEmpty)) {
                            return '기타 카테고리 내용을 입력해주세요';
                          }
                          return null;
                        },
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // 우선순위 선택
                    DropdownButtonFormField<Priority>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '우선순위',
                      ),
                      items: Priority.values
                          .map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: priority.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Text(priority.displayName),
                              ],
                            ),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedPriority = v!),
                    ),
                    const SizedBox(height: 12),
                    
                    // 마감일 타입 선택
                    DropdownButtonFormField<DueDateType>(
                      value: _dueDateType,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '마감일 설정',
                      ),
                      items: DueDateType.values
                          .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type.displayName),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _dueDateType = v!),
                    ),
                    
                    // 마감일/시간 선택 버튼들
                    if (_dueDateType != DueDateType.none) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(Icons.calendar_today),
                              label: Text(_dueDate != null 
                                ? '${_dueDate!.month}/${_dueDate!.day}'
                                : '날짜 선택'),
                            ),
                          ),
                          if (_dueDateType == DueDateType.dateTime) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _pickTime,
                                icon: const Icon(Icons.schedule),
                                label: Text(_dueTime != null 
                                  ? '${_dueTime!.hour.toString().padLeft(2, '0')}:${_dueTime!.minute.toString().padLeft(2, '0')}'
                                  : '시간 선택'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                    
                    const SizedBox(height: 12),
                    
                    // 알림 간격 선택
                    DropdownButtonFormField<NotificationInterval>(
                      value: _notificationInterval,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '알림 주기',
                      ),
                      items: NotificationInterval.values
                          .map((interval) => DropdownMenuItem(
                            value: interval,
                            child: Text(interval.displayName),
                          ))
                          .toList(),
                      onChanged: (v) => setState(() => _notificationInterval = v!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('취소'),
                  ),
                  ElevatedButton(
                    onPressed: _submit,
                    child: const Text('추가'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}