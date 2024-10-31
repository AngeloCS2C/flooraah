import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart'; // For rootBundle
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'result_screen.dart'; // Ensure correct import

List<CameraDescription> cameras = [];
var logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const FloraFoliumApp());
}

class FloraFoliumApp extends StatelessWidget {
  const FloraFoliumApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CameraScreen(),
    );
  }
}

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  CameraScreenState createState() => CameraScreenState();
}

class CameraScreenState extends State<CameraScreen> {
  CameraController? controller;
  XFile? imageFile;
  final ImagePicker _picker = ImagePicker();

  Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    controller = CameraController(cameras[0], ResolutionPreset.high);
    controller?.initialize().then((_) {
      if (!mounted) return;
      setState(() {});
    });

    // Load the model
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      logger.i("Loading model...");
      _interpreter = await Interpreter.fromAsset('assets/flora.tflite');
      _labels = await _loadLabels('assets/labels.txt');
      logger.i("Model and labels loaded successfully.");
    } catch (e) {
      logger.e("Failed to load model or labels: $e");
    }
  }

  Future<List<String>> _loadLabels(String filePath) async {
    try {
      final labelsData = await rootBundle.loadString(filePath);
      return labelsData.split('\n').where((label) => label.isNotEmpty).toList();
    } catch (e) {
      logger.e("Error loading labels: $e");
      return [];
    }
  }

  Future<void> captureImage() async {
    if (!controller!.value.isInitialized) {
      logger.e("Camera not initialized.");
      return;
    }
    if (controller!.value.isTakingPicture) {
      logger.w("Camera is currently taking a picture.");
      return;
    }

    try {
      XFile picture = await controller!.takePicture();
      setState(() {
        imageFile = picture;
      });

      if (mounted) {
        _navigateToResult(picture);
      }
    } catch (e) {
      logger.e("Error capturing image: $e");
    }
  }

  Future<void> pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          imageFile = pickedFile;
        });

        if (mounted) {
          _navigateToResult(pickedFile);
        }
      }
    } catch (e) {
      logger.e("Error picking image: $e");
    }
  }

  Future<void> _navigateToResult(XFile image) async {
    try {
      var result = await classifyImage(image.path);

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultScreen(
              plantName: result,
              imagePath: image.path,
              confidence: 95.0, // Dummy confidence, adjust as necessary
            ),
          ),
        );
      }
    } catch (e) {
      logger.e("Error classifying image: $e");
    }
  }

  Future<String> classifyImage(String imagePath) async {
    try {
      Uint8List imageBytes = await File(imagePath).readAsBytes();
      logger.i("Image loaded");

      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        logger.e("Image decoding failed.");
        return "Error decoding image.";
      }

      img.Image resizedImage = img.copyResize(image, width: 256, height: 256);
      logger.i("Image resized");

      var input = List.generate(1 * 256 * 256 * 3, (i) => 0.0);
      int pixelIndex = 0;

      for (int y = 0; y < 256; y++) {
        for (int x = 0; x < 256; x++) {
          var pixel = resizedImage.getPixel(x, y);
          input[pixelIndex++] = img.getRed(pixel) / 255.0;
          input[pixelIndex++] = img.getGreen(pixel) / 255.0;
          input[pixelIndex++] = img.getBlue(pixel) / 255.0;
        }
      }

      var reshapedInput = _reshape(input, 1, 256, 256, 3);
      logger.i("Image preprocessing completed");

      if (_interpreter == null) {
        logger.e("Interpreter is not initialized.");
        return "Model not loaded.";
      }

      var output = List.generate(1, (_) => List.filled(_labels.length, 0.0));
      logger.i("Running inference");

      _interpreter!.run(reshapedInput, output);
      logger.i("Inference completed");

      var probabilities = output[0];
      final maxProbabilityIndex = probabilities.indexWhere((element) =>
          element == probabilities.reduce((a, b) => a > b ? a : b));

      if (maxProbabilityIndex >= 0 && maxProbabilityIndex < _labels.length) {
        return _labels[maxProbabilityIndex];
      } else {
        logger.e("Output index out of bounds for labels.");
        return "Classification failed.";
      }
    } catch (e) {
      logger.e("Error classifying image: $e");
      return "Error occurred during classification.";
    }
  }

  List<List<List<List<double>>>> _reshape(
      List<double> input, int batch, int height, int width, int channels) {
    return List.generate(batch, (b) {
      return List.generate(height, (h) {
        return List.generate(width, (w) {
          return List.generate(channels, (c) {
            return input[(b * height * width * channels) +
                (h * width * channels) +
                (w * channels) +
                c];
          });
        });
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'FloraFolium',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  child: Stack(
                    children: [
                      if (controller!.value.isInitialized)
                        CameraPreview(controller!)
                      else
                        const Center(child: CircularProgressIndicator()),
                      if (imageFile != null)
                        Positioned.fill(
                          child: Image.file(
                            File(imageFile!.path),
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: Image.asset('assets/upload.png'),
                      iconSize: 64,
                      onPressed: () => pickImage(),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: Image.asset('assets/startcamera.png'),
                      iconSize: 64,
                      onPressed: () => captureImage(),
                    ),
                  ),
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 4),
                        ),
                      ],
                      color: Colors.white,
                    ),
                    child: IconButton(
                      icon: Image.asset('assets/tips.png'),
                      iconSize: 64,
                      onPressed: () {},
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
