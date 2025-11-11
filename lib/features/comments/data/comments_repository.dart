import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/comment_model.dart';

enum CommentType { course, book, surgicalTool }

class CommentsRepository {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Cache لبيانات المستخدمين لتحسين الأداء
  final Map<String, Map<String, dynamic>> _usersCache = {};

  // الحصول على معرف المستخدم الحالي
  String? get currentUserId => _supabase.auth.currentUser?.id;

  // جلب التعليقات لكورس أو كتاب أو أداة جراحية
  Future<List<Comment>> getComments({
    required String itemId,
    required CommentType type,
    int? limit, // إضافة limit parameter اختياري
  }) async {
    try {
      String tableName;
      String itemIdKey;
      
      switch (type) {
        case CommentType.course:
          tableName = 'course_comments';
          itemIdKey = 'course_id';
          break;
        case CommentType.book:
          tableName = 'book_comments';
          itemIdKey = 'book_id';
          break;
        case CommentType.surgicalTool:
          tableName = 'surgical_tool_comments';
          itemIdKey = 'distributor_surgical_tool_id';
          break;
      }

      var query = _supabase
          .from(tableName)
          .select('''
            *,
            users!inner(
              display_name,
              photo_url,
              role
            )
          ''')
          .eq(itemIdKey, itemId)
          .order('created_at', ascending: false);
      
      // تطبيق limit إذا تم تحديده
      if (limit != null) {
        query = query.limit(limit);
      }
      
      final response = await query;

      return (response as List)
          .map((json) {
            // دمج بيانات المستخدم في object واحد
            final userdata = json['users'];
            json['user_name'] = userdata['display_name'];
            json['user_photo_url'] = userdata['photo_url'];
            json['user_role'] = userdata['role'];
            
            return Comment.fromJson(json, itemIdKey: itemIdKey);
          })
          .toList();
    } catch (e) {
      print('خطأ في جلب التعليقات: $e');
      return [];
    }
  }

