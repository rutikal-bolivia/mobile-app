import 'package:flutter_bloc/flutter_bloc.dart';

class NavigationCubit extends Cubit<int> {
  NavigationCubit() : super(1); // Empezamos en la pestaña 1 (Mapa) por defecto

  void changeTab(int index) => emit(index);
}
