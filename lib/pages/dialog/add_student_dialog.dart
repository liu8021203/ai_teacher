import 'dart:io';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AddStudentDialog extends StatefulWidget {
  final VoidCallback? onSaveSuccess;

  const AddStudentDialog({super.key, this.onSaveSuccess});

  @override
  State<AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends State<AddStudentDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // 1: 男, 2: 女
  int _gender = 1;
  DateTime? _selectedDate;
  XFile? _avatarImage;
  String? _compressImagePath;

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

  Future<void> _onSave({bool isContinue = false}) async {
    final String name = _nameController.text.trim();
    final String nickname = _nicknameController.text.trim();
    final String phone = _phoneController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入学生姓名')));
      return;
    }

    if (nickname.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入学生乳名')));
      return;
    }

    if (_gender == 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择学生性别')));
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择出生年月')));
      return;
    }

    final String? classId = SPUtil.getString('classId', defaultValue: null);
    if (classId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('班级信息异常')));
      return;
    }

    context.loaderOverlay.show();

    try {
      Map<String, dynamic> params = {
        "token": UserManager().getUserInfo()?.token,
        "schoolId": UserManager().getUserInfo()?.schoolId ?? 0,
        "classId": classId,
        "studentName": name,
        "studentNickName": nickname,
        "studentBirthday": DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(_selectedDate!),
        "studentSex": _gender, // 1: 男, 2: 女, 已经与 UI 绑定一致
      };

      if (phone.isNotEmpty) {
        params["studentPhone"] = phone;
      }

      String? filePath;
      if (_avatarImage != null) {
        filePath = _avatarImage!.path;

        final extension = path.extension(_avatarImage!.name).toLowerCase();
        final fileLength = await _avatarImage!.length();
        final fileSizeMB = fileLength / (1024 * 1024);
        debugPrint("fileSizeMB : $fileSizeMB");

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
          filePath!,
          filename: "avatar$extension", // 确保文件名有后缀
          // contentType: DioMediaType("image", "jpeg"), // 可选，Dio 通常会自动推断
        );
        params["studentAvatar"] = file;
      }

      // 这里的泛型 dynamic 即可，假设不需要返回特定的实体，只要 code=0 即可
      await DioClient().post(
        '/addStudent',
        data: FormData.fromMap(params),
        fromJson: (json) => json, // 不关心返回值内容
      );

      if (mounted) {
        context.loaderOverlay.hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('添加成功')));

        // 回调刷新列表
        widget.onSaveSuccess?.call();

        if (!isContinue) {
          Navigator.of(context).pop();
        } else {
          _resetForm();
        }
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    }
  }

  void _resetForm() {
    setState(() {
      _nameController.clear();
      _nicknameController.clear();
      _phoneController.clear();
      _gender = 0;
      _selectedDate = null;
      _avatarImage = null;
      _compressImagePath = null;
    });
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
                            : Image.asset(
                                'assets/images/avatar.png', // 默认头像
                                width: 60,
                                height: 60,
                              ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '上传头像',
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

            // 底部按钮区
            Row(
              children: [
                // 取消按钮
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
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
                        style: TextStyle(
                          color: Color(0xFF333333),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 保存并继续添加
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _onSave(isContinue: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF82A6F5),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        '保存并继续添加',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // 完成
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () => _onSave(isContinue: false),
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
                  ),
                ),
              ],
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
            width: 60, // 电话标题较长，给多点空间
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
          debugPrint("_gender === $value");
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
