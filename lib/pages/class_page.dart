import 'package:ai_teacher/base/base_stateful_widget.dart';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/dialog/class_selection_dialog.dart';
import 'package:ai_teacher/pages/login_page.dart';
import 'package:ai_teacher/pages/student_detail_page.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_popup/flutter_popup.dart';
import 'dialog/add_student_dialog.dart';

class ClassPage extends StatefulWidget {
  const ClassPage({super.key});

  @override
  State<ClassPage> createState() => _ClassPageState();
}

class _ClassPageState extends State<ClassPage> {
  ShowState _showState = ShowLoading();
  List<StudentListEntity>? _studentList;

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
  }

  Future<void> _fetchStudentList() async {
    debugPrint("user : ${UserManager().user}");
    setState(() {
      _showState = ShowLoading();
    });

    try {
      final String? classId = SPUtil.getString('classId', defaultValue: null);
      if (classId == null) {
        setState(() {
          _showState = ShowEmptyView();
        });
        return;
      }

      List<StudentListEntity>? list = await DioClient()
          .post<List<StudentListEntity>>(
            '/studentList',
            data: {
              'token': UserManager().getUserInfo()?.token,
              'schoolId': UserManager().getUserInfo()?.schoolId,
              'classId': classId,
            },
            fromJson: (json) {
              if (json is List) {
                return json.map((e) => StudentListEntity.fromJson(e)).toList();
              }
              return [];
            },
          );

      if (mounted) {
        setState(() {
          _studentList = list;
          _showState = (list == null || list.isEmpty)
              ? ShowEmptyView()
              : ShowSuccess();
        });
      }
    } catch (e) {
      if (mounted) {
        if (e is HttpException) {
          setState(() {
            _showState = ShowNetworkErrorView(e.code, e.message ?? '网络异常');
          });
        } else {
          setState(() {
            _showState = ShowNetworkErrorView(-1, '未知错误');
          });
        }
      }
    }
  }

  void _showAddStudentDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AddStudentDialog(
          onSaveSuccess: () {
            // 添加成功后刷新列表
            _fetchStudentList();
          },
        );
      },
    );
  }

  void _showClassSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const ClassSelectionDialog();
      },
    ).then((_) {
      // 弹窗关闭后（可能是选了班级），刷新数据
      _fetchStudentList();
    });
  }

  void _logout() {
    // 1. 清除用户信息
    UserManager().logout();
    // 2. 清除班级信息等（可选）
    SPUtil.remove('classId');
    // 3. 跳转回登录页，清空路由栈
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseStatefulWidget(
      showState: _showState,
      reloadDataCallBack: _fetchStudentList,
      appBar: AppBar(
        title: const Text(
          '班级管理',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        leading: IconButton(
          icon: const Icon(Icons.add, color: Colors.white),
          onPressed: _showAddStudentDialog,
        ),
        actions: [
          CustomPopup(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPopupItem(Icons.swap_horiz, '切换班级', () {
                  Navigator.of(context).pop(); // 关闭 Popup
                  _showClassSelectionDialog();
                }),
                // const Divider(height: 1, color: Color(0xFFEEEEEE)),
                _buildPopupItem(Icons.exit_to_app, '退出登录', () {
                  Navigator.of(context).pop(); // 关闭 Popup
                  _logout();
                }),
              ],
            ),
            backgroundColor: Colors.white,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Icon(Icons.more_horiz, color: Colors.white),
            ),
          ),
        ],
      ),
      child: ListView.separated(
        itemCount: _studentList?.length ?? 0,
        separatorBuilder: (context, index) => const Divider(
          height: 0.1,
          color: Color(0xFFE5E5E5),
          indent: 86,
          endIndent: 16,
        ),
        itemBuilder: (context, index) {
          final item = _studentList![index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StudentDetailPage(student: item),
                ),
              );
            },
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // 头像
                  ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: CachedNetworkImage(
                      imageUrl: item.studentAvatar ?? "",
                      width: 56,
                      height: 56,
                      maxHeightDiskCache: 300,
                      maxWidthDiskCache: 300,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Image.asset(
                        'assets/images/avatar.png',
                        width: 56,
                        height: 56,
                      ),
                      errorWidget: (context, url, error) => Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF7EA1FF),
                        ),
                        child: Image.asset(
                          'assets/images/avatar.png',
                          width: 56,
                          height: 56,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 姓名
                  Text(
                    item.studentName,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF333333),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPopupItem(IconData icon, String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: const Color(0xFF333333)),
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(fontSize: 14, color: Color(0xFF333333)),
            ),
          ],
        ),
      ),
    );
  }
}
