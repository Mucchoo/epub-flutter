Guide to app architecture
The recommended way to architect a Flutter app.

The following pages demonstrate how to build an app using best practices. The recommendations in this guide can be applied to most apps, making them easier to scale, test, and maintain. However, they're guidelines, not steadfast rules, and you should adapt them to your unique requirements.

This section provides a high-level overview of how Flutter applications can be architected. It explains the layers of an application, along with the classes that exist within each layer. The section after this provides concrete code samples and walks through a Flutter application that's implemented these recommendations.

Overview of project structure
Separation-of-concerns is the most important principle to follow when designing your Flutter app. Your Flutter application should split into two broad layers, the UI layer and the Data layer.

Each layer is further split into different components, each of which has distinct responsibilities, a well-defined interface, boundaries and dependencies. This guide recommends you split your application into the following components:

Views
View models
Repositories
Services
MVVM
If you've encountered the Model-View-ViewModel architectural pattern (MVVM), this will be familiar. MVVM is an architectural pattern that separates a feature of an application into three parts: the Model, the ViewModel and the View. Views and view models make up the UI layer of an application. Repositories and services represent the data of an application, or the model layer of MVVM. Each of these components is defined in the next section.

MVVM architectural pattern
Every feature in an application will contain one view to describe the UI and one view model to handle logic, one or more repositories as the sources of truth for your application data, and zero or more services that interact with external APIs, like client servers and platform plugins.

A single feature of an application might require all of the following objects:

An example of the Dart objects that might exist in one feature using the architecture described on page.
Each of these objects and the arrows that connect them will be explained thoroughly by the end of this page. Throughout this guide, the following simplified version of that diagram will be used as an anchor.

A simplified diagram of the architecture described on this page.
Note
Apps with complex logic might also have a logic layer that sits in between the UI layer and data layer. This logic layer is commonly called the domain layer. The domain layer contains additional components often called interactors or use-cases. The domain layer is covered later in this guide.

UI layer
An application's UI layer is responsible for interacting with the user. It displays an application's data to the user and receives user input, such as tap events and form inputs.

The UI reacts to data changes or user input. When the UI receives new data from a Repository, it should re-render to display that new data. When the user interacts with the UI, it should change to reflect that interaction.

The UI layer is made up of two architectural components, based on the MVVM design pattern:

Views describe how to present application data to the user. Specifically, they refer to compositions of widgets that make a feature. For instance, a view is often (but not always) a screen that has a Scaffold widget, along with all of the widgets below it in the widget tree. Views are also responsible for passing events to the view model in response to user interactions.
View models contain the logic that converts app data into UI State, because data from repositories is often formatted differently from the data that needs to be displayed. For example, you might need to combine data from multiple repositories, or you might want to filter a list of data records.
Views and view models should have a one-to-one relationship.

A simplified diagram of the architecture described on this page with the view and view model objects highlighted.

In the simplest terms, a view model manages the UI state and the view displays that state. Using views and view models, your UI layer can maintain state during configuration changes (such as screen rotations), and you can test the logic of your UI independently of Flutter widgets.

Note
'View' is an abstract term, and one view doesn't equal one widget. Widgets are composable, and several can be combined to create one view. Therefore, view models don't have a one-to-one relationship with widgets, but rather a one-to-one relationship with a collection of widgets.

A feature of an application is user centric, and therefore defined by the UI layer. Every instance of a paired view and view model defines one feature in your app. This is often a screen in your app, but it doesn't have to be. For example, consider logging in and out. Logging in is generally done on a specific screen whose only purpose is to provide the user with a way to log in. In the application code, the login screen would be made up of a LoginViewModel class and a LoginView class.

On the other hand, logging out of an app is generally not done on a dedicated screen. The ability to log out is generally presented to the user as a button in a menu, a user account screen, or any number of different locations. It's often presented in multiple locations. In such scenarios, you might have a LogoutViewModel and a LogoutView which only contains a single button that can be dropped into other widgets.

Views
In Flutter, views are the widget classes of your application. Views are the primary method of rendering UI, and shouldn't contain any business logic. They should be passed all data they need to render from the view model.

A simplified diagram of the architecture described on this page with the view object highlighted.

The only logic a view should contain is:

Simple if-statements to show and hide widgets based on a flag or nullable field in the view model
Animation logic
Layout logic based on device information, like screen size or orientation.
Simple routing logic
All logic related to data should be handled in the view model.

View models
A view model exposes the application data necessary to render a view. In the architecture design described on this page, most of the logic in your Flutter application lives in view models.

A simplified diagram of the architecture described on this page with the view model object highlighted.

A view model's main responsibilities include:

Retrieving application data from repositories and transforming it into a format suitable for presentation in the view. For example, it might filter, sort, or aggregate data.
Maintaining the current state needed in the view, so that the view can rebuild without losing data. For example, it might contain boolean flags to conditionally render widgets in the view, or a field that tracks which section of a carousel is active on screen.
Exposes callbacks (called commands) to the view that can be attached to an event handler, like a button press or form submission.
Commands are named for the command pattern, and are Dart functions that allow views to execute complex logic without knowledge of its implementation. Commands are written as members of the view model class to be called by the gesture handlers in the view class.

You can find examples of views, view models, and commands on the UI layer portion of the App architecture case study.

For a gentle introduction to MVVM in Flutter, check out the state management fundamentals.

Data layer
The data layer of an app handles your business data and logic. Two pieces of architecture make up the data layer: services and repositories. These pieces should have well-defined inputs and outputs to simplify their reusability and testability.

A simplified diagram of the architecture described on this page with the Data layer highlighted.

Using MVVM language, services and repositories make up your model layer.

Repositories
Repository classes are the source of truth for your model data. They're responsible for polling data from services, and transforming that raw data into domain models. Domain models represent the data that the application needs, formatted in a way that your view model classes can consume. There should be a repository class for each different type of data handled in your app.

Repositories handle the business logic associated with services, such as:

Caching
Error handling
Retry logic
Refreshing data
Polling services for new data
Refreshing data based on user actions
A simplified diagram of the architecture described on this page with the Repository object highlighted.

Repositories output application data as domain models. For example, a social media app might have a UserProfileRepository class that exposes a Stream<UserProfile?>, which emits a new value whenever the user signs in or out.

The models output by repositories are consumed by view models. Repositories and view models have a many-to-many relationship. A view model can use many repositories to get the data it needs, and a repository can be used by many view models.

Repositories should never be aware of each other. If your application has business logic that needs data from two repositories, you should combine the data in the view model or in the domain layer, especially if your repository-to-view-model relationship is complex.

Managing app-wide session state
Because repositories are the single source of truth for application data, they are also the ideal place to manage app-wide lifecycle state—state that needs to be shared across multiple view models but shouldn't persist beyond the current application session.

Examples of app-wide lifecycle state include an active user session, in-memory data caches, or transient application settings. Because view models and repositories have a many-to-many relationship, multiple view models can depend on the same repository instance (typically managed through a service locator or dependency injection container). This allows distinct features to reactively observe and modify the same shared state through streams and methods exposed by the repository, without violating the clean one-to-one boundary between a view and its view model.

Services
Services are in the lowest layer of your application. They wrap API endpoints and expose asynchronous response objects, such as Future and Stream objects. They're only used to isolate data-loading, and they hold no state. Your app should have one service class per data source. Examples of endpoints that services might wrap include:

The underlying platform, like iOS and Android APIs
REST endpoints
Local files
As a rule of thumb, services are most helpful when the necessary data lives outside of your application's Dart code - which is true of each of the preceding examples.

Services and repositories have a many-to-many relationship. A single Repository can use several services, and a service can be used by multiple repositories.

A simplified diagram of the architecture described on this page with the Service object highlighted.

Optional: Domain layer
As your app grows and adds features, you might need to abstract away logic that adds too much complexity to your view models. These classes are often called interactors or use-cases.

Use-cases are responsible for making interactions between the UI and Data layers simpler and more reusable. They take data from repositories and make it suitable for the UI layer.

MVVM design pattern with an added domain layer object

Use-cases are primarily used to encapsulate business logic that would otherwise live in the view model and meets one or more of the following conditions:

Requires merging data from multiple repositories
Is exceedingly complex
The logic will be reused by different view models
This layer is optional because not all applications or features within an application have these requirements. If you suspect your application would benefit from this additional layer, consider the pros and cons:

Pros	Cons
✅ Avoid code duplication in view models	❌ Increases complexity of your architecture, adding more classes and higher cognitive load
✅ Improve testability by separating complex business logic from UI logic	❌ Testing requires additional mocks
✅ Improve code readability in view models	❌ Adds additional boilerplate to your code
Data access with use-cases
Another consideration when adding a Domain layer is whether view models will continue to have access to repository data directly, or if you'll enforce view models to go through use-cases to get their data. Put another way, will you add use-cases as you need them? Perhaps when you notice repeated logic in your view models? Or, will you create a use-case each time a view model needs data, even if the logic in the use-case is simple?

If you choose to do the latter, it intensifies the earlier outlined pros and cons. Your application code will be extremely modular and testable, but it also adds a significant amount of unnecessary overhead.

A good approach is to add use-cases only when needed. If you find that your view models are accessing data through use-cases most of the time, you can always refactor your code to utilize use-cases exclusively. The example app used later in this guide has use-cases for some features, but also has view models that interact with repositories directly. A complex feature might ultimately end up looking like this:

A simplified diagram of the architecture described on this page with a use case object.

This method of adding use-cases is defined by the following rules:

