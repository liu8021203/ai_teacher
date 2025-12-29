// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'activity_list_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ActivityListEntity _$ActivityListEntityFromJson(Map<String, dynamic> json) =>
    ActivityListEntity(
      id: (json['id'] as num).toInt(),
      parentId: (json['parentId'] as num?)?.toInt(),
      categoryTitle: json['categoryTitle'] as String,
      imageUrl: json['imageUrl'] as String?,
      color: json['color'] as String?,
    );

Map<String, dynamic> _$ActivityListEntityToJson(ActivityListEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'parentId': instance.parentId,
      'categoryTitle': instance.categoryTitle,
      'imageUrl': instance.imageUrl,
      'color': instance.color,
    };
