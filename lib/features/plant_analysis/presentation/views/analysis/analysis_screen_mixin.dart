part of 'analysis_screen.dart';

/// Mixin for handling the business logic of the [AnalysisScreen].
/// This includes image selection, location management, animations,
/// and starting the plant analysis process.
mixin _AnalysisScreenMixin on State<AnalysisScreen> {
  /// The file path of the selected image for analysis.
  File? _selectedImage;

  /// Controllers for the location and field name text fields.
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _fieldNameController = TextEditingController();

  /// Service for handling location-related operations, like fetching provinces.
  final LocationService _locationService = LocationService();


  /// Data lists for location selection dropdowns.
  List<Province> _provinces = [];
  List<District> _districts = [];
  List<Neighborhood> _neighborhoods = [];

  /// Selected location values from the dropdowns.
  Province? _selectedProvince;
  District? _selectedDistrict;
  Neighborhood? _selectedNeighborhood;

  /// Loading state flags for location data fetching.
  bool _loadingProvinces = false;
  bool _loadingDistricts = false;
  bool _loadingNeighborhoods = false;

  /// Stores the ID of the last analysis that was navigated to,
  /// to prevent duplicate navigation.
  String? _lastNavigatedAnalysisId;


  /// Controller for managing the screen's entry animations.
  late AnimationController _animationController;

  /// Scale animation for the content.
  late Animation<double> _scaleAnimation;

  /// Fade animation for the content.
  late Animation<double> _fadeAnimation;

  @override
  void dispose() {
    _locationController.dispose();
    _fieldNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  /// Initializes the animations for the screen.
  /// Sets up the fade and scale transitions.
  void _initializeAnimations() {
    AppLogger.i('AnalysisScreen - Initializing animations');
    try {
      if (!mounted) {
        return;
      }

      final vsync = this as TickerProvider;
      _animationController = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 300),
      );

      _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Sprung(30)),
      );
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
      );

      _animationController.forward();
    } catch (e, stackTrace) {
      AppLogger.e('Animation initialization error', e, stackTrace);
    }
  }

  /// Checks if the app is running on an emulator.
  /// This method is currently a placeholder for future implementation.
  Future<void> _checkEmulator() async {
    // TODO(developer): Add emulator check logic if needed in the future.
    AppLogger.i('Device check completed');
  }

  /// Displays a dialog to choose the photo source (camera or gallery).
  ///
  /// Uses MediaPermissionHandler with on-demand permission requests.
  /// Permissions will be requested only when user chooses camera or gallery.
  Future<void> _showPhotoSourceDialog() async {
    if (!mounted) return;

    AppLogger.i('📸 Analysis screen: Starting photo source selection');

    try {
      final selectedImage = await MediaPermissionHandler.instance.selectMedia(context);
      
      if (selectedImage != null && mounted) {
        final file = File(selectedImage.path);
        setState(() {
          _selectedImage = file;
        });
        
        HapticFeedback.lightImpact();
        _animationController.forward(from: 0.0);
        AppLogger.i('✅ Analysis screen: Image selected successfully: ${selectedImage.path}');
      } else {
        AppLogger.i('ℹ️ Analysis screen: User cancelled image selection or permission denied');
      }
    } catch (e) {
      AppLogger.e('❌ Analysis screen: Error in photo selection', e);
      if (mounted) {
        await _showErrorDialog('photo_selection_error'.locale(context));
      }
    }
  }




  /// Shows an action sheet with options for the selected image.
  ///
  /// Options include changing the photo or deleting it.
  Future<void> _showImageOptionsMenu() async {
    if (!mounted) return;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text('photo_ops'.locale(context)),
        actions: <CupertinoActionSheetAction>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _showPhotoSourceDialog();
            },
            child: Text('change_photo'.locale(context)),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              setState(() => _selectedImage = null);
              AppLogger.i('Photo removed');
            },
            child: Text('delete_photo'.locale(context)),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Displays a generic error dialog.
  ///
  /// If [needsPremium] is true, it shows a dialog prompting the user
  /// to upgrade to a premium plan. Otherwise, a standard error dialog is shown.
  Future<void> _showErrorDialog(String message,
      {bool needsPremium = false}) async {
    if (!mounted) return;

    if (needsPremium) {
      await AppDialogManager.showPremiumRequiredDialog(
        context: context,
        title: 'premium_required_title'.locale(context),
        message: message,
        onPremiumButtonPressed: () {
          if (mounted) {
            context.go(RoutePaths.premium);
          }
        },
      );
    } else {
      await AppDialogManager.showErrorDialog(
        context: context,
        title: 'error'.locale(context),
        message: message,
      );
    }
  }

  /// Shows a generic Cupertino action sheet for selecting an item from a list.
  ///
  /// This method is used to display selection dialogs for provinces, districts,
  /// and neighborhoods in a consistent way.
  ///
  /// - [title]: The title of the action sheet.
  /// - [message]: A descriptive message displayed below the title.
  /// - [items]: A list of items to be displayed as actions.
  /// - [onItemSelected]: A callback that is triggered when an item is selected.
  void _showLocationSelectionSheet<T>({
    required String title,
    required String message,
    required List<T> items,
    required String Function(T) itemTitleBuilder,
    required VoidCallback Function(T) onItemSelected,
  }) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => CupertinoActionSheet(
        title: Text(title),
        message: Text(message),
        actions: items
            .map(
              (item) => CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.of(context).pop(); // Önce modal'ı kapat
                  onItemSelected(item)(); // Sonra callback'i çağır
                },
                child: Text(itemTitleBuilder(item)),
              ),
            )
            .toList(),
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          isDestructiveAction: true,
          child: Text('cancel'.locale(context)),
        ),
      ),
    );
  }

  /// Shows the province selection action sheet.
  ///
  /// If provinces are not yet loaded, it initiates the loading process.
  void _showProvinceSelection() {
    if (_loadingProvinces) {
      _showLoadingDialog('provinces_loading'.locale(context));
      return;
    }

    if (_provinces.isEmpty) {
      _loadProvinces();
      _showErrorDialog('provinces_not_loaded'.locale(context));
      return;
    }

    _showLocationSelectionSheet<Province>(
      title: 'select_province'.locale(context),
      message: 'select_province_desc'.locale(context),
      items: _provinces,
      itemTitleBuilder: (province) => province.name,
      onItemSelected: (province) => () {
        setState(() {
          _selectedProvince = province;
          _updateLocationText();
        });

        // After selecting a province, load its districts.
        _loadDistricts(province).then((_) {
          // Automatically show the district selection dialog.
          if (_districts.isNotEmpty && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showDistrictSelection();
              }
            });
          }
        });
      },
    );
  }

  /// Shows the district selection action sheet.
  ///
  /// Requires a province to be selected first.
  void _showDistrictSelection() {
    if (_selectedProvince == null) {
      _showErrorDialog('select_province_first'.locale(context));
      return;
    }

    if (_loadingDistricts) {
      _showLoadingDialog('districts_loading'.locale(context));
      return;
    }

    if (_districts.isEmpty) {
      _loadDistricts(_selectedProvince!);
      _showErrorDialog('districts_not_loaded'.locale(context));
      return;
    }

    _showLocationSelectionSheet<District>(
      title: 'select_district'.locale(context),
      message: 'select_district_desc'.locale(context),
      items: _districts,
      itemTitleBuilder: (district) => district.name,
      onItemSelected: (district) => () {
        setState(() {
          _selectedDistrict = district;
          _updateLocationText();
        });

        // After selecting a district, load its neighborhoods.
        _loadNeighborhoods(_selectedProvince!, district).then((_) {
          // Automatically show the neighborhood selection dialog.
          if (_neighborhoods.isNotEmpty && mounted) {
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                _showNeighborhoodSelection();
              }
            });
          }
        });
      },
    );
  }

  /// Shows the neighborhood selection action sheet.
  ///
  /// Requires a district to be selected first.
  void _showNeighborhoodSelection() {
    if (_selectedDistrict == null) {
      _showErrorDialog('select_district_first'.locale(context));
      return;
    }

    if (_loadingNeighborhoods) {
      _showLoadingDialog('neighborhoods_loading'.locale(context));
      return;
    }

    if (_neighborhoods.isEmpty) {
      _loadNeighborhoods(_selectedProvince!, _selectedDistrict!);
      _showErrorDialog('neighborhoods_not_loaded'.locale(context));
      return;
    }

    _showLocationSelectionSheet<Neighborhood>(
      title: 'select_neighborhood'.locale(context),
      message: 'select_neighborhood_desc'.locale(context),
      items: _neighborhoods,
      itemTitleBuilder: (neighborhood) => neighborhood.name,
      onItemSelected: (neighborhood) => () {
        setState(() {
          _selectedNeighborhood = neighborhood;
          _updateLocationText();
        });

        // After location selection is complete, guide the user.
        if (_selectedImage != null) {
          // If an image is already selected, provide haptic feedback
          // to draw attention to the analysis button.
          HapticFeedback.mediumImpact();
        } else {
          // If no image is selected, prompt the user to choose one.
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              _showPhotoSourceDialog();
            }
          });
        }
      },
    );
  }

  /// Shows a temporary loading dialog.
  ///
  /// The dialog displays an activity indicator and a [message].
  /// It automatically dismisses after 2 seconds.
  void _showLoadingDialog(String message) {
    if (!mounted) return;

    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CupertinoActivityIndicator(),
            const SizedBox(height: 8),
            Text(message),
          ],
        ),
      ),
    );

    // Automatically close the dialog after a short period.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        try {
          if (Navigator.of(context).canPop()) {
            Navigator.pop(context);
          }
        } catch (e) {
          AppLogger.w('Loading dialog auto-close error: $e');
        }
      }
    });
  }

  /// Orchestrates the entire analysis process by calling validation and execution steps.
  void _startAnalysis() async {
    if (!_validateInputs()) {
      return;
    }

    final authState = await _ensureUserIsAuthenticated();
    if (authState == null) {
      return; // Authentication failed
    }

    final canProceed = await _checkAnalysisCredits(authState);
    if (!canProceed) {
      return; // Insufficient credits
    }

    // If all checks pass, proceed with the analysis.
    _initiateAnalysis(authState.user);
  }

  /// Validates that an image and location have been selected.
  /// Returns `true` if inputs are valid, otherwise shows an error and returns `false`.
  bool _validateInputs() {
    if (_selectedImage == null) {
      _showErrorDialog('select_photo_first'.locale(context));
      return false;
    }

    final currentLanguage =
        LocalizationManager.instance.currentLocale.languageCode;
    bool isLocationMissing = false;

    if (currentLanguage == 'tr') {
      if (_selectedProvince == null ||
          _selectedDistrict == null ||
          _selectedNeighborhood == null) {
        isLocationMissing = true;
      }
    } else {
      if (_locationController.text.trim().isEmpty) {
        isLocationMissing = true;
      }
    }

    if (isLocationMissing) {
      _showErrorDialog('select_location_first'.locale(context));
      return false;
    }

    return true;
  }

  /// Ensures the user is authenticated.
  ///
  /// If the user is not logged in, it attempts to sign in anonymously.
  /// Returns [AuthAuthenticated] state if successful, otherwise `null`.
  Future<AuthAuthenticated?> _ensureUserIsAuthenticated() async {
    final authCubit = context.read<AuthCubit>();
    if (authCubit.state is AuthAuthenticated) {
      return authCubit.state as AuthAuthenticated;
    }

    AppLogger.w('User not authenticated, attempting anonymous sign-in...');
    try {
      await authCubit.signInAnonymously();
      final newAuthState = authCubit.state;
      if (newAuthState is AuthAuthenticated) {
        return newAuthState;
      } else {
        if (mounted) {
          await _showErrorDialog('auth_required_for_analysis'.locale(context));
        }
        return null;
      }
    } catch (e) {
      AppLogger.e('Anonymous sign-in error: $e');
      if (mounted) {
        await _showErrorDialog('auth_login_error'.locale(context));
      }
      return null;
    }
  }

  /// Checks if the user has enough credits or is a premium user.
  ///
  /// Performs a real-time check against Firestore for accuracy.
  /// Returns `true` if the user can proceed, otherwise `false`.
  Future<bool> _checkAnalysisCredits(AuthAuthenticated authState) async {
    final currentUser = authState.user;
    AppLogger.i(
        'Checking analysis credits for user: ${currentUser.analysisCredits}, Premium: ${currentUser.isPremium}');

    try {
      final firestoreService = ServiceLocator.get<FirestoreService>();
      final userDoc = await firestoreService.firestore
          .collection('users')
          .doc(currentUser.id)
          .get();

      bool canProceed = false;
      if (userDoc.exists) {
        final userData = userDoc.data();
        final realTimeCredits = userData?['analysisCredits'] ?? 0;
        final realTimePremium = userData?['isPremium'] ?? false;
        AppLogger.i(
            'Real-time Firestore credit check - User: ${currentUser.id}, Credits: $realTimeCredits, Premium: $realTimePremium');
        canProceed = realTimePremium || realTimeCredits > 0;
      } else {
        AppLogger.w(
            'User document not found in Firestore, using cached data as fallback.');
        canProceed = currentUser.isPremium || currentUser.analysisCredits > 0;
      }

      if (!canProceed) {
        AppLogger.w('User has no analysis credits, showing premium dialog.');
        if (mounted) {
          await _showErrorDialog(
            'free_analysis_limit_reached'.locale(context),
            needsPremium: true,
          );
        }
        return false;
      }

      AppLogger.i('Credit validation passed.');
      return true;
    } catch (firestoreError) {
      AppLogger.w(
          'Firestore credit check failed, using cached data as fallback: $firestoreError');
      // Fallback to cached data if Firestore query fails.
      final canProceed =
          currentUser.isPremium || currentUser.analysisCredits > 0;
      if (!canProceed) {
        if (mounted) {
          await _showErrorDialog(
            'free_analysis_limit_reached'.locale(context),
            needsPremium: true,
          );
        }
        return false;
      }
      return true;
    }
  }

  /// Triggers the actual image analysis process.
  void _initiateAnalysis(UserModel user) {
    // Double-check Firebase Auth user status just before the final call.
    if (FirebaseAuth.instance.currentUser == null) {
      _showErrorDialog('firebase_auth_error'.locale(context));
      AppLogger.e('Critical: Firebase user became null before analysis call.');
      return;
    }

    HapticFeedback.heavyImpact();

    context.read<PlantAnalysisCubitDirect>().analyzeImageDirect(
          imageFile: _selectedImage!,
          user: user,
          location: _locationController.text.trim(),
          province: _selectedProvince?.name,
          district: _selectedDistrict?.name,
          neighborhood: _selectedNeighborhood?.name,
          fieldName: _fieldNameController.text.trim().isNotEmpty
              ? _fieldNameController.text.trim()
              : null,
        );
  }

  /// Fetches the list of provinces from the location service.
  Future<void> _loadProvinces() async {
    if (!mounted) return;
    setState(() => _loadingProvinces = true);
    try {
      final provinces = await _locationService.getProvinces();
      if (mounted) {
        setState(() {
          _provinces = provinces;
          _loadingProvinces = false;
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load provinces', e);
      if (mounted) {
        setState(() => _loadingProvinces = false);
        _showErrorDialog('provinces_load_error'.locale(context));
      }
    }
  }

  /// Fetches the list of districts for the selected [province].
  ///
  /// This also resets the selected district and neighborhood.
  Future<void> _loadDistricts(Province province) async {
    if (!mounted) return;
    setState(() {
      _loadingDistricts = true;
      _districts = [];
      _selectedDistrict = null;
      _neighborhoods = [];
      _selectedNeighborhood = null;
      _updateLocationText();
    });
    try {
      final districts = await _locationService.getDistricts(province.name);
      if (mounted) {
        setState(() {
          _districts = districts;
          _loadingDistricts = false;
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load districts', e);
      if (mounted) {
        setState(() => _loadingDistricts = false);
        _showErrorDialog('districts_load_error'.locale(context));
      }
    }
  }

  /// Fetches the list of neighborhoods for the selected [district].
  ///
  /// This also resets the selected neighborhood.
  Future<void> _loadNeighborhoods(Province province, District district) async {
    if (!mounted) return;
    setState(() {
      _loadingNeighborhoods = true;
      _neighborhoods = [];
      _selectedNeighborhood = null;
      _updateLocationText();
    });
    try {
      final neighborhoods =
          await _locationService.getNeighborhoods(province.name, district.name);
      if (mounted) {
        setState(() {
          _neighborhoods = neighborhoods;
          _loadingNeighborhoods = false;
        });
      }
    } catch (e) {
      AppLogger.e('Failed to load neighborhoods', e);
      if (mounted) {
        setState(() => _loadingNeighborhoods = false);
        _showErrorDialog('neighborhoods_load_error'.locale(context));
      }
    }
  }

  /// Updates the location text field with the selected province,
  /// district, and neighborhood.
  void _updateLocationText() {
    final parts = [
      _selectedProvince?.name,
      _selectedDistrict?.name,
      _selectedNeighborhood?.name,
    ];
    _locationController.text = parts.where((p) => p != null).join('/');
  }

  // Premium navigation artık HomePremiumCard widget'ı içinde handle ediliyor
}
