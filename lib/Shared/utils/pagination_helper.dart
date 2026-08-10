/// Utilidades para paginación y lazy loading
class PaginationHelper {
  /// Calcular página actual basado en índice y tamaño de página
  static int getCurrentPage(int index, int pageSize) {
    return (index / pageSize).floor();
  }

  /// Calcular índice inicial de una página
  static int getPageStartIndex(int page, int pageSize) {
    return page * pageSize;
  }

  /// Calcular índice final de una página
  static int getPageEndIndex(int page, int pageSize, int totalItems) {
    final startIndex = getPageStartIndex(page, pageSize);
    return (startIndex + pageSize).clamp(0, totalItems);
  }

  /// Obtener elementos de una página específica
  static List<T> getPageItems<T>(List<T> items, int page, int pageSize) {
    if (items.isEmpty) return [];
    
    final startIndex = getPageStartIndex(page, pageSize);
    final endIndex = getPageEndIndex(page, pageSize, items.length);
    
    if (startIndex >= items.length) return [];
    
    return items.sublist(startIndex, endIndex);
  }

  /// Calcular total de páginas
  static int getTotalPages(int totalItems, int pageSize) {
    if (totalItems == 0) return 0;
    return ((totalItems - 1) / pageSize).floor() + 1;
  }

  /// Verificar si hay página siguiente
  static bool hasNextPage(int currentPage, int totalItems, int pageSize) {
    return currentPage < getTotalPages(totalItems, pageSize) - 1;
  }

  /// Verificar si hay página anterior
  static bool hasPreviousPage(int currentPage) {
    return currentPage > 0;
  }

  /// Clase para manejar estado de paginación
  static class PaginationState<T> {
    final List<T> items;
    final int currentPage;
    final int pageSize;
    final int totalItems;
    final bool isLoading;
    final bool hasMore;

    const PaginationState({
      required this.items,
      required this.currentPage,
      required this.pageSize,
      required this.totalItems,
      this.isLoading = false,
      this.hasMore = true,
    });

    int get totalPages => getTotalPages(totalItems, pageSize);
    int get currentStartIndex => getPageStartIndex(currentPage, pageSize);
    int get currentEndIndex => getPageEndIndex(currentPage, pageSize, totalItems);

    PaginationState<T> copyWith({
      List<T>? items,
      int? currentPage,
      int? pageSize,
      int? totalItems,
      bool? isLoading,
      bool? hasMore,
    }) {
      return PaginationState<T>(
        items: items ?? this.items,
        currentPage: currentPage ?? this.currentPage,
        pageSize: pageSize ?? this.pageSize,
        totalItems: totalItems ?? this.totalItems,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
      );
    }

    PaginationState<T> withLoading(bool loading) {
      return copyWith(isLoading: loading);
    }

    PaginationState<T> nextPage() {
      if (!hasNextPage(currentPage, totalItems, pageSize)) {
        return this;
      }
      return copyWith(currentPage: currentPage + 1);
    }

    PaginationState<T> previousPage() {
      if (!hasPreviousPage(currentPage)) {
        return this;
      }
      return copyWith(currentPage: currentPage - 1);
    }
  }
}