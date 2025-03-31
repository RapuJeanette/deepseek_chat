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

  Future<bool> _checkCompatibility() async {
    bool isSpeechAvailable = await _speech.initialize();
    bool isTtsAvailable = await _tts.isLanguageAvailable('es-ES');
    return isSpeechAvailable && isTtsAvailable;
  }

  Future<void> _search(String query) async {
  if (query.isEmpty) return;

  setState(() {
    _isLoading = true;
    _results.add("👤: $query");
  });

  try {
    final pdfUrl = Uri.parse("http://127.0.0.1:8000/buscar/?query=$query");
    final response = await http.get(pdfUrl);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      String botResponde = data['respuesta'];

      setState(() {
        _results.add("🤖: $botResponde");
        _isLoading = false;
      });
      _speak(botResponde);
    } else {
      setState(() {
        _results.add("❌ Error al obtener respuesta");
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


String limpiarTexto(String texto) {
  texto = texto.replaceAll(RegExp(r'\\boxed\{|\}'), '');
  texto = texto.replaceAll(RegExp(r'^\s*(json|python|dart|java|c\+\+|html)\s*\{?'), '').trim();
  texto = texto.replaceAll(RegExp(r'\}$'), '').trim();

  return texto;
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
    } else {
    }
  }

  void _stopListening(){
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
    } catch (e) {
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkCompatibility(), // Verifica si el dispositivo es compatible
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (!snapshot.hasData || !snapshot.data!) {
          return const Center(
            child: Text('El dispositivo no es compatible con algunas funciones.'),
          );
        }

        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(10),
                itemCount: _results.length,
                itemBuilder: (context, index) {
                  bool isUser = _results[index].startsWith("👤");
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
      },
    );
  }
}