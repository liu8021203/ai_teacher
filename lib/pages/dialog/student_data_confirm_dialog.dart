import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:loader_overlay/loader_overlay.dart';

class StudentDataConfirmDialog extends StatefulWidget {
  final StudentListEntity? student;
  final List<StudentDataConfirmListEntity> dataList;

  const StudentDataConfirmDialog({
    super.key,
    this.student,
    required this.dataList,
  });

  @override
  State<StudentDataConfirmDialog> createState() =>
      _StudentDataConfirmDialogState();
}

class _StudentDataConfirmDialogState extends State<StudentDataConfirmDialog>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late PageController _pageController;
  late AnimationController _animationController;

  // 存储每个数据项选中的学生
  Map<int, StudentListEntity?> _selectedStudents = {};

  // 本地数据列表副本，用于动态删除
  late List<StudentDataConfirmListEntity> _localDataList;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.85);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 复制数据列表
    _localDataList = List.from(widget.dataList);

    // 初始化选中的学生
    if (widget.student != null) {
      for (int i = 0; i < _localDataList.length; i++) {
        _selectedStudents[i] = widget.student;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendData() async {
    if (_currentIndex >= _localDataList.length) return;

    final currentData = _localDataList[_currentIndex];

    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/confirmStudentData',
        data: {'id': currentData.id},
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '确认成功');

        // 从列表中移除已确认的数据
        setState(() {
          _localDataList.removeAt(_currentIndex);
          _selectedStudents.remove(_currentIndex);
        });

        // 检查是否还有数据
        if (_localDataList.isEmpty) {
          // 全部处理完
          Navigator.of(context).pop(true);
        } else {
          // 如果当前索引超出范围，调整到最后一个
          if (_currentIndex >= _localDataList.length) {
            setState(() {
              _currentIndex = _localDataList.length - 1;
            });
          }
          // 刷新页面
          _pageController.jumpToPage(_currentIndex);
        }
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '确认失败') : '确认失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  Future<void> _discard() async {
    debugPrint("_discard");
    if (_currentIndex >= _localDataList.length) return;

    final currentData = _localDataList[_currentIndex];

    try {
      context.loaderOverlay.show();

      await DioClient().post(
        '/deleteStudentData',
        data: {'id': currentData.id},
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '已删除');

        // 从列表中移除已删除的数据
        setState(() {
          _localDataList.removeAt(_currentIndex);
          _selectedStudents.remove(_currentIndex);
        });

        // 检查是否还有数据
        if (_localDataList.isEmpty) {
          // 全部处理完
          Navigator.of(context).pop(true);
        } else {
          // 如果当前索引超出范围，调整到最后一个
          if (_currentIndex >= _localDataList.length) {
            setState(() {
              _currentIndex = _localDataList.length - 1;
            });
          }
          // 刷新页面
          _pageController.jumpToPage(_currentIndex);
        }
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '删除失败') : '删除失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future<void> _showStudentSelector() async {
    // 获取学生列表
    final String? classId = SPUtil.getString('classId', defaultValue: null);
    if (classId == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _StudentSelectorSheet(
        classId: classId,
        onStudentSelected: (student) {
          setState(() {
            _selectedStudents[_currentIndex] = student;
          });
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 0),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: _localDataList.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _buildCard(_localDataList[index], index),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(StudentDataConfirmListEntity currentData, int index) {
    final selectedStudent = _selectedStudents[index];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2F9),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 学生信息
          GestureDetector(
            onTap: _showStudentSelector,
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: selectedStudent != null
                      ? CachedNetworkImage(
                          imageUrl: selectedStudent.studentAvatar ?? "",
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey,
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(
                              Icons.person,
                              size: 30,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade300,
                          child: const Icon(
                            Icons.help_outline,
                            size: 30,
                            color: Colors.grey,
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    selectedStudent?.studentName ??
                        currentData.studentName ??
                        '未知',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF2E2E2E),
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFF666666)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 活动选择
          GestureDetector(
            onTap: () {
              // TODO: 选择活动
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
              ),
              child: Row(
                children: [
                  const Text(
                    '活动：',
                    style: TextStyle(fontSize: 16, color: Color(0xFF2E2E2E)),
                  ),
                  Expanded(
                    child: Text(
                      currentData.activity ?? '未选择',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Color(0xFF666666)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 观察内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '观察内容',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    // constraints: const BoxConstraints(
                    //   minHeight: 150,
                    //   maxHeight: 400,
                    // ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        currentData.description ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2E2E2E),
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 底部按钮
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _discard,
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '放弃',
                    style: TextStyle(fontSize: 16, color: Color(0xFF666666)),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _sendData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF82A6F5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    '确认',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// 学生选择底部面板
class _StudentSelectorSheet extends StatefulWidget {
  final String classId;
  final Function(StudentListEntity) onStudentSelected;

  const _StudentSelectorSheet({
    required this.classId,
    required this.onStudentSelected,
  });

  @override
  State<_StudentSelectorSheet> createState() => _StudentSelectorSheetState();
}

class _StudentSelectorSheetState extends State<_StudentSelectorSheet> {
  List<StudentListEntity>? _studentList;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
  }

  Future<void> _fetchStudentList() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      List<StudentListEntity>? list = await DioClient()
          .post<List<StudentListEntity>>(
            '/studentList',
            data: {
              'token': UserManager().getUserInfo()?.token,
              'schoolId': UserManager().getUserInfo()?.schoolId,
              'classId': widget.classId,
            },
            fromJson: (json) {
              if (json is List) {
                return json.map((e) => StudentListEntity.fromJson(e)).toList();
              }
              return null;
            },
          );

      if (mounted) {
        setState(() {
          _studentList = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '获取学生列表失败';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5E5), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    '选择学生',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E2E2E),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Color(0xFF666666)),
                ),
              ],
            ),
          ),

          // 学生列表
          Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _errorMessage!,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Color(0xFF999999),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _fetchStudentList,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: _studentList?.length ?? 0,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFE5E5E5)),
                    itemBuilder: (context, index) {
                      final student = _studentList![index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(25),
                          child: CachedNetworkImage(
                            imageUrl: student.studentAvatar ?? "",
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.person,
                                size: 25,
                                color: Colors.grey,
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: Colors.grey.shade300,
                              child: const Icon(
                                Icons.person,
                                size: 25,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        title: Text(
                          student.studentName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF2E2E2E),
                          ),
                        ),
                        subtitle:
                            student.studentNickName != null &&
                                student.studentNickName!.isNotEmpty
                            ? Text(
                                student.studentNickName!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF999999),
                                ),
                              )
                            : null,
                        onTap: () {
                          widget.onStudentSelected(student);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
