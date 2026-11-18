import 'dart:io';

class WalletFileStore {
  const WalletFileStore(this.directory);
  final Future<Directory> Function() directory;

  Future<File> _file() async =>
      File('${(await directory()).path}/pocket_wallet.json');
  Future<String?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsString() : null;
  }

  Future<void> write(String contents) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    // Replace only after a complete write, preserving the old file on failure.
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    await temporary.rename(file.path);
  }
}
