import 'package:json_annotation/json_annotation.dart';

part 'class_list_entity.g.dart';

@JsonSerializable()
class ClassListEntity {
  late final int id;
  late final String className;

  ClassListEntity({
    required this.id,
    required this.className
  });

  factory ClassListEntity.fromJson(Map<String, dynamic> json) => _$ClassListEntityFromJson(json);

  Map<String, dynamic> toJson() => _$ClassListEntityToJson(this);
}