Use-cases depend on repositories
Use-cases and repositories have a many-to-many relationship
View models depend on one or more use-cases and one or more repositories
This method of using use-cases ends up looking less like a layered lasagna, and more like a plated dinner with two mains (UI and data layers) and a side (domain layer). Use-cases are just utility classes that have well-defined inputs and outputs. This approach is flexible and extendable, but it requires greater diligence to maintain order.

---
title: Architecture case study
shortTitle: Architecture case study
description: >-
  A walk-through of a Flutter app that implements the MVVM architectural pattern.
prev:
  title: Guide to app architecture
  path: /app-architecture/guide
next:
  title: UI Layer
  path: /app-architecture/case-study/ui-layer
---

The code examples in this guide are from the [Compass sample application][],
an app that helps users build and book itineraries for trips.
It's a robust sample application with many features, routes, and screens.
The app communicates with an HTTP server,
has development and production environments,
includes brand-specific styling, and contains high test coverage.
In these ways and more, it simulates a real-world,
feature-rich Flutter application.

<div class="wrapping-row" style="margin-block-end: 2rem">
  <DashImage figure image="app-architecture/case-study/splash_screen.png" alt="A screenshot of the splash screen of the compass app." img-style="max-height: 400px;" />
  <DashImage figure image="app-architecture/case-study/home_screen.png" alt="A screenshot of the home screen of the compass app." img-style="max-height: 400px;" />
  <DashImage figure image="app-architecture/case-study/search_form_screen.png" alt="A screenshot of the search form screen of the compass app." img-style="max-height: 400px;" />
  <DashImage figure image="app-architecture/case-study/booking_screen.png" alt="A screenshot of the booking screen of the compass app." img-style="max-height: 400px;" />
</div>

The Compass app's architecture most resembles the [MVVM architectural pattern][]
as described in Flutter's [app architecture guidelines][].
This architecture case study demonstrates how to
implement those guidelines by walking through
the "Home" feature of the compass app.
If you aren't familiar with MVVM, you should read those guidelines first.

The Home screen of the Compass app displays user account information and
a list of the user's saved trips.
From this screen you can log out, open detailed trip pages,
delete saved trips, and navigate to the first page of the core app flow,
which allows the user to build a new itinerary.

In this case study, you'll learn the following:

* How to implement Flutter's [app architecture guidelines][]
  using repositories and services in the [data layer][] and
  the MVVM architectural pattern in the [UI layer][]
* How to use the [Command pattern][] to safely render UI as data changes
* How to use [`ChangeNotifier`][] and [`Listenable`][] objects to manage state
* How to implement [Dependency Injection][] using `package:provider`
* How to [set up tests][] when following the recommended architecture
* Effective [package structure][] for large Flutter apps

This case-study was written to be read in order.
Any given page might reference the previous pages.

The code examples in this case-study include all the details needed to
understand the architecture, but they're not complete, runnable snippets.
If you prefer to follow along with the full app,
you can find it on [GitHub][].

## Package structure

Well-organized code is easier for multiple engineers to work on with
minimal code conflicts and is easier for new engineers to
navigate and understand.
Code organization both benefits and benefits from well-defined architecture.

There are two popular means of organizing code:

1. By feature - The classes needed for each feature are grouped together. For
   example, you might have an `auth` directory, which would contain files
   like `auth_viewmodel.dart`, `login_usecase.dart`, `logout_usecase.dart`,
   `login_screen.dart`, `logout_button.dart`, etc.
2. By type - Each "type" of architecture is grouped together.
   For example, you might have directories such as
   `repositories`, `models`, `services`, and `viewmodels`.

The architecture recommended in this guide lends itself to
a combination of the two.
Data layer objects (repositories and services) aren't tied to a single feature,
while UI layer objects (views and view models) are.
The following is how the code is organized within the Compass application.

<FileTree>

- lib/
  - ui/
    - core/
      - ui/ 
        - <shared_widgets>
      - themes/
    - <feature_name>/
      - view_models/
        - <view_model_class>.dart
      - widgets/
        - <feature_name>_screen.dart
        - <other_widgets>
  - domain/
    - models/
      - <model_name>.dart
  - data/
    - repositories/
      - <repository_class>.dart
    - services/
      - <service_class>.dart
    - model/
      - <api_model_class>.dart
  - config/
  - utils/
  - routing/
  - main_staging.dart
  - main_development.dart
  - main.dart
- test/ // Contains unit and widget tests.
  - data/
  - domain/
  - ui/
  - utils/
- testing/ // Contains mocks that other classes need to execute tests.
  - fakes/
  - models/

</FileTree>

Most of the application code lives in the
`data`, `domain`, and `ui` folders.
The data folder organizes code by type,
because repositories and services can be used across
different features and by multiple view models.
The ui folder organizes the code by feature,
because each feature has exactly one view and exactly one view model.

Other notable features of this folder structure:

* The UI folder also contains a subdirectory named "core".
  Core contains widgets and theme logic that is shared by multiple views,
  such as buttons with your brand styling.
* The domain folder contains the application data types, because they're
  used by the data and ui layers.
* The app contains three "main" files, which act as different entry points to
  the application for development, staging, and production.
* There are two test-related directories at the same level as `lib`: `test/` has
  the test code, and its own structure matches `lib/`. `testing/` is a
  subpackage that contains mocks and other testing utilities which can be used
  in other packages' test code. The `testing/` folder could be described as a
  version of your app that you don't ship. It's the content that is tested.

There's additional code in the compass app that doesn't pertain to architecture.
For the full package structure, [view it on GitHub][].

## Other architecture options

The example in this case-study demonstrates how one application abides by our
recommended architectural rules, but there are many other example apps that
could've been written. The UI of this app leans heavily on view models
and `ChangeNotifier`, but it could've easily been written
with streams, or with other libraries such as [`riverpod`][],
[`flutter_bloc`][], and [`signals`][].
The communication between layers of this app handled
everything with method calls, including polling for new data.
It could've instead used streams to expose data from a repository to
a view model and still abide by the rules covered in this guide.

Even if you do follow this guide exactly,
and choose not to introduce additional libraries, you have decisions to make:
Will you have a domain layer?
If so, how will you manage data access?
The answer depends so much on an individual team's needs that
there isn't a single right answer.
Regardless of how you answer these questions,
the principles in this guide will help you write scalable Flutter apps.

And if you squint, aren't all architectures MVVM anyway?

[Compass sample application]: https://github.com/flutter/samples/tree/main/compass_app
[MVVM architectural pattern]: https://en.wikipedia.org/wiki/Model%E2%80%93view%E2%80%93viewmodel
[app architecture guidelines]: /app-architecture/guide
[data layer]: /app-architecture/case-study/data-layer
[UI layer]: /app-architecture/case-study/ui-layer
[Command pattern]: /app-architecture/case-study/ui-layer#command-objects
[`ChangeNotifier`]: {{site.api}}/flutter/foundation/ChangeNotifier-class.html
[`Listenable`]: {{site.api}}/flutter/foundation/Listenable-class.html
[Dependency Injection]: /app-architecture/case-study/dependency-injection
[set up tests]: /app-architecture/case-study/testing
[view it on GitHub]: https://github.com/flutter/samples/tree/main/compass_app
[GitHub]: https://github.com/flutter/samples/tree/main/compass_app
[`riverpod`]: {{site.pub-pkg}}/riverpod
[`flutter_bloc`]: {{site.pub-pkg}}/flutter_bloc
[`signals`]: {{site.pub-pkg}}/signals
[package structure]: /app-architecture/case-study#package-structure

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="case-study/index"

---
title: Data layer
shortTitle: Data layer
description: >-
  A walk-through of the data layer of an app that implements MVVM architecture.
prev:
  title: UI layer
  path: /app-architecture/case-study/ui-layer
next:
  title: Dependency Injection
  path: /app-architecture/case-study/dependency-injection
---


The data layer of an application, known as the *model* in MVVM terminology,
is the source of truth for all application data.
As the source of truth,
it's the only place that application data should be updated.

It's responsible for consuming data from various external APIs,
exposing that data to the UI,
handling events from the UI that require data to be updated,
and sending update requests to those external APIs as needed.

The data layer in this guide has two main components,
[repositories][] and [services][].

![A diagram that highlights the data layer components of an application.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Data-highlighted.png)

* **Repositories** are the source of the truth for application data, and contain
  logic that relates to that data, like updating the data in response to new
  user events or polling for data from services. Repositories are responsible
  for synchronizing the data when offline capabilities are supported, managing
  retry logic, and caching data.
* **Services** are stateless Dart classes that interact with APIs, like HTTP
  servers and platform plugins. Any data that your application needs that isn't
  created inside the application code itself should be fetched from within
  service classes.

## Define a service

A service class is the least ambiguous of all the architecture components.
It's stateless, and its functions don't have side effects.
Its only job is to wrap an external API.
There's generally one service class per data source,
such as a client HTTP server or a platform plugin.


![A diagram that shows the inputs and outputs of service objects.](/assets/images/docs/app-architecture/case-study/mvvm-case-study-services-architecture.png)

In the Compass app, for example, there's an [`APIClient`][] service that
handles the CRUD calls to the client-facing server.

```dart title=api_client.dart
class ApiClient {
  // Some code omitted for demo purposes.

  Future<Result<List<ContinentApiModel>>> getContinents() async { /* ... */ }

  Future<Result<List<DestinationApiModel>>> getDestinations() async { /* ... */ }

  Future<Result<List<ActivityApiModel>>> getActivityByDestination(String ref) async { /* ... */ }

  Future<Result<List<BookingApiModel>>> getBookings() async { /* ... */ }

  Future<Result<BookingApiModel>> getBooking(int id) async { /* ... */ }

  Future<Result<BookingApiModel>> postBooking(BookingApiModel booking) async { /* ... */ }

  Future<Result<void>> deleteBooking(int id) async { /* ... */ }

  Future<Result<UserApiModel>> getUser() async { /* ... */ }
}
```

