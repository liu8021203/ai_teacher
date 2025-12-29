// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student_data_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StudentDataListEntity _$StudentDataListEntityFromJson(
  Map<String, dynamic> json,
) => StudentDataListEntity(
  id: (json['id'] as num).toInt(),
  activity: json['activity'] as String?,
  description: json['description'] as String?,
  createDate: json['createDate'] as String,
);

Map<String, dynamic> _$StudentDataListEntityToJson(
  StudentDataListEntity instance,
) => <String, dynamic>{
  'id': instance.id,
  'activity': instance.activity,
  'description': instance.description,
  'createDate': instance.createDate,
};
