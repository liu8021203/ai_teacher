// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserEntity _$UserEntityFromJson(Map<String, dynamic> json) => UserEntity(
  teacherName: json['teacherName'] as String,
  teacherPhone: json['teacherPhone'] as String,
  schoolId: (json['schoolId'] as num).toInt(),
  token: json['token'] as String,
);

Map<String, dynamic> _$UserEntityToJson(UserEntity instance) =>
    <String, dynamic>{
      'teacherName': instance.teacherName,
      'teacherPhone': instance.teacherPhone,
      'schoolId': instance.schoolId,
      'token': instance.token,
    };
