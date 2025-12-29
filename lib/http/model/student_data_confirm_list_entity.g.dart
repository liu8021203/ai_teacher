// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_data_confirm_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentDataConfirmListEntity _$StudentDataConfirmListEntityFromJson(
  Map<String, dynamic> json,
) => StudentDataConfirmListEntity(
  id: (json['id'] as num).toInt(),
  studentId: (json['studentId'] as num?)?.toInt(),
  studentName: json['studentName'] as String?,
  activity: json['activity'] as String?,
  description: json['description'] as String?,
  createDate: json['createDate'] as String,
);

Map<String, dynamic> _$StudentDataConfirmListEntityToJson(
  StudentDataConfirmListEntity instance,
) => <String, dynamic>{
  'id': instance.id,
  'studentId': instance.studentId,
  'studentName': instance.studentName,
  'activity': instance.activity,
  'description': instance.description,
  'createDate': instance.createDate,
};
