import 'dart:io';
import 'package:ai_teacher/base/base_stateful_widget.dart';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_data_confirm_list_entity.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/pages/dialog/student_data_confirm_dialog.dart';
import 'package:ai_teacher/util/app_util.dart';
import 'package:ai_teacher/util/sp_util.dart';
import 'package:badges/badges.dart' as badges;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  ShowState _studentShowState = ShowLoading();
  List<StudentListEntity>? _studentList = null;
  double _studentWidth = 0;
  double _studentHeight = 0;

  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _recordedFilePath;

  // 未读数据相关
  List<StudentDataConfirmListEntity> _unreadDataList = [];
  Map<int, int> _studentUnreadCount = {}; // 学生ID -> 未读数量
  int _unknownUnreadCount = 0; // 未知条目的未读数量

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
    _fetchUnreadData();
  }

  @override
  void dispose() {
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentList() async {
    setState(() {
      _studentShowState = ShowLoading();
    });

    try {
      final String? classId = SPUtil.getString('classId', defaultValue: null);
      debugPrint("classId : $classId");

      if (classId == null) {
        setState(() {
          _studentShowState = ShowSuccess();
        });
        return;
      }

      List<StudentListEntity>? list = await DioClient()
          .post<List<StudentListEntity>>(
            '/studentList',
            data: {
              'token': UserManager().getUserInfo()?.token,
              'schoolId': UserManager().getUserInfo()?.schoolId,
              "classId": classId,
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
          _studentShowState = ShowSuccess();
        });
      }
    } catch (e) {
      HttpException? exception = e as HttpException?;
      if (exception != null) {
        if (mounted) {
          setState(() {
            _studentShowState = ShowNetworkErrorView(
              exception.code,
              exception.message,
            );
          });
        }
      }
    }
  }

  Future<void> _fetchUnreadData() async {
    try {
      final String? classId = SPUtil.getString('classId', defaultValue: null);
      if (classId == null) {
        return;
      }

      List<StudentDataConfirmListEntity>? list = await DioClient()
          .post<List<StudentDataConfirmListEntity>>(
            '/getStudentDataToBeConfirmed',
            data: {'classId': classId},
            fromJson: (json) {
              if (json is List) {
                return json
                    .map((e) => StudentDataConfirmListEntity.fromJson(e))
                    .toList();
              }
              return null;
            },
          );

      if (mounted && list != null) {
        setState(() {
          _unreadDataList = list;
          _calculateUnreadCounts();
        });
      }
    } catch (e) {
      debugPrint('获取未读数据失败: $e');
    }
  }

  void _calculateUnreadCounts() {
    _studentUnreadCount.clear();
    _unknownUnreadCount = 0;

    for (var item in _unreadDataList) {
      if (item.studentId == null || item.studentId == 0) {
        // studentId 为 null 或 0 的归为未知条目
        _unknownUnreadCount++;
      } else {
        // 统计每个学生的未读数量
        _studentUnreadCount[item.studentId!] =
            (_studentUnreadCount[item.studentId!] ?? 0) + 1;
      }
    }
  }

  void _onStudentTap(int studentId, StudentListEntity? student) {
    // 获取该学生的未读数据
    List<StudentDataConfirmListEntity> studentDataList = [];

    if (studentId == 0) {
      // 未知条目
      studentDataList = _unreadDataList
          .where((item) => item.studentId == null || item.studentId == 0)
          .toList();
    } else {
      // 普通学生
      studentDataList = _unreadDataList
          .where((item) => item.studentId == studentId)
          .toList();
    }

    if (studentDataList.isEmpty) {
      // 没有未读数据，不弹出Dialog
      return;
    }

    // 显示Dialog
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          StudentDataConfirmDialog(student: student, dataList: studentDataList),
    ).then((result) {
      if (result == true) {
        // 刷新未读数据
        _fetchUnreadData();
      }
    });
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    // 检查是否已有权限
    final currentStatus = await Permission.microphone.status;

    // 如果没有权限，先请求权限
    if (!currentStatus.isGranted) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能录音')));
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已授予麦克风权限，请再次长按开始录音')));
      }
      return;
    }

    // 已有权限，开始录音
    try {
      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/record_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() {
        _isRecording = true;
        _recordedFilePath = filePath;
      });

      debugPrint('开始录音: $filePath');
    } catch (e) {
      debugPrint('录音失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('录音失败: $e')));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
      });

      debugPrint('录音结束: $path');

      if (path != null && path.isNotEmpty) {
        _uploadAudio(path);
      }
    } catch (e) {
      debugPrint('停止录音失败: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _uploadAudio(String filePath) async {
    context.loaderOverlay.show();

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        throw Exception('录音文件不存在');
      }

      MultipartFile audioFile = await MultipartFile.fromFile(
        filePath,
        filename: 'audio.m4a',
      );
      final String? classId = SPUtil.getString('classId', defaultValue: null);

      await DioClient().post(
        '/aiAnalyzeRecordAudio',
        data: FormData.fromMap({
          'token': UserManager().getUserInfo()?.token,
          'classId': classId,
          'audioFile': audioFile,
        }),
        fromJson: (json) => json,
      );

      if (mounted) {
        context.loaderOverlay.hide();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('上传成功')));

        // 删除音频文件
        _deleteAudioFile(filePath);
      }
    } catch (e) {
      if (mounted) {
        context.loaderOverlay.hide();

        // 显示重试对话框
        _showRetryDialog(filePath);
      }
    }
  }

  void _showRetryDialog(String filePath) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('上传失败'),
          content: const Text('音频上传失败，是否重试？'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAudioFile(filePath);
              },
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _uploadAudio(filePath);
              },
              child: const Text('重试'),
            ),
          ],
        );
      },
    );
  }

  void _deleteAudioFile(String filePath) {
    try {
      final file = File(filePath);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('音频文件已删除: $filePath');
      }
    } catch (e) {
      debugPrint('删除音频文件失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _studentWidth = (MediaQuery.of(context).size.width - 16 - 12 * 4) / 9 * 2;
    _studentHeight =
        AppUtil.calculateTextWidth(
          "小明",
          TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ) +
        _studentWidth +
        6 +
        8;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          '观察记录',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF82A6F5),
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            height: _studentHeight,
            margin: EdgeInsets.fromLTRB(0, 16, 0, 0),
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                // 判断是否是最后一个（未知条目）
                final isUnknown = index == (_studentList?.length ?? 0);
                final studentId = isUnknown ? 0 : _studentList![index].id;
                final unreadCount = isUnknown
                    ? _unknownUnreadCount
                    : (_studentUnreadCount[studentId] ?? 0);

                return GestureDetector(
                  onTap: () {
                    if (unreadCount > 0) {
                      _onStudentTap(
                        studentId,
                        isUnknown ? null : _studentList![index],
                      );
                    }
                  },
                  child: Column(
                    children: [
                      badges.Badge(
                        position: badges.BadgePosition.bottomEnd(
                          bottom: -10,
                          end: -3,
                        ),
                        showBadge: unreadCount > 0,
                        ignorePointer: false,
                        onTap: () {},
                        badgeContent: Text(
                          '$unreadCount',
                          style: TextStyle(color: Colors.white, fontSize: 12),
                        ),
                        badgeStyle: badges.BadgeStyle(
                          shape: badges.BadgeShape.circle,
                          badgeColor: Colors.red,
                          padding: EdgeInsets.all(5),
                          borderSide: BorderSide(color: Colors.white, width: 2),
                          elevation: 0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: isUnknown
                              ? Container(
                                  width: _studentWidth,
                                  height: _studentWidth,
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.help_outline,
                                    size: 40,
                                    color: Colors.grey,
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl:
                                      _studentList![index].studentAvatar ?? "",
                                  width: _studentWidth,
                                  height: _studentWidth,
                                  maxHeightDiskCache: 300,
                                  maxWidthDiskCache: 300,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.grey.shade300,
                                    child: Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: Colors.grey.shade300,
                                        child: Icon(
                                          Icons.person,
                                          size: 40,
                                          color: Colors.grey,
                                        ),
                                      ),
                                ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Container(
                        width: _studentWidth,
                        alignment: Alignment.center,
                        child: Text(
                          isUnknown ? '未知' : _studentList![index].studentName,
                          style: TextStyle(
                            overflow: TextOverflow.ellipsis,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) {
                return SizedBox(width: 12);
              },
              itemCount: (_studentList?.length ?? 0) + 1, // +1 为未知条目
            ),
          ),

          // 顶部提示文字
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 40, left: 20, right: 20),
            child: Text(
              _isRecording ? '录音中...' : '请说出记录内容',
              style: TextStyle(
                fontSize: 24,
                color: _isRecording
                    ? const Color(0xFFFF6B6B)
                    : const Color(0xFF333333),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),

          const Spacer(flex: 2),

          // 中间点状装饰条
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(25, (index) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF82A6F5),
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),

          const Spacer(flex: 3),

          // 底部录音按钮区域
          Column(
            children: [
              // 蓝色圆形按钮
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _isRecording ? 174 : 154,
                  height: _isRecording ? 174 : 154,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? const Color(0xFFFF6B6B)
                        : const Color(0xFF82A6F5),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isRecording
                                    ? const Color(0xFFFF6B6B)
                                    : const Color(0xFF82A6F5))
                                .withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop : Icons.mic,
                    color: Colors.white,
                    size: _isRecording ? 50 : 40,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              // 底部文字
              const Text(
                '长按按钮\n进行观察记录',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2E2E2E),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}
