import 'package:flutter/material.dart';

import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/dashboard/dashboard_screen.dart';

import '../features/medicine/add_medicine_screen.dart';
import '../features/medicine/medicine_list_screen.dart';
import '../features/medicine/medicine_transaction_history_screen.dart';
import '../features/medicine/record_transaction_screen.dart';
import '../features/medicine/edit_medicine_screen.dart';
import '../features/medicine/medicine_monitor_screen.dart';

import '../features/posts/create_post_screen.dart';
import '../features/posts/manage_posts_screen.dart';
import '../features/posts/edit_post_screen.dart';

import '../features/events/create_event_screen.dart';
import '../features/events/manage_events_screen.dart';
import '../features/events/edit_event_screen.dart';
import '../features/events/event_registrants_screen.dart';

import '../features/surveys/create_survey_screen.dart';
import '../features/surveys/manage_surveys_screen.dart';
import '../features/surveys/edit_survey_screen.dart';
import '../features/surveys/survey_responses_screen.dart';

import '../features/profile/profile_screen.dart';

import '../features/public/public_events_screen.dart';
import '../features/public/public_home_screen.dart';
import '../features/public/public_posts_screen.dart';
import '../features/public/public_surveys_screen.dart';
import '../features/public/social_health_updates_screen.dart';
import '../features/public/public_rhu_directory_screen.dart';
import '../features/public/public_activity_history_screen.dart';

import '../features/splash/splash_screen.dart';
import '../features/sync/sync_screen.dart';

import '../features/users/create_health_worker_screen.dart';
import '../features/users/users_screen.dart';

import '../features/prescriptions/create_prescription_screen.dart';
import '../features/prescriptions/pharmacist_prescription_scanner_screen.dart';
import '../features/prescriptions/pharmacist_claimed_prescriptions_screen.dart';
import '../features/prescriptions/prescription_claim_monitor_screen.dart';

import '../features/appointments/apply_appointment_screen.dart';
import '../features/appointments/manage_appointments_screen.dart';
import '../features/appointments/my_appointments_screen.dart';
import '../features/appointments/appointment_qr_checkin_screen.dart';
import '../features/appointments/appointment_chat_screen.dart';
import '../features/appointments/appointment_availability_settings_screen.dart';
import '../features/appointments/patient_view_screen.dart';

import '../features/messages/public_messages_screen.dart';

import '../features/notifications/notification_center_screen.dart';

import '../features/video/video_call_screen.dart';


class AppRoutes {
  AppRoutes._();

  static const String splash = SplashScreen.routeName;
  static const String login = LoginScreen.routeName;
  static const String register = RegisterScreen.routeName;
  static const String dashboard = DashboardScreen.routeName;

  static const String medicines = MedicineListScreen.routeName;
  static const String addMedicine = AddMedicineScreen.routeName;
  static const String recordTransaction = RecordTransactionScreen.routeName;
  static const String medicineTransactions = MedicineTransactionHistoryScreen.routeName;
  static const String editMedicine = EditMedicineScreen.routeName;
  static const String medicineMonitor = MedicineMonitorScreen.routeName;

  static const String managePosts = ManagePostsScreen.routeName;
  static const String createPost = CreatePostScreen.routeName;
  static const String editPost = EditPostScreen.routeName;

  static const String manageEvents = ManageEventsScreen.routeName;
  static const String createEvent = CreateEventScreen.routeName;
  static const String editEvent = EditEventScreen.routeName;
  static const String eventRegistrants = EventRegistrantsScreen.routeName;

  static const String manageSurveys = ManageSurveysScreen.routeName;
  static const String createSurvey = CreateSurveyScreen.routeName;
  static const String editSurvey = EditSurveyScreen.routeName;
  static const String surveyResponses = SurveyResponsesScreen.routeName;

  static const String sync = SyncScreen.routeName;
  static const String profile = ProfileScreen.routeName;

  static const String publicHome = PublicHomeScreen.routeName;
  static const String publicPosts = PublicPostsScreen.routeName;
  static const String publicEvents = PublicEventsScreen.routeName;
  static const String publicSurveys = PublicSurveysScreen.routeName;
  static const String socialHealthUpdates = SocialHealthUpdatesScreen.routeName;
  static const String publicRhus = PublicRhuDirectoryScreen.routeName;
  static const String publicActivityHistory = PublicActivityHistoryScreen.routeName;

  static const String users = UsersScreen.routeName;
  static const String createHealthWorker = CreateHealthWorkerScreen.routeName;


  static const String createPrescription = CreatePrescriptionScreen.routeName;
  static const String pharmacistPrescriptionScanner = PharmacistPrescriptionScannerScreen.routeName;
  static const String pharmacistClaimedPrescriptions = PharmacistClaimedPrescriptionsScreen.routeName;
  static const String prescriptionClaimMonitor = PrescriptionClaimMonitorScreen.routeName;


  static const String applyAppointment = ApplyAppointmentScreen.routeName;
  static const String manageAppointments = ManageAppointmentsScreen.routeName;
  static const String myAppointments = MyAppointmentsScreen.routeName;
  static const String appointmentQrCheckIn = AppointmentQrCheckInScreen.routeName;
  static const String appointmentChat = AppointmentChatScreen.routeName;
  static const String appointmentSettings = AppointmentAvailabilitySettingsScreen.routeName;
  static const String patientView = PatientViewScreen.routeName;

  static const String publicMessages = PublicMessagesScreen.routeName;

  static const String notifications = NotificationCenterScreen.routeName;

  static const String videoCall = VideoCallScreen.routeName;


