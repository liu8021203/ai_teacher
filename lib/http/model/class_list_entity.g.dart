// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClassListEntity _$ClassListEntityFromJson(Map<String, dynamic> json) =>
    ClassListEntity(
      id: (json['id'] as num).toInt(),
      className: json['className'] as String,
    );

Map<String, dynamic> _$ClassListEntityToJson(ClassListEntity instance) =>
    <String, dynamic>{'id': instance.id, 'className': instance.className};
