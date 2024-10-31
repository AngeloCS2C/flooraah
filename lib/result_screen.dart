import 'dart:io';
import 'package:flutter/material.dart';
import 'plant_info.dart'; // Import PlantInfoData class

class ResultScreen extends StatefulWidget {
  final String plantName;
  final String imagePath;
  final double confidence;

  const ResultScreen({
    super.key,
    required this.plantName,
    required this.imagePath,
    required this.confidence,
  });

  @override
  ResultScreenState createState() => ResultScreenState();
}

class ResultScreenState extends State<ResultScreen> {
  String currentLanguage = 'en'; // Track current language

  // Toggle language between English and Tagalog
  void toggleLanguage() {
    setState(() {
      currentLanguage = currentLanguage == 'en' ? 'tl' : 'en';
    });
  }

  @override
  Widget build(BuildContext context) {
    final plantInfo = PlantInfoData.plantInfoMap[widget.plantName] ??
        {
          'plantType': 'Unknown',
          'scientificName': {'en': 'N/A', 'tl': 'N/A'},
          'description': {
            'en': 'No information is available for this plant.',
            'tl': 'Walang impormasyon tungkol sa halamang ito.'
          },
          'recommendation': {
            'en': 'No recommendations available.',
            'tl': 'Walang rekomendasyon na magagamit.'
          }
        };

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Result',
          style: TextStyle(color: Colors.black),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Image placeholder or actual image from classification
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(widget.imagePath),
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 10),

            // Display plant name and confidence level
            Text(
              '${widget.plantName}  ${widget.confidence.toStringAsFixed(2)}%',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 5),

            // Characteristics Section
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10.0),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Scrollbar(
                  thickness: 5,
                  radius: const Radius.circular(10),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Characteristics',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Plant type:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              plantInfo['plantType'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Scientific Name:',
                              style: TextStyle(fontSize: 16),
                            ),
                            Text(
                              plantInfo['scientificName'][currentLanguage] ??
                                  'N/A',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Description:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          plantInfo['description'][currentLanguage] ??
                              'No description available.',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 15),

            // Recommendation Button at the bottom
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _showRecommendationsModal(context, plantInfo);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Recommendation',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Function to show recommendations in a modal
  void _showRecommendationsModal(
      BuildContext context, Map<String, dynamic> plantInfo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Recommendation"),
          content: Text(plantInfo["recommendation"][currentLanguage] ??
              "No recommendations available."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }
}
