import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import '../http/core/dio_client.dart';
import '../http/exception/http_exception.dart';
import 'main_page.dart';
import '../manager/user_manager.dart';
import '../http/model/user_entity.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // 0: 登录, 1: 注册
  int _tabIndex = 0;

  // 表单控制器
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();

  // 倒计时相关
  Timer? _timer;
  int _countdown = 0;
  bool _isSendingCode = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _schoolController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 发送验证码逻辑
  Future<void> _sendSms() async {
    // 如果正在倒计时，直接返回
    if (_countdown > 0 || _isSendingCode) return;

    final String phone = _phoneController.text.trim();

    // 校验手机号
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手机号格式不正确')));
      return;
    }

    setState(() {
      _isSendingCode = true;
    });

    try {
      // 调用发送验证码接口
      await DioClient().post('/sendSms', data: {'phone': phone});

      // 开始倒计时
      _startCountdown();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('验证码已发送')));
    } catch (e) {
      String message = '服务异常，请稍后重试';
      if (e is HttpException) {
        message = e.message ?? message;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _isSendingCode = false;
        });
      }
    }
  }

  void _startCountdown() {
    setState(() {
      _countdown = 60;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _onLoginOrRegister() async {
    // TODO: 实现登录或注册逻辑
    final String phone = _phoneController.text.trim();
    // 校验手机号
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入手机号')));
      return;
    }

    if (phone.length != 11) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('手机号格式不正确')));
      return;
    }
    final String code = _codeController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入验证码')));
      return;
    }

    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入正确的验证码')));
      return;
    }
    // 临时跳转到主页
    if (_tabIndex == 0) {
      context.loaderOverlay.show();
      try {
        UserEntity? user = await DioClient().post<UserEntity>(
          '/login',
          data: {'phone': phone, 'code': code},
          fromJson: (json) => UserEntity.fromJson(json),
        );

        // 登录成功，更新 UserManager
        UserManager().login(user!);

        if (mounted) {
          context.loaderOverlay.hide();
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainPage()),
          );
        }
      } catch (e) {
        if (mounted) {
          context.loaderOverlay.hide();
          String message = '登录失败，请稍后重试';
          if (e is HttpException) {
            message = e.message ?? message;
          }
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        }
      }
    } else if (_tabIndex == 1) {
      final String schoolCode = _schoolController.text.trim();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请园区编码')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: AssetImage('assets/images/login_bg.png'), // 本地图片
          fit: BoxFit.cover, // 填充方式
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 100),
            // 顶部标题
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '欢迎来到AI萌记',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // 主要内容区域（白色卡片）
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFE5ECFF),
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Tab 栏
                  Row(
                    children: [_buildTabItem(0, '登录'), _buildTabItem(1, '注册')],
                  ),

                  // 表单区域
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        bottomLeft: const Radius.circular(24),
                        bottomRight: const Radius.circular(24),
                        topRight: _tabIndex == 0
                            ? const Radius.circular(24)
                            : Radius.zero,
                        topLeft: _tabIndex == 1
                            ? const Radius.circular(24)
                            : Radius.zero,
                      ),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        // 手机号输入框
                        _buildTextField(
                          controller: _phoneController,
                          hintText: '请输入手机号',
                        ),
                        const SizedBox(height: 20),

                        // 验证码输入框 + 发送按钮
                        Row(
                          children: [
                            Expanded(
                              child: _buildTextField(
                                controller: _codeController,
                                hintText: '请输入验证码',
                              ),
                            ),
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: _sendSms,
                              child: Container(
                                height: 50,
                                width: 100,
                                // 稍微加宽一点以容纳倒计时文字
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5ECFF), // 灰色按钮
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: _isSendingCode
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.black54,
                                        ),
                                      )
                                    : Text(
                                        _countdown > 0
                                            ? '${_countdown}s'
                                            : '发送',
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          color: _countdown > 0
                                              ? Colors.grey
                                              : Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),

                        // 注册模式下的密码输入框
                        if (_tabIndex == 1) ...[
                          const SizedBox(height: 20),
                          _buildTextField(
                            controller: _schoolController,
                            hintText: '请输入园区编码',
                            obscureText: true,
                          ),
                        ],

                        const SizedBox(height: 40),

                        // 登录/注册按钮
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _onLoginOrRegister,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7EA1FF),
                              // 灰色按钮
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              _tabIndex == 0 ? '登录' : '注册',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: Container()),
            const SizedBox(height: 40),
            // 底部协议
            Center(
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF666666),
                    fontSize: 12,
                  ),
                  children: [
                    TextSpan(text: _tabIndex == 0 ? '登录即表示同意' : '点击注册即表示同意'),
                    TextSpan(
                      text: '《用户协议》',
                      style: const TextStyle(color: Color(0xFF4A90E2)),
                      recognizer: TapGestureRecognizer()..onTap = () {},
                    ),
                    const TextSpan(text: ' 和 '),
                    TextSpan(
                      text: '《隐私政策》',
                      style: const TextStyle(color: Color(0xFF4A90E2)),
                      recognizer: TapGestureRecognizer()..onTap = () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String text) {
    final bool isSelected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
          });
        },
        child: Container(
          height: 50,
          color: Colors.transparent,
          child: Stack(
            children: [
              // 反向圆角底色层 (仅未选中时显示，用于填补圆角空隙)
              if (!isSelected)
                Positioned(
                  bottom: 0,
                  left: index == 1 ? 0 : null,
                  // 注册页在右，处理左下角
                  right: index == 0 ? 0 : null,
                  // 登录页在左，处理右下角
                  width: 25,
                  height: 25,
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                ),
              // Tab 主体
              Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : const Color(0xFFE5ECFF),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    // 未选中状态下底部保留圆角，配合底下的白色层形成反向圆角效果
                    bottomLeft: isSelected
                        ? Radius.zero
                        : const Radius.circular(24),
                    bottomRight: isSelected
                        ? Radius.zero
                        : const Radius.circular(24),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5), // 浅灰色背景
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hintText,
          hintStyle: const TextStyle(color: Color(0xFF999999)),
          isDense: true,
        ),
        style: const TextStyle(color: Color(0xFF333333)),
      ),
    );
  }
}