The service itself is a class,
where each method wraps a different API endpoint and
exposes asynchronous response objects.
Continuing the earlier example of deleting a saved booking,
the `deleteBooking` method returns a `Future<Result<void>>`.

:::note
Some methods return data classes that are
specifically for raw data from the API,
such as the `BookingApiModel` class.
As you'll soon see, repositories extract data and
expose it in a different format.
:::


## Define a repository

A repository's sole responsibility is to manage application data.
A repository is the source of truth for a single type of application data,
and it should be the only place where that data type is mutated.
The repository is responsible for polling new data from external sources,
handling retry logic, managing cached data,
and transforming raw data into domain models.

![A diagram that highlights the repository component of an application.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Repository-highlighted.png)

You should have a separate repository for
each different type of data in your application.
For example, the Compass app has repositories called `UserRepository`,
`BookingRepository`, `AuthRepository`, `DestinationRepository`, and more.

The following example is the `BookingRepository` from the Compass app,
and shows the basic structure of a repository.

```dart title=booking_repository_remote.dart
class BookingRepositoryRemote implements BookingRepository {
  BookingRepositoryRemote({
    required ApiClient apiClient,
  }) : _apiClient = apiClient;

  final ApiClient _apiClient;
  List<Destination>? _cachedDestinations;

  Future<Result<void>> createBooking(Booking booking) async {...}
  Future<Result<Booking>> getBooking(int id) async {...}
  Future<Result<List<BookingSummary>>> getBookingsList() async {...}
  Future<Result<void>> delete(int id) async {...}
}
```

:::note Development versus staging environments
The class in the previous example is `BookingRepositoryRemote`,
which extends an abstract class called `BookingRepository`.
This base class is used to create repositories for different environments.
For example, the compass app also has a class called `BookingRepositoryLocal`,
which is used for local development.

You can see the differences between the
[`BookingRepository` classes on GitHub][].
:::


The `BookingRepository` takes the `ApiClient` service as an input,
which it uses to get and update the raw data from the server.
It's important that the service is a private member,
so that the UI layer can't bypass the repository and call a service directly.

With the `ApiClient` service,
the repository can poll for updates to a user's saved bookings that
might happen on the server, and make `POST` requests to delete saved bookings.

The raw data that a repository transforms into application models can come from
multiple sources and multiple services,
and therefore repositories and services have a many-to-many relationship.
A service can be used by any number of repositories,
and a repository can use more than one service.

![A diagram that highlights the data layer components of an application.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Data-highlighted.png)

### Domain models

The `BookingRepository` outputs `Booking` and `BookingSummary` objects,
which are *domain models*.
All repositories output corresponding domain models.
These data models differ from API models in that they only contain the data
needed by the rest of the app.
API models contain raw data that often needs to be filtered,
combined, or deleted to be useful to the app's view models.
The repo refines the raw data and outputs it as domain models.

In the example app, domain models are exposed through
return values on methods like `BookingRepository.getBooking`.
The `getBooking` method is responsible for getting the raw data from
the `ApiClient` service, and transforming it into a `Booking` object.
It does this by combining data from multiple service endpoints.

```dart title=booking_repository_remote.dart highlightLines=14-21
// This method was edited for brevity.
Future<Result<Booking>> getBooking(int id) async {
  try {
    // Get the booking by ID from server.
    final resultBooking = await _apiClient.getBooking(id);
    if (resultBooking is Error<BookingApiModel>) {
      return Result.error(resultBooking.error);
    }
    final booking = resultBooking.asOk.value;

    final destination = _apiClient.getDestination(booking.destinationRef);
    final activities = _apiClient.getActivitiesForBooking(
            booking.activitiesRef);

    return Result.ok(
      Booking(
        startDate: booking.startDate,
        endDate: booking.endDate,
        destination: destination,
        activity: activities,
      ),
    );
  } on Exception catch (e) {
    return Result.error(e);
  }
}
```

:::note
In the Compass app, service classes return `Result` objects.
`Result` is a utility class that wraps asynchronous calls and
makes it easier to handle errors and manage UI state that relies
on asynchronous calls.

This pattern is a recommendation, but not a requirement.
The architecture recommended in this guide can be implemented without it.

You can learn about this class in the [Result cookbook recipe][].
:::

### Complete the event cycle

Throughout this page, you've seen how a user can delete a saved booking,
starting with an event—a user swiping on a `Dismissible` widget.
The view model handles that event by delegating
the actual data mutation to the `BookingRepository`.
The following snippet shows the `BookingRepository.deleteBooking` method.

```dart title=booking_repository_remote.dart
Future<Result<void>> delete(int id) async {
  try {
    return _apiClient.deleteBooking(id);
  } on Exception catch (e) {
    return Result.error(e);
  }
}
```

The repository sends a `POST` request to the API client with
the `_apiClient.deleteBooking` method, and returns a `Result`.
The `HomeViewModel` consumes the `Result` and the data it contains,
then ultimately calls `notifyListeners`, completing the cycle.

[repositories]: /app-architecture/guide#repositories
[services]:  /app-architecture/guide#services
[`APIClient`]: https://github.com/flutter/samples/blob/main/compass_app/app/lib/data/services/api/api_client.dart
[`sealed`]: {{site.dart-site}}/language/class-modifiers#sealed
[`BookingRepository` classes on GitHub]: https://github.com/flutter/samples/tree/main/compass_app/app/lib/data/repositories/booking
[Result cookbook recipe]: /app-architecture/design-patterns/result

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="case-study/data-layer"

---
title: Communicating between layers
shortTitle: Dependency injection
description: >-
  How to implement dependency injection to communicate between MVVM layers.
prev:
  title: Data layer
  path: /app-architecture/case-study/data-layer
next:
  title: Testing
  path: /app-architecture/case-study/testing
---

Along with defining clear responsibilities for each component of the architecture,
it's important to consider how the components communicate.
This refers to both the rules that dictate communication,
and the technical implementation of how components communicate.
An app's architecture should answer the following questions:

* Which components are allowed to communicate with which other components
  (including components of the same type)?
* What do these components expose as output to each other?
* How is any given layer 'wired up' to another layer?

![A diagram showing the components of app architecture.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified.png)

Using this diagram as a guide, the rules of engagement are as follows:

| Component  | Rules of engagement                                                                                                                                                                                                                                               |
|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| View       | <ol><li> A view is only aware of exactly one view model, and is never aware of any other layer or component. When created, Flutter passes the view model to the view as an argument, exposing the view model's data and command callbacks to the view. </li></ul> |
| ViewModel  | <ol><li>A ViewModel belongs to exactly one view, which can see its data, but the model never needs to know that a view exists.</li><li>A view model is aware of one or more repositories, which are passed into the view model's constructor.</li></ul>           |
| Repository | <ol><li>A repository can be aware of many services, which are passed as arguments into the repository constructor.</li><li>A repository can be used by many view models, but it never needs to be aware of them.</li></ol>                                        |
| Service    | <ol><li>A service can be used by many repositories, but it never needs to be aware of a repository (or any other object).</li></ol>                                                                                                                               |

{:.table .table-striped}

## Dependency injection

This guide has shown how these different components communicate
with each other by using inputs and outputs.
In every case, communication between two layers is facilitated by passing
a component into the constructor methods (of the components that
consume its data), such as a `Service` into a `Repository.`

```dart
class MyRepository {
  MyRepository({required MyService myService})
          : _myService = myService;

  late final MyService _myService;
}
```

One thing that's missing, however, is object creation. Where,
in an application, is the `MyService` instance created so that it can be
passed into `MyRepository`?
This answer to this question involves a
pattern known as [dependency injection][].

In the Compass app, *dependency injection* is handled using
[`package:provider`][]. Based on their experience building Flutter apps,
teams at Google recommend using `package:provider` to implement
dependency injection.

Services and repositories are exposed to the top level of the widget tree of
the Flutter application as `Provider` objects.

```dart title=dependencies.dart
runApp(
  MultiProvider(
    providers: [
      Provider(create: (context) => AuthApiClient()),
      Provider(create: (context) => ApiClient()),
      Provider(create: (context) => SharedPreferencesService()),
      ChangeNotifierProvider(
        create: (context) => AuthRepositoryRemote(
          authApiClient: context.read(),
          apiClient: context.read(),
          sharedPreferencesService: context.read(),
        ) as AuthRepository,
      ),
      Provider(create: (context) =>
        DestinationRepositoryRemote(
          apiClient: context.read(),
        ) as DestinationRepository,
      ),
      Provider(create: (context) =>
        ContinentRepositoryRemote(
          apiClient: context.read(),
        ) as ContinentRepository,
      ),
      // In the Compass app, additional service and repository providers live here.
    ],
    child: const MainApp(),
  ),
);
```

Services are exposed only so they can immediately be
injected into repositories via the `BuildContext.read` method from `provider`,
as shown in the preceding snippet.
Repositories are then exposed so that they can be
injected into view models as needed.

Slightly lower in the widget tree, view models that correspond to
a full screen are created in the [`package:go_router`][] configuration,
where provider is again used to inject the necessary repositories.

