import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class SearchInput extends StatefulWidget {
  const SearchInput({super.key});

  @override
  _SearchInputState createState() => _SearchInputState();
}

class _SearchInputState extends State<SearchInput> {
  final TextEditingController _controller = TextEditingController();
  final List<String> _results = [];
  bool _isLoading = false;
  bool _escuchando = false;
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _results.add("\ud83d\udc64: $query");
      _controller.clear(); // Limpiar el campo de texto
    });

    try {
      final uri = Uri.parse("http://127.0.0.1:8000/buscar/");
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: utf8.encode(jsonEncode({"query": query})),
      );

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        String botResponse = data['respuesta'];

        setState(() {
          _results.add("\ud83e\udd16: $botResponse");
          _isLoading = false;
        });
        _speak(botResponse);
      } else {
        setState(() {
          _results.add("❌ Error al obtener respuesta (${response.statusCode})");
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _results.add("❌ Error de conexión: $e");
        _isLoading = false;
      });
    }
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _escuchando = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() {
      _escuchando = false;
    });
    _search(_controller.text);
  }

  Future<void> _speak(String text) async {
    try {
      await _tts.setLanguage("es-ES");
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    // ignore: empty_catches
    } catch (e) {}
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
              bool isUser = _results[index].startsWith("\ud83d\udc64");
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
                onPressed: _escuchando ? _stopListening : _startListening,
                icon: Icon(
                  Icons.mic,
                  color: _escuchando ? Colors.red : Colors.blue,
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
