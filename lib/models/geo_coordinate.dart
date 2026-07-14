String formatCoordinateText(double latitude, double longitude) {
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

/// External Google Maps search URI for a WGS84 coordinate pair.
Uri googleMapsSearchUri(double latitude, double longitude) {
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
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
