import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'global.dart' as global;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Product App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // Список экранов для навигации
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      ProductListScreen(),
      FavoritesScreen (),
      CartScreen(),
      ProfileScreen(),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: 'Избранное'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Корзина'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.blue, // Цвет выбранного элемента
        unselectedItemColor: Colors.grey, // Цвет невыбранных элементов
      ),
    );
  }
}

class ProductListScreen extends StatefulWidget {
  @override
  _ProductListScreenState createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  List<dynamic> products = [];
  List<dynamic> filteredProducts = [];
  bool isLoading = true;
  final TextEditingController searchController = TextEditingController();

  // Состояние сортировки: 0 - без сортировки, 1 - по возрастанию, 2 - по убыванию
  int sortState = 0;

  @override
  void initState() {
    super.initState();
    fetchProducts();
    searchController.addListener(() {
      filterProducts();
    });
  }

  Future<void> fetchProducts() async {
    final url = Uri.parse('http://10.0.2.2:8080/products');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          products = json.decode(response.body);
          filteredProducts = products; // Изначально все товары отображаются
          isLoading = false;
        });
      }
    } catch (error) {
      print('Ошибка загрузки продуктов: $error');
    }
  }

  void filterProducts() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredProducts = products.where((product) {
        return product['Name'].toLowerCase().contains(query);
      }).toList();
      sortProducts();  // Применяем сортировку после фильтрации
    });
  }

  void sortProducts() {
    if (sortState == 1) {
      filteredProducts.sort((a, b) => a['Price'].compareTo(b['Price'])); // Сортировка по возрастанию
    } else if (sortState == 2) {
      filteredProducts.sort((a, b) => b['Price'].compareTo(a['Price'])); // Сортировка по убыванию
    }
  }

  void toggleSort() {
    setState(() {
      sortState = (sortState + 1) % 3; // Переключаем состояния сортировки
      sortProducts();  // Применяем новую сортировку
    });
  }

  Future<void> addToFavorites(int id) async {
    final url = Uri.parse('http://10.0.2.2:8080/users/favorites/add');
    await http.post(url, body: json.encode({'product_id': id}));

    setState(() {
      global.favorites.add(id.toString());
    });
  }

  Future<void> removeFromFavorites(int id) async {
    final url = Uri.parse('http://10.0.2.2:8080/users/favorites/remove');
    await http.post(url, body: json.encode({'product_id': id}));

    setState(() {
      global.favorites.remove(id.toString());
    });
  }

  Future<void> addToCart(int productId) async {
    // Предположим, что вы храните идентификатор пользователя в глобальной переменной
    int userId = int.parse(global.userId); // Убедитесь, что userId у вас корректно настроен

    final url = Uri.parse('http://10.0.2.2:8080/users/cart/add');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,  // Здесь отправляем идентификатор пользователя
          'product_id': productId  // Отправляем идентификатор продукта
        }),
      );

      if (response.statusCode == 200) {
        // Успешно добавлено в корзину
        setState(() {
          global.inCart.add(productId.toString()); // Добавляем продукт в глобальную корзину
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Товар добавлен в корзину')),
        );
      } else {
        // Обработка ошибки
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось добавить товар в корзину')),
        );
        print('Ошибка при добавлении товара: ${response.statusCode} - ${response.body}');
      }
    } catch (error) {
      // Обработка исключений
      print('Ошибка: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при добавлении товара в корзину')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Продукты'),
        actions: [
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () {
              showSearchDialog();
            },
          ),
          IconButton(
            icon: Icon(Icons.sort), // Значок сортировки
            onPressed: toggleSort,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => AddProductScreen()), // Навигация к экрану добавления товара
          );
        },
        child: Icon(Icons.add),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          final isFavorite = global.favorites.contains(product['ID'].toString());

          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(productId: product['ID']),
                ),
              );
            },
            child: Card(
              margin: EdgeInsets.all(8.0),
              child: ListTile(
                leading: Container(
                  width: 50, // Установите фиксированную ширину
                  height: 50, // Установите фиксированную высоту для квадратного изображения
                  child: Image.network(
                    product['ImageURL'],
                    fit: BoxFit.cover, // Чтобы сохранить соотношение сторон
                  ),
                ),
                title: Text(product['Name']),
                subtitle: Text('\$${product['Price']}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : null,
                      ),
                      onPressed: () {
                        if (isFavorite) {
                          removeFromFavorites(product['ID']);
                        } else {
                          addToFavorites(product['ID']);
                        }
                      },
                    ),
                    IconButton(
                      icon: Icon(Icons.add_shopping_cart),
                      onPressed: () {
                        addToCart(product['ID']);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
  void showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Поиск товаров'),
          content: TextField(
            controller: searchController,
            decoration: InputDecoration(hintText: "Введите название товара"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }
}
class ProductDetailScreen extends StatelessWidget {
  final int productId;

  ProductDetailScreen({required this.productId});

  Future<Map<String, dynamic>> fetchProductDetails() async {
    final url = Uri.parse('http://10.0.2.2:8080/products/$productId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // Преобразуйте байтовый массив в строку, если это необходимо
      // Это может помочь, если данные действительно не в правильной кодировке
      String responseBody = utf8.decode(response.bodyBytes);
      return json.decode(responseBody);
    } else {
      throw Exception('Failed to load product');
    }
  }

  Future<void> deleteProduct() async {
    final url = Uri.parse('http://10.0.2.2:8080/products/delete/$productId');
    await http.delete(url);
    // Дополнительная обработка ответов и переход на предыдущую страницу
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Детали товара'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: fetchProductDetails(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('Товар не найден'));
          }

          final product = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(product['ImageURL']),
                SizedBox(height: 20),
                Text(
                  product['Name'],
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text('\$${product['Price']}', style: TextStyle(fontSize: 20)),
                SizedBox(height: 10),
                Text(product['Description']),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        showEditDialog(context, product);
                      },
                      child: Text('Редактировать'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        deleteProduct().then((_) {
                          Navigator.pop(context);
                        });
                      },
                      child: Text('Удалить'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void showEditDialog(BuildContext context, Map<String, dynamic> product) {
    final nameController = TextEditingController(text: product['Name']);
    final priceController = TextEditingController(text: product['Price'].toString());
    final descriptionController = TextEditingController(text: product['Description']);
    final imageUrlController = TextEditingController(text: product['ImageURL']); // Добавляем контроллер для URL изображения

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Редактировать товар'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Название'),
              ),
              TextField(
                controller: priceController,
                decoration: InputDecoration(labelText: 'Цена'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(labelText: 'Описание'),
              ),
              TextField(
                controller: imageUrlController, // Поле для ввода URL изображения
                decoration: InputDecoration(labelText: 'URL изображения'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                updateProduct(
                  product['ID'],
                  nameController.text,
                  double.parse(priceController.text),
                  descriptionController.text,
                  imageUrlController.text, // Передаём URL изображения
                );
                Navigator.of(context).pop(); // Закрываем диалог после обновления
              },
              child: Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> updateProduct(int id, String name, double price, String description, String imageUrl) async {
    final url = Uri.parse('http://10.0.2.2:8080/products/update/$id');
    await http.put(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'Name': name,
        'Price': price,
        'Description': description,
        'ImageURL': imageUrl, // Добавляем URL изображения в тело запроса
      }),
    );
    // Дополнительная обработка ответов
  }
}
class AddProductScreen extends StatelessWidget {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  Future<void> addProduct() async {
    final url = Uri.parse('http://10.0.2.2:8080/products/create');
    await http.post(
      url,
      headers: {'Content-Type': 'application/json; charset=UTF-8'},
      body: json.encode({
        'Name': nameController.text,
        'Price': double.tryParse(priceController.text),
        'Description': descriptionController.text,
        'ImageURL': imageUrlController.text,
      }),
    );
    // Дополнительная обработка ответов (например, уведомление об успешном добавлении)
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Добавить товар'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: priceController,
              decoration: InputDecoration(labelText: 'Цена'),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(labelText: 'Описание'),
            ),
            TextField(
              controller: imageUrlController,
              decoration: InputDecoration(labelText: 'URL изображения'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                addProduct().then((_) {
                  Navigator.pop(context); // Закрываем экран после добавления
                });
              },
              child: Text('Добавить товар'),
            ),
          ],
        ),
      ),
    );
  }
}


