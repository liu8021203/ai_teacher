import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/dialog/edit_student_info_dialog.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';

class StudentInfoDialog extends StatefulWidget {
  final StudentListEntity student;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const StudentInfoDialog({
    super.key,
    required this.student,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<StudentInfoDialog> createState() => _StudentInfoDialogState();
}

class _StudentInfoDialogState extends State<StudentInfoDialog> {
  String _formatBirthday(String birthday) {
    try {
      final date = DateTime.parse(birthday);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (e) {
      return birthday;
    }
  }

  Future<void> _deleteStudent() async {
    // 显示确认对话框（不关闭学生信息对话框）
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('确定要删除这个学生吗？删除后无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消', style: TextStyle(color: Color(0xFF999999))),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定', style: TextStyle(color: Color(0xFF8D0D0D))),
          ),
        ],
      ),
    );

    // 用户取消删除，直接返回
    if (confirmed != true) return;

    // 用户确认删除，调用删除接口
    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/deleteStudent',
        data: {
          'token': UserManager().getUserInfo()?.token,
          'id': widget.student.id,
        },
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '删除成功');

        // 发送学生数据变更事件，通知其他页面刷新
        eventBus.fire(StudentDataChangedEvent());

        // 关闭学生信息对话框
        Navigator.of(context).pop();

        // 调用删除回调
        widget.onDelete?.call();
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '删除失败') : '删除失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  void _showEditDialog() {
    // 关闭当前对话框
    Navigator.of(context).pop();

    // 延迟显示编辑对话框，确保当前对话框完全关闭
    Future.delayed(const Duration(milliseconds: 100), () {
      showDialog(
        context: context,
        builder: (context) => EditStudentInfoDialog(
          student: widget.student,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Color(0xFF7EA1FF),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题
            const Text(
              '学生信息',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textScaler: TextScaler.noScaling,
            ),
            const SizedBox(height: 6),

            // 学生信息卡片
            Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  // padding: const EdgeInsets.symmetric(
                  //   horizontal: 16,
                  //   vertical: 8,
                  // ),
                  child: Stack(
                    children: [
                      Positioned(
                        right: 0,
                        child: Image.asset(
                          'assets/images/student_info_mark.png',
                          height: 65,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 24,
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                // 左侧头像区域
                                Container(
                                  width: 62,
                                  height: 62,
                                  clipBehavior: Clip.hardEdge,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF7EA1FF),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black,
                                      width: 1,
                                    ),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl:
                                        widget.student.studentAvatar ?? '',
                                    width: 62,
                                    height: 62,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Image.asset(
                                      'assets/images/student_info_avatar.png',
                                      // 默认头像
                                      width: 62,
                                      height: 62,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        Image.asset(
                                          'assets/images/student_info_avatar.png',
                                          // 默认头像
                                          width: 62,
                                          height: 62,
                                        ),
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  widget.student.studentName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // 性别
                            _buildInfoRow(
                              '性别',
                              widget.student.studentSex == 1 ? '男' : '女',
                            ),
                            const SizedBox(height: 2),
                            Divider(color: Colors.black, height: 1),
                            const SizedBox(height: 12),

                            // 乳称
                            _buildInfoRow(
                              '昵称',
                              widget.student.studentNickName ?? '未设置',
                            ),
                            const SizedBox(height: 2),
                            Divider(color: Colors.black, height: 1),
                            const SizedBox(height: 12),

                            // 生日
                            _buildInfoRow(
                              '生日',
                              _formatBirthday(widget.student.studentBirthday),
                            ),
                            const SizedBox(height: 2),
                            Divider(color: Colors.black, height: 1),
                            const SizedBox(height: 12),
                            // 生日
                            _buildInfoRow('电话', widget.student.phone ?? "暂无"),
                            const SizedBox(height: 2),
                            Divider(color: Colors.black, height: 1),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 7),

            // 底部按钮
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: _showEditDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    maximumSize: Size(58, 38),
                    minimumSize: Size(58, 38),
                  ),
                  child: const Text(
                    '编辑',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      fontWeight: FontWeight.w400,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
                const SizedBox(width: 85),
                ElevatedButton(
                  onPressed: _deleteStudent,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFD4D4),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    maximumSize: Size(58, 38),
                    minimumSize: Size(58, 38),
                  ),
                  child: const Text(
                    '删除',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      fontWeight: FontWeight.w400,
                    ),
                    textScaler: TextScaler.noScaling,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, color: Color(0xFF1B0E6E)),
        ),
        Spacer(),
        Text(
          value,
          style: const TextStyle(fontSize: 16, color: Color(0xFF2E2E2E)),
        ),
      ],
    );
  }
}
