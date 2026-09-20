/// Whether [path] has a directory segment named [name].
///
/// Compared by segment, so `view_models` matches the directory and not a file
/// called `view_models.dart`.
bool hasDirectory(String path, String name) =>
    path.replaceAll(r'\', '/').split('/').contains(name);
