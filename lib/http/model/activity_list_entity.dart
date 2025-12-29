import 'package:json_annotation/json_annotation.dart';

part 'activity_list_entity.g.dart';

@JsonSerializable()
class ActivityListEntity {
  late final int id;
  late final int? parentId;
  late final String categoryTitle;
  late final String? imageUrl;
  late final String? color;

  ActivityListEntity({
    required this.id,
    this.parentId,
    required this.categoryTitle,
    this.imageUrl,
    this.color
  });

  factory ActivityListEntity.fromJson(Map<String, dynamic> json) => _$ActivityListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$ActivityListEntityToJson(this);
}
