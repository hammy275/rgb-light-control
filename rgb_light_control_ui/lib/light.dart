class Light {
  final String ip;
  final String name;

  const Light({required this.ip, required this.name});

  factory Light.fromJson(Map<String, dynamic> json) {
    return switch (json) {
      {"ip": String ip, "name": String name} => Light(ip: ip, name: name),
      _ => throw const FormatException("Invalid format received.")
    };
  }
}