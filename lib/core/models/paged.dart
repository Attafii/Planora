import '../network/api_client.dart';

class Paged<T> {
  const Paged(this.items, {this.hasMore = false});
  factory Paged.fromJson(JsonMap json, T Function(JsonMap) decode) => Paged(
    (json['items'] as List).map((item) => decode(item as JsonMap)).toList(),
    hasMore: json['has_more'] == true,
  );
  final List<T> items;
  final bool hasMore;
}