```dart title=router.dart
// This code was modified for demo purposes.
GoRouter router(
  AuthRepository authRepository,
) =>
    GoRouter(
      initialLocation: Routes.home,
      debugLogDiagnostics: true,
      redirect: _redirect,
      refreshListenable: authRepository,
      routes: [
        GoRoute(
          path: Routes.login,
          builder: (context, state) {
            return LoginScreen(
              viewModel: LoginViewModel(
                authRepository: context.read(),
              ),
            );
          },
        ),
        GoRoute(
          path: Routes.home,
          builder: (context, state) {
            final viewModel = HomeViewModel(
              bookingRepository: context.read(),
            );
            return HomeScreen(viewModel: viewModel);
          },
          routes: [
            // ...
          ],
        ),
      ],
    );
```

Within the view model or repository, the injected component should be private.
For example, the `HomeViewModel` class looks like this:

```dart title=home_viewmodel.dart
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required BookingRepository bookingRepository,
    required UserRepository userRepository,
  })  : _bookingRepository = bookingRepository,
        _userRepository = userRepository;

  final BookingRepository _bookingRepository;
  final UserRepository _userRepository;

  // ...
}
```

Private methods prevent the view, which has access to the view model, from
calling methods on the repository directly.

This concludes the code walkthrough of the Compass app. This page only walked
through the architecture-related code, but it doesn't tell the whole story. Most
utility code, widget code, and UI styling was ignored. Browse the code in
the [Compass app repository][] for a complete
example of a robust Flutter application built following these principles.

[`package:provider`]: {{site.pub-pkg}}/provider
[`package:go_router`]: {{site.pub-pkg}}/go_router
[Compass app repository]: https://github.com/flutter/samples/tree/main/compass_app
[dependency injection]: https://en.wikipedia.org/wiki/Dependency_injection

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="case-study/dependency-injection"

---
title: Testing each layer
shortTitle: Testing
description: >-
  How to test an app that implements MVVM architecture.
prev:
  title: Dependency injection
  path: /app-architecture/case-study/dependency-injection
---

## Testing the UI layer

One way to determine whether your architecture is sound is
considering how easy (or difficult) the application is to test.
Because view models and views have well-defined inputs,
their dependencies can easily be mocked or faked,
and unit tests are easily written.

### ViewModel unit tests

To test the UI logic of the view model, you should write unit tests that
don't rely on Flutter libraries or testing frameworks.

