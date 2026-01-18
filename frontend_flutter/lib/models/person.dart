class Person {
  final String name;
  final int photos;
  final String? eyeColor;
  final String? hairColor;

  Person({
    required this.name,
    required this.photos,
    this.eyeColor,
    this.hairColor,
  });

  factory Person.fromMap(Map<String, dynamic> json) {
    return Person(
      name: (json['name'] as String?) ?? '',
      photos: (json['photos_count'] as num?)?.toInt() ?? 0,
      eyeColor: json['eye_color'] as String?,
      hairColor: json['hair_color'] as String?,
    );
  }
}