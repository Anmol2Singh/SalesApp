import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

void main() async {
  final env = await File('.env').readAsString();
  final lines = env.split('\n');
  String url = '';
  String key = '';
  for (final line in lines) {
    if (line.startsWith('SUPABASE_URL=')) url = line.split('=')[1].trim();
    if (line.startsWith('SUPABASE_ANON_KEY=')) key = line.split('=')[1].trim();
  }
  
  final res = await http.post(
    Uri.parse('$url/rest/v1/complaints'),
    headers: {
      'apikey': key,
      'Authorization': 'Bearer $key',
      'Prefer': 'return=representation',
      'Content-Type': 'application/json'
    },
    body: jsonEncode({"technician_id": "00000000-0000-0000-0000-000000000000", "technician_name": "Test"})
  );
  
  print('Status: ${res.statusCode}');
  print('Body: ${res.body}');
}
