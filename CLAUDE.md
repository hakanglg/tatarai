# Claude Instructions for Tatar AI Project

## Project Overview
This is a Flutter mobile application for plant analysis using AI (Gemini). The app provides plant identification, health analysis, and premium features through RevenueCat integration.

## Project Structure
- **lib/**: Main Flutter application code
  - **core/**: Core services, utilities, and widgets
    - **services/**: AI services, payment, localization
    - **widgets/**: Reusable UI components
  - **features/**: Feature-specific modules
    - **auth/**: Authentication (login/register)
    - **home/**: Home screen and dashboard
    - **plant_analysis/**: Plant analysis and results
    - **settings/**: App settings and preferences
    - **payment/**: Payment and subscription handling
    - **splash/**: Splash screen and initialization
- **assets/**: Static assets including translations
- **ios/**: iOS-specific configuration

## Development Guidelines

### Code Standards
- Follow Flutter/Dart conventions
- Use BLoC pattern with Cubits for state management
- Implement proper error handling
- Use localization for all user-facing text
- Follow the existing file structure and naming conventions

## Coding Rules

### General Principles
- Use English for all code (identifiers, comments) and documentation
- Always explicitly specify types for variables, function parameters, and return values
- Avoid using the any type; prefer precise types or generics to maintain type safety
- Define custom types or classes as needed rather than overusing primitive types
- Do not leave unnecessary blank lines within function bodies – keep code blocks compact
- Limit each source file to a single responsibility (e.g. one public class or one widget per file)

### Naming Conventions
- Use PascalCase for class names (e.g. MyAwesomeWidget)
- Use camelCase for variable, function, and method names (e.g. isLoading, fetchData())
- Use snake_case (all lowercase, words separated by _) for file and directory names
- Use UPPER_SNAKE_CASE for constant values and environment variables
- Avoid magic numbers or strings in code; define them as named constants for clarity
- Use descriptive, complete words in identifiers. Avoid abbreviations unless they are standard
- Accepted exceptions are common acronyms (API, URL, HTTP) or conventional short names (i, j for loop indices; err for error objects; ctx for context; req, res, next in middleware, etc.)

### Functions and Methods
- Keep functions short and focused, ideally under 20 lines of code and doing one specific task
- Name functions as verbs or verb phrases that clearly describe their action (e.g. calculateTotal, sendRequest)
- If a function returns a boolean, start its name with is, has, or can (e.g. isAuthenticated())
- If a function performs an action and returns void, use an imperative verb (e.g. initiateUpload(), saveData())
- Avoid deeply nested logic inside functions. Use early returns, guard clauses, or split out helper functions
- Use higher-order functions and collection methods (like map, filter, reduce) instead of manual loops
- Use arrow function syntax for simple single-expression functions
- Use default parameter values for optional parameters instead of requiring null checks inside the function
- Reduce the number of parameters a function takes by grouping related parameters into an object
- Maintain a single level of abstraction within a function

### Data and State Management
- Encapsulate related data into composite types (classes/structs) instead of passing around lots of individual primitives
- Avoid scattered data validation logic. Validate inputs at boundaries or within data classes themselves
- Prefer immutability for data objects. Use final for variables that should not change after initialization
- Mark literal values and collections as const wherever possible
- Use immutable data classes or patterns (e.g. the Freezed package) to represent UI state or model objects

### Classes and Object-Oriented Design
- Follow SOLID object-oriented design principles (Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion)
- Favor composition over inheritance: use mixins, extensions, or helper classes to share functionality
- Use abstract classes or interfaces to define clear contracts for your classes' behavior
- Keep classes small and focused on a single purpose or responsibility
- Aim to keep each class under ~200 lines of code
- Limit the public API of a class to around 10 methods or fewer, and avoid having more than about 10 fields in a class

### Error Handling and Exceptions
- Use exceptions for unexpected error conditions only. Do not use exceptions for normal control flow
- When you throw an exception, provide a clear message or use a specific exception type
- Only catch exceptions if you can handle the error or need to add context
- If an exception cannot be meaningfully handled in place, allow it to propagate up to a higher-level error handler

### Testing
- Write unit tests for every public function or critical piece of logic
- Structure test code using the Arrange-Act-Assert pattern for clarity
- Name test variables and mocks clearly so their purpose is obvious
- Use test doubles (mocks, stubs, fakes) to simulate external dependencies or side effects in tests
- Write higher-level integration or acceptance tests for each module or feature
- When writing behavior-driven tests, use the Given-When-Then convention

### Flutter-Specific Best Practices
- **Architectural Pattern**: Use Clean Architecture principles to organize your Flutter project
- **State Management**: Use Riverpod (or a similar state management solution) to manage application state
- **Controller/ViewModel**: Employ a controller or ViewModel pattern for business logic. Keep widget UI classes lean
- **Repository Pattern**: Use the repository pattern for data access and persistence
- **Dependency Injection**: Use a service locator or dependency injection tool (e.g. get_it) to manage object creation
- **Factory Pattern**: Use factory constructors or factory classes to create complex objects
- **Navigation**: Use a routing package like AutoRoute to manage navigation declaratively
- **Extensions**: Use extension methods to add reusable functionality to existing classes
- **Theming**: Manage app theming with ThemeData and theming classes
- **Localization**: Use Flutter's internationalization tools for managing all user-facing text
- **Constants**: Centralize constant values in a dedicated constants file or class
- **Widget Tree Depth**: Avoid overly deep widget hierarchies
- **Reusable Widgets**: Break down large, complex widgets into smaller, reusable widgets
- **Const Constructors**: Wherever possible, declare your Flutter widgets as const

### Documentation Guidelines
- All public classes, methods, properties, getters, and setters must include `///` DartDoc comments
- Comments must clearly describe the purpose, behavior, parameters (if any), and return values
- Comments should explain "why" something is done, not "what" is done

### Theming & Styling Rules
- Do not use `TextStyle` directly in widgets
- Use `Theme.of(context).textTheme` or a centralized `AppTextStyles` class for all text styles
- Do not hardcode values for font size, font weight, letter spacing, or colors

### Layout & Sizing Rules
- Do not use hardcoded values for margin, padding, height, width, spacing, or radius
- Do not write raw values inside `EdgeInsets`, `SizedBox`, `Container`, etc.
- Always use context extensions from the `kartal` package or centralized constants such as `AppSizes`, `AppPaddings`, `AppRadius`, etc.

### Constants Management
- All visual and structural constants must be defined under centralized constant classes

### Repository & Service Layer
- All data access and external API logic must be handled via repository classes
- Implement caching inside the repository layer or a dedicated caching service
- Abstract services behind interfaces and avoid tightly coupled implementations

### State Management
- Use Cubit as the primary state management solution
- Keep UI code minimal and move all business logic to `ViewModel` classes

### Required Folder Structure
```
lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── services/
│   ├── widgets/
│   ├── utils/
│   └── network/
├── feature/
│   ├── auth/
│   ├── home/
│   └── profile/
└── main.dart
```

### Firebase CLI Usage
- Use Firebase CLI for all Firebase-related operations and deployments

### Key Services
- **GeminiService**: AI plant analysis integration
- **PaywallManager**: Premium feature and subscription handling
- **PermissionService**: Camera and storage permissions
- **ServiceLocator**: Dependency injection

### Testing
- Run `flutter test` to execute unit tests
- Use `flutter analyze` for static analysis
- Test on both iOS and Android platforms

### Build Commands
- **Development**: `flutter run`
- **Release**: `flutter build apk` or `flutter build ios`
- **Analysis**: `flutter analyze`
- **Tests**: `flutter test`

### Localization
- Translation files are in `assets/translations/`
- Support for English (en.json) and Turkish (tr.json)
- Use localization keys for all user-facing text

### Premium Features
- Managed through RevenueCat integration
- PaywallManager handles subscription logic
- Premium features gated behind subscription checks

## Important Notes
- Always test premium feature flows
- Ensure proper permission handling for camera/storage
- Follow iOS App Store guidelines for in-app purchases
- Maintain compatibility with both iOS and Android platforms