  // إضافة تعليق جديد
  Future<Comment?> addComment({
    required String itemId,
    required String commentText,
    required CommentType type,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('يجب تسجيل الدخول أولاً');
      }

      String tableName;
      String itemIdKey;
      
      switch (type) {
        case CommentType.course:
          tableName = 'course_comments';
          itemIdKey = 'course_id';
          break;
        case CommentType.book:
          tableName = 'book_comments';
          itemIdKey = 'book_id';
          break;
        case CommentType.surgicalTool:
          tableName = 'surgical_tool_comments';
          itemIdKey = 'distributor_surgical_tool_id';
          break;
      }

      final response = await _supabase
          .from(tableName)
          .insert({
            itemIdKey: itemId,
            'user_id': userId,
            'comment_text': commentText.trim(),
          })
          .select('''
            *,
            users!inner(
              display_name,
              photo_url,
              role
            )
          ''')
          .single();

      // دمج بيانات المستخدم
      final userData = response['users'];
      response['user_name'] = userData['display_name'];
      response['user_photo_url'] = userData['photo_url'];
      response['user_role'] = userData['role'];

      return Comment.fromJson(response, itemIdKey: itemIdKey);
    } catch (e) {
      print('خطأ في إضافة التعليق: $e');
      return null;
    }
  }

  // حذف تعليق
  Future<bool> deleteComment({
    required String commentId,
    required CommentType type,
  }) async {
    try {
      String tableName;
      
      switch (type) {
        case CommentType.course:
          tableName = 'course_comments';
          break;
        case CommentType.book:
          tableName = 'book_comments';
          break;
        case CommentType.surgicalTool:
          tableName = 'surgical_tool_comments';
          break;
      }
      
      await _supabase
          .from(tableName)
          .delete()
          .eq('id', commentId);

      return true;
    } catch (e) {
      print('خطأ في حذف التعليق: $e');
      return false;
    }
  }

  // تعديل تعليق
  Future<Comment?> updateComment({
    required String commentId,
    required String newText,
    required CommentType type,
  }) async {
    try {
      String tableName;
      String itemIdKey;
      
      switch (type) {
        case CommentType.course:
          tableName = 'course_comments';
          itemIdKey = 'course_id';
          break;
        case CommentType.book:
          tableName = 'book_comments';
          itemIdKey = 'book_id';
          break;
        case CommentType.surgicalTool:
          tableName = 'surgical_tool_comments';
          itemIdKey = 'distributor_surgical_tool_id';
          break;
      }

      final response = await _supabase
          .from(tableName)
          .update({
            'comment_text': newText.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commentId)
          .select('''
            *,
            users!inner(
              display_name,
              photo_url,
              role
            )
          ''')
          .single();

      // دمج بيانات المستخدم
      final userData = response['users'];
      response['user_name'] = userData['display_name'];
      response['user_photo_url'] = userData['photo_url'];
      response['user_role'] = userData['role'];

      return Comment.fromJson(response, itemIdKey: itemIdKey);
    } catch (e) {
      print('خطأ في تعديل التعليق: $e');
      return null;
    }
  }

  // حساب عدد التعليقات
  Future<int> getCommentsCount({
    required String itemId,
    required CommentType type,
  }) async {
    try {
      String tableName;
      String itemIdKey;
      
      switch (type) {
        case CommentType.course:
          tableName = 'course_comments';
          itemIdKey = 'course_id';
          break;
        case CommentType.book:
          tableName = 'book_comments';
          itemIdKey = 'book_id';
          break;
        case CommentType.surgicalTool:
          tableName = 'surgical_tool_comments';
          itemIdKey = 'distributor_surgical_tool_id';
          break;
      }

      final response = await _supabase
          .from(tableName)
          .select('id')
          .eq(itemIdKey, itemId);

      return (response as List).length;
    } catch (e) {
      print('خطأ في حساب التعليقات: $e');
      return 0;
    }
  }

  // الاستماع للتعليقات الجديدة (Realtime)
  Stream<List<Comment>> watchComments({
    required String itemId,
    required CommentType type,
    int? limit, // إضافة limit parameter اختياري
  }) {
    String tableName;
    String itemIdKey;
    
    switch (type) {
      case CommentType.course:
        tableName = 'course_comments';
        itemIdKey = 'course_id';
        break;
      case CommentType.book:
        tableName = 'book_comments';
        itemIdKey = 'book_id';
        break;
      case CommentType.surgicalTool:
        tableName = 'surgical_tool_comments';
        itemIdKey = 'distributor_surgical_tool_id';
        break;
    }

    var stream = _supabase
        .from(tableName)
        .stream(primaryKey: ['id'])
        .eq(itemIdKey, itemId)
        .order('created_at', ascending: false);
    
    // تطبيق limit إذا تم تحديده
    if (limit != null) {
      stream = stream.limit(limit);
    }
    
    return stream.asyncMap((data) async {
          // جلب بيانات المستخدمين لكل تعليق
          final Set<Comment> comments = {};
          
          for (final json in data) {
            try {
              final userId = json['user_id'];
              
              // التحقق من الـ Cache أولاً
              Map<String, dynamic>? userData = _usersCache[userId];
              
              // إذا لم تكن في الـ Cache، جلبها من قاعدة البيانات
              if (userData == null) {
                userData = await _supabase
                    .from('users')
                    .select('display_name, photo_url, role')
                    .eq('id', userId)
                    .maybeSingle();
                
                // حفظ في الـ Cache
                if (userData != null) {
                  _usersCache[userId] = userData;
                }
              }
              
              if (userData != null) {
                json['user_name'] = userData['display_name'];
                json['user_photo_url'] = userData['photo_url'];
                json['user_role'] = userData['role'];
              }
              
              comments.add(Comment.fromJson(json, itemIdKey: itemIdKey));
            } catch (e) {
              print('خطأ في معالجة تعليق: $e');
            }
          }
          
          return comments.toList();
        });
  }
}