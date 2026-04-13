class ActionService {
  Future<void> moveMouseTo(int x, int y) async {
    print('🖱️ SIMULADO: Mouse movido a ($x, $y)');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> click() async {
    print('🖱️ SIMULADO: Clic izquierdo');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> doubleClick() async {
    print('🖱️ SIMULADO: Doble clic');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> rightClick() async {
    print('🖱️ SIMULADO: Clic derecho');
    await Future.delayed(const Duration(milliseconds: 50));
  }

  Future<void> typeText(String text) async {
    print('⌨️ SIMULADO: Texto escrito: "$text"');
    await Future.delayed(const Duration(milliseconds: 100));
  }

  Future<void> pressKey(String key) async {
    print('⌨️ SIMULADO: Tecla presionada: $key');
    await Future.delayed(const Duration(milliseconds: 50));
  }
}