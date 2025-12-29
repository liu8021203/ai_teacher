import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentDetailPage extends StatefulWidget {
  final StudentListEntity student;

  const StudentDetailPage({super.key, required this.student});

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> {
  DateTime _selectedDate = DateTime.now();
  List<StudentDataConfirmListEntity> _dataList = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0; // 0: 观察, 1: 日报, 2: 照片

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

      List<StudentDataConfirmListEntity>? list = await DioClient()
          .post<List<StudentDataConfirmListEntity>>(
            '/getStudentData',
            data: {'studentId': widget.student.id, 'date': dateStr},
            fromJson: (json) {
              if (json is List) {
                return json
                    .map((e) => StudentDataConfirmListEntity.fromJson(e))
                    .toList();
              }
              return null;
            },
          );

      if (mounted) {
        setState(() {
          _dataList = list ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e is HttpException ? e.message : '加载失败';
        });
      }
    }
  }

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF82A6F5)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchStudentData();
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatTime(String? createDate) {
    if (createDate == null || createDate.isEmpty) {
      return '--:--';
    }
    try {
      final date = DateTime.parse(createDate);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return '--:--';
    }
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
        title: Text(
          '${widget.student.studentName}的主页',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              // TODO: 菜单功能
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部Tab栏
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                _buildTab('观察', 0),
                const SizedBox(width: 16),
                _buildTab('日报', 1),
              ],
            ),
          ),

          // 日期选择栏
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                Text(
                  _isToday(_selectedDate)
                      ? '今天'
                      : DateFormat('yyyy-MM-dd').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  DateFormat('EEEE', 'zh_CN').format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF999999),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _selectDate,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF2E2E2E),
                  ),
                ),
              ],
            ),
          ),

          // 内容区域
          Expanded(
            child: Container(
              color: Colors.white,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                            onPressed: _fetchStudentData,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    )
                  : _dataList.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF999999),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _dataList.length,
                      itemBuilder: (context, index) {
                        return _buildDataCard(_dataList[index], index);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF7EA1FF) : Color(0xFFF2F5FF),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            color: isSelected ? Colors.white : Color(0xFF212121),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildDataCard(StudentDataConfirmListEntity data, int index) {
    // 根据index决定背景颜色
    Color backgroundColor;
    if (index % 3 == 0) {
      backgroundColor = const Color(0xFFE8F0FF); // 蓝色
    } else if (index % 3 == 1) {
      backgroundColor = const Color(0xFFFFF0F0); // 粉色
    } else {
      backgroundColor = const Color(0xFFFFFBE8); // 黄色
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFF424242), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 内容区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 活动标题
                Row(
                  children: [
                    Text(
                      data.activity ?? '未知活动',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF44588D),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(data.createDate),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 描述内容
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Color(0xFFD7D6E8), width: 1),
                  ),
                  child: Text(
                    data.description ?? '',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF2E2E2E),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // 底部操作按钮
                Row(
                  children: [
                    const Spacer(),
                    _buildActionButton(
                      'assets/images/student_details_edit.png',
                      Color(0xFF44588D),
                      '编辑',
                      () {},
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'assets/images/student_details_delete.png',
                      Color(0xFF8D0D0D),
                      '删除',
                      () {},
                    ),
                    const SizedBox(width: 16),
                    _buildActionButton(
                      'assets/images/student_details_move.png',
                      Color(0xFF44588D),
                      '移动',
                      () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Image.asset(icon, width: 20, height: 20),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }
}