class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool isLoginMode = true;
  bool isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    loadUserData(); // Загружаем данные пользователя при инициализации
  }

  Future<void> loadUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Получаем данные из shared_preferences и записываем их в глобальные переменные
    setState(() {
      isLoggedIn = (prefs.getBool('isLoggedIn') ?? false);
      global.userId = prefs.getString('userId') ?? '';
      global.userName = prefs.getString('userName') ?? '';
      global.userSurname = prefs.getString('userSurname') ?? '';
      global.userMail = prefs.getString('userMail') ?? '';
      global.userPhone = prefs.getString('userPhone') ?? '';
      global.favorites = prefs.getStringList('favorites') ?? [];
      global.inCart = prefs.getStringList('inCart') ?? [];
    });
  }

  Future<void> saveUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Сохраняем данные в shared_preferences
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userId', global.userId);
    await prefs.setString('userName', global.userName);
    await prefs.setString('userSurname', global.userSurname);
    await prefs.setString('userMail', global.userMail);
    await prefs.setString('userPhone', global.userPhone);
    await prefs.setStringList('favorites', global.favorites);
    await prefs.setStringList('inCart', global.inCart);
  }

  Future<void> clearUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Удаляем данные пользователя из shared_preferences
    await prefs.remove('isLoggedIn');
    await prefs.remove('userId');
    await prefs.remove('userName');
    await prefs.remove('userSurname');
    await prefs.remove('userMail');
    await prefs.remove('userPhone');
    await prefs.remove('favorites');
    await prefs.remove('inCart');

    // Сбрасываем состояние и глобальные переменные
    setState(() {
      isLoggedIn = false;
      global.userId = '';
      global.userName = '';
      global.userSurname = '';
      global.userMail = '';
      global.userPhone = '';
      global.favorites = [];
      global.inCart = [];
    });
  }

  void toggleForm() {
    setState(() {
      isLoginMode = !isLoginMode;
    });
  }

  Future<void> loginUser() async {
    final url = Uri.parse(
        'http://10.0.2.2:8080/users/login'); // Замените на ваш URL
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'Mail': emailController.text,
        'Password': passwordController.text,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        isLoggedIn = true;
        global.userId = data['ID']?.toString() ?? '';
        global.userName = data['Name'] ?? '';
        global.userSurname = data['Surname'] ?? '';
        global.userMail = data['Mail'] ?? '';
        global.userPhone = data['Phone'] ?? '';
        global.favorites = (data['Favorites'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
        global.inCart = (data['InCart'] as List<dynamic>)
            .map((id) => id.toString())
            .toList();
      });

      await saveUserData(); // Сохраняем данные пользователя
      showMessage('Вы успешно вошли!');
    } else {
      showMessage('Ошибка входа: ${response.statusCode}');
    }
  }

  Future<void> registerUser() async {
    final url = Uri.parse(
        'http://10.0.2.2:8080/users/register'); // Замените на ваш URL
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'Name': nameController.text,
        'Surname': surnameController.text,
        'Mail': emailController.text,
        'Phone': phoneController.text,
        'Password': passwordController.text,
      }),
    );

    if (response.statusCode == 201) {
      final data = json.decode(response.body);
      setState(() {
        isLoggedIn = true;
        global.userId = data['ID']?.toString() ?? '';
        global.userName = data['Name'] ?? '';
        global.userSurname = data['Surname'] ?? '';
        global.userMail = data['Mail'] ?? '';
        global.userPhone = data['Phone'] ?? '';
        global.favorites = List<String>.from(data['Favorites'] ?? []);
        global.inCart = List<String>.from(data['InCart'] ?? []);
      });

      await saveUserData(); // Сохраняем данные пользователя
      showMessage('Вы успешно зарегистрированы!');
    } else {
      showMessage('Ошибка регистрации: ${response.statusCode}');
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Профиль'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLoggedIn) ...[
                    if (!isLoginMode) ...[
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: 'Имя'),
                        validator: (value) =>
                        value!.isEmpty
                            ? 'Введите имя'
                            : null,
                      ),
                      TextFormField(
                        controller: surnameController,
                        decoration: InputDecoration(labelText: 'Фамилия'),
                        validator: (value) =>
                        value!.isEmpty
                            ? 'Введите фамилию'
                            : null,
                      ),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(labelText: 'Email'),
                        validator: (value) =>
                        value!.isEmpty
                            ? 'Введите email'
                            : null,
                      ),
                      TextFormField(
                        controller: phoneController,
                        decoration: InputDecoration(labelText: 'Телефон'),
                        validator: (value) =>
                        value!.isEmpty
                            ? 'Введите телефон'
                            : null,
                      ),
                    ],
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(labelText: 'Email'),
                      validator: (value) =>
                      value!.isEmpty
                          ? 'Введите email'
                          : null,
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      validator: (value) =>
                      value!.isEmpty
                          ? 'Введите пароль'
                          : null,
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        if (isLoginMode) {
                          if (_formKey.currentState!.validate()) {
                            loginUser();
                          }
                        } else {
                          if (_formKey.currentState!.validate()) {
                            registerUser();
                          }
                        }
                      },
                      child: Text(isLoginMode ? 'Войти' : 'Зарегистрироваться'),
                    ),
                    TextButton(
                      onPressed: toggleForm,
                      child: Text(isLoginMode
                          ? 'Нет аккаунта? Зарегистрироваться'
                          : 'Уже зарегистрированы? Войти'),
                    ),
                  ] else
                    ...[
                      Text('ID пользователя: ${global.userId}'),
                      Text('Имя: ${global.userName}'),
                      Text('Фамилия: ${global.userSurname}'),
                      Text('Email: ${global.userMail}'),
                      Text('Телефон: ${global.userPhone}'),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          clearUserData(); // Очистить данные при выходе
                        },
                        child: Text('Выход'),
                      ),
                      Text('Избранное: ${global.favorites.join(", ")}'),
                      Text('В корзине: ${global.inCart.join(", ")}'),
                    ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class FavoritesScreen extends StatefulWidget {
  @override
  _FavoritesScreenState createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Product> favoriteProducts = [];

  @override
  void initState() {
    super.initState();
    loadFavorites(); // Загружаем избранные товары при инициализации
  }

  Future<void> loadFavorites() async {
    favoriteProducts.clear();
    for (String productId in global.favorites) {
      await fetchProductById(productId);
    }
  }

  Future<void> fetchProductById(String productId) async {
    final url = Uri.parse('http://10.0.2.2:8080/products/$productId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final product = Product.fromJson(json.decode(response.body));
      setState(() {
        favoriteProducts.add(product);
      });
    } else {
      print('Ошибка загрузки продукта с ID $productId: ${response.statusCode}');
    }
  }

  Future<void> removeFromFavorites(String productId) async {
    final url = Uri.parse('http://10.0.2.2:8080/users/favorites/remove');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': int.parse(global.userId), // Отправляем как число
        'product_id': int.parse(productId),   // Отправляем как число
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        favoriteProducts.removeWhere((product) => product.id.toString() == productId);
        global.favorites.remove(productId);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Товар удален из избранного')));
    } else {
      print('Ошибка при удалении товара: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Избранное'),
      ),
      body: favoriteProducts.isEmpty
          ? Center(child: Text('Ваши избранные товары пусты.'))
          : ListView.builder(
        itemCount: favoriteProducts.length,
        itemBuilder: (context, index) {
          final product = favoriteProducts[index];
          return GestureDetector(
            onTap: () {
              // Переход к экрану деталей продукта
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailScreen(
                    productId: int.parse(product.id), // Преобразуем в int
                  ),
                ),
              );
            },
            child: Card(
              margin: EdgeInsets.all(10),
              child: ListTile(
                contentPadding: EdgeInsets.all(16),
                leading: Image.network(product.imageUrl, width: 50),
                title: Text(product.name),
                subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
                trailing: IconButton(
                  icon: Icon(Icons.favorite, color: Colors.red),
                  onPressed: () => removeFromFavorites(product.id.toString()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
class Product {
  final String id;
  final String imageUrl;
  final String name;
  final String description;
  final double price;

  Product({
    required this.id,
    required this.imageUrl,
    required this.name,
    required this.description,
    required this.price,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['ID'].toString(), // Убедитесь, что ID - строка
      imageUrl: json['ImageURL'],
      name: json['Name'],
      description: json['Description'],
      price: json['Price'].toDouble(),
    );
  }
}
class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<Product> cartProducts = []; // Список продуктов в корзине
  List<int> quantities = []; // Список количеств для каждого товара

  @override
  void initState() {
    super.initState();
    loadCart(); // Загружаем корзину при инициализации
  }

  Future<void> loadCart() async {
    cartProducts.clear();
    quantities.clear();
    for (String productId in global.inCart) {
      await fetchProductById(productId);
    }
  }

  Future<void> fetchProductById(String productId) async {
    final url = Uri.parse('http://10.0.2.2:8080/products/$productId');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final product = Product.fromJson(json.decode(response.body));
      setState(() {
        cartProducts.add(product);
        quantities.add(1); // Начальное количество = 1
      });
    } else {
      print('Ошибка загрузки продукта с ID $productId: ${response.statusCode}');
    }
  }

  void increaseQuantity(int index) {
    setState(() {
      quantities[index]++;
    });
  }

  void decreaseQuantity(int index) {
    if (quantities[index] > 0) {
      setState(() {
        quantities[index]--;
      });
      if (quantities[index] == 0) {
        _showRemoveDialog(index);
      }
    }
  }

  void _showRemoveDialog(int index) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Удаление товара'),
          content: Text('Хотите ли вы удалить товар "${cartProducts[index].name}" из корзины?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Закрываем диалог
              },
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                removeFromCart(index);
                Navigator.of(context).pop(); // Закрываем диалог
              },
              child: Text('Удалить'),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeFromCart(int index) async {
    final url = Uri.parse('http://10.0.2.2:8080/users/cart/remove');

    // Извлекаем user_id
    int userId = int.parse(global.userId);

    // Преобразуем productId из String в int
    int productId = int.parse(cartProducts[index].id); // Убедитесь, что cartProducts[index].id - это строка!

    print('Отправка данных: user_id: $userId, product_id: $productId'); // Отладочное сообщение

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': userId, // Отправляем как число
        'product_id': productId, // ID продукта
      }),
    );

    if (response.statusCode == 200) {
      setState(() {
        global.inCart.remove(cartProducts[index].id.toString());
        cartProducts.removeAt(index);
        quantities.removeAt(index);
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Товар удален из корзины')));
    } else {
      print('Ошибка при удалении товара: ${response.statusCode} - ${response.body}');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить товар из корзины')));
    }
  }



  double getTotalPrice() {
    double totalPrice = 0.0;
    for (int i = 0; i < cartProducts.length; i++) {
      totalPrice += cartProducts[i].price * quantities[i];
    }
    return totalPrice;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Корзина'),
      ),
      body: cartProducts.isEmpty
          ? Center(child: Text('Ваша корзина пуста.'))
          : ListView.builder(
        itemCount: cartProducts.length,
        itemBuilder: (context, index) {
          final product = cartProducts[index];
          return Card(
            margin: EdgeInsets.all(10),
            child: ListTile(
              contentPadding: EdgeInsets.all(16),
              title: Text(product.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Цена: \$${product.price.toStringAsFixed(2)}'),
                  Text('Количество: ${quantities[index]}'),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove),
                        onPressed: () => decreaseQuantity(index),
                      ),
                      IconButton(
                        icon: Icon(Icons.add),
                        onPressed: () => increaseQuantity(index),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Общая стоимость: \$${getTotalPrice().toStringAsFixed(2)}'),
              ElevatedButton(
                onPressed: () {
                  // TODO:  функционал для заказа
                },
                child: Text('Заказать'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class PlaceholderScreen extends StatelessWidget {
  final String label;

  const PlaceholderScreen({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label),
    );
  }
}