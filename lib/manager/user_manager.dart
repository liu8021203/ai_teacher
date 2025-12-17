import 'dart:convert';

import 'package:ai_teacher/util/sp_util.dart';
import 'package:flutter/foundation.dart';
import '../http/model/user_entity.dart';

class UserManager extends ChangeNotifier {
  // 单例模式
  static final UserManager _instance = UserManager._internal();

  factory UserManager() => _instance;

  UserManager._internal();

  UserEntity? _user;

  // 获取当前用户
  UserEntity? get user => _user;

  // 登录/设置用户信息
  void login(UserEntity user) {
    _user = user;
    SPUtil.setString("user_info", jsonEncode(user));
    notifyListeners();
  }

  bool isLogin() {
    String? userInfo = SPUtil.getString("user_info", defaultValue: null);
    if (userInfo == null) {
      return false;
    } else {
      return true;
    }
  }

  // 退出登录
  void logout() {
    _user = null;
    SPUtil.remove("user_info");
    notifyListeners();
  }

  // 更新部分信息 (示例)
  void updateUserName(String name) {
    // if (_user != null) {
    //   _user = UserEntity(
    //     token: _user!.token,
    //     name: name,
    //     avatar: _user!.avatar,
    //     phone: _user!.phone,
    //   );
    //   notifyListeners();
    // }
  }

  UserEntity? getUserInfo() {
    String? userInfo = SPUtil.getString("user_info", defaultValue: null);
    if (userInfo != null) {
      UserEntity? result = UserEntity.fromJson(jsonDecode(userInfo));
      return result;
    } else {
      return null;
    }
  }
}
