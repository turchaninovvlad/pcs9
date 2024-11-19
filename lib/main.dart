import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auto Parts Store',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ProductListScreen(),
    );
  }
}

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<dynamic> products = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchProducts();
  }

  Future<void> fetchProducts() async {
    final url = Uri.parse('http://10.0.2.2:8080/products'); // URL для локального сервера

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        print("Fetched data: $data");

        setState(() {
          products = data;
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
        });
        print('Request failed with status: ${response.statusCode}');
      }
    } catch (error) {
      setState(() {
        isLoading = false;
      });
      print('Error occurred: $error');
    }
  }

  Future<void> deleteProduct(int id) async {
    final url = Uri.parse('http://10.0.2.2:8080/products/delete/$id');

    try {
      final response = await http.delete(url);

      if (response.statusCode == 204) {
        setState(() {
          products.removeWhere((product) => product['ID'] == id);
        });
      } else {
        print('Failed to delete product: ${response.statusCode}');
      }
    } catch (error) {
      print('Error occurred: $error');
    }
  }

  void navigateToAddProduct() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => AddUpdateProductScreen()))
        .then((_) => fetchProducts());
  }

  void navigateToUpdateProduct(Map<String, dynamic> product) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (context) => AddUpdateProductScreen(product: product)))
        .then((_) => fetchProducts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Product List'),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : products.isEmpty
          ? Center(child: Text('No products found.'))
          : GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return Card(
            elevation: 4,
            margin: EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: product['ImageURL'] != null
                      ? FadeInImage.assetNetwork(
                    placeholder: 'assets/placeholder.png', // Заглушка изображения
                    image: product['ImageURL'],
                    fit: BoxFit.cover,
                    imageErrorBuilder: (context, error, stackTrace) {
                      return Icon(Icons.image_not_supported, size: 100);
                    },
                  )
                      : Icon(Icons.image_not_supported, size: 100),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product['Name'] ?? 'No Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 4),
                      Text(
                        product['Description'] ?? 'No Description',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 8),
                      Text(
                        '\$${product['Price'] ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit),
                      onPressed: () => navigateToUpdateProduct(product),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => deleteProduct(product['ID']),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToAddProduct,
        child: Icon(Icons.add),
      ),
    );
  }
}

class AddUpdateProductScreen extends StatefulWidget {
  final Map<String, dynamic>? product;

  AddUpdateProductScreen({this.product});

  @override
  _AddUpdateProductScreenState createState() => _AddUpdateProductScreenState();
}

class _AddUpdateProductScreenState extends State<AddUpdateProductScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _imageURLController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?['Name'] ?? '');
    _descriptionController = TextEditingController(text: widget.product?['Description'] ?? '');
    _priceController = TextEditingController(text: widget.product?['Price']?.toString() ?? '');
    _imageURLController = TextEditingController(text: widget.product?['ImageURL'] ?? '');
  }

  Future<void> submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final productData = {
        'Name': _nameController.text,
        'Description': _descriptionController.text,
        'Price': double.tryParse(_priceController.text) ?? 0,
        'ImageURL': _imageURLController.text,
      };

      final url = widget.product == null
          ? Uri.parse('http://10.0.2.2:8080/products/create')
          : Uri.parse('http://10.0.2.2:8080/products/update/${widget.product!['ID']}');

      try {
        final response = await (widget.product == null
            ? http.post(url, body: json.encode(productData), headers: {'Content-Type': 'application/json'})
            : http.put(url, body: json.encode(productData), headers: {'Content-Type': 'application/json'}));

        if (response.statusCode == 200 || response.statusCode == 201) {
          Navigator.of(context).pop();
        } else {
          print('Failed to save product: ${response.statusCode}');
        }
      } catch (error) {
        print('Error occurred: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add Product' : 'Update Product'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(labelText: 'Description'),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _priceController,
                decoration: InputDecoration(labelText: 'Price'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter a price';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _imageURLController,
                decoration: InputDecoration(labelText: 'Image URL'),
                validator: (value) {
                  if (value?.isEmpty ?? true) {
                    return 'Please enter an image URL';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: submitForm,
                child: Text(widget.product == null ? 'Add Product' : 'Update Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