Repositories are a view model's only dependencies
(unless you're implementing [use-cases][]),
and writing `mocks` or `fakes` of the repository is
the only setup you need to do.
In this example test, a fake called `FakeBookingRepository` is used.

```dart title=home_screen_test.dart
void main() {
  group('HomeViewModel tests', () {
    test('Load bookings', () {
      // HomeViewModel._load is called in the constructor of HomeViewModel.
      final viewModel = HomeViewModel(
        bookingRepository: FakeBookingRepository()
          ..createBooking(kBooking),
        userRepository: FakeUserRepository(),
      );

      expect(viewModel.bookings.isNotEmpty, true);
    });
  });
}
```

The [`FakeBookingRepository`][] class implements [`BookingRepository`][].
In the [data layer section][] of this case-study,
the `BookingRepository` class is explained thoroughly.

```dart title=fake_booking_repository.dart
class FakeBookingRepository implements BookingRepository {
  List<Booking> bookings = List.empty(growable: true);

  @override
  Future<Result<void>> createBooking(Booking booking) async {
    bookings.add(booking);
    return Result.ok(null);
  }
  // ...
}
```

:::note
If you're using this architecture with [use-cases][], these would
similarly need to be faked.
:::

### View widget tests

Once you've written tests for your view model,
you've already created the fakes you need to write widget tests as well.
The following example shows how the `HomeScreen` widget tests
are set up using the `HomeViewModel` and needed repositories:

```dart title=home_screen_test.dart
void main() {
  group('HomeScreen tests', () {
    late HomeViewModel viewModel;
    late MockGoRouter goRouter;
    late FakeBookingRepository bookingRepository;

    setUp(() {
      bookingRepository = FakeBookingRepository()
        ..createBooking(kBooking);
      viewModel = HomeViewModel(
        bookingRepository: bookingRepository,
        userRepository: FakeUserRepository(),
      );
      goRouter = MockGoRouter();
      when(() => goRouter.push(any())).thenAnswer((_) => Future.value(null));
    });

    // ...
  });
}
```

This setup creates the two fake repositories needed,
and passes them into a `HomeViewModel` object.
This class doesn't need to be faked.

:::note
The code also defines a `MockGoRouter`.
The router is mocked using [`package:mocktail`][],
and is outside the scope of this case-study.
You can find general testing guidance in [Flutter's testing documentation][].
:::

After the view model and its dependencies are defined,
the Widget tree that will be tested needs to be created.
In the tests for `HomeScreen`, a `loadWidget` method is defined.

```dart title=home_screen_test.dart highlightLines=11-23
void main() {
  group('HomeScreen tests', () {
    late HomeViewModel viewModel;
    late MockGoRouter goRouter;
    late FakeBookingRepository bookingRepository;

    setUp(
      // ...
    );

    void loadWidget(WidgetTester tester) async {
      await testApp(
        tester,
        ChangeNotifierProvider.value(
          value: FakeAuthRepository() as AuthRepository,
          child: Provider.value(
            value: FakeItineraryConfigRepository() as ItineraryConfigRepository,
            child: HomeScreen(viewModel: viewModel),
          ),
        ),
        goRouter: goRouter,
      );
    }

    // ...
  });
}
```

This method turns around and calls `testApp`,
a generalized method used for all widget tests in the compass app.
It looks like this:

```dart title=testing/app.dart
void testApp(
  WidgetTester tester,
  Widget body, {
  GoRouter? goRouter,
}) async {
  tester.view.devicePixelRatio = 1.0;
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  await mockNetworkImages(() async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: [
          GlobalWidgetsLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          AppLocalizationDelegate(),
        ],
        theme: AppTheme.lightTheme,
        home: InheritedGoRouter(
          goRouter: goRouter ?? MockGoRouter(),
          child: Scaffold(
            body: body,
          ),
        ),
      ),
    );
  });
}
```

This function's only job is to create a widget tree that can be tested.

The `loadWidget` method passes in the unique parts of a widget tree for testing.
In this case, that includes the `HomeScreen` and its view model,
as well as some additional faked repositories that
are higher in the widget tree.

The most important thing to take away is that view and view model tests
only require mocking repositories if your architecture is sound.

## Testing the data layer

Similar to the UI layer, the components of the data layer have
well-defined inputs and outputs, making both sides fake-able.
To write unit tests for any given repository,
mock the services that it depends on.
The following example shows a unit test for the `BookingRepository`.

```dart title=booking_repository_remote_test.dart
void main() {
  group('BookingRepositoryRemote tests', () {
    late BookingRepository bookingRepository;
    late FakeApiClient fakeApiClient;

    setUp(() {
      fakeApiClient = FakeApiClient();
      bookingRepository = BookingRepositoryRemote(
        apiClient: fakeApiClient,
      );
    });

    test('should get booking', () async {
      final result = await bookingRepository.getBooking(0);
      final booking = result.asOk.value;
      expect(booking, kBooking);
    });
  });
}
```

To learn more about writing mocks and fakes,
check out examples in the [Compass App `testing` directory][] or
read [Flutter's testing documentation][].

[use-cases]: /app-architecture/guide#optional-domain-layer
[`FakeBookingRepository`]: https://github.com/flutter/samples/blob/main/compass_app/app/testing/fakes/repositories/fake_booking_repository.dart
[`BookingRepository`]: https://github.com/flutter/samples/tree/main/compass_app/app/lib/data/repositories/booking
[data layer section]: /app-architecture/case-study/data-layer
[`package:mocktail`]: {{site.pub-pkg}}/mocktail
[Flutter's testing documentation]: /testing/overview
[Compass App `testing` directory]: https://github.com/flutter/samples/tree/main/compass_app/app/testing

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="case-study/testing"

---
title: UI layer case study
shortTitle: UI layer
description: >-
  A walk-through of the UI layer of an app that implements MVVM architecture.
prev:
  title: Case study overview
  path: /app-architecture/case-study
next:
  title: Data Layer
  path: /app-architecture/case-study/data-layer
---

The [UI layer][] of each feature in your Flutter application should be
made up of two components: a **[`View`][]** and
a **[`ViewModel`][].**

![A screenshot of the booking screen of the compass app.](/assets/images/docs/app-architecture/case-study/mvvm-case-study-ui-layer-highlighted.png)

In the most general sense, view models manage UI state,
and views display UI state.
Views and view models have a one-to-one relationship;
for each view, there's exactly one corresponding view model that
manages that view's state.
Each pair of view and view model make up the UI for a single feature.
For example, an app might have classes called
`LogOutView` and a `LogOutViewModel`.

## Define a view model

A view model is a Dart class responsible for handling UI logic.
View models take domain data models as input and expose that data as
UI state to their corresponding views.
They encapsulate logic that the view can attach to
event handlers, like button presses, and
manage sending these events to the data layer of the app,
where data changes happen.

The following code snippet is a class declaration for
a view model class called the `HomeViewModel`.
Its inputs are the [repositories][] that provide its data.
In this case,
the view model is dependent on the
`BookingRepository` and `UserRepository` as arguments.

```dart title=home_viewmodel.dart
class HomeViewModel {
  HomeViewModel({
    required BookingRepository bookingRepository,
    required UserRepository userRepository,
  }) :
    // Repositories are manually assigned because they're private members.
    _bookingRepository = bookingRepository,
    _userRepository = userRepository;

  final BookingRepository _bookingRepository;
  final UserRepository _userRepository;
  // ...
}
```

View models are always dependent on data repositories,
which are provided as arguments to the view model's constructor.
View models and repositories have a many-to-many relationship,
and most view models will depend on multiple repositories.

As in the earlier `HomeViewModel` example declaration,
repositories should be private members on the view model,
otherwise views would have direct access to
the data layer of the application.

### UI state

The output of a view model is data that a view needs to render, generally
referred to as **UI State**, or just state. UI state is an immutable snapshot of
data that is required to fully render a view.

![A screenshot of the booking screen of the compass app.](/assets/images/docs/app-architecture/case-study/mvvm-case-study-ui-state-highlighted.png)

The view model exposes state as public members.
On the view model in the following code example,
the exposed data is a `User` object,
as well as the user's saved itineraries which
are exposed as an object of type `List<BookingSummary>`.

```dart title=home_viewmodel.dart
class HomeViewModel {
  HomeViewModel({
   required BookingRepository bookingRepository,
   required UserRepository userRepository,
  }) : _bookingRepository = bookingRepository,
      _userRepository = userRepository;

  final BookingRepository _bookingRepository;
  final UserRepository _userRepository;

  User? _user;
  User? get user => _user;

  List<BookingSummary> _bookings = [];

  /// Items in an [UnmodifiableListView] can't be directly modified,
  /// but changes in the source list can be modified. Since _bookings
  /// is private and bookings is not, the view has no way to modify the
  /// list directly.
  UnmodifiableListView<BookingSummary> get bookings => UnmodifiableListView(_bookings);

  // ...
}
```

As mentioned, the UI state should be immutable.
This is a crucial part of bug-free software.

The compass app uses the [`package:freezed`][] to
enforce immutability on data classes. For example,
the following code shows the `User` class definition.
`freezed` provides deep immutability,
and generates the implementation for useful methods like
`copyWith` and `toJson`.

```dart title=user.dart
@freezed
class User with _$User {
  const factory User({
    /// The user's name.
    required String name,

    /// The user's picture URL.
    required String picture,
  }) = _User;

  factory User.fromJson(Map<String, Object?> json) => _$UserFromJson(json);
}
```

:::note
In the view model example,
two objects are needed to render the view.
As the UI state for any given model grows in complexity,
a view model might have many more pieces of data from
many more repositories exposed to the view.
In some cases,
you might want to create objects that specifically represent the UI state.
For example, you could create a class named `HomeUiState`.
:::

### Updating UI state

In addition to storing state,
view models need to tell Flutter to re-render views when
the data layer provides a new state.
In the Compass app, view models extend [`ChangeNotifier`][] to achieve this.

```dart title=home_viewmodel.dart
class HomeViewModel [!extends ChangeNotifier!] {
  HomeViewModel({
   required BookingRepository bookingRepository,
   required UserRepository userRepository,
  }) : _bookingRepository = bookingRepository,
      _userRepository = userRepository;
  final BookingRepository _bookingRepository;
  final UserRepository _userRepository;

  User? _user;
  User? get user => _user;

  List<BookingSummary> _bookings = [];
  List<BookingSummary> get bookings => _bookings;

  // ...
}
```

`HomeViewModel.user` is a public member that the view depends on.
When new data flows from the data layer and
new state needs to be emitted, [`notifyListeners`][] is called.

<figure>

![A screenshot of the booking screen of the compass app.](/assets/images/docs/app-architecture/case-study/mvvm-case-study-update-ui-steps.png)

    <figcaption>
This figure shows from a high-level how new data in the repository
propagates up to the UI layer and triggers a re-build of your Flutter widgets.
    </figcaption>
</figure>

1. New state is provided to the view model from a Repository.
2. The view model updates its UI state to reflect the new data.
3. `ViewModel.notifyListeners` is called, alerting the View of new UI State.
4. The view (widget) re-renders.

For example, when the user navigates to the Home screen and the view model is
created, the `_load` method is called.
Until this method completes, the UI state is empty,
the view displays a loading indicator.
When the `_load` method completes, if it's successful,
there's new data in the view model, and it must
notify the view that new data is available.

```dart title=home_viewmodel.dart highlightLines=19
class HomeViewModel extends ChangeNotifier {
  // ...

 Future<Result> _load() async {
    try {
      final userResult = await _userRepository.getUser();
      switch (userResult) {
        case Ok<User>():
          _user = userResult.value;
          _log.fine('Loaded user');
        case Error<User>():
          _log.warning('Failed to load user', userResult.error);
      }

      // ...

      return userResult;
    } finally {
      notifyListeners();
    }
  }
}
```

:::note
`ChangeNotifier` and [`ListenableBuilder`][] (discussed later on this page) are
part of the Flutter SDK,
and provide a good solution for updating the UI when state changes.
You can also use a robust third-party state management solution, such as
[`package:riverpod`][], [`package:flutter_bloc`][], or [`package:signals`][].
These libraries offer different tools for handling UI updates.
Read more about using `ChangeNotifier` in
our [state-management documentation][].
:::

[`package:riverpod`]: {{site.pub-pkg}}/riverpod
[`package:flutter_bloc`]: {{site.pub-pkg}}/flutter_bloc
[`package:signals`]: {{site.pub-pkg}}/signals
[state-management documentation]: /data-and-backend/state-mgmt/intro

## Define a view

A view is a widget within your app.
Often, a view represents one screen in your app that
has its own route and includes a [`Scaffold`][] at the top of the
widget subtree, such as the `HomeScreen`, but this isn't always the case.

Sometimes a view is a single UI element that
encapsulates functionality that needs to be re-used throughout the app.
For example, the Compass app has a view called `LogoutButton`,
which can be dropped anywhere in the widget tree that a user might
expect to find a logout button.
The `LogoutButton` view has its own view model called `LogoutViewModel`.
And on larger screens, there might be multiple views on screen that
would take up the full screen on mobile.

:::note
"View" is an abstract term, and one view doesn't equal one widget.
Widgets are composable, and several can be combined to create one view.
Therefore, view models don't have a one-to-one relationship with widgets,
but rather a one-to-one relation with a *collection* of widgets.
:::

The widgets within a view have three responsibilities:

* They display the data properties from the view model.
* They listen for updates from the view model and re-render when new data is available.
* They attach callbacks from the view model to event handlers, if applicable.

![A diagram showing a view's relationship to a view model.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified-View-highlighted.png)


Continuing the Home feature example,
the following code shows the definition of the `HomeScreen` view.

```dart title=home_screen.dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.viewModel});

  final HomeViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ...
    );
  }
}
```

Most of the time, a view's only inputs should be a `key`,
which all Flutter widgets take as an optional argument,
and the view's corresponding view model.

### Display UI data in a view

A view depends on a view model for its state. In the Compass app,
the view model is passed in as an argument in the view's constructor.
The following example code snippet is from the `HomeScreen` widget.

```dart title=home_screen.dart
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, [!required this.viewModel!]});

  [!final HomeViewModel viewModel;!]

  @override
  Widget build(BuildContext context) {
    // ...
  }
}
```

Within the widget, you can access the passed-in bookings from the `viewModel`.
In the following code,
the `booking` property is being provided to a sub-widget.

```dart title=home_screen.dart
@override
  Widget build(BuildContext context) {
    return Scaffold(
      // Some code was removed for brevity.
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(...),
                SliverList.builder(
                   itemCount: [!viewModel.bookings.length!],
                    itemBuilder: (_, index) => _Booking(
                      key: ValueKey([!viewModel.bookings[index].id!]),
                      booking:viewModel.bookings[index],
                      onTap: () => context.push(Routes.bookingWithId(
                         viewModel.bookings[index].id)),
                      onDismissed: (_) => viewModel.deleteBooking.execute(
                           viewModel.bookings[index].id,
                         ),
                    ),
                ),
              ],
            );
          },
        ),
      ),
```

### Update the UI

The `HomeScreen` widget listens for updates from the view model with
the [`ListenableBuilder`][] widget.
Everything in the widget subtree under the `ListenableBuilder` widget
re-renders when the provided [`Listenable`][] changes.
In this case, the provided `Listenable` is the view model.
Recall that the view model is of type [`ChangeNotifier`][]
which is a subtype of the `Listenable` type.

```dart title=home_screen.dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    // Some code was removed for brevity.
      body: SafeArea(
        child: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(),
                SliverList.builder(
                  itemCount: viewModel.bookings.length,
                  itemBuilder: (_, index) =>
                      _Booking(
                        key: ValueKey(viewModel.bookings[index].id),
                        booking: viewModel.bookings[index],
                        onTap: () =>
                            context.push(Routes.bookingWithId(
                                viewModel.bookings[index].id)
                            ),
                        onDismissed: (_) =>
                            viewModel.deleteBooking.execute(
                              viewModel.bookings[index].id,
                            ),
                      ),
                ),
              ],
            );
          }
        )
      )
  );
}
```

### Handling user events

Finally, a view needs to listen for *events* from users,
so the view model can handle those events.
This is achieved by exposing a callback method on the view model class which
encapsulates all the logic.

![A diagram showing a view's relationship to a view model.](/assets/images/docs/app-architecture/guide/feature-architecture-simplified-UI-highlighted.png)

On the `HomeScreen`, users can delete previously booked events by swiping
a [`Dismissible`][] widget.

Recall this code from the previous snippet:

<CodePreview direction="row">

  <DashImage 
    image="app-architecture/case-study/dismissible.webp"
    alt="A clip that demonstrates the 'dismissible' functionality of the Compass app."
    img-style="max-height: 480px; border-radius: 12px; border: black 2px solid;"
    />

  ```dart title=home_screen.dart highlightLines=9-10
  SliverList.builder(
    itemCount: widget.viewModel.bookings.length,
    itemBuilder: (_, index) => _Booking(
      key: ValueKey(viewModel.bookings[index].id),
      booking: viewModel.bookings[index],
      onTap: () => context.push(
        Routes.bookingWithId(viewModel.bookings[index].id)
      ),
      onDismissed: (_) =>
        viewModel.deleteBooking.execute(widget.viewModel.bookings[index].id),
    ),
  ),
  ```

</CodePreview>

On the `HomeScreen`, a user's saved trip is represented by
the `_Booking` widget. When a `_Booking` is dismissed,
the `viewModel.deleteBooking` method is executed.

A saved booking is application state that persists beyond
a session or the lifetime of a view,
and only repositories should modify such application state.
So, the `HomeViewModel.deleteBooking` method turns around and
calls a method exposed by a repository in the data layer,
as shown in the following code snippet.

```dart title=home_viewmodel.dart highlightLines=3
Future<Result<void>> _deleteBooking(int id) async {
  try {
    final resultDelete = await _bookingRepository.delete(id);
    switch (resultDelete) {
      case Ok<void>():
        _log.fine('Deleted booking $id');
      case Error<void>():
        _log.warning('Failed to delete booking $id', resultDelete.error);
        return resultDelete;
    }

    // Some code was omitted for brevity.
    // final  resultLoadBookings = ...;

    return resultLoadBookings;
  } finally {
    notifyListeners();
  }
}
```

In the Compass app,
these methods that handle user events are called **commands**.

### Command objects

Commands are responsible for the interaction that starts in the UI layer and
flows back to the data layer. In this app specifically,
a `Command` is also a type that helps update the UI safely,
regardless of the response time or contents.

The `Command` class wraps a method and
helps handle the different states of that method,
such as `running`, `complete`, and `error`.
These states make it easy to display different UI,
like loading indicators when `Command.running` is true.

The following is code from the `Command` class.
Some code has been omitted for demo purposes.

```dart title=command.dart
abstract class Command<T> extends ChangeNotifier {
  Command();
  bool running = false;
  Result<T>? _result;

  /// true if action completed with error
  bool get error => _result is Error;

  /// true if action completed successfully
  bool get completed => _result is Ok;

  /// Internal execute implementation
  Future<void> _execute(action) async {
    if (_running) return;

    // Emit running state - e.g. button shows loading state
    _running = true;
    _result = null;
    notifyListeners();

    try {
      _result = await action();
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}
```

The `Command` class itself extends `ChangeNotifier`,
and within the method `Command.execute`,
`notifyListeners` is called multiple times.
This allows the view to handle different states with very little logic,
which you'll see an example of later on this page.

You may have also noticed that `Command` is an abstract class.
It's implemented by concrete classes such as `Command0` `Command1`.
The integer in the class name refers to
the number of arguments that the underlying method expects.
You can see examples of these implementation classes in
the Compass app's [`utils` directory][].

:::tip Package option
To use this pattern without writing your own command classes,
consider using a package such as [`command_it`][],
which provides command types to wrap actions and
track their running, completed, and error states.
:::

[`command_it`]: {{site.pub-pkg}}/command_it

### Ensuring views can render before data exists

In view model classes, commands are created in the constructor.

```dart title=home_viewmodel.dart highlightLines=8-9,15-16,24-30
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
   required BookingRepository bookingRepository,
   required UserRepository userRepository,
  }) : _bookingRepository = bookingRepository,
      _userRepository = userRepository {
    // Load required data when this screen is built.
    load = Command0(_load)..execute();
    deleteBooking = Command1(_deleteBooking);
  }

  final BookingRepository _bookingRepository;
  final UserRepository _userRepository;

  late Command0 load;
  late Command1<void, int> deleteBooking;

  User? _user;
  User? get user => _user;

  List<BookingSummary> _bookings = [];
  List<BookingSummary> get bookings => _bookings;

  Future<Result> _load() async {
    // ...
  }

  Future<Result<void>> _deleteBooking(int id) async {
    // ...
  }

  // ...
}
```

The `Command.execute` method is asynchronous,
so it can't guarantee that the data will be available when
the view wants to render. This gets at *why* the Compass app uses `Commands`.
In the view's `Widget.build` method,
the command is used to conditionally render different widgets.

```dart title=home_screen.dart
// ...
child: ListenableBuilder(
  listenable: [!viewModel.load!],
  builder: (context, child) {
    if ([!viewModel.load.running!]) {
      return const Center(child: CircularProgressIndicator());
    }

    if ([!viewModel.load.error!]) {
      return ErrorIndicator(
        title: AppLocalization.of(context).errorWhileLoadingHome,
        label: AppLocalization.of(context).tryAgain,
          onPressed: viewModel.load.execute,
        );
     }

    // The command has completed without error.
    // Return the main view widget.
    return child!;
  },
),

// ...
```

Because the `load` command is a property that exists on
the view model rather than something ephemeral,
it doesn't matter when the `load` method is called or when it resolves.
For example, if the load command resolves before
the `HomeScreen` widget was even created,
it isn't a problem because the `Command` object still exists,
and exposes the correct state.

This pattern standardizes how common UI problems are solved in the app,
making your codebase less error-prone and more scalable,
but it's not a pattern that every app will want to implement.
Whether you want to use it is highly dependent on
other architectural choices you make.
Many libraries that help you manage state have
their own tools to solve these problems.
For example, if you were to use
[streams][] and [`StreamBuilders`][] in your app,
the [`AsyncSnapshot`][] classes provided by Flutter have
this functionality built in.

:::note Real world example
While building the Compass app, we found a bug that was solved by using
the Command pattern. [Read about it on GitHub][].
:::

[UI layer]: /app-architecture/guide#ui-layer
[`View`]: /app-architecture/guide#views
[`ViewModel`]: /app-architecture/guide#view-models
[repositories]: /app-architecture/guide#repositories
[commands]: /app-architecture/guide#command-objects
[`package:freezed`]: {{site.pub-pkg}}/freezed
[`ChangeNotifier`]: {{site.api}}/flutter/foundation/ChangeNotifier-class.html
[`Listenable`]: {{site.api}}/flutter/foundation/Listenable-class.html
[`ListenableBuilder`]: {{site.api}}/flutter/widgets/ListenableBuilder-class.html
[`notifyListeners`]: {{site.api}}/flutter/foundation/ChangeNotifier/notifyListeners.html
[`Scaffold`]: {{site.api}}/flutter/material/Scaffold-class.html
[`Dismissible`]: {{site.api}}/flutter/widgets/Dismissible-class.html
[`utils` directory]: https://github.com/flutter/samples/blob/main/compass_app/app/lib/utils/command.dart
[streams]: {{site.api}}/flutter/dart-async/Stream-class.html
[`StreamBuilders`]: {{site.api}}/flutter/widgets/StreamBuilder-class.html
[`AsyncSnapshot`]: {{site.api}}/flutter/widgets/AsyncSnapshot-class.html
[Read about it on GitHub]: https://github.com/flutter/samples/pull/2449#pullrequestreview-2328333146

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="case-study/ui-layer"

---
title: Common architecture concepts
shortTitle: Architecture concepts
description: >
  Learn about common architecture concepts in application design,
  and how they apply to Flutter.
prev:
    title: Architecting Flutter apps
    path: /app-architecture
next:
    title: Guide to app architecture
    path: /app-architecture/guide
---

In this section, you'll find tried and true principles that guide architectural
decisions in the larger world of app development,
as well as information about how they fit into Flutter specifically.
It's a gentle introduction to vocabulary and concepts related to
the recommended architecture and best practices,
so they can be explored in more detail throughout this guide.

## Separation of concerns

[Separation-of-concerns][] is a core principle in app development that
promotes modularity and maintainability by dividing an application's
functionality into distinct, self-contained units. From a high-level,
this means separating your UI logic from your business logic.
This is often described as *layered* architecture.
Within each layer, you should further separate your application by
feature or functionality. For example, your application's authentication logic
should be in a different class than the search logic.

In Flutter, this applies to [widgets](/resources/glossary#widget) in the UI layer as well. You should write
reusable, lean widgets that hold as little logic as possible.

## Layered architecture

Flutter applications should be written in *layers*. Layered architecture is a
software design pattern that organizes an application into distinct layers, each
with specific roles and responsibilities. Typically, applications are separated
into 2 to 3 layers, depending on complexity.

<img src='/assets/images/docs/app-architecture/common-architecture-concepts/horizontal-layers-with-icons.png' alt="The three common layers of app architecture, the UI layer, logic layer, and data layer.">

* **UI layer** - Displays data to the user that is exposed by the business logic
  layer, and handles user interaction. This is also commonly referred to as the
  "presentation layer".
* **Logic layer** - Implements core business logic, and facilitates interaction
  between the data layer and UI layer. Commonly known as the "domain layer".
  The logic layer is optional, and only needs to be implemented if your
  application has complex business logic that happens on the client.
  Many apps are only concerned with presenting data to a user and
  allowing the user to change that data (colloquially known as CRUD apps).
  These apps might not need this optional layer.
* **Data layer** - Manages interactions with data sources, such as databases or
  platform plugins. Exposes data and methods to the business logic layer.

These are called "layers" because each layer can only communicate with the
layers directly below or above it. The UI layer shouldn't know that the data
layer exists, and vice versa.

## Single source of truth

Every data type in your app should have a [single source of truth][] (SSOT).
The source of truth is responsible for representing local or remote state.
If the data can be modified in the app,
the SSOT class should be the only class that can do so.

This can dramatically reduce the number of bugs in your application,
and it can simplify code because you'll only ever have one copy of the same data.

Generally, the source of truth for any given type of data in your application is
held in a class called a **Repository**, which is part of the data layer.
There is typically one repository class for each type of data in your app.

This principle can be applied across layers and components in your application
as well as within individual classes. For example,
a Dart class might use [getters][] to derive values from an SSOT field
(instead of having multiple fields that need to be updated independently)
or a list of [records][] to group related values
(instead of parallel lists whose indices might get out of sync).

## Unidirectional data flow

[Unidirectional data flow][] (UDF) refers to a design pattern that helps
decouple state from the UI that displays that state. In the simplest terms,
state flows from the data layer through the logic layer and eventually to the
widgets in the UI layer.
Events from user-interaction flow the opposite direction,
from the presentation layer back through the logic layer and to the data layer.

<img src='/assets/images/docs/app-architecture/common-architecture-concepts/horizontal-layers-with-UDF.png' alt="The three common layers of app architecture, the UI layer, logic layer, and data layer, and the flow of state from the data layer to the UI layer.">

In UDF, the update loop from user interaction to re-rendering the UI looks like
this:

1. [UI layer] An event occurs due to user interaction, such as a button being
   clicked. The widget's event handler callback invokes a method exposed by a
   class in the logic layer.
2. [Logic layer] The logic class calls methods exposed by a repository that
   know how to mutate the data.
3. [Data layer] The repository updates data (if necessary) and then provides the
   new data to the logic class.
4. [Logic layer] The logic class saves its new state, which it sends to the UI.
5. [UI layer] The UI displays the new state of the view model.

New data can also start at the data layer.
For example, a repository might poll an HTTP server for new data.
In this case, the data flow only makes the second half of the journey.
The most important idea is that data changes always happen
in the [SSOT][], which is the data layer.
This makes your code easier to understand, less error prone, and
prevents malformed or unexpected data from being created.


## UI is a function of (immutable) state

Flutter is declarative,
meaning that it builds its UI to reflect the current state of your app.
When state changes,
your app should trigger a rebuild of the UI that depends on that state.
In Flutter, you'll often hear this described as "UI is a function of state".

<img src='/assets/images/docs/app-architecture/common-architecture-concepts/ui-f-state.png' style="width:50%; margin:auto; display:block" alt="UI is a function of state.">

It's crucial that your data drive your UI, and not the other way around.
Data should be immutable and persistent,
and views should contain as little logic as possible.
This minimizes the possibility of data being lost when an app is closed,
and makes your app more testable and resilient to bugs.

## Extensibility

Each piece of architecture should have a well defined list of inputs and outputs.
For example, a view model in the logic layer should only
take in data sources as inputs, such as repositories,
and should only expose commands and data formatted for views.

Using clean interfaces in this way allows you to swap out
concrete implementations of your classes without needing to
change any of the code that consumes the interface.

## Testability

The principles that make software extensible also make software easier to test.
For example, you can test the self-contained logic of a view model by mocking a
repository.
The view model tests don't require you to mock other parts of your application,
and you can test your UI logic separate from Flutter widgets themselves.

Your app will also be more flexible.
It will be straightforward and low risk to add new logic and new UI.
For example, adding a new view model cannot break any logic
from the data or business logic layers.

The next section explains the idea of inputs and outputs for any given component
in your application's architecture.

[Separation-of-concerns]: https://en.wikipedia.org/wiki/Separation_of_concerns
[single source of truth]: https://en.wikipedia.org/wiki/Single_source_of_truth
[SSOT]: https://en.wikipedia.org/wiki/Single_source_of_truth
[getters]: {{site.dart-site}}/effective-dart/design#do-use-getters-for-operations-that-conceptually-access-properties
[records]: {{site.dart-site}}/language/records
[Unidirectional data flow]: https://en.wikipedia.org/wiki/Unidirectional_Data_Flow_(computer_science)

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="concepts"

---
title: Architecture design patterns
shortTitle: Design patterns
description: >-
  A collection of articles about useful design patterns for
  building Flutter applications.
prev:
  title: Recommendations
  path: /app-architecture/recommendations
showToc: false
---

If you've already read through the [architecture guide][] page,
or if you're comfortable with Flutter and the MVVM pattern,
the following articles are for you.

These articles aren't about high-level app architecture,
rather they're about solving specific design problems that improve your
application's code base regardless of how you've architected your app.
That said, the articles do assume the MVVM pattern laid out on the
previous pages in the code examples.

<ExpansionList list="design-patterns" baseId="design-patterns">

[architecture guide]: /app-architecture/guide

---
title: Guide to app architecture
shortTitle: Architecture guide
description: >-
  The recommended way to architect a Flutter app.
prev:
    title: Common architecture concepts
    path: /app-architecture/concepts
next:
  title: Architecture case study
  path: /app-architecture/case-study
---

The following pages demonstrate how to build an app using best practices.
The recommendations in this guide can be applied to most apps,
making them easier to scale, test, and maintain.
However, they're guidelines, not steadfast rules,
and you should adapt them to your unique requirements.

This section provides a high-level overview of how Flutter applications
can be architected. It explains the layers of an application,
along with the classes that exist within each layer.
The section after this provides concrete code samples and
walks through a Flutter application that's implemented these recommendations.

## Overview of project structure

[Separation-of-concerns][] is the most important principle to follow when
designing your Flutter app.
Your Flutter application should split into two broad layers,
the UI layer and the Data layer.

Each layer is further split into different components,
each of which has distinct responsibilities, a well-defined interface,
boundaries and dependencies.
This guide recommends you split your application into the following components:

* Views
* View models
* Repositories
* Services

### MVVM

If you've encountered the [Model-View-ViewModel architectural pattern][] (MVVM),
this will be familiar.
MVVM is an architectural pattern that separates a
feature of an application into three parts:
the `Model`, the `ViewModel` and the `View`.
Views and view models make up the UI layer of an application.
Repositories and services represent the data of an application,
or the model layer of MVVM.
Each of these components is defined in the next section.

<img src='/assets/images/docs/app-architecture/guide/mvvm-intro-with-layers.png' alt="MVVM architectural pattern">

Every feature in an application will contain one view to describe the UI and
one view model to handle logic,
one or more repositories as the sources of truth for your application data,
and zero or more services that interact with external APIs,
like client servers and platform plugins.

A single feature of an application might require all of the following objects:

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-example.png' alt="An example of the Dart objects that might exist in one feature using the architecture described on page.">

Each of these objects and the arrows that connect them will be explained
thoroughly by the end of this page. Throughout this guide,
the following simplified version of that diagram will be used as an anchor.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified.png' alt="A simplified diagram of the architecture described on this page.">

:::note
Apps with complex logic might also have a logic layer that sits in between the
UI layer and data layer. This logic layer is commonly called the *domain layer*.
The domain layer contains additional components often called *interactors* or
*use-cases*. The domain layer is covered later in this guide.
:::

[Model-View-ViewModel architectural pattern]: https://en.wikipedia.org/wiki/Model–view–viewmodel

## UI layer

An application's UI layer is responsible for interacting with the user.
It displays an application's data to the user and receives user input,
such as tap events and form inputs.

The UI reacts to data changes or user input.
When the UI receives new data from a Repository,
it should re-render to display that new data.
When the user interacts with the UI,
it should change to reflect that interaction.

The UI layer is made up of two architectural components,
based on the MVVM design pattern:

* **Views** describe how to present application data to the user.
  Specifically, they refer to *compositions of widgets* that make a feature.
  For instance, a view is often (but not always) a screen that
  has a `Scaffold` widget, along with
  all of the widgets below it in the widget tree.
  Views are also responsible for passing events to
  the view model in response to user interactions.
* **View models** contain the logic that converts app data into *UI State*,
  because data from repositories is often formatted differently from
  the data that needs to be displayed.
  For example, you might need to combine data from multiple repositories,
  or you might want to filter a list of data records.

Views and view models should have a one-to-one relationship.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-UI-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the view and view model objects highlighted.">

In the simplest terms,
a view model manages the UI state and the view displays that state.
Using views and view models, your UI layer can maintain state during
configuration changes (such as screen rotations),
and you can test the logic of your UI independently of Flutter widgets.

:::note
'View' is an abstract term, and one view doesn't equal one widget.
Widgets are composable, and several can be combined to create one view.
Therefore, view models don't have a one-to-one relationship with widgets,
but rather a one-to-one relationship with a *collection* of widgets.
:::

A feature of an application is user centric,
and therefore defined by the UI layer.
Every instance of a paired *view* and *view model* defines one feature in your app.
This is often a screen in your app, but it doesn't have to be.
For example, consider logging in and out.
Logging in is generally done on a specific screen whose
only purpose is to provide the user with a way to log in.
In the application code, the login screen would be
made up of a `LoginViewModel` class and a `LoginView` class.

On the other hand,
logging out of an app is generally not done on a dedicated screen.
The ability to log out is generally presented to the user as a button in
a menu, a user account screen, or any number of different locations.
It's often presented in multiple locations.
In such scenarios, you might have a `LogoutViewModel` and a `LogoutView` which
only contains a single button that can be dropped into other widgets.

### Views

In Flutter, views are the widget classes of your application.
Views are the primary method of rendering UI,
and shouldn't contain any business logic.
They should be passed all data they need to render from the view model.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-View-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the view object highlighted.">

The only logic a view should contain is:

* Simple if-statements to show and hide widgets based on a flag or nullable
  field in the view model
* Animation logic
* Layout logic based on device information, like screen size or orientation.
* Simple routing logic

All logic related to data should be handled in the view model.

### View models

A view model exposes the application data necessary to render a view.
In the architecture design described on this page,
most of the logic in your Flutter application lives in view models.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-ViewModel-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the view model object highlighted.">

A view model's main responsibilities include:

* Retrieving application data from repositories and transforming it into a
  format suitable for presentation in the view.
  For example, it might filter, sort, or aggregate data.
* Maintaining the current state needed in the view,
  so that the view can rebuild without losing data.
  For example, it might contain boolean flags to
  conditionally render widgets in the view, or a field that
  tracks which section of a carousel is active on screen.
* Exposes callbacks (called **commands**) to the view that can be
  attached to an event handler, like a button press or form submission.

Commands are named for the [command pattern][],
and are Dart functions that allow views to
execute complex logic without knowledge of its implementation.
Commands are written as members of the view model class to
be called by the gesture handlers in the view class.

You can find examples of views, view models, and commands on
the [UI layer][] portion of the [App architecture case study][].

For a gentle introduction to MVVM in Flutter,
check out the [state management fundamentals][].

[UI layer]: /app-architecture/case-study/ui-layer
[App architecture case study]: /app-architecture/case-study
[state management fundamentals]: /data-and-backend/state-mgmt/intro

## Data layer

The data layer of an app handles your business data and logic.
Two pieces of architecture make up the data layer: services and repositories.
These pieces should have well-defined inputs and outputs
to simplify their reusability and testability.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Data-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the Data layer highlighted.">

Using MVVM language, services and repositories make up your *model layer*.

### Repositories

[Repository][] classes are the source of truth for your model data.
They're responsible for polling data from services,
and transforming that raw data into **domain models**.
Domain models represent the data that the application needs,
formatted in a way that your view model classes can consume.
There should be a repository class for
each different type of data handled in your app.

Repositories handle the business logic associated with services, such as:

* Caching
* Error handling
* Retry logic
* Refreshing data
* Polling services for new data
* Refreshing data based on user actions

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Repository-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the Repository object highlighted.">

Repositories output application data as domain models.
For example, a social media app might have a
`UserProfileRepository` class that exposes a `Stream<UserProfile?>`,
which emits a new value whenever the user signs in or out.

The models output by repositories are consumed by view models.
Repositories and view models have a many-to-many relationship.
A view model can use many repositories to get the data it needs,
and a repository can be used by many view models.

Repositories should never be aware of each other.
If your application has business logic that needs data from two repositories,
you should combine the data in the view model or in the domain layer,
especially if your repository-to-view-model relationship is complex.

#### Managing app-wide session state

Because repositories are the single source of truth for application data,
they are also the ideal place to manage **app-wide lifecycle state**—state that
needs to be shared across multiple view models but shouldn't persist beyond the
current application session.

Examples of app-wide lifecycle state include an active user session,
in-memory data caches, or transient application settings.
Because view models and repositories have a many-to-many relationship,
multiple view models can depend on the same repository instance
(typically managed through a service locator or dependency injection container).
This allows distinct features to reactively observe and modify
the same shared state through streams and methods exposed by the repository,
without violating the clean one-to-one boundary between a view and its view model.

### Services

Services are in the lowest layer of your application.
They wrap API endpoints and expose asynchronous response objects,
such as `Future` and `Stream` objects.
They're only used to isolate data-loading, and they hold no state.
Your app should have one service class per data source.
Examples of endpoints that services might wrap include:

* The underlying platform, like iOS and Android APIs
* REST endpoints
* Local files

As a rule of thumb, services are most helpful when
the necessary data lives outside of your application's Dart code -
which is true of each of the preceding examples.

Services and repositories have a many-to-many relationship.
A single Repository can use several services,
and a service can be used by multiple repositories.

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-Service-highlighted.png'
  alt="A simplified diagram of the architecture described on this page with the Service object highlighted.">

## Optional: Domain layer

As your app grows and adds features, you might need to abstract away logic
that adds too much complexity to your view models.
These classes are often called interactors or **use-cases**.

Use-cases are responsible for making interactions between
the UI and Data layers simpler and more reusable.
They take data from repositories and make it suitable for the UI layer.

<img src='/assets/images/docs/app-architecture/guide/mvvm-intro-with-domain-layer.png'
  alt="MVVM design pattern with an added domain layer object">

Use-cases are primarily used to encapsulate business logic that would otherwise
live in the view model and meets one or more of the following conditions:

1. Requires merging data from multiple repositories
2. Is exceedingly complex
3. The logic will be reused by different view models

This layer is optional because not all applications or features within an
application have these requirements.
If you suspect your application would
benefit from this additional layer, consider the pros and cons:


| Pros                                                                     | Cons                                                                                       |
|--------------------------------------------------------------------------|--------------------------------------------------------------------------------------------|
| ✅ Avoid code duplication in view models                                  | ❌ Increases complexity of your architecture, adding more classes and higher cognitive load |
| ✅ Improve testability by separating complex business logic from UI logic | ❌ Testing requires additional mocks                                                        |
| ✅ Improve code readability in view models                                | ❌ Adds additional boilerplate to your code                                                 |

{:.table .table-striped}

### Data access with use-cases

Another consideration when adding a Domain layer is whether view models will
continue to have access to repository data directly, or if you'll enforce
view models to go through use-cases to get their data. Put another way,
will you add use-cases as you need them?
Perhaps when you notice repeated logic in your view models?
Or, will you create a use-case each time a view model needs data,
even if the logic in the use-case is simple?

If you choose to do the latter,
it intensifies the earlier outlined pros and cons.
Your application code will be extremely modular and testable,
but it also adds a significant amount of unnecessary overhead.

A good approach is to add use-cases only when needed.
If you find that your view models are
accessing data through use-cases most of the time,
you can always refactor your code to utilize use-cases exclusively.
The example app used later in this guide has use-cases for some features,
but also has view models that interact with repositories directly.
A complex feature might ultimately end up looking like this:

<img src='/assets/images/docs/app-architecture/guide/feature-architecture-simplified-with-logic-layer.png'
alt="A simplified diagram of the architecture described on this page with a use case object.">

This method of adding use-cases is defined by the following rules:

* Use-cases depend on repositories
* Use-cases and repositories have a many-to-many relationship
* View models depend on one or more use-cases *and* one or more repositories

This method of using use-cases ends up looking
less like a layered lasagna, and more like a plated dinner with
two mains (UI and data layers) and a side (domain layer).
Use-cases are just utility classes that have well-defined inputs and outputs.
This approach is flexible and extendable,
but it requires greater diligence to maintain order.

[Separation-of-concerns]: https://en.wikipedia.org/wiki/Separation_of_concerns
[command pattern]: https://en.wikipedia.org/wiki/Command_pattern
[Repository]: https://martinfowler.com/eaaCatalog/repository.html

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="guide"

---
title: Architecture recommendations and resources
shortTitle: Architecture recommendations
description: >
  Recommendations for building scalable Flutter applications.
prev:
  title: Architecture case study
  path: /app-architecture/case-study
next:
  title: Design patterns
  path: /app-architecture/design-patterns
---

This page presents architecture best practices, why they matter, and
whether we recommend them for your Flutter application.
You should treat these recommendations as recommendations,
and not steadfast rules, and you should
adapt them to your app's unique requirements.

The best practices on this page have a priority,
which reflects how strongly the Flutter team recommends it.

* **Strongly recommend:** You should always implement this recommendation if
  you're starting to build a new application. You should strongly consider
  refactoring an existing app to implement this practice unless doing so would
  fundamentally clash with your current approach.
* **Recommend**: This practice will likely improve your app.
* **Conditional**: This practice can improve your app in certain circumstances.

## Separation of concerns

You should separate your app into a UI layer and a data layer. Within those layers, 
you should further separate logic into classes by responsibility.

<ArchitectureRecommendations category="separation-of-concerns" />

## Handling data

Handling data with care makes your code easier to understand, less error prone, and
prevents malformed or unexpected data from being created.

<ArchitectureRecommendations category="handling-data" />

## App structure

Well organized code benefits both the health of the app itself, and the team working on the code.

<ArchitectureRecommendations category="app-structure" />

## Testing

Good testing practices makes your app flexible. 
It also makes it straightforward and low risk to add new logic and new UI.

<ArchitectureRecommendations category="testing" />

<a id="recommended-resources" aria-hidden="true"></a>

## Recommended resources {:#resources}

* Code and templates
  * [Compass app source code][] -
    Source code of a full-featured, robust Flutter application that
    implements many of these recommendations.
  * [very_good_cli][] -
    A Flutter application template made by
    the Flutter experts Very Good Ventures.
    This template generates a similar app structure.
* Documentation
  * [Very Good Engineering architecture documentation][] -
    Very Good Engineering is a documentation site by VGV that has
    technical articles, demos, and open-sourced projects.
    It includes documentation on architecting Flutter applications.
* Tooling
  * [Flutter developer tools][] -
    DevTools is a suite of performance and debugging tools for Dart and Flutter.
  * [flutter_lints][] -
    A package that contains the lints for
    Flutter apps recommended by the Flutter team.
    Use this package to encourage good coding practices across a team.


[Compass app source code]: https://github.com/flutter/samples/tree/main/compass_app
[very_good_cli]: https://cli.vgv.dev/
[Very Good Engineering architecture documentation]: https://engineering.verygood.ventures/architecture/architecture/
[Flutter developer tools]: /tools/devtools
[flutter_lints]: https://pub.dev/packages/flutter_lints

## Feedback

As this section of the website is evolving,
we [welcome your feedback][]!

[welcome your feedback]: https://google.qualtrics.com/jfe/form/SV_4T0XuR9Ts29acw6?page="recommendations"