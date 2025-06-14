// import 'package:tatarai/core/base/base_state.dart';
// import 'package:tatarai/features/auth/models/user_model.dart';

// /// Profil ekranı için state sınıfı
// class ProfileState extends BaseState {
//   /// Kullanıcı verisi
//   final UserModel? user;

//   /// Profil güncellenme durumu
//   final bool isProfileUpdated;

//   /// Profil fotoğrafı yükleniyor durumu
//   final bool isImageUploading;

//   /// Kullanıcı verisi yenileniyor durumu
//   final bool isRefreshing;

//   /// Constructor
//   const ProfileState({
//     this.user,
//     super.isLoading,
//     super.errorMessage,
//     this.isProfileUpdated = false,
//     this.isImageUploading = false,
//     this.isRefreshing = false,
//   });

//   /// Başlangıç state'i
//   factory ProfileState.initial() {
//     return const ProfileState();
//   }

//   /// State kopyalama methodu
//   ProfileState copyWith({
//     UserModel? user,
//     bool? isLoading,
//     String? errorMessage,
//     bool? isProfileUpdated,
//     bool? isImageUploading,
//     bool? isRefreshing,
//   }) {
//     return ProfileState(
//       user: user ?? this.user,
//       isLoading: isLoading ?? this.isLoading,
//       errorMessage: errorMessage,
//       isProfileUpdated: isProfileUpdated ?? this.isProfileUpdated,
//       isImageUploading: isImageUploading ?? this.isImageUploading,
//       isRefreshing: isRefreshing ?? this.isRefreshing,
//     );
//   }

//   @override
//   List<Object?> get props => [
//         user,
//         isLoading,
//         errorMessage,
//         isProfileUpdated,
//         isImageUploading,
//         isRefreshing,
//       ];
// }
