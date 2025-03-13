import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchInput extends StatefulWidget {
  const SearchInput({super.key});

  @override
  _SearchInputState createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  final TextEditingController _controller = TextEditingController();
  List<String> _results = [];
  bool _isLoading = false;

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true; // Muestra el indicador de carga
      _results.clear(); // Borra resultados anteriores
    });

    const apiKey =
        "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";
    final url = Uri.parse(
        'https://openrouter.ai/api/v1/chat/completions'); // Reemplaza con la URL real de DeepSeek
    final response = await http.post(
      url,
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
        "HTTP-Referer": "<YOUR_SITE_URL>",
        "X-Title": "<YOUR_SITE_NAME>"
      },
      body: jsonEncode({
        "model": "deepseek/deepseek-r1-zero:free",
        "messages": [
          {"role": "user", "content": query}
        ]
      }),
    );

    if (response.statusCode == 200) {
      final body = utf8.decode(response.bodyBytes); // Decodifica en UTF-8
      final data = json.decode(body); // convertir a JSON
      setState(() {
        _results = [data['choices'][0]['message']['content']];
        _isLoading = false;
      });
    } else {
      setState(() {
        _results = ['Error al obtener resultados'];
        _isLoading = false;
      });
    }
  }

  @override
Widget build(BuildContext context) {
  return Column(
    children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(10),
          itemCount: _results.length,
          itemBuilder: (context, index) {
            bool isUser = index % 2 == 0; // Alternar entre usuario y bot
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 5),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isUser ? Colors.blue[200] : Colors.grey[300],
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: isUser ? const Radius.circular(12) : Radius.zero,
                    bottomRight: isUser ? Radius.zero : const Radius.circular(12),
                  ),
                ),
                child: Text(
                  _results[index],
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            );
          },
        ),
      ),
      if (_isLoading)
        const Padding(
          padding: EdgeInsets.all(10),
          child: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 10),
              Text("Buscando...", style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Escribe un mensaje...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              icon: const Icon(Icons.send, color: Colors.blue),
              onPressed: () => _search(_controller.text),
            ),
          ],
        ),
      ),
    ],
  );
}

}
