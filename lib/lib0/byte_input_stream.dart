import 'dart:typed_data';

class ByteArrayInputStream {
  late Uint8List buf;
  late int pos;
  late int _mark;
  late int count;

  ByteArrayInputStream(this.buf) {
    pos = 0;
    count = buf.length;
  }

  ByteArrayInputStream.fromBuffer(this.buf, int offset, int length) {
    pos = offset;
    count = offset + length < buf.length ? offset + length : buf.length;
    _mark = offset;
  }

  int read() {
    return (pos < count) ? buf[pos++] & 0xff : -1;
  }

  int readBytes(Uint8List b, int off, int len) {
    if (pos >= count) {
      return -1;
    }

    int avail = count - pos;
    if (len > avail) {
      len = avail;
    }
    if (len <= 0) {
      return 0;
    }
    b.setRange(off, off + len, buf.sublist(pos, pos + len));
    pos += len;
    return len;
  }

  Uint8List readAllBytes() {
    Uint8List result = buf.sublist(pos, count);
    pos = count;
    return result;
  }

  int readNBytes(Uint8List b, int off, int len) {
    int n = readBytes(b, off, len);
    return n == -1 ? 0 : n;
  }

  int skip(int n) {
    int k = count - pos;
    if (n < k) {
      k = n < 0 ? 0 : n;
    }

    pos += k;
    return k;
  }

  int available() {
    return count - pos;
  }

  bool isClosed() {
    return false;
  }

  bool markSupported() {
    return true;
  }

  void mark(int readAheadLimit) {
    _mark = pos;
  }

  void reset() {
    pos = _mark;
  }

  void close() {}
}
