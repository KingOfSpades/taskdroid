class FilterTab {
  final String id;
  final String name;
  final String searchQuery;
  final Set<String> selectedTags;
  final Set<String> selectedProjects;

  FilterTab({
    required this.id,
    required this.name,
    this.searchQuery = '',
    Set<String>? selectedTags,
    Set<String>? selectedProjects,
  })  : selectedTags = selectedTags ?? {},
        selectedProjects = selectedProjects ?? {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'searchQuery': searchQuery,
      'selectedTags': selectedTags.toList(),
      'selectedProjects': selectedProjects.toList(),
    };
  }

  factory FilterTab.fromJson(Map<String, dynamic> json) {
    return FilterTab(
      id: json['id'] as String,
      name: json['name'] as String,
      searchQuery: json['searchQuery'] as String? ?? '',
      selectedTags: (json['selectedTags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
      selectedProjects: (json['selectedProjects'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toSet() ??
          {},
    );
  }

  FilterTab copyWith({
    String? id,
    String? name,
    String? searchQuery,
    Set<String>? selectedTags,
    Set<String>? selectedProjects,
  }) {
    return FilterTab(
      id: id ?? this.id,
      name: name ?? this.name,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedTags: selectedTags ?? this.selectedTags,
      selectedProjects: selectedProjects ?? this.selectedProjects,
    );
  }
}

