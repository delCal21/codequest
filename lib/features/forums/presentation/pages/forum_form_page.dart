import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:codequest/features/forums/presentation/bloc/forum_bloc.dart';
import 'package:codequest/features/forums/domain/models/forum_model.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:codequest/features/auth/presentation/bloc/auth_state.dart';

class ForumFormPage extends StatefulWidget {
  final ForumModel? forum;
  final String courseId;

  const ForumFormPage({Key? key, this.forum, required this.courseId})
      : super(key: key);

  @override
  State<ForumFormPage> createState() => _ForumFormPageState();
}

class _ForumFormPageState extends State<ForumFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.forum != null) {
      _titleController.text = widget.forum!.title;
      _contentController.text = widget.forum!.content;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authState = context.read<AuthBloc>().state;
      if (authState is! Authenticated) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post')),
        );
        setState(() => _isLoading = false);
        return;
      }

      if (widget.forum == null) {
        context.read<ForumBloc>().add(
              CreateForum(
                title: _titleController.text,
                content: _contentController.text,
                authorId: authState.user.id,
                authorName: authState.user.name,
                courseId: widget.courseId,
              ),
            );
      } else {
        context.read<ForumBloc>().add(
              UpdateForum(
                widget.forum!.copyWith(
                  title: _titleController.text,
                  content: _contentController.text,
                  updatedAt: DateTime.now(),
                ),
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ForumBloc, ForumState>(
      listener: (context, state) {
        if (state is ForumLoaded) {
          setState(() => _isLoading = false);
          Navigator.pop(context);
        } else if (state is ForumError) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        } else if (state is ForumLoading) {
          setState(() => _isLoading = true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.green[600],
          title: Text(widget.forum == null ? 'Create Post' : 'Edit Post',
              style: const TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Colors.green))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Title',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a title';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _contentController,
                          decoration: InputDecoration(
                            labelText: 'Content',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.green[200]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.green[600]!, width: 2),
                            ),
                            alignLabelWithHint: true,
                          ),
                          maxLines: 10,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter some content';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green[600],
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              widget.forum == null
                                  ? 'Create Post'
                                  : 'Update Post',
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
