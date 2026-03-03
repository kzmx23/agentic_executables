import 'dart:convert';
import 'dart:io';

import '../config/ae_core_config.dart';
import '../models/types.dart';
import '../ports/registry_client.dart';

class GitHubRawRegistryClient implements RegistryClient {
  GitHubRawRegistryClient({
    final HttpClient? httpClient,
    this.owner = AeCoreConfig.registryOwner,
    this.repo = AeCoreConfig.registryRepo,
    this.branch = AeCoreConfig.registryBranch,
  }) : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;
  final String owner;
  final String repo;
  final String branch;

  @override
  Future<bool> libraryExists(final String libraryId) async {
    try {
      await _fetchByPath(
        '${AeCoreConfig.registryBasePath}/$libraryId/README.md',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String> fetchRegistryFile(
    final String libraryId,
    final AeAction action,
  ) async {
    final filePath = AeCoreConfig.registryPath(libraryId, action);
    return _fetchByPath(filePath);
  }

  @override
  String buildRegistryUrl(final String libraryId, final AeAction action) =>
      AeCoreConfig.buildGitHubRawUrl(
        owner: owner,
        repo: repo,
        branch: branch,
        path: AeCoreConfig.registryPath(libraryId, action),
      );

  Future<String> _fetchByPath(final String filePath) async {
    final mainUrl = AeCoreConfig.buildGitHubRawUrl(
      owner: owner,
      repo: repo,
      branch: branch,
      path: filePath,
    );

    final mainAttempt = await _fetch(mainUrl);
    if (mainAttempt != null) {
      return mainAttempt;
    }

    if (branch != 'master') {
      final masterUrl = AeCoreConfig.buildGitHubRawUrl(
        owner: owner,
        repo: repo,
        branch: 'master',
        path: filePath,
      );
      final masterAttempt = await _fetch(masterUrl);
      if (masterAttempt != null) {
        return masterAttempt;
      }
    }

    throw HttpException(
      'File not found: $filePath (tried branches: $branch${branch == 'master' ? '' : ', master'})',
    );
  }

  Future<String?> _fetch(final String url) async {
    final uri = Uri.parse(url);
    final request = await _httpClient.getUrl(uri);
    final response = await request.close();

    if (response.statusCode == 200) {
      return response.transform(utf8.decoder).join();
    }

    if (response.statusCode == 404) {
      return null;
    }

    throw HttpException(
      'Failed to fetch file: HTTP ${response.statusCode}',
      uri: uri,
    );
  }

  void close() {
    _httpClient.close();
  }
}
