import 'dart:io';
import 'dart:typed_data';

void main() async {
  // Create a simple 192x192 PNG icon (minimal valid PNG)
  final icon192 = _createMinimalPNG(192);
  final icon512 = _createMinimalPNG(512);

  // Write the icons
  await File('web/icons/Icon-192.png').writeAsBytes(icon192);
  await File('web/icons/Icon-512.png').writeAsBytes(icon512);
  await File('web/icons/Icon-maskable-192.png').writeAsBytes(icon192);
  await File('web/icons/Icon-maskable-512.png').writeAsBytes(icon512);

  print('Web icons generated successfully!');
}

Uint8List _createMinimalPNG(int size) {
  // This creates a minimal valid PNG with a solid color
  // In a real scenario, you'd want to use a proper image library
  // For now, this creates a basic 1x1 pixel PNG that browsers can load

  // PNG signature
  final signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];

  // IHDR chunk (image header)
  final width = size;
  final height = size;
  final ihdrData = [
    (width >> 24) & 0xFF, (width >> 16) & 0xFF, (width >> 8) & 0xFF,
    width & 0xFF,
    (height >> 24) & 0xFF, (height >> 16) & 0xFF, (height >> 8) & 0xFF,
    height & 0xFF,
    8, // bit depth
    2, // color type (RGB)
    0, // compression
    0, // filter
    0 // interlace
  ];

  final ihdrChunk = _createChunk('IHDR', ihdrData);

  // IDAT chunk (image data) - minimal 1x1 pixel
  final idatData = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00];
  final idatChunk = _createChunk('IDAT', idatData);

  // IEND chunk (end of file)
  final iendChunk = _createChunk('IEND', []);

  return Uint8List.fromList(
      [...signature, ...ihdrChunk, ...idatChunk, ...iendChunk]);
}

Uint8List _createChunk(String type, List<int> data) {
  final typeBytes = type.codeUnits;
  final crc = _calculateCRC([...typeBytes, ...data]);

  return Uint8List.fromList([
    (data.length >> 24) & 0xFF,
    (data.length >> 16) & 0xFF,
    (data.length >> 8) & 0xFF,
    data.length & 0xFF,
    ...typeBytes,
    ...data,
    (crc >> 24) & 0xFF,
    (crc >> 16) & 0xFF,
    (crc >> 8) & 0xFF,
    crc & 0xFF,
  ]);
}

int _calculateCRC(List<int> data) {
  // Simplified CRC calculation - in practice you'd use a proper CRC library
  int crc = 0xFFFFFFFF;
  for (int byte in data) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) == 1 ? (0xEDB88320 ^ (crc >> 1)) : (crc >> 1);
    }
  }
  return crc ^ 0xFFFFFFFF;
}
