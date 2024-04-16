import 'dart:io';

import 'package:ydart/lib0/byte_input_stream.dart';
import 'package:ydart/lib0/byte_output_stream.dart';
import 'package:ydart/utils/encoding_utils.dart';
import 'package:ydart/utils/update_decoder_v2.dart';
import 'package:ydart/utils/update_encoder_v2.dart';

void main() {
  var docBytes = File('demo/newData.data').readAsBytesSync();
  var decoder = UpdateDecoderV2(ByteArrayInputStream(docBytes));
  var output = ByteArrayOutputStream();
  var encoder = UpdateEncoderV2(output);
  EncodingUtils.encrypt(decoder, encoder);
  var decode = encoder.toArray();
  assert(decode.length == docBytes.length);
  for (var i = 0; i < decode.length; i++) {
    assert(decode[i] == docBytes[i]);
  }
}