  static Map<String, WidgetBuilder> get routes {

    


    return <String, WidgetBuilder>{
      splash: (BuildContext context) => const SplashScreen(),
      login: (BuildContext context) => const LoginScreen(),
      register: (BuildContext context) {return const RegisterScreen();},
      dashboard: (BuildContext context) => const DashboardScreen(),

      medicines: (BuildContext context) => const MedicineListScreen(),
      addMedicine: (BuildContext context) => const AddMedicineScreen(),
      recordTransaction: (BuildContext context) =>
          const RecordTransactionScreen(),
      medicineTransactions: (BuildContext context) =>
          const MedicineTransactionHistoryScreen(),
      editMedicine: (BuildContext context) {
        final Object? arguments = ModalRoute.of(context)?.settings.arguments;

        if (arguments is EditMedicineArguments) {
          return EditMedicineScreen(
            medicine: arguments.medicine,
          );
        }

        return const Scaffold(
          body: Center(
            child: Text('Medicine data is missing.'),
          ),
        );
      },
      medicineMonitor: (BuildContext context) {
        return const MedicineMonitorScreen();
      },

      managePosts: (BuildContext context) => const ManagePostsScreen(),
      createPost: (BuildContext context) => const CreatePostScreen(),
      editPost: (BuildContext context) {
        final Object? arguments = ModalRoute.of(context)?.settings.arguments;

        if (arguments is EditPostArguments) {
          return EditPostScreen(
            post: arguments.post,
          );
        }

        return const Scaffold(
          body: Center(
            child: Text('Post data is missing.'),
          ),
        );
      },

      manageEvents: (BuildContext context) => const ManageEventsScreen(),
      createEvent: (BuildContext context) => const CreateEventScreen(),
      editEvent: (BuildContext context) {
        final Object? arguments = ModalRoute.of(context)?.settings.arguments;

        if (arguments is EditEventArguments) {
          return EditEventScreen(
            event: arguments.event,
          );
        }

        return const Scaffold(
          body: Center(
            child: Text('Event data is missing.'),
          ),
        );
      },
      eventRegistrants: (BuildContext context) {
        return const EventRegistrantsScreen();
      },

      manageSurveys: (BuildContext context) => const ManageSurveysScreen(),
      createSurvey: (BuildContext context) => const CreateSurveyScreen(),
      editSurvey: (BuildContext context) {
        final Object? arguments = ModalRoute.of(context)?.settings.arguments;

        if (arguments is EditSurveyArguments) {
          return EditSurveyScreen(
            survey: arguments.survey,
          );
        }

        return const Scaffold(
          body: Center(
            child: Text('Survey data is missing.'),
          ),
        );
      },
      surveyResponses: (BuildContext context) {
        return const SurveyResponsesScreen();
      },


      socialHealthUpdates: (BuildContext context) {
        return const SocialHealthUpdatesScreen();
      },
      publicRhus: (BuildContext context) {
        return const PublicRhuDirectoryScreen();
      },
      publicActivityHistory: (BuildContext context) {
        return const PublicActivityHistoryScreen();
      },


      createPrescription: (BuildContext context) {
        return const CreatePrescriptionScreen();
      },
      pharmacistPrescriptionScanner: (BuildContext context) {
        return const PharmacistPrescriptionScannerScreen();
      },
      pharmacistClaimedPrescriptions: (BuildContext context) {
        return const PharmacistClaimedPrescriptionsScreen();
      },
      prescriptionClaimMonitor: (BuildContext context) {
        return const PrescriptionClaimMonitorScreen();
      },


      applyAppointment: (BuildContext context) {
        final Object? args = ModalRoute.of(context)?.settings.arguments;

        String? preselectedRhuId;

        if (args is String) {
          preselectedRhuId = args;
        }

        if (args is Map<String, dynamic>) {
          preselectedRhuId = args['rhuId']?.toString();
        }

        return ApplyAppointmentScreen(
          preselectedRhuId: preselectedRhuId,
        );
      },
      manageAppointments: (BuildContext context) {
        return const ManageAppointmentsScreen();
      },
      myAppointments: (BuildContext context) {
        return const MyAppointmentsScreen();
      },
      appointmentQrCheckIn: (BuildContext context) {
        return const AppointmentQrCheckInScreen();
      },
      appointmentChat: (BuildContext context) {
        final Object? args = ModalRoute.of(context)?.settings.arguments;

        return AppointmentChatScreen(
          appointment: args is Map<String, dynamic> ? args : null,
        );
      },
      appointmentSettings: (BuildContext context) {
        return const AppointmentAvailabilitySettingsScreen();
      },
      patientView: (BuildContext context) {
        return const PatientViewScreen();
      },
      

      publicMessages: (BuildContext context) {
        return const PublicMessagesScreen();
      },

      notifications: (BuildContext context) {
        return const NotificationCenterScreen();
      },

      videoCall: (BuildContext context) {
        return const VideoCallScreen();
      },

      sync: (BuildContext context) => const SyncScreen(),
      profile: (BuildContext context) => const ProfileScreen(),

      users: (BuildContext context) => const UsersScreen(),
      createHealthWorker: (BuildContext context) =>
      const CreateHealthWorkerScreen(),

      publicHome: (BuildContext context) => const PublicHomeScreen(),
      publicPosts: (BuildContext context) => const PublicPostsScreen(),
      publicEvents: (BuildContext context) => const PublicEventsScreen(),
      publicSurveys: (BuildContext context) => const PublicSurveysScreen(),
    };




    
  }
}