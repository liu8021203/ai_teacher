// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentListEntity _$StudentListEntityFromJson(Map<String, dynamic> json) =>
    StudentListEntity(
      id: (json['id'] as num).toInt(),
      studentName: json['studentName'] as String,
      studentNickName: json['studentNickName'] as String?,
      phone: json['phone'] as String?,
      studentAvatar: json['studentAvatar'] as String?,
      studentSex: (json['studentSex'] as num).toInt(),
      studentBirthday: json['studentBirthday'] as String,
    );

Map<String, dynamic> _$StudentListEntityToJson(StudentListEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'studentName': instance.studentName,
      'studentNickName': instance.studentNickName,
      'phone': instance.phone,
      'studentAvatar': instance.studentAvatar,
      'studentSex': instance.studentSex,
      'studentBirthday': instance.studentBirthday,
    };
