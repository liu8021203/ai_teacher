import 'dart:io';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/util/event_bus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class EditStudentInfoDialog extends StatefulWidget {
  final StudentListEntity student;

  const EditStudentInfoDialog({
    super.key,
    required this.student,
  });

  @override
  State<EditStudentInfoDialog> createState() => _EditStudentInfoDialogState();
}

class _EditStudentInfoDialogState extends State<EditStudentInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _nicknameController;
  late TextEditingController _phoneController;

  // 1: 男, 2: 女
  late int _gender;
  DateTime? _selectedDate;
  XFile? _avatarImage;
  String? _compressImagePath;
  String? _currentAvatarUrl; // 当前头像 URL

  @override
  void initState() {
    super.initState();
    // 初始化表单数据
    _nameController = TextEditingController(text: widget.student.studentName);
    _nicknameController = TextEditingController(
      text: widget.student.studentNickName ?? '',
    );
    _phoneController = TextEditingController(text: widget.student.phone ?? '');
    _gender = widget.student.studentSex;
    _currentAvatarUrl = widget.student.studentAvatar;

    // 解析生日
    try {
      _selectedDate = DateTime.parse(widget.student.studentBirthday);
    } catch (e) {
      debugPrint('解析生日失败: $e');
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nicknameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _avatarImage = image;
      });
    }
  }

  void _onDateSelect() {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        return Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    child: const Text('取消'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  CupertinoButton(
                    child: const Text('确定'),
                    onPressed: () {
                      if (_selectedDate == null) {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                      }
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.date,
                  initialDateTime: _selectedDate ?? DateTime.now(),
                  maximumDate: DateTime.now(),
                  onDateTimeChanged: (val) {
                    setState(() {
                      _selectedDate = val;
                    });
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _onSave() async {
    final String name = _nameController.text.trim();
    final String nickname = _nicknameController.text.trim();
    final String phone = _phoneController.text.trim();

    if (name.isEmpty) {
      Fluttertoast.showToast(msg: '请输入学生姓名');
      return;
    }

    if (nickname.isEmpty) {
      Fluttertoast.showToast(msg: '请输入学生昵称');
      return;
    }

    if (_selectedDate == null) {
      Fluttertoast.showToast(msg: '请选择出生年月');
      return;
    }

    context.loaderOverlay.show();

    try {
      Map<String, dynamic> params = {
        "token": UserManager().getUserInfo()?.token,
        "studentId": widget.student.id,
        "studentName": name,
        "studentNickName": nickname,
        "studentBirthday": DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(_selectedDate!),
        "studentSex": _gender,
      };

      if (phone.isNotEmpty) {
        params["studentPhone"] = phone;
      }

      // 处理头像上传
      String? filePath;
      if (_avatarImage != null) {
        filePath = _avatarImage!.path;

        final extension = path.extension(_avatarImage!.name).toLowerCase();
        final fileLength = await _avatarImage!.length();
        final fileSizeMB = fileLength / (1024 * 1024);
        debugPrint("fileSizeMB : $fileSizeMB");

        // 如果文件大于 2MB，进行压缩
        if (fileSizeMB > 2) {
          final directory = await getTemporaryDirectory();
          final compressDir = Directory("${directory.path}/Compress");
          if (!compressDir.existsSync()) {
            compressDir.createSync(recursive: true);
          }

          _compressImagePath =
              "${compressDir.path}/${DateTime.now().millisecondsSinceEpoch}$extension";
          debugPrint("_compressImagePath : $_compressImagePath");

          var result = await FlutterImageCompress.compressAndGetFile(
            _avatarImage!.path,
            _compressImagePath!,
            quality: (150 / fileSizeMB).toInt(),
          );

          if (result != null) {
            filePath = result.path;
          }
        }

        MultipartFile file = await MultipartFile.fromFile(
          filePath,
          filename: "avatar$extension",
        );
        params["studentAvatar"] = file;
      }

      await DioClient().post(
        '/editStudent',
        data: FormData.fromMap(params),
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();

        // 1. 先关闭自己的对话框（在 context 失效前）
        Navigator.of(context).pop();

        // 2. 然后再通知其他人（此时即使触发父 widget 重建也不会影响当前 widget）
        // 使用 Future.microtask 确保在下一个事件循环中执行，避免任何潜在的 context 问题
          Fluttertoast.showToast(msg: '修改成功');

          // 发送学生数据变更事件，通知其他页面刷新
          eventBus.fire(StudentDataChangedEvent());

      }
    } catch (e) {
      debugPrint("e : $e");
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '修改失败') : '修改失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 左侧头像上传
                GestureDetector(
                  onTap: _pickImage,
                  child: Column(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF82A6F5),
                          shape: BoxShape.circle,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _avatarImage != null
                            ? Image.file(
                                File(_avatarImage!.path),
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                              )
                            : (_currentAvatarUrl?.isNotEmpty ?? false)
                            ? Image.network(
                                _currentAvatarUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/avatar.png',
                                    width: 60,
                                    height: 60,
                                  );
                                },
                              )
                            : Image.asset(
                                'assets/images/avatar.png', // 默认头像
                                width: 60,
                                height: 60,
                              ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '修改头像',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF999999),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // 右侧表单
                Expanded(
                  child: Column(
                    children: [
                      _buildTextField('姓名', _nameController),
                      _buildTextField('昵称', _nicknameController),

                      // 性别选择
                      Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 60,
                              child: Text(
                                '性别',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF2E2E2E),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildGenderItem(1, '♂'),
                                  _buildGenderItem(2, '♀'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 生日选择
                      GestureDetector(
                        onTap: _onDateSelect,
                        child: Container(
                          height: 48,
                          alignment: Alignment.centerLeft,
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFFEEEEEE),
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 60,
                                child: Text(
                                  '生日',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _selectedDate == null
                                      ? ''
                                      : "${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF2E2E2E),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 20,
                                color: Color(0xFF333333),
                              ),
                            ],
                          ),
                        ),
                      ),
                      _buildTextField(
                        '电话',
                        _phoneController,
                        showLine: true,
                        hint: "选填",
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 底部按钮区（只有取消和完成）
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 取消按钮
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5ECFF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '取消',
                      style: TextStyle(color: Color(0xFF333333), fontSize: 14),
                    ),
                  ),

                  // 完成按钮
                  ElevatedButton(
                    onPressed: _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF82A6F5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text(
                      '完成',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool showLine = true,
    String? hint,
  }) {
    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      decoration: showLine
          ? const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            )
          : null,
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              textAlign: TextAlign.start,
              style: const TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderItem(int value, String icon) {
    final bool isSelected = _gender == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _gender = value;
        });
      },
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: () {
            if (value == 1 && isSelected) {
              return const Color(0xFFCEF4FF);
            } else if (value == 2 && isSelected) {
              return const Color(0xFFFFE2E2);
            } else {
              return Colors.transparent;
            }
          }(),
          shape: BoxShape.circle,
        ),
        child: Icon(
          value == 1 ? Icons.male : Icons.female,
          size: 20,
          color: const Color(0xFF333333),
        ),
      ),
    );
  }
}
