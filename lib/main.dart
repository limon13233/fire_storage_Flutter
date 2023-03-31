import 'dart:typed_data';
import 'dart:ui';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';

final storage =
    FirebaseStorage.instanceFor(bucket: 'gs://fir-auth-3a1b6.appspot.com');
final cloud = FirebaseFirestore.instance.collection('images');

List<imageDetails> imgUrl = <imageDetails>[];

class imageDetails {
  String? downloadPath;
  String? name;
  int? size;

  imageDetails(this.downloadPath, this.name, this.size);
}

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  storage.ref('images').listAll().then((snap) {
    for (var item in snap.items) {
      var tempDetails = imageDetails("", "", -1);
      item.getMetadata().then((img) {
        tempDetails.name = img.name;
        tempDetails.size = img.size;
      });
      item.getDownloadURL().then((img) {
        tempDetails.downloadPath = img;
      });

      imgUrl.add(tempDetails);
    }
  });

  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'images',
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final Stream<QuerySnapshot> _images = cloud.snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<QuerySnapshot>(
        stream: _images,
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasData) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width,
                  maxHeight: MediaQuery.of(context).size.height),
              child: GridView.count(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 5),
                  children: List.generate(snapshot.data!.docs.length, (i) {
                    Map<String, dynamic> data =
                        snapshot.data!.docs[i].data()! as Map<String, dynamic>;

                    return Material(
                        borderRadius: BorderRadius.circular(15),
                        child: Column(
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                  textStyle:
                                      Theme.of(context).textTheme.labelLarge),
                              child: const Text("Удалить"),
                              onPressed: () {
                                storage
                                    .ref("images/" +
                                        (snapshot.data!.docs[i].id).toString() +
                                        (data['date']).toString() +
                                        data['name'])
                                    .delete()
                                    .then((value) {
                                  cloud
                                      .doc(snapshot.data!.docs[i].id)
                                      .delete()
                                      .then((value) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text("Успешно удалено")));
                                  }).catchError((error) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(
                                                "Произошла ошибка при удалении: $error")));
                                  });
                                }).catchError((error) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text(
                                              "Произошла ошибка при удалении: $error")));
                                });
                              },
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  textStyle:
                                      Theme.of(context).textTheme.labelLarge),
                              child: const Text("Скачать"),
                              onPressed: () {
                                launchUrl(Uri.parse(data['downloadURL']));
                                Navigator.of(context).pop();
                              },
                            ),
                            Text(data['name']),
                            Text(
                                "Размер: ${(data['size'] / 1024).toStringAsFixed(5)} Kбайт"),
                            Image.network(
                              data['downloadURL'],
                              fit: BoxFit.cover,
                            ),
                          ],
                        ));
                  })),
            );
          }

          if (snapshot.hasError)
            return Center(child: Text('Произошла ошибка \n${snapshot.error}'));

          if (!snapshot.hasData)
            return const Center(child: Text("Картинок еще нет"));

          return const Center(child: Text("Картинок еще нет"));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: ['jpg', 'png', 'jpeg', 'gif']);

            if (result != null) {
              int timestamp = DateTime.now().millisecondsSinceEpoch;

              cloud.add({
                'name': result.files.first.name,
                'size': result.files.first.size,
                'downloadURL': "",
                'date': timestamp
              }).then((firestoreValue) async {
                await storage
                    .ref(
                        'images/${firestoreValue.id + timestamp.toString() + result.files.first.name}')
                    .putData(result.files.first.bytes!)
                    .then((value) {
                  storage
                      .ref(
                          'images/${firestoreValue.id + timestamp.toString() + result.files.first.name}')
                      .getDownloadURL()
                      .then((url) {
                    cloud.doc(firestoreValue.id).set({
                      'name': result.files.first.name,
                      'size': result.files.first.size,
                      'downloadURL': url,
                      'date': timestamp
                    }).then((suc) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Успешно добавлено")));
                    }).catchError((e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text("Произошла ошибка: $e")));
                    });
                  }).catchError((e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Произошла ошибка: $e")));
                  });
                }).catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Произошла ошибка: $e")));
                });
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Произошла ошибка")));
            }
          } catch (e) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text("Произошла ошибка: $e")));
          }
        },
        tooltip: 'Add image',
        child: const Icon(Icons.add),
      ),
    );
  }
}
