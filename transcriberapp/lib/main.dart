import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

void main() {
  runApp(const MyApp());
}

// To manage the app's state
enum AppState {
  initial, // Initial state
  fileShared, // File received
  uploading, // File is uploading
  transcribing, // Transcribing
  success, // Success
  error // Error occurred
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // A clean UI, easy to read for older people
    final textTheme = Theme.of(context).textTheme.apply(
          bodyColor: Colors.blueGrey[900],
          displayColor: Colors.blueGrey[900],
          fontFamily: 'Roboto', // A clear font
        );

    return MaterialApp(
      title: 'Audio Transcriber', // Changed
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: Colors.blueGrey.shade800,
          secondary: Colors.teal.shade600,
          background: Colors.grey.shade50,
        ),
        textTheme: textTheme.copyWith(
          titleLarge: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          titleMedium: textTheme.titleMedium?.copyWith(
            fontSize: 18,
            color: Colors.blueGrey.shade700,
          ),
          bodyLarge: textTheme.bodyLarge?.copyWith(
            fontSize: 17,
            height: 1.5,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blueGrey.shade800,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            textStyle:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
          ),
        ),
      ),
      home: const AudioTranscriberPage(),
    );
  }
}

class AudioTranscriberPage extends StatefulWidget {
  const AudioTranscriberPage({Key? key}) : super(key: key);

  @override
  State<AudioTranscriberPage> createState() => _AudioTranscriberPageState();
}

class _AudioTranscriberPageState extends State<AudioTranscriberPage> {
  // --- State Variables ---

  // FIXME: Add your Gemini API key here
  final String _geminiApiKey = "********************";

  AppState _appState = AppState.initial;
  String? _sharedFilePath;
  String? _sharedFileMimeType; // <-- ADD THIS to store the correct mimeType
  String? _transcribedText;
  String? _errorMessage;
  String _statusMessage = "";

  // --- Lifecycle Methods ---

  @override
  void initState() {
    super.initState();
    _initSharingListener();
  }

