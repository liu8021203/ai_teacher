import 'dart:io';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AddActivityPage extends StatefulWidget {
  final int parentId; // 父级分类ID

  const AddActivityPage({super.key, required this.parentId});

  @override
  State<AddActivityPage> createState() => _AddActivityPageState();
}

class _AddActivityPageState extends State<AddActivityPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _directGoalController = TextEditingController();
  final TextEditingController _indirectGoalController = TextEditingController();
  final TextEditingController _errorControlController = TextEditingController();
  final TextEditingController _followUpWorkController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _practiseController = TextEditingController();

  // 练习与目的的关系控制器列表

  String? _imageUrl; // 上传后的图片URL
  File? _localImageFile; // 本地选择的图片文件
  String _selectedAgeRange = 'CASA'; // 选中的年龄段

  @override
  void dispose() {
    _nameController.dispose();
    _directGoalController.dispose();
    _indirectGoalController.dispose();
    _errorControlController.dispose();
    _followUpWorkController.dispose();
    _remarksController.dispose();
    _practiseController.dispose();
    super.dispose();
  }

  // 选择图片
  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _localImageFile = File(image.path);
      });
      // 选择后立即上传
      _uploadImage(File(image.path));
    }
  }

  // 上传图片
  Future<void> _uploadImage(File imageFile) async {
    try {
      context.loaderOverlay.show();

      // 压缩图片（如果大于2MB）
      String? filePath = imageFile.path;
      final extension = path.extension(imageFile.path).toLowerCase();
      final fileLength = await imageFile.length();
      final fileSizeMB = fileLength / (1024 * 1024);

      if (fileSizeMB > 2) {
        final directory = await getTemporaryDirectory();
        final compressPath =
            '${directory.path}/compress_${DateTime.now().millisecondsSinceEpoch}$extension';

        var result = await FlutterImageCompress.compressAndGetFile(
          imageFile.path,
          compressPath,
          quality: (150 / fileSizeMB).toInt(),
        );

        filePath = result?.path ?? imageFile.path;
      }

      // 创建 FormData
      MultipartFile file = await MultipartFile.fromFile(
        filePath,
        filename: "activity_image.jpg",
      );

      FormData formData = FormData.fromMap({'image': file});

      // 调用上传接口
      String? imageUrl = await DioClient().post<String>(
        '/imageUpload',
        data: formData,
        fromJson: (json) => json as String,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        if (imageUrl != null && imageUrl.isNotEmpty) {
          setState(() {
            _imageUrl = imageUrl;
          });
          Fluttertoast.showToast(msg: '图片上传成功');
        } else {
          Fluttertoast.showToast(msg: '图片上传失败');
        }
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '上传失败') : '上传失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  // 保存活动
  Future<void> _saveActivity() async {
    // 验证必填项
    if (_nameController.text.trim().isEmpty) {
      Fluttertoast.showToast(msg: '请输入活动名称');
      return;
    }

    try {
      context.loaderOverlay.show();

      Map<String, dynamic> data = {
        'token': UserManager().getUserInfo()?.token,
        'schoolId': UserManager().getUserInfo()?.schoolId,
        'parentId': widget.parentId,
        'categoryTitle': _nameController.text.trim(),
        'ageRange': _selectedAgeRange,
      };

      // 添加可选字段
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        data['imageUrl'] = _imageUrl;
      }
      if (_directGoalController.text.trim().isNotEmpty) {
        data['directGoal'] = _directGoalController.text.trim();
      }
      if (_indirectGoalController.text.trim().isNotEmpty) {
        data['indirectGoal'] = _indirectGoalController.text.trim();
      }

      if (_errorControlController.text.trim().isNotEmpty) {
        data['errorControl'] = _errorControlController.text.trim();
      }
      if (_followUpWorkController.text.trim().isNotEmpty) {
        data['followUpWork'] = _followUpWorkController.text.trim();
      }
      if (_remarksController.text.trim().isNotEmpty) {
        data['remarks'] = _remarksController.text.trim();
      }
      if (_practiseController.text.trim().isNotEmpty) {
        data['practise'] = _practiseController.text.trim();
      }

      await DioClient().post(
        '/addActivityData',
        data: data,
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        Fluttertoast.showToast(msg: '添加成功');
        // 返回新添加的活动名称
        Navigator.of(context).pop(_nameController.text.trim());
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();
        final message = e is HttpException ? (e.message ?? '添加失败') : '添加失败';
        Fluttertoast.showToast(msg: message);
      }
    }
  }

  // 选择年龄范围
  void _selectAgeRange() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '选择年龄范围',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
              ),
              const Divider(height: 1),
              ...['CASA', 'IC', 'JUNIOR', 'SENIOR'].map((age) {
                return ListTile(
                  title: Text(
                    age,
                    style: TextStyle(
                      fontSize: 16,
                      color: _selectedAgeRange == age
                          ? const Color(0xFF82A6F5)
                          : const Color(0xFF2E2E2E),
                    ),
                  ),
                  trailing: _selectedAgeRange == age
                      ? const Icon(Icons.check, color: Color(0xFF82A6F5))
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedAgeRange = age;
                    });
                    Navigator.of(context).pop();
                  },
                );
              }).toList(),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '添加活动',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        actions: [
          TextButton(
            onPressed: _saveActivity,
            child: const Text(
              '保存',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 活动名称
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildRequiredLabel('活动名称'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide.none,
                            ),
                            // hintText: '请输入活动名称',
                            // border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 6,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // 活动图片
                  Row(
                    children: [
                      const Text(
                        '*',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.transparent,
                        ),
                      ),
                      const Text(
                        '活动图片',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF666666),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFE3E3E3),
                              width: 1,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: _localImageFile != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    _localImageFile!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : const Center(
                                  child: Icon(
                                    Icons.add,
                                    size: 48,
                                    color: Color(0xFFE3E3E3),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 年龄范围
            _buildSectionCard(
              child: GestureDetector(
                onTap: _selectAgeRange,
                child: Row(
                  children: [
                    _buildRequiredLabel('年龄范围'),
                    const Spacer(),
                    Text(
                      _selectedAgeRange,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2E2E2E),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF999999),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // 目的
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '目的',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '直接目的',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
                  ),
                  const SizedBox(height: 8),
                  _buildMultilineTextField(_directGoalController, '请简单描述'),
                  const SizedBox(height: 16),
                  const Text(
                    '间接目的',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
                  ),
                  const SizedBox(height: 8),
                  _buildMultilineTextField(_indirectGoalController, '请简单描述'),
                  const SizedBox(height: 16),
                  const Text(
                    '练习与目的的关系',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
                  ),
                  const SizedBox(height: 8),

                  _buildMultilineTextField(_practiseController, '请简单描述'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 其他
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '其他',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '错误控制',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
                  ),
                  const SizedBox(height: 8),
                  _buildMultilineTextField(_errorControlController, '请简单描述'),
                  const SizedBox(height: 16),
                  const Text(
                    '后续需要示范的工作',
                    style: TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
                  ),
                  const SizedBox(height: 8),
                  _buildMultilineTextField(_followUpWorkController, '请简单描述'),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 备注
            _buildSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '备注',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF666666),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildMultilineTextField(_remarksController, '请简单描述'),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // 构建区块卡片
  Widget _buildSectionCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  // 构建必填标签
  Widget _buildRequiredLabel(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('*', style: TextStyle(fontSize: 14, color: Colors.red)),
        Text(
          text,
          style: const TextStyle(fontSize: 14, color: Color(0xFF2E2E2E)),
        ),
      ],
    );
  }

  // 构建多行输入框
  Widget _buildMultilineTextField(
    TextEditingController controller,
    String hint,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFFCCCCCC), fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }
}
