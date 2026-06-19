void main() {
  // Simple CRC32 implementation to test
  final table = List<int>.filled(256, 0);
  for (int i = 0; i < 256; i++) {
    int crc = i;
    for (int j = 0; j < 8; j++) {
      if (crc & 1 != 0) {
        crc = (crc >> 1) ^ 0xEDB88320;
      } else {
        crc = crc >> 1;
      }
    }
    table[i] = crc;
  }
  
  int crc32(String str) {
    int crc = 0xFFFFFFFF;
    for (final c in str.codeUnits) {
      crc = table[(crc ^ c) & 0xFF] ^ (crc >> 8);
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }
  
  print('CRC32 of 3778678 = \');
  print('CRC32 of 541148882 = \');
  
  // Now test the actual API
  final id3778678 = crc32("3778678");
  final id541148882 = crc32("541148882");
  print('playlist URL: https://music-api.gdstudio.xyz/api.php?types=playlist&id=3778678&s=\');
  print('userlist URL: https://music-api.gdstudio.xyz/api.php?types=userlist&id=541148882&s=\');
}