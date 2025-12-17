import 'package:json_annotation/json_annotation.dart';

part 'user_entity.g.dart';

@JsonSerializable()
class UserEntity {
  late final String teacherName;
  late final String teacherPhone;
  late final int schoolId;
  late final String token;

  UserEntity({
    required this.teacherName,
    required this.teacherPhone,
    required this.schoolId,
    required this.token,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) => _$UserEntityFromJson(json);

  Map<String, dynamic> toJson() => _$UserEntityToJson(this);
}
