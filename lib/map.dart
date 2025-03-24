import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:html' as html; // Web-specific import for file handling
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:image_picker_web/image_picker_web.dart'; // Web-specific image picker
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _initialCameraPosition = CameraPosition(
    target: LatLng(54.86667, 69.15),
    zoom: 11.5,
  );
  bool _mapInteractionEnabled = true;
  late GoogleMapController _googleMapController;
  LatLng? _selectedLocation;
  Marker? _selectedMarker;
  final DatabaseReference _databaseRef = FirebaseDatabase.instance.ref('locations');
  html.File? _imageFile;
  Uint8List? fileBytes;
  Map<MarkerId, Marker> _markers = {};
  Map<CircleId, Circle> _circles = {}; // Store circles for pollution areas
  double _minPollutionLevel = 0;
  double _maxPollutionLevel = 5;
  double _minAQI = 0;
  double _maxAQI = 5;
  List<List<String>> setsOfCategories = [
    ['littering', 'e-waste', 'plastic'],
    ['agro', 'water pollution']
  ];
  Set<String> _selectedCategories = {};  // Набор выбранных категорий
  User? currentUser; // Current authenticated user
  final FirebaseAuth _auth = FirebaseAuth.instance;
  @override
  void initState() {
    super.initState();
    _loadSavedLocations();
    _getCurrentUser();
  }

  void _getCurrentUser() {
    // Get the current user
    setState(() {
      currentUser = _auth.currentUser;
    });
  }
  Widget _buildCategoryChips() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: setsOfCategories.map((set) => Wrap(
        spacing: 8.0, // Горизонтальное расстояние между чипами
        runSpacing: 16.0, // Вертикальное расстояние между строками чипов
        children: set.map((category) => FilterChip(
          label: Text(category),
          selected: _selectedCategories.contains(category),
          onSelected: (bool selected) {
            setState(() {
              if (selected) {
                _selectedCategories.add(category);
              } else {
                _selectedCategories.remove(category);
              }
              _loadSavedLocations();  // Обновляем маркеры при изменении фильтра
            });
          },
        )).toList(),
      )).toList(),
    );
  }
  Widget _buildResetButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: ElevatedButton(
        onPressed: () {
          setState(() {
            _selectedCategories.clear();  // Сбрасываем выбранные категории
            _loadSavedLocations();  // Обновляем маркеры
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Сбросить фильтры',
              style: TextStyle(
                fontWeight: FontWeight.w100,
                fontFamily: 'Futura',
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFilterControls() {
    return Column(
      children: [
        const Text('Фильтр по уровню загрязнения'),
        RangeSlider(
          values: RangeValues(_minPollutionLevel, _maxPollutionLevel),
          min: 0,
          max: 5,
          divisions: 5,
          labels: RangeLabels('$_minPollutionLevel', '$_maxPollutionLevel'),
          onChangeStart: (value) {
            setState(() {
              _mapInteractionEnabled = false;  // Отключаем взаимодействие с картой
            });
          },
          onChanged: (values) {
            setState(() {
              _minPollutionLevel = values.start;
              _maxPollutionLevel = values.end;
            });
            _loadSavedLocations();
          },
          onChangeEnd: (value) {
            setState(() {
              _mapInteractionEnabled = true;  // Включаем взаимодействие с картой
            });
          },
        ),
        const Text('Фильтр по индексу качества воздуха'),
        RangeSlider(
          values: RangeValues(_minAQI, _maxAQI),
          min: 0,
          max: 5,
          divisions: 5,
          labels: RangeLabels('$_minAQI', '$_maxAQI'),
          onChangeStart: (value) {
            setState(() {
              _mapInteractionEnabled = false;  // Отключаем взаимодействие с картой
            });
          },
          onChanged: (values) {
            setState(() {
              _minAQI = values.start;
              _maxAQI = values.end;
            });
            _loadSavedLocations();
          },
          onChangeEnd: (value) {
            setState(() {
              _mapInteractionEnabled = true;  // Включаем взаимодействие с картой
            });
          },
        ),
        _buildCategoryChips(),  // Фильтр с чипами
        SizedBox(height: 20),
        _buildResetButton(), // Добавляем фильтр по категориям
      ],
    );
  }
  Future<int?> fetchAirQualityIndex(LatLng location) async {
    final apiKey = 'c6816ce934ee3584017e345e90393ac6';
    final lat = location.latitude;
    final lon = location.longitude;
    final url = Uri.parse('https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$apiKey');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aqi = data['list'][0]['main']['aqi'] as int?; // Extract AQI from the response
        print("$lat $lon $aqi");
        return aqi;
      } else {
        print('Failed to load air quality data: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error fetching air quality data: $e');
      return null;
    }
  }
  @override
  void dispose() {
    _googleMapController.dispose();
    super.dispose();
  }
  void _loadSavedLocations() {
    _databaseRef.onValue.listen((DatabaseEvent event) {
      final data = event.snapshot.value as Map<dynamic, dynamic>?;
      if (data != null) {
        setState(() {
          _markers.clear();
          _circles.clear();
          data.forEach((key, value) {
            final latitude = value['latitude'] as double;
            final longitude = value['longitude'] as double;
            final imageUrl = value['photo'] as String?;
            final pollutionRating = value['pollutionRating'] as int?;
            final aqi = value['aqi'] as int?;
            final tip = value['tip'] as String?;
            final category = value['category'] as String?;
            if ((pollutionRating == null || pollutionRating <= _maxPollutionLevel) &&
                (aqi == null || aqi >= _minAQI && aqi <= _maxAQI) &&
                (_selectedCategories.isEmpty || _selectedCategories.contains(category))) {
              final markerId = MarkerId(key);
              final marker = Marker(
                markerId: markerId,
                position: LatLng(latitude, longitude),
                infoWindow: InfoWindow(
                  title: 'Сохраненное место',
                  snippet: 'Индекс качества воздуха: $aqi',
                  onTap: () {
                    _showImageBottomSheet(key, imageUrl, tip!, category!); // Открыть информацию по клику
                  },
                ),
                onTap: () => _showImageBottomSheet(key, imageUrl, tip!, category!),
              );
              _markers[markerId] = marker;
              if (pollutionRating != null) {
                final circleId = CircleId(key);

                // Create a color gradient from yellow to red (pollutionRating 1 = yellow, pollutionRating 5 = red)
                Color circleColor;
                if (pollutionRating == 1) {
                  circleColor = Colors.green;
                } else if (pollutionRating == 2) {
                  circleColor = Colors.yellow; // Between yellow and orange
                } else if (pollutionRating == 3) {
                  circleColor = Colors.orange; // Orange for pollutionRating 3
                } else if (pollutionRating == 4) {
                  circleColor = Color.lerp(Colors.orange, Colors.red, 0.5)!; // Between orange and red
                } else {
                  circleColor = Colors.red; // Pollution rating 5 = red
                }

                final circleRadius = 300.0; // Example radius, adjust as needed

                final circle = Circle(
                  circleId: circleId,
                  center: LatLng(latitude, longitude),
                  radius: circleRadius, // Radius in meters
                  strokeColor: circleColor.withOpacity(0.8),
                  fillColor: circleColor.withOpacity(0.3),
                  strokeWidth: 2,
                );
                _circles[circleId] = circle;
              }

            }
          });
        });
      }
    });
  }
  void _onMapTapped(LatLng position) {
    setState(() {
      _selectedLocation = position;
      final markerId = MarkerId('selected_location');
      _selectedMarker = Marker(
        markerId: markerId,
        position: position,
        infoWindow: const InfoWindow(
          title: 'Выбранное место',
          snippet: 'Это место, которое вы выбрали',
        ),
      );

      // Add or update the marker in the map
      _markers[markerId] = _selectedMarker!;
    });
  }


  void _showBottomSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 150,
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Выбрать из галереи'),
              onTap: () => _selectImageFromGallery(),
            ),
            ListTile(
              leading: const Icon(Icons.save),
              title: const Text('Сохранить место без фотографии'),
              onTap: () {
                Navigator.pop(context);
                _saveLocationToDatabase(true);
              },
            ),
          ],
        ),
      ),
    );
  }
  void _showCommentsDialog(String locationKey) {
    final TextEditingController _commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Комментарии'),
          content: FutureBuilder(
            future: _loadComments(locationKey),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) {
                return const Text('Нет комментариев.');
              }

              final comments = snapshot.data as List<Map<String, dynamic>>;

              return SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: comments.length,
                        itemBuilder: (context, index) {
                          final comment = comments[index];
                          return ListTile(
                            title: Text(comment['userName']),
                            subtitle: Text(comment['text']),
                          );
                        },
                      ),
                    ),
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Напишите комментарий',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                final text = _commentController.text;
                if (text.isNotEmpty && currentUser != null) {
                  _saveComment(locationKey, text);
                  _commentController.clear();
                }
              },
              child: const Text('Отправить'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  Future<String> getImageUrl(String imageRef) async {
    try {
      // Get the download URL from Firebase Storage
      final ref = FirebaseStorage.instance.ref().child(imageRef);
      final url = await ref.getDownloadURL();
      return url;
    } catch (e) {
      throw Exception('Error retrieving image: $e');
    }
  }
  Future<void> _selectImageFromGallery() async {
    final pickedFile = await ImagePickerWeb.getImageAsFile(); // Web-specific method
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
      Navigator.pop(context);
      _saveLocationToDatabase(false);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected!')),
      );
    }
  }
  Future<Uint8List> _readFileAsBytes(html.File file) async {
    final reader = html.FileReader();
    final completer = Completer<Uint8List>();

    reader.onLoadEnd.listen((e) {
      completer.complete(reader.result as Uint8List);
    });

    reader.readAsArrayBuffer(file);
    return completer.future;
  }
  Future<Map<String, dynamic>> _getPollutionEvaluation(html.File imageFile) async {
    try {
      final bytes = await _readFileAsBytes(imageFile);
      final base64Image = base64Encode(bytes);
      final prompt =
          "write only json category:(littering, e-waste, plastic, agro, water pollution) rate:(1-clean, 2-can be solved in 10 min, 3-need 1 hour, 4 - 10, 5-more than day) tip:(one paragraph 2-3 sentence)";
      print(imageFile.name);
      final request = http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer sk-2ruHUfuexrGGvI3JkS6GBXpPQacBoG7CjgINSwuUZVT3BlbkFJBl8zXKJcR-TTVQg72cf3UNDg_E_YwZLgqefgJfr1UA',
        },
        body: jsonEncode({
          "model": "gpt-4o",
          "messages": [
            {
              "role": "user",
              "content": [
                {
                  "type": "text",
                  "text": prompt
                },
                {
                  "type": "image_url",
                  "image_url": {
                    "url": "data:image/jpeg;base64,${base64Image}"
                  }
                }
              ]
            }
          ],
        }),
      );
      final response = await request;
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        var messageContent = responseData['choices'][0]['message']['content'];

        // Clean and parse the content as JSON
        messageContent = messageContent.replaceAll('```json', '').replaceAll('```', '').trim();
        final pollutionData = jsonDecode(messageContent);
        print('Pollution Data: $pollutionData');
        return pollutionData; // Return the pollution data (rate, category, tip)
      } else {
        print('Failed to get response: ${response.statusCode}');
        return {};
      }
    } catch (e) {
      print('Error in making API call: $e');
      return {};
    }
  }
  String location = "";
  String? imageUrl;
  Future<void> _saveLocationToDatabase(bool nothing) async {
    if (_selectedLocation != null) {
      Map<String, dynamic>? pollutionData;
      int? aqi = await fetchAirQualityIndex(_selectedLocation!); // Fetch AQI for location

      if (_imageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('images/${DateTime.now().millisecondsSinceEpoch}.png');
        fileBytes = await _readFileAsBytes(_imageFile!);
        final uploadTask = storageRef.putData(fileBytes!);
        final snapshot = await uploadTask.whenComplete(() {});
        imageUrl = await snapshot.ref.getDownloadURL();
        pollutionData = await _getPollutionEvaluation(_imageFile!);
      }

      // Создаем уникальный ключ на основе широты и долготы
      final locationKey = _encodeLocationKey(
        _selectedLocation!.latitude,
        _selectedLocation!.longitude,
      );

      final locationData = {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
        'photo': nothing? "unknown": imageUrl,
        'pollutionRating': nothing? -1: pollutionData?['rate'] ?? -1,
        'category': nothing? "Unknown": pollutionData?['category'] ?? 'unknown',
        'tip': nothing? "No image": pollutionData?['tip'] ?? 'No tip provided',
        'aqi': aqi, // Save AQI value
      };

      // Используем locationKey в качестве ключа для новых данных
      await _databaseRef.child(locationKey).set(locationData);

      setState(() {
        _selectedLocation = null;
        _imageFile = null;
      });
    }
  }

  String _encodeLocationKey(double latitude, double longitude) {
    return '${latitude.toString().replaceAll('.', '-')}_${longitude.toString().replaceAll('.', '-')}';
  }


  Future<List<Map<String, dynamic>>> _loadComments(String locationKey) async {
    final snapshot = await _databaseRef.child('$locationKey/comments').get();
    if (snapshot.exists) {
      final comments = snapshot.value as Map<dynamic, dynamic>;
      return comments.values.map((comment) => Map<String, dynamic>.from(comment)).toList();
    }
    return [];
  }
  void _showImageBottomSheet(String location, String? imageUrl, String tip, String category) {
    if (imageUrl != null) {
      // Declare the OverlayEntry variable
      late OverlayEntry overlayEntry;

      // Initialize the OverlayEntry after it's declared
      overlayEntry = OverlayEntry(
        builder: (context) => Positioned(
          right: 10,
          bottom: 10,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 300,
              width: 500,
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Remove the overlay and show comments dialog
                      overlayEntry.remove();
                      _showCommentsDialog(location);
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: imageUrl != "unknown"?Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        height: 150,
                        width: 150,
                      ):Container(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Tip: $tip',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Category: $category',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          TextButton(
                              onPressed: () {
                                location = _encodeLocationKey(
                                  _selectedLocation!.latitude,
                                  _selectedLocation!.longitude,
                                );
                                _selectImageFromGallery();
                              },
                              child: Text("save new")
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Insert the overlay into the widget tree
      Overlay.of(context)?.insert(overlayEntry);

      // Remove the overlay after 5 seconds unless already removed
      Future.delayed(Duration(seconds: 5)).then((value) {
        if (overlayEntry.mounted) {
          overlayEntry.remove();
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image available for this location.')),
      );
    }
  }


  Future<void> _saveComment(String locationKey, String text) async {
    if (currentUser != null) {
      final userName = (await FirebaseDatabase.instance.ref('users/${currentUser!.uid}/name').get()).value as String?;
      final commentData = {
        'userId': currentUser!.uid,
        'userName': userName ?? 'Anonymous',
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _databaseRef.child('$locationKey/comments').push().set(commentData);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xffee0003),
        title: const Text('Map Screen'),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.black
            ),
            onPressed: (){},
            child: Text("Map view"),
          ),
          SizedBox(width: 10,),
          TextButton(
            style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.black
            ),
            onPressed: () {
              if (_selectedLocation != null) {
                _showBottomSheet(); // Add a marker with an image
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a location on the map.')),
                );
              }
            }, child: Text("Add mark"),
          ),
          SizedBox(width: 10,),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color(0xffee0003),
              ),
              child: Text(
                'Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                ),
              ),
            ),
            _buildFilterControls(),
          ],
        ),
      ),
      body: GoogleMap(
        gestureRecognizers: _mapInteractionEnabled
            ? <Factory<OneSequenceGestureRecognizer>>{
          Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()), // Enable gestures
        }
            : <Factory<OneSequenceGestureRecognizer>>{}, // Disable all gestures
        initialCameraPosition: _initialCameraPosition,
        myLocationEnabled: true,
        zoomControlsEnabled: false,
        onMapCreated: (controller) => _googleMapController = controller,
        markers: _markers.values.toSet(),
        circles: _circles.values.toSet(),  // <-- Add this line to display circles
        onTap: _onMapTapped,
        scrollGesturesEnabled: _mapInteractionEnabled, // Disable scroll gestures
        zoomGesturesEnabled: _mapInteractionEnabled,   // Disable zoom gestures
        rotateGesturesEnabled: _mapInteractionEnabled, // Disable rotation gestures
        tiltGesturesEnabled: _mapInteractionEnabled,
      ),
    );
  }
}
class FiltersWidget extends StatefulWidget {
  @override
  _FiltersWidgetState createState() => _FiltersWidgetState();
}

class _FiltersWidgetState extends State<FiltersWidget> {
  bool filterPlastic = false;
  bool filterGlass = false;
  bool filterMetal = false;
  bool filterPaper = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 4,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Filters', style: TextStyle(fontWeight: FontWeight.bold)),
          CheckboxListTile(
            title: Text('Plastic'),
            value: filterPlastic,
            onChanged: (value) {
              setState(() {
                filterPlastic = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Glass'),
            value: filterGlass,
            onChanged: (value) {
              setState(() {
                filterGlass = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Metal'),
            value: filterMetal,
            onChanged: (value) {
              setState(() {
                filterMetal = value!;
              });
            },
          ),
          CheckboxListTile(
            title: Text('Paper'),
            value: filterPaper,
            onChanged: (value) {
              setState(() {
                filterPaper = value!;
              });
            },
          ),
        ],
      ),
    );
  }
}