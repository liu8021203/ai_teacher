import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/pages/dialog/activity_selector_dialog.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';

class EditStudentDataDialog extends StatefulWidget {
  final StudentDataConfirmListEntity data;
  final int? parentId;
  final VoidCallback? onSaveSuccess;

  const EditStudentDataDialog({
    super.key,
    required this.data,
    this.parentId,
    this.onSaveSuccess,
  });

  @override
  State<EditStudentDataDialog> createState() => _EditStudentDataDialogState();
}

class _EditStudentDataDialogState extends State<EditStudentDataDialog> {
  late TextEditingController _descriptionController;
  String? _selectedActivityTitle;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.data.description,
    );
    _selectedActivityTitle = widget.data.activity;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (widget.parentId == null) {
      return const Color(0xFFFFC88D);
    }

    switch (widget.parentId) {
      case 1:
        return const Color(0xFFBED0FF);
      case 2:
        return const Color(0xFFE5FDFF);
      case 3:
        return const Color(0xFFFFFDCE);
      case 4:
        return const Color(0xFFFFE5F3);
      case 5:
        return const Color(0xFFEFFFE5);
      default:
        return const Color(0xFFFFC88D);
    }
  }

  Color _getActivityTitleColor() {
    if (widget.parentId == null) {
      return const Color(0xFFB1600A);
    }

    switch (widget.parentId) {
      case 1:
        return const Color(0xFF44588D);
      case 2:
        return const Color(0xFF549CA2);
      case 3:
        return const Color(0xFF817901);
      case 4:
        return const Color(0xFF6F004F);
      case 5:
        return const Color(0xFF407939);
      default:
        return const Color(0xFFB1600A);
    }
  }

  Color _getButtonColor() {
    if (widget.parentId == null) {
      return const Color(0xFFB1600A);
    }

    switch (widget.parentId) {
      case 1:
        return const Color(0xFF44588D);
      case 2:
        return const Color(0xFF549CA2);
      case 3:
        return const Color(0xFF817901);
      case 4:
        return const Color(0xFF6F004F);
      case 5:
        return const Color(0xFF407939);
      default:
        return const Color(0xFFB1600A);
    }
  }

  Future<void> _saveData() async {
    // 验证所有参数不能为空
    if (_selectedActivityTitle == null || _selectedActivityTitle!.isEmpty) {
      Fluttertoast.showToast(msg: '请选择活动类型');
      return;
    }

    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      Fluttertoast.showToast(msg: '请输入描述内容');
      return;
    }

    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/editStudentData',
        data: {
          'id': widget.data.id,
          'activity': _selectedActivityTitle!,
          'description': description,
        },
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '保存成功');
        Navigator.of(context).pop();
        widget.onSaveSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '保存失败') : '保存失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = _getBackgroundColor();
    final titleColor = _getActivityTitleColor();

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF424242), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 顶部活动选择区域
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showActivitySelector(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFFD7D6E8),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedActivityTitle ?? '选择活动',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: titleColor,
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_drop_down, color: titleColor),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _saveData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getButtonColor(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '保存',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 描述输入区域
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFD7D6E8),
                    width: 1,
                    style: BorderStyle.solid,
                  ),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2E2E2E),
                    height: 1.5,
                  ),
                  decoration: const InputDecoration(
                    hintText: '请输入描述内容...',
                    hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showActivitySelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ActivitySelectorDialog(
          selectedActivityTitle: _selectedActivityTitle,
          onActivitySelected: (activityTitle) {
            setState(() {
              _selectedActivityTitle = activityTitle;
            });
          },
        );
      },
    );
  }
}
