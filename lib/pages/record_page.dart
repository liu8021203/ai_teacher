import 'dart:io';
import 'package:ai_teacher/base/base_stateful_widget.dart';
import 'package:ai_teacher/http/core/dio_client.dart';
import 'package:ai_teacher/http/exception/http_exception.dart';
import 'package:ai_teacher/http/model/student_list_entity.dart';
import 'package:ai_teacher/manager/user_manager.dart';
import 'package:ai_teacher/util/app_util.dart';
import 'package:ai_teacher/util/sp_util.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchStudentList();
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

  Future<bool> _requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;

    final hasPermission = await _requestPermission();
    if (!hasPermission) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('需要麦克风权限才能录音')));
      return;
    }

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

      await DioClient().post(
        '/aiAnalyzeRecordAudio',
        data: FormData.fromMap({
          'token': UserManager().getUserInfo()?.token,
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
        6;
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
                return Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(40),
                      child: CachedNetworkImage(
                        imageUrl: _studentList![index].studentAvatar ?? "",
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
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey.shade300,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 4),
                    Container(
                      width: _studentWidth,
                      alignment: Alignment.center,
                      child: Text(
                        _studentList![index].studentName,
                        style: TextStyle(
                          overflow: TextOverflow.ellipsis,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                );
              },
              separatorBuilder: (context, index) {
                return SizedBox(width: 12);
              },
              itemCount: _studentList?.length ?? 0,
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