  void _initSharingListener() {
    // When file is shared while app is open
    ReceiveSharingIntent.instance
        .getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleNewFile(value.first.path, value.first.mimeType); // <-- PASS mimeType
      }
    });

    // When file is shared while app is closed
    ReceiveSharingIntent.instance
        .getInitialMedia()
        .then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _handleNewFile(value.first.path, value.first.mimeType); // <-- PASS mimeType
      }
    });
  }

  void _handleNewFile(String path, String? mimeType) { // <-- UPDATE signature
    setState(() {
      _sharedFilePath = path;
      _sharedFileMimeType = mimeType; // <-- SAVE the mimeType
      _appState = AppState.fileShared;
      _transcribedText = null;
      _errorMessage = null;
      _statusMessage = "";
    });
  }

  // --- API Logic (Two-Step Process) ---

  Future<void> _startTranscriptionProcess() async {
    if (_sharedFilePath == null) return;

    if (_geminiApiKey == "YOUR_GEMINI_API_KEY_HERE") {
      setState(() {
        _errorMessage = "Please enter your Gemini API key in the code."; // Changed
        _appState = AppState.error;
      });
      return;
    }

    File audioFile = File(_sharedFilePath!);
    // String? mimeType = lookupMimeType(audioFile.path); // <-- REMOVE this line
    String? mimeType = _sharedFileMimeType; // <-- USE the stored mimeType

    if (mimeType == null || !mimeType.startsWith('audio/')) {
      setState(() {
        _errorMessage = "The shared file is not an audio file."; // Changed
        _appState = AppState.error;
      });
      return;
    }

    setState(() {
      _appState = AppState.uploading;
      _statusMessage = "Uploading file..."; // Changed
    });

    try {
      // --- API Call 1: Upload File ---
      // Upload file and get URI, mimeType
      final uploadResponse = await _uploadFile(audioFile, mimeType);

      setState(() {
        _appState = AppState.transcribing;
        _statusMessage = "Transcribing audio..."; // Changed
      });

      // --- API Call 2: Generate Content (Transcribe) ---
      // Perform transcription using the received URI
      final transcribeResponse = await _generateContent(
        uploadResponse['uri'],
        uploadResponse['mimeType'],
      );

      setState(() {
        _transcribedText = transcribeResponse;
        _appState = AppState.success;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _appState = AppState.error;
      });
    }
  }

  /// API Call 1: Uploads the file to Google's server
  Future<Map<String, dynamic>> _uploadFile(
      File file, String mimeType) async {
    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/upload/v1beta/files?key=$_geminiApiKey");

    var request = http.MultipartRequest('POST', uri);

    // Specify header
    request.headers['X-Goog-Upload-Protocol'] = 'multipart';

    // --- FIX: ADD THE METADATA PART (Part 1) ---
    // This part must come first and be application/json
    final metadata = {
      "file": {
        "mimeType": mimeType,
        // "displayName": file.path.split('/').last // You could add this here too
      }
    };

    request.files.add(http.MultipartFile.fromString(
      'metadata', // The 'name' of this part
      jsonEncode(metadata),
      contentType: MediaType.parse('application/json'),
    ));

    // --- ADD THE FILE PART (Part 2) ---
    // This part comes second and contains the file bytes
    request.files.add(await http.MultipartFile.fromPath(
      'file', // The 'name' of this part
      file.path,
      contentType: MediaType.parse(mimeType),
    ));

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseBody);
      return {
        "uri": data['file']['uri'],
        "mimeType": data['file']['mimeType'],
      };
    } else {
      throw Exception(
          "File upload failed: ${response.statusCode}\n$responseBody"); // Changed
    }
  }

  /// API Call 2: Asks to transcribe the uploaded file
  Future<String> _generateContent(String fileUri, String mimeType) async {
    final uri = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$_geminiApiKey");

    // This prompt is language-agnostic and will transcribe whatever it hears.
    final prompt =
        "Transcribe the given audio word to word exactly in the audio with correct spacing, punctuation.";

    final body = jsonEncode({
      "contents": [
        {
          "parts": [
            {
              "fileData": {"mimeType": mimeType, "fileUri": fileUri}
            },
            {
              "text": prompt
            }
          ]
        }
      ]
    });

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // Check for empty response from Gemini 2.5 Flash
      if (data['candidates'] == null || data['candidates'].isEmpty) {
        throw Exception("Transcription failed (No candidates found)."); // Changed
      }
      return data['candidates'][0]['content']['parts'][0]['text'];
    } else {
      // Show API error clearly
      final errorData = jsonDecode(response.body);
      final errorMsg = errorData['error']?['message'] ?? response.body;
      throw Exception("Transcription failed: $errorMsg"); // Changed
    }
  }

  // --- Helper Methods ---

  void _copyToClipboard() {
    if (_transcribedText != null && _transcribedText!.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _transcribedText!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Transcription copied!"), // Changed
          backgroundColor: Colors.teal,
        ),
      );
    }
  }

  void _resetApp() {
    setState(() {
      _appState = AppState.initial;
      _sharedFilePath = null;
      _sharedFileMimeType = null; // <-- ADD this to clear the mimeType
      _transcribedText = null;
      _errorMessage = null;
      _statusMessage = "";
    });
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Audio Transcriber'), // Changed
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Show UI based on current app state
                  _buildStatusUI(context)
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Provides the correct widget based on app state
  Widget _buildStatusUI(BuildContext context) {
    switch (_appState) {
      case AppState.initial:
        return _buildInitialUI(context);
      case AppState.fileShared:
        return _buildFileSharedUI(context);
      case AppState.uploading:
      case AppState.transcribing:
        return _buildLoadingUI(context);
      case AppState.success:
        return _buildSuccessUI(context);
      case AppState.error:
        return _buildErrorUI(context);
    }
  }

  /// 1. Initial UI
  Widget _buildInitialUI(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 100,
              color: Colors.blueGrey.shade200,
            ),
            const SizedBox(height: 24),
            Text(
              "Share an audio file\nto get started...", // Changed
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 2. UI after file is received
  Widget _buildFileSharedUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          elevation: 0,
          child: ListTile(
            leading: Icon(
              Icons.audio_file_rounded,
              color: Colors.teal.shade600,
              size: 40,
            ),
            title: Text(
              _sharedFilePath!.split('/').last,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text("Ready to transcribe"), // Changed
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          icon: const Icon(Icons.translate_rounded),
          label: const Text("Start Transcription"), // Changed
          onPressed: _startTranscriptionProcess,
        ),
      ],
    );
  }

  /// 3. Loading UI (Uploading & Transcribing)
  Widget _buildLoadingUI(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(),
            ),
            const SizedBox(height: 24),
            Text(
              _statusMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  /// 4. Success UI (Transcription Result)
  Widget _buildSuccessUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Transcription Result", // Changed
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.copy_all_rounded,
                        color: Colors.blueGrey.shade400,
                      ),
                      tooltip: "Copy", // Changed
                      onPressed: _copyToClipboard,
                    ),
                  ],
                ),
                const Divider(height: 24),
                SelectableText(
                  _transcribedText ?? "No text found.", // Changed
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 19.0)
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          child: const Text("Transcribe another file"), // Changed
          onPressed: _resetApp,
        ),
      ],
    );
  }

  /// 5. Error UI
  Widget _buildErrorUI(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: Colors.red.shade50,
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "An Error Occurred", // Changed
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.red.shade900,
                      ),
                ),
                const Divider(height: 20),
                SelectableText(
                  _errorMessage ?? "Unknown error.", // Changed
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.red.shade800,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        TextButton(
          child: const Text("Try Again"), // Changed
          onPressed: _resetApp,
        ),
      ],
    );
  }
}
