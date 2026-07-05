String formatCoordinateText(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

bool isZeroCoordinate(
  double latitude,
  double longitude, {
  double tolerance = 0,
}) {
  final threshold = tolerance.abs();
  if (threshold == 0) return latitude == 0 && longitude == 0;
  return latitude.abs() < threshold && longitude.abs() < threshold;
}
