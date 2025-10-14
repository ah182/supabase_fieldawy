import 'package:fieldawy_store/features/books/domain/book_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BooksRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all books
  Future<List<Book>> getAllBooks() async {
    try {
      final response = await _supabase.rpc('get_all_books');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load books: $e');
    }
  }

  /// Get current user's books
  Future<List<Book>> getMyBooks() async {
    try {
      final response = await _supabase.rpc('get_my_books');
      
      if (response == null) return [];
      
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Book.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception('Failed to load my books: $e');
    }
  }

  /// Create a new book
  Future<String> createBook({
    required String name,
    required String author,
    required String description,
    required double price,
    required String phone,
    required String imageUrl,
  }) async {
    try {
      final response = await _supabase.rpc('create_book', params: {
        'p_name': name,
        'p_author': author,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      return response as String;
    } catch (e) {
      throw Exception('Failed to create book: $e');
    }
  }

  /// Update an existing book
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
      final response = await _supabase.rpc('update_book', params: {
        'p_book_id': bookId,
        'p_name': name,
        'p_author': author,
        'p_description': description,
        'p_price': price,
        'p_phone': phone,
        'p_image_url': imageUrl,
      });
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to update book: $e');
    }
  }

  /// Delete a book
  Future<bool> deleteBook(String bookId) async {
    try {
      final response = await _supabase.rpc('delete_book', params: {
        'p_book_id': bookId,
      });
      
      return response as bool;
    } catch (e) {
      throw Exception('Failed to delete book: $e');
    }
  }

  /// Increment book views
  Future<void> incrementBookViews(String bookId) async {
    try {
      await _supabase.rpc('increment_book_views', params: {
        'p_book_id': bookId,
      });
    } catch (e) {
      // Silent fail for views
      print('Failed to increment book views: $e');
    }
  }
}
