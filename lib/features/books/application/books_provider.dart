import 'package:fieldawy_store/features/books/data/books_repository.dart';
import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Repository Provider
final booksRepositoryProvider = Provider<BooksRepository>((ref) {
  return BooksRepository();
});

// All Books Provider
final allBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.read(booksRepositoryProvider);
  return repository.getAllBooks();
});

// My Books Provider
final myBooksProvider = FutureProvider<List<Book>>((ref) async {
  final repository = ref.read(booksRepositoryProvider);
  return repository.getMyBooks();
});

// Books State Notifier for mutations
class BooksNotifier extends StateNotifier<AsyncValue<List<Book>>> {
  final BooksRepository _repository;
  final bool _isMyBooks;

  BooksNotifier(this._repository, {bool isMyBooks = false}) 
      : _isMyBooks = isMyBooks,
        super(const AsyncValue.loading()) {
    loadBooks();
  }

  Future<void> loadBooks() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      if (_isMyBooks) {
        return _repository.getMyBooks();
      } else {
        return _repository.getAllBooks();
      }
    });
  }

  Future<bool> createBook({
    required String name,
    required String author,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      await _repository.createBook(
        name: name,
        author: author,
        description: description,
        price: price,
        phone: phone,
        imageUrl: imageUrl,
      );
      await loadBooks();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateBook({
    required String bookId,
    required String name,
    required String author,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final success = await _repository.updateBook(
        bookId: bookId,
        name: name,
        author: author,
        description: description,
        price: price,
        phone: phone,
        imageUrl: imageUrl,
      );
      if (success) {
        await loadBooks();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteBook(String bookId) async {
    try {
      final success = await _repository.deleteBook(bookId);
      if (success) {
        await loadBooks();
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  Future<void> incrementViews(String bookId) async {
    await _repository.incrementBookViews(bookId);
  }
}

// All Books Notifier Provider
final allBooksNotifierProvider = StateNotifierProvider<BooksNotifier, AsyncValue<List<Book>>>((ref) {
  final repository = ref.read(booksRepositoryProvider);
  return BooksNotifier(repository, isMyBooks: false);
});

// My Books Notifier Provider
final myBooksNotifierProvider = StateNotifierProvider<BooksNotifier, AsyncValue<List<Book>>>((ref) {
  final repository = ref.read(booksRepositoryProvider);
  return BooksNotifier(repository, isMyBooks: true);
});